# TODO — Kế hoạch phát hành GeoDash3D

Danh sách việc **để lên kế hoạch**, chưa bắt đầu (lập 2026-10-15). Khi bắt đầu một mục, chuyển nó sang
`docs/roadmap.md` (giữ nguyên mã `GD3-2xx`) và cập nhật trạng thái ở đó.

- **Ai làm:** Claude = code/tool/tài liệu · Người dùng = tài khoản, tiền, pháp lý, quyết định, chơi thử · Cả hai.
- **Công sức (phần code, ước lượng thô):** S ≤ 1 ngày · M 2–5 ngày · L 1–2 tuần · XL > 2 tuần.
- Mọi SDK/plugin bên ngoài (Firebase, AdMob, Billing, In-App Review…) **cần người dùng duyệt trước** (CLAUDE.md §7),
  và phải đo FPS/bộ nhớ trên máy thật sau khi thêm (ưu tiên tối thượng: giữ FPS).

## 0. Việc chặn phát hành — quyết định sớm
- [~] **GD3-200** (→ roadmap Phase 7) Giấy phép nhạc (Người dùng). Mọi bài trong `assets/music/` đang **chưa xác nhận dùng thương mại**
      (Google Flow Music, hdgstudio86 — CLAUDE.md §8). Phải có xác nhận quyền dùng trong game bán/quảng cáo, hoặc
      thay bài. Không lên store khi chưa xong.
- [~] **GD3-201** (→ roadmap Phase 7) Tên game, icon, thương hiệu (Người dùng quyết, Claude gợi ý). "GeoDash" dễ bị coi là gần
      "Geometry Dash" (RobTop) → rủi ro bị gỡ/khiếu nại; nên chọn tên riêng, kiểm tra trùng tên trên cả hai store.
- [~] **GD3-202** (→ roadmap Phase 7) Chính sách quyền riêng tư + điều khoản sử dụng, có URL công khai (Cả hai, S). Bắt buộc khi có
      Firebase/quảng cáo/IAP; nội dung phải khớp với form Data safety (Play) và Privacy labels (Apple).
- [~] **GD3-203** (→ roadmap Phase 7) Đối tượng người chơi: đặt 13+ (không nhắm trẻ em) để tránh ràng buộc Families/COPPA với quảng cáo.

## 1. Thử màn hình dọc (dễ làm video marketing)
- [~] **GD3-210** (→ roadmap Phase 7) Prototype dọc (Claude, M): tùy chọn hướng màn hình theo build, bộ shot camera cho 9:16 (góc nhìn
      ngang hiện tại quá hẹp khi dọc → thử nhìn từ sau/trên cao), HUD và safe area dọc, chụp ảnh 720×1280, đo FPS trên máy.
- [ ] **GD3-211** Tiêu chí quyết định (Cả hai): thấy trước được ≥ 1.5 s đường phía trước; người chơi thử chết không
      nhiều hơn bản ngang ở cùng màn; FPS không kém bản ngang; dàn LED và vật cản dưới đường vẫn đọc được.
- [x] **GD3-212** (→ roadmap Phase 7) Phương án rẻ nếu dọc không hợp (Claude, S–M): giữ gameplay ngang, thêm chế độ quay video dọc
      (camera dọc + xuất chuỗi ảnh/clip) chỉ để làm TikTok/Shorts/Reels.

## 2. Công cụ làm level
- [x] **GD3-220** (→ roadmap Phase 7) Một lệnh sinh level (Claude, M): `python tools/charting/auto_level.py <bài.mp3>` tự đo BPM/offset,
      kiểm tra bài có hợp game (`hit_grid` ≥ 50 % ô nhịp) và có nằm trên lưới nhịp, tạo dữ liệu LED, chọn độ khó theo
      mật độ cú đánh và bảng màu, sinh level LED, tự kiểm tra (nạp chart, autoplay qua màn, dung sai) và in báo cáo;
      chỉ dừng hỏi khi không chắc (2 ứng viên BPM sát nhau, bài không đạt).
- [ ] **GD3-221** Sinh level ngay trong game từ nhạc của người chơi (Claude, XL): chuyển phần phân tích (FFT, onset,
      bước nhảy LED) sang GDScript hoặc GDExtension C++, chạy ở thread nền, lưu chart vào `user://`. Phân tích một bài
      3 phút trên điện thoại có thể mất vài chục giây đến vài phút; bài nào cũng thành màn (kể cả bài không hợp).
      Là điều kiện của gói IAP "tự tạo level" (GD3-243).

## 3. Firebase: tìm lỗi và chỉ số
Firebase **không có SDK chính thức cho Godot**. Plugin cộng đồng dạng REST không có Crashlytics → nên tự viết plugin
Android (Godot Android plugin v2 bọc Firebase Android SDK), iOS làm sau (GD3-262).
- [~] **GD3-230** (→ roadmap Phase 7) Plugin Firebase Android (Claude, L): Crashlytics (crash + ANR; `push_error` của GDScript gửi thành
      lỗi non-fatal), Analytics, Remote Config. Lớp GDScript `Telemetry` để code game không gọi thẳng plugin
      (PC/test: không gửi gì). Không gửi gì trong attract mode/autoplay/capture.
- [~] **GD3-231** (→ roadmap Phase 7) Bộ event (Claude, M) — gửi **một event mỗi lượt chơi**, không gửi theo từng lần chạm:

  | Event | Tham số chính |
  |---|---|
  | `level_start` | song_id, chart_version, mode (normal/practice), attempt, quality_tier |
  | `level_end` | song_id, result (dead/complete/quit), progress_pct, death_beat, death_cue, hazard_id, duration_sec, perfect/great/good/miss, max_combo, score, mean_error_ms, shields_used, miss_cues (chuỗi ≤ 100 ký tự) |
  | `new_best`, `first_clear` | song_id, score, attempts |
  | `calibration_done` | offset_ms, cách (thủ công/tự học) |
  | `perf_sample` (1 lần/phiên) | tier, fps_p50, fps_p10, scene (model máy Firebase tự ghi) |
  | `song_select`, `shop_view`, `iap_click`, `rate_prompt_shown` | song_id / product_id |

  User property: quality_tier, no_ads, songs_unlocked, songs_cleared. Quảng cáo và mua hàng: dùng event tự động
  khi liên kết AdMob/Play (`ad_impression` có doanh thu, `in_app_purchase`).
- [ ] **GD3-232** Phân tích độ khó level (Cả hai, M) — phương pháp:
      1. Mỗi chart: tỉ lệ qua màn (complete/start), số lần thử tới lần qua đầu (trung vị), phân bố % xa nhất, tỉ lệ
         bỏ chơi sau khi chết, biểu đồ chỗ chết theo ô 4 beat và theo cue/vật cản.
      2. **Điểm nghẽn:** cue có tỉ lệ chết cao bất thường trong số lượt tới được nó → xem lại (vật cản hiện muộn,
         lệch nhạc, quá khó) và sửa chart hoặc làm mềm.
      3. **Lệch nhạc theo cue:** độ lệch trung bình có dấu của từng cue; cue nào người chơi luôn chạm sớm/muộn
         (vd. +40 ms) trong khi tổng thể ~0 → cue đặt lệch tiếng, đặt lại (phản hồi cho tool làm level).
      4. So độ khó thật với công thức `ChartDifficulty` → chỉnh trọng số, sắp lại danh sách bài và nhãn EASY…EXPERT.
      5. Phễu: % người chơi tới bài 2, 3, … → thứ tự bài và nhịp mở khóa.
- [ ] **GD3-233** Remote Config + A/B (Claude, M): cửa sổ timing, số PERFECT để nạp lá chắn, bậc tốc độ, tần suất
      quảng cáo, thứ tự bài — đổi không cần cập nhật app. Giữ tất định: giá trị chốt lúc bắt đầu lượt.
- [ ] **GD3-234** Dashboard (Cả hai, S–M): Firebase console + xuất BigQuery (phân tích theo cue; gói miễn phí có
      giới hạn) + Looker Studio cho các bảng ở mục 7.
- [ ] **GD3-235** Hiệu năng ngoài thực tế (Claude, S): FPS p50/p10 theo model máy và tier từ `PerfProbe`, thời gian
      tải màn; chỉnh ngưỡng tự chọn tier (`QualityAutoTuner`) theo dữ liệu thật.

## 4. Kiếm tiền
- [ ] **GD3-240** Quảng cáo AdMob (Claude, L; ứng viên plugin: Poing Studios `godot-admob-plugin`, cần duyệt):
      - Interstitial chỉ **giữa các lượt**: sau khi qua màn hoặc khi về menu, giới hạn tần suất (vd. ≥ 3 phút chơi
        giữa 2 lần), **không** hiện sau mỗi lần chết (game tự chơi lại sau 0.9 s).
      - Rewarded (tự nguyện): vd. mở thử 1 bài bị khóa, hoặc bắt đầu lượt với 1 lá chắn.
      - Banner: chỉ ở menu, không bao giờ trong lúc chơi.
      - Khi quảng cáo mở: dừng nhạc và `SongClock`, khôi phục đúng khi quay lại. Không bao giờ chen giữa lượt chơi.
      - Đồng ý dữ liệu: Google UMP (bắt buộc với EEA/UK), ATT trên iOS. Đo FPS và bộ nhớ trước/sau khi thêm SDK.
- [ ] **GD3-241** IAP (Claude, L; Google Play Billing — plugin chính thức Godot; iOS StoreKit — cần duyệt):
      - `remove_ads` (non-consumable): bỏ interstitial và banner, giữ rewarded tự nguyện.
      - `unlock_all_songs` (non-consumable), có thể gộp gói `remove_ads + unlock_all` giá ưu đãi.
      - `creator_mode` (non-consumable): tự tạo level bằng nhạc riêng (GD3-243).
      - Nút **Restore purchases** (Apple bắt buộc), quyền lợi lưu cục bộ + kiểm tra lại với store khi mở app.
- [ ] **GD3-242** Chính sách khóa bài (Người dùng quyết, Claude làm S–M): bao nhiêu bài miễn phí, bài khóa mở bằng
      tiến độ / xem quảng cáo / IAP; hiển thị khóa và giá trong danh sách bài.
- [ ] **GD3-243** Chế độ tự tạo level (Claude, L, cần GD3-221): chọn file nhạc trên máy → phân tích → chơi, lưu
      kỷ lục riêng. Nhạc người chơi chỉ dùng cục bộ, không có chia sẻ (tránh vấn đề bản quyền và kiểm duyệt).
- [ ] **GD3-244** Mời đánh giá (Claude, S–M): Google Play In-App Review API, `SKStoreReviewController` trên iOS
      (Apple chỉ hiện tối đa 3 lần/365 ngày; Google có quota, có thể không hiện). Chỉ gọi sau khoảnh khắc vui
      (qua màn lần đầu, NEW BEST, ≥ 3 phiên), không bao giờ sau khi chết. **Không** hỏi "bạn thích game không?" để lọc
      trước khi mời (review gating bị cấm).

## 5. Tối ưu UI/UX
- [ ] **GD3-250** Lần chơi đầu (Claude, M): hướng dẫn 1 thao tác chạm (nhảy, né, lộn, chạy mặt dưới) trong một màn ngắn,
      gộp bước hiệu chỉnh độ trễ vào luồng này.
- [ ] **GD3-251** Màn hình (Claude, M–L): danh sách bài (khóa/giá/BEST/độ khó), kết quả (điểm, sao/hạng, NEW BEST, nút
      chơi lại/bài tiếp), cửa hàng (IAP + restore), cài đặt, tạm dừng; nút đủ lớn cho ngón tay, safe area.
- [x] **GD3-252** (→ roadmap Phase 7) Ngôn ngữ vi/en (Claude, S–M), chuẩn bị chỗ cho ngôn ngữ khác.
- [x] **GD3-253** (→ roadmap Phase 7) Rung phản hồi (haptics) khi PERFECT/chết, tùy chọn tắt; tùy chọn giảm nhấp nháy đã có.
- [ ] **GD3-254** Chụp ảnh mọi màn hình ở 19.5:9, 16:9 và 4:3 (tablet), dọc nếu chọn GD3-210; tự xem trước khi xong.

## 5b. Làm lại âm thanh hiệu ứng (SFX) theo kiểu trống (thêm 2026-10-15)
Mọi âm trong game vẫn là âm tạm sinh bằng code (`status: placeholder` trong `assets/audio/audio_catalog.json`) và
không hợp game. Quy trình tạo âm thật đã có sẵn (prompt → Google Flow tạo video có tiếng → tải về → tách âm bằng
`tools/audio/build_sfx.py`); chỉ cần đổi phong cách sang **tiếng trống**, nhất là tiếng chạm và tiếng chạm đất.
- [x] **GD3-255** (→ roadmap Phase 7) Chốt bộ âm (Claude đề xuất, Người dùng duyệt, S): một bộ trống thống nhất hợp nhạc synthwave/EDM và
      tribal. Đề xuất bộ trống điện tử kiểu 808/909, kèm vài take trống taiko để so. Âm ngắn, khô, không thành giai điệu:
      - Lần chạm: `player.jump` rimshot hoặc snare ngắn; `player.dodge` clap hoặc tom nhỏ; `player.flip` (cả lộn tròn và
        chạy mặt dưới) 2 nhát tom nhanh.
      - Chạm đất `player.land`: kick hoặc floor tom trầm, ngắn, nhỏ hơn kick của nhạc (tiếp đất rất thường xuyên).
      - `judge.perfect` clave/woodblock cao, nhỏ; `judge.great` nhẹ hơn.
      - `player.death` trống lớn + crash; `player.shield_break` cymbal choke; vật cản vào sân: tom/taiko nhẹ;
        `run.complete` fill trống + crash.
      - Rà lại danh sách ID trong `tools/audio/sfx_spec.py`: thêm ID nếu cần âm riêng cho vòng nhảy, bệ bật, chạy mặt dưới.
- [x] **GD3-256** (→ roadmap Phase 7) Viết lại prompt (Claude, S): sửa `docs/design/sfx/sfx_video_prompts.md` theo phong cách trống (đuôi prompt
      kiểu "single close-miked drum hit, dry, short decay, no melody, no music, no speech"). Giữ quy tắc cũ: mỗi clip một
      loại âm lặp 3–4 lần cách nhau 1,5–2 giây, camera đứng yên; chụp lại ảnh đầu vào từ game hiện tại nếu cần.
- [ ] **GD3-257** Tạo video (Người dùng): Google Flow, 2–3 take mỗi ID, tải về `art_source/sfx/<ID>_take<N>.mp4`
      (không commit). Ghi lại gói/ngày tạo để chứng minh quyền dùng thương mại.
- [~] **GD3-258** (→ roadmap Phase 7) Tách âm và đưa vào game (Claude, S–M):
      - Chạy `python tools/audio/build_sfx.py` (tách âm, cắt, chuẩn hóa), nghe thử ở `tools/audio/out/sfx_review.html`.
      - Chỉnh mức to theo nhóm trong `sfx_spec.py` so với nhạc; thêm tùy chọn tắt riêng tiếng chạm nếu người chơi thấy rối.
      - Cân nhắc phát tiếng chạm đất **đúng beat tiếp đất**: thời điểm này biết trước nhờ parabol, nên có thể phát sớm
        bù độ trễ âm thanh để tiếng trống trùng phách. Tiếng chạm phát ngay lúc chạm (không đoán trước được), nên phải
        thật ngắn và attack gắt.
      - Chơi thử trên điện thoại.

## 6. Xuất bản store
- [ ] **GD3-260** Bản release Android (Claude + Người dùng, M; thay cho GD3-053): keystore release + Play App Signing,
      AAB, target API theo mốc yêu cầu hiện hành của Google Play, version code tự tăng, icon adaptive.
- [ ] **GD3-261** Trang store (Người dùng, Claude hỗ trợ): ảnh chụp, feature graphic, video, mô tả vi/en, xếp hạng nội
      dung, form Data safety (Firebase + AdMob), khai báo có quảng cáo.
- [ ] **GD3-262** iOS (Cả hai, L): **cần máy Mac + Xcode** (Windows không build/upload được), Apple Developer
      99 USD/năm; plugin iOS cho Firebase/AdMob/StoreKit/review; Privacy labels; ATT; TestFlight.
- [ ] **GD3-263** Thử kín (Người dùng): tài khoản Play cá nhân tạo sau 11/2023 phải chạy thử kín với **≥ 12 người
      trong 14 ngày liên tục** trước khi lên production (kiểm tra lại quy định lúc làm). Chạy song song với mục 4.
- [ ] **GD3-264** Soft launch Android ở 1–3 thị trường nhỏ (Cả hai): đo giữ chân và doanh thu (mục 7), chỉnh độ khó và
      quảng cáo bằng Remote Config, rồi mới ra toàn cầu.
- [ ] **GD3-265** Sau ra mắt: theo dõi Android vitals (ANR, crash), cập nhật đều (vd. thêm bài mỗi tháng nhờ GD3-220).

## 7. Chỉ số cần theo dõi
Mốc tham khảo thường dùng cho game casual — chỉnh theo dữ liệu thật của game.

| Nhóm | Chỉ số | Nguồn | Mốc tham khảo |
|---|---|---|---|
| Kỹ thuật | Crash-free users; tỉ lệ ANR / crash (Android vitals) | Crashlytics, Play Console | ≥ 99.5 %; ANR < 0.47 %, crash < 1.09 % |
| Kỹ thuật | FPS p50/p10 theo máy và tier; thời gian tải màn | `perf_sample` | p10 ≥ 50 FPS ở tier tự chọn |
| Gameplay | Tỉ lệ qua màn, số lần thử tới lần qua, chỗ chết, lệch nhạc theo cue | `level_end` | xem GD3-232 |
| Gắn bó | Retention D1 / D7 / D30; số phiên/ngày; thời lượng phiên; DAU/MAU | Analytics | D1 35–40 %, D7 ~15 %, D30 ~5 % |
| Kiếm tiền | ARPDAU; số quảng cáo/DAU; eCPM; fill rate | AdMob + Analytics | interstitial ≤ 1 lần / 3 phút chơi |
| Kiếm tiền | Tỉ lệ người trả tiền; ARPPU; doanh thu theo gói; LTV D7/D30 | Play Billing + Analytics | người trả tiền 1–3 % |
| Marketing | Lượt cài theo nguồn; CPI; tỉ lệ xem trang store → cài; ROAS; điểm đánh giá | Play Console, Google Ads, Analytics | điểm ≥ 4.3; ROAS D30 > chi phí |

## 8. Lộ trình đề xuất
Thứ tự theo phụ thuộc: đo lường có trước khi có người chơi bên ngoài; quyết định màn dọc trước khi làm UI; 14 ngày thử
kín chạy song song với phần kiếm tiền.

| Giai đoạn | Thời gian (ước) | Việc | Kết quả để đi tiếp |
|---|---|---|---|
| A. Quyết định nền | tuần 1–2 | GD3-200, 201, 202, 203; GD3-210–212; GD3-220 | Nhạc được phép dùng, tên mới, chốt ngang/dọc, lệnh sinh level |
| B. Đo lường | tuần 3–4 | GD3-230, 231, 235 (232–234 dựng khung) | Crash và event về Firebase từ bản test nội bộ |
| C. UI + âm thanh + bản release | tuần 4–6 | GD3-250–254, GD3-255–258 (tạo video Flow song song), GD3-260 | Bản AAB ký release có SFX trống, thử nội bộ |
| D. Kiếm tiền + store | tuần 6–8 | GD3-240, 241, 242, 244, GD3-261; bắt đầu GD3-263 (14 ngày) | Quảng cáo/IAP chạy ở thử kín, trang store xong |
| E. Soft launch | tuần 9–12 | GD3-264, GD3-232–234 với dữ liệu thật, GD3-233 A/B; GD3-262 nếu có Mac | Chỉ số mục 7 đạt mốc → ra toàn cầu |
| F. Sau ra mắt | từ tháng 4 | GD3-221 + GD3-243 (tự tạo level, IAP), GD3-265 | Gói creator, bài mới đều đặn |
