# Phân tích độ khó và chỉ số (GD3-232, GD3-234)

Dữ liệu: Firebase Analytics → **BigQuery export** (bật trong Firebase console → Project settings → Integrations →
BigQuery, chọn "Daily"; gói Spark miễn phí giới hạn 1 GB xuất/ngày, đủ cho giai đoạn thử). Bảng
`<project>.analytics_<id>.events_YYYYMMDD`. Event do game gửi: `level_start`, `level_end`, `new_best`, `first_clear`,
`song_select`, `song_unlock`, `rewarded_trial`, `ad_shown`, `shop_view`, `iap_click`, `calibration_done`,
`perf_sample` (định nghĩa: `src/presentation/level/run_telemetry.gd`, `docs/todo.md` GD3-231).

Hàm tiện dụng (dán trước mỗi truy vấn):
```sql
CREATE TEMP FUNCTION p_str(params ANY TYPE, k STRING) AS ((SELECT value.string_value FROM UNNEST(params) WHERE key = k));
CREATE TEMP FUNCTION p_num(params ANY TYPE, k STRING) AS ((SELECT COALESCE(value.int_value, value.double_value) FROM UNNEST(params) WHERE key = k));
```

## 1. Tỉ lệ qua màn, số lần thử tới lần qua đầu, bỏ chơi sau khi chết
```sql
WITH ends AS (
  SELECT user_pseudo_id AS user, p_str(event_params, 'song_id') AS song, p_str(event_params, 'result') AS result,
         p_num(event_params, 'attempt') AS attempt, event_timestamp AS ts
  FROM `PROJECT.analytics_ID.events_*`
  WHERE event_name = 'level_end' AND p_str(event_params, 'mode') = 'normal'
    AND _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)) AND FORMAT_DATE('%Y%m%d', CURRENT_DATE()))
SELECT song,
  COUNT(*) AS runs,
  COUNTIF(result = 'complete') / COUNT(*) AS clear_rate,
  COUNTIF(result = 'quit') / COUNT(*) AS quit_rate,
  APPROX_QUANTILES(IF(result = 'complete', attempt, NULL), 2 IGNORE NULLS)[OFFSET(1)] AS median_attempts_to_clear
FROM ends GROUP BY song ORDER BY clear_rate;
```
*Lưu ý:* `attempt` đếm trong một lần mở màn (về menu là đếm lại); số lần thử tích lũy tới lần qua đầu lấy từ
`first_clear.attempts` cộng các phiên trước — xem truy vấn 5.

## 2. Bản đồ chỗ chết (ô 4 beat) và điểm nghẽn theo cue
```sql
WITH deaths AS (
  SELECT p_str(event_params, 'song_id') AS song, p_num(event_params, 'death_beat') AS beat,
         p_str(event_params, 'death_cue') AS cue, p_str(event_params, 'hazard_id') AS hazard
  FROM `PROJECT.analytics_ID.events_*`
  WHERE event_name = 'level_end' AND p_str(event_params, 'result') = 'dead' AND p_str(event_params, 'mode') = 'normal'),
reach AS (  -- mọi lượt của bài (mẫu số); lượt *tới được* một cue = lượt có progress_pct vượt vị trí cue
  SELECT p_str(event_params, 'song_id') AS song, p_num(event_params, 'progress_pct') AS pct
  FROM `PROJECT.analytics_ID.events_*` WHERE event_name = 'level_end')
SELECT song, cue, hazard, COUNT(*) AS deaths,
  COUNT(*) / ANY_VALUE(total_runs) AS death_share
FROM deaths JOIN (SELECT song, COUNT(*) AS total_runs FROM reach GROUP BY song) USING (song)
GROUP BY song, cue, hazard ORDER BY deaths DESC LIMIT 50;
```
**Điểm nghẽn** = cue có `deaths / số lượt tới được nó` cao bất thường so với các cue cùng bài (vd. > 3× trung vị).
Cách sửa: xem lại cue trong chart (vật cản hiện muộn, lệch nhạc, quá khó) bằng `tolerance_report.gd` và sửa hoặc làm mềm.
Bản đồ nhiệt: `FLOOR(beat / 4) * 4` thay cho `cue` ở `GROUP BY`.

## 3. Lệch nhạc
`level_end.mean_error_ms` là độ lệch trung bình có dấu của *cả lượt* (dương = chạm muộn). Phân phối theo bài:
```sql
SELECT p_str(event_params, 'song_id') AS song, APPROX_QUANTILES(p_num(event_params, 'mean_error_ms'), 4) AS quartiles_ms
FROM `PROJECT.analytics_ID.events_*` WHERE event_name = 'level_end' AND p_num(event_params, 'perfect') > 10
GROUP BY song;
```
Một bài lệch đều (vd. +30 ms trong khi bài khác ~0) → `offset` của chart sai. **Chưa có** lệch theo từng cue (giữ luật
"một event mỗi lượt"); nếu cần, thêm vào `level_end` chuỗi lệch của 10 cue lệch nhất (≤ 100 ký tự) — hỏi trước.

## 4. So độ khó thật với `ChartDifficulty`
Ghép `clear_rate` (truy vấn 1) với điểm `ChartDifficulty.score` của từng chart (in bằng script trong
`docs/design/song_unlocks.md`), xếp hạng hai cột và tính tương quan Spearman; bài lệch hạng nhiều → chỉnh trọng số trong
`src/gameplay/chart/chart_difficulty.gd` hoặc đổi thứ tự (ảnh hưởng chuỗi mở khóa GD3-242 — Remote Config sau này).

## 5. Phễu bài và mở khóa
```sql
SELECT p_str(event_params, 'song_id') AS song, event_name, COUNT(DISTINCT user_pseudo_id) AS players
FROM `PROJECT.analytics_ID.events_*` WHERE event_name IN ('level_start', 'song_unlock', 'first_clear')
GROUP BY song, event_name ORDER BY song, event_name;
```
Đọc theo thứ tự chuỗi: % người chơi tới bài 2, 3, …; tỉ lệ dùng `rewarded_trial` trên bài khóa; `iap_click` sau
`shop_view`.

## 6. Hiệu năng ngoài thực tế (GD3-235)
```sql
SELECT device.mobile_model_name AS model, p_str(event_params, 'tier') AS tier,
  APPROX_QUANTILES(p_num(event_params, 'fps_p10'), 2)[OFFSET(1)] AS median_fps_p10, COUNT(*) AS sessions
FROM `PROJECT.analytics_ID.events_*` WHERE event_name = 'perf_sample'
GROUP BY model, tier HAVING sessions >= 5 ORDER BY median_fps_p10;
```
Máy có `fps_p10 < 50` ở tier tự chọn → hạ ngưỡng chọn tier trong `QualityAutoTuner` cho model đó hoặc toàn bộ.

## Dashboard (GD3-234)
Looker Studio → nguồn BigQuery → mỗi truy vấn trên thành một bảng/biểu đồ: (1) tỉ lệ qua màn theo bài, (2) chỗ chết,
(5) phễu, (6) FPS theo máy; thêm từ Firebase console: retention D1/D7/D30, DAU/MAU, doanh thu (AdMob + Play liên kết).
Mốc tham khảo: `docs/todo.md` mục 7.
