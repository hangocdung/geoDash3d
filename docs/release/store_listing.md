# Trang Google Play — bản nháp (GD3-261)

Tên game: **BeatGlide** (chốt 2026-10-15, GD3-201); tên trên store: "BeatGlide — Ride the Rhythm" (27 ký tự). Giới hạn của Play: tên ≤ 30 ký tự, mô tả ngắn ≤ 80,
mô tả đầy đủ ≤ 4000. Không dùng "Geometry Dash" hay tên game khác trong tên / mô tả / từ khóa (vi phạm chính sách
metadata và nhãn hiệu).

## Tiếng Việt
**Tên:** BeatGlide — Ride the Rhythm
**Mô tả ngắn (≤ 80):** Chạm đúng nhịp, lao qua thành phố neon. Một chạm — nhảy, lách, lộn ngược theo nhạc.

**Mô tả đầy đủ:**
> Khối neon của bạn tự lao trên đường ray giữa thành phố ánh sáng. Bạn chỉ có một thao tác: **chạm đúng nhịp nhạc**.
> Chạm để nhảy qua gai, lách khỏi tường, lộn xuống chạy ngược dưới đường — mọi vật cản xuất hiện đúng theo nhịp trống.
>
> • Một chạm, dễ học: gợi ý hiện đúng lúc khi bạn gặp thao tác mới
> • Màn chơi dựng theo từng cú đánh của bài nhạc — chạm đúng là nghe đúng
> • Camera và ánh sáng chuyển động theo nhạc; chơi ngang hoặc dọc tùy bạn
> • Chấm PERFECT / GREAT / GOOD, combo, lá chắn khi chuỗi PERFECT, hạng S–C và kỷ lục từng bài
> • Chế độ luyện tập với điểm lưu và tốc độ 50–100 %
> • Tự chỉnh độ trễ âm thanh cho loa hoặc tai nghe của bạn
> • Mở khóa bài mới bằng cách qua màn, hoặc chơi thử bằng quảng cáo
>
> Nhạc trong game được tạo bằng AI (Google Flow Music). Game có quảng cáo; có thể mua để bỏ quảng cáo hoặc mở mọi bài.

## English
**Title:** BeatGlide — Ride the Rhythm
**Short description (≤ 80):** Tap to the beat and glide through a neon city. One tap: jump, dodge, flip.

**Full description:**
> Your neon cube races along a rail through a city of light. You have one move: **tap on the beat**. Tap to jump over
> spikes, sidestep walls and flip under the track to run upside down — every obstacle lands right on the drums.
>
> • One-tap controls with hints the first time you meet a new move
> • Levels built hit by hit from each song — when your tap is right, it sounds right
> • Camera and lights move with the music; play in landscape or portrait
> • PERFECT / GREAT / GOOD timing, combos, shields for PERFECT streaks, S–C ranks and per-song records
> • Practice mode with checkpoints and 50–100 % speed
> • Audio latency calibration for your speakers or headphones
> • Unlock songs by clearing the one before, or try them with a rewarded ad
>
> Music generated with AI (Google Flow Music). Contains ads; optional purchases remove ads or unlock every song.

## Hình ảnh cần có (người dùng duyệt, Claude dựng)
| Mục | Kích thước | Nguồn |
|---|---|---|
| Icon | 512×512 PNG | `assets/brand/icon_512.png` (icon adaptive cho app: 432×432 hai lớp) |
| Feature graphic | 1024×500 | ảnh màn chơi + tên |
| Ảnh điện thoại (2–8) | 1080×1920 hoặc 1920×1080 | `bash tools/capture/screens.sh vi` + `--capture` ở đoạn đẹp |
| Video (YouTube, tùy chọn) | 30 s | `bash tools/capture/record_clip.sh <bài> <beat> 30 landscape` |

## Khai báo
- **Danh mục:** Trò chơi → Âm nhạc. **Đối tượng:** 13+ (GD3-203). **Có quảng cáo:** Có.
- **Xếp hạng nội dung (IARC):** không bạo lực, không mua bán ngẫu nhiên (không loot box), có mua trong app.
- **Data safety:** thu thập ID quảng cáo, tương tác app (Analytics), chẩn đoán lỗi (Crashlytics), IP / vị trí thô
  (AdMob); không bán dữ liệu; mã hóa khi truyền; có cách yêu cầu xóa (email trong chính sách quyền riêng tư).
- **Chính sách quyền riêng tư:** URL công khai của `docs/release/privacy_policy.md` (GD3-202).
