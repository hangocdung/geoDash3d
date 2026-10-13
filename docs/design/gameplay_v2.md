# Gameplay v2: lách làn, lộn mặt dưới, vật cản vào theo nhịp, độ khó tăng dần

> Nguồn: yêu cầu playtest của người dùng ngày 2026-10-13. **Đã thực hiện** ở Phase 4.5 (GD3-070 … GD3-074).
> Khác biệt so với bản nháp: cột đỡ đường hạ thấp 2.8 đơn vị để chừa chỗ chạy mặt dưới; flip đặt cố định qua
> `plan.fixed` (104, 120, 140, 160, 180, 196, 210); camera dùng shot `underside` khi lộn.

## 1. Lý do
- **Dash bị cảm nhận như "đổi tốc độ"**, do khối vuông lao về phía trước (lunge) và hiệu ứng FOV kick.
  Người dùng không muốn tốc độ chạy thay đổi bởi hành động.
- Thay dash bằng hành động **né ngang** hoặc **lộn xuống mặt dưới đường**. Không lật môi trường.
- Vật cản nên **xuất hiện theo nhịp nhạc**: trồi từ mặt đất, rơi từ trên trời…
- **Độ khó phải tăng về cuối bài.** Hiện tại đoạn 192–224 (breakdown) lại dễ đi.

## 2. Hành động (vẫn một chạm; cue quyết định hành động)
Mở rộng `ActionDefinition` với `kind` gồm `JUMP | DODGE | FLIP`. Thêm hàm
`offset_at(progress) -> Vector2(lateral, height)` thay cho `height_at`. Hành động không bao giờ đổi `s(t)`.

| Hành động | Thời lượng | Chuyển động | Vật cản đi kèm (offset) |
|---|---|---|---|
| `jump` | 1 beat | parabol cao 2.0 | `spike` (+0.5) |
| `dodge_left` / `dodge_right` | 1.25 beat | trượt sang làn ±1 (smoothstep 20% đầu, giữ, 20% cuối về giữa) | `wall_gap_left` / `wall_gap_right` (+0.625) |
| `flip` | 2 beat | góc θ = π·hold; lateral = sin θ · 2.2; height = (cos θ − 1) · D/2 với D = độ dày đường + 1 | `gate` (+1.0) |

- **Hệ trục frame:** X = hướng đi, Y = lên, **+Z = bên phải người chơi** (phía camera side). Trái = −Z.
- **Dung sai đã tính ở 120 BPM:**
  - Dodge 1.25 beat: chịu lệch khoảng ±150 ms (tường dày 0.9, hitbox người chơi rộng ±0.38).
  - Flip 2 beat: rất rộng, khoảng ±375 ms. Cửa sổ cue 150 ms mới là giới hạn thực tế.
- **Recovery dùng cho sinh chart:** jump 1.5, dodge 1.75, flip 2.5 beat.
- **Lộn mặt dưới:** khối xoay quanh trục X một góc π (lăn về phía +Z, tức phía camera). Lúc treo ngược, cạnh
  dưới khối ở −D. Không có vật cản mặt dưới ở v2. Để sau: gai mặt dưới, bắt buộc lộn lại đúng nhịp.
- **Hình ảnh khối:**
  - Dodge: lăn ngang ±90° quanh trục X theo hold, kèm bóng mờ.
  - Flip: thêm FOV kick nhẹ, kèm bóng mờ.
  - **Không lao về phía trước.**

## 3. Vật cản (thêm trục ngang vào va chạm)
`HazardDefinition` thêm các trường: `lateral_center`, `lateral_half_width`, `visual` (`SPIKE | WALL | GATE`),
`entrance` (`RISE | DROP | UNFOLD`), `lead_beats`, `visual_width`.
`HazardChecker.find_collision` nhận thêm lateral và half width của người chơi (`player_half_width` = 0.38).

| id | Hình | Ngang (center ± half) | Cao | Vào sân | lead | Màu |
|---|---|---|---|---|---|---|
| `spike` | kim tự tháp | 0 ± 0.4 | 0–0.85 | RISE (trồi lên) | 2 | hồng |
| `wall_gap_left` | khối 2 làn | +0.5 ± 0.98 (chặn giữa và phải) | 0–3.2 | DROP (rơi xuống) | 3 | cam |
| `wall_gap_right` | khối 2 làn | −0.5 ± 0.98 | 0–3.2 | DROP | 3 | cam |
| `gate` | khung, cột và mặt năng lượng | 0 ± 2.6 | 0–4.5 | UNFOLD (bung ngang) | 3 | xanh lime |

- Bỏ `barrier`. Có thể dùng lại shader `energy_barrier` cho mặt năng lượng của `gate`.
- Độ rộng và độ dày đường chuyển vào `GameplayConfig` (`track_width` 3, `track_thickness` 1.1, `lane_width` 1).
  `TrackView` và flip đọc chung giá trị này.

## 4. Vật cản vào theo nhịp (chỉ trình bày, tất định theo beat)
- `appear_beat = floor(hazard_beat − lead_beats)`: cú tiếp đất rơi đúng **nguyên beat**.
  Trước thời điểm `appear − thời lượng animation`, vật cản bị ẩn. Vòng cue trên mặt đường vẫn hiện từ xa để báo trước.
- Ba kiểu animation (là hàm thuần của `beat − appear_beat`):
  - **RISE:** trong 0.25 beat từ dưới mặt đường trồi lên (ease-out, scale Y 0.6 → 1), sau đó nảy nhẹ 0.3 beat.
  - **DROP:** rơi từ +14 trong 0.5 beat (gia tốc t²), chạm đúng beat. Squash 0.3 beat, kèm vòng bụi và rung camera nhẹ.
  - **UNFOLD:** scale ngang 0 → 1 (ease-out-back) trong 0.375 beat, kèm lóe sáng.
- `ObstacleView` phát signal `hazard_landed(position, color, entrance)`, `LevelRunner` chuyển cho `VfxDirector`.
  Khi bắt đầu giữa bài, dùng `rewind_to(start_beat)` để không phát hiệu ứng cho vật cản đã xuất hiện.
- **Ký hiệu cue:**
  - Jump: ^ hồng.
  - Dodge: vòng cue đặt **ở làn trống**, có dải mũi tên phẳng chiếu sáng làn đó, cộng ký hiệu ↔ màu cam.
  - Flip: ký hiệu ↻ lime.
  - Thêm glyph 4 (↔) và 5 (↻) vào `glyph.gdshader`.
- **Tổ chức file:** tách `obstacle_factory.gd` (dựng mesh), `obstacle_entrance.gd` (animation thuần),
  `material_cache.gd`. Giữ `obstacle_view.gd` dưới 300 dòng.

## 5. Camera
- **Flip assist:** khi khối đang ở mặt dưới, `CameraDirector` blend shot hiện tại về một shot "underside"
  (khoảng `(1.5, −0.8, 12.5)` nhìn `(5, −1.2, 0)`), theo `hold_amount`. Nhờ vậy shot nào cũng thấy được mặt dưới.
- **Dodge khó đọc ở camera ngang thuần** (vì lách làn chỉ là thay đổi chiều sâu). Plan chỉ đặt dodge trong các đoạn
  có camera `chase`, `chase_low`, `high`, `diagonal` hoặc `side_high`.

## 6. Độ khó tăng dần (plan và draft_chart.py)
- **Tốc độ chỉ tăng:** 7 → 7.5 (beat 64) → 8 (96) → 8.5 (128) → 9 (176) → 9.5 (200).
- **Mở khóa dần:**
  - intro: chỉ jump.
  - build/verse: jump và dodge.
  - chorus trở đi: thêm flip, đặt cố định ở đầu các câu nhạc qua `plan.fixed`, ví dụ 104, 120, 136, 152, 168, 184, 200, 208.
- **Ngưỡng `threshold` và `min_gap` giảm dần theo từng đoạn.** Đoạn 192–222 đổi tên thành `finale`, là đoạn
  dày nhất, kể cả khi năng lượng nhạc thấp hơn. Khi đó dùng cả onset hi-hat (dải high).
- **Hướng dodge:** tất định, xen kẽ có lặp, ví dụ `(int(beat*2) // 3) % 2`.
- `draft_chart.py` in mật độ hành động trên mỗi 16 beat theo từng đoạn.
  Test kiểm tra mật độ ở 1/4 cuối lớn hơn 1/4 đầu.

## 7. Test cần có
- Jump vào tường thì chết, dodge đúng hướng thì qua, dodge sai hướng (lấy cue ngược) thì chết.
- Flip qua được gate. Jump vào gate thì chết.
- Biên cửa sổ ±140 ms vẫn sống với jump, dodge và flip.
- Tất định theo frame rate với dodge và flip.
- Autoplay qua được chart dày trộn cả 4 hành động.
- Test chart sẵn có: thêm kiểm tra độ khó tăng dần.
