# Quảng cáo AdMob (GD3-240)

Plugin Poing Studios `godot-admob-plugin` v5.1.0 (MIT, người dùng duyệt 2026-10-15), chỉ phần `ads` (AdMob, Google
Mobile Ads SDK thế hệ mới `ads-mobile-sdk` 1.4.0 + UMP), không cài mạng mediation. Code game chỉ gọi `Ads`
(`src/core/ads.gd`); trên PC và trong test mọi lệnh là no-op.

## Hành vi
- Khởi động (menu chính lần đầu): hỏi đồng ý bằng Google UMP (bắt buộc ở EEA/UK) → khởi tạo SDK với xếp hạng nội dung
  **T** và không nhắm trẻ em (GD3-203) → tải sẵn 1 interstitial.
- **Interstitial**: chỉ khi về menu chính sau khi chơi, và chỉ khi đã chơi ≥ 180 s từ lần trước
  (`Ads.MIN_PLAY_BETWEEN_INTERSTITIALS_SEC`; thời gian chơi tính từ `level_end` của `RunTelemetry`, không tính
  autoplay/attract). Không bao giờ sau mỗi lần chết (game tự chơi lại) và không bao giờ trong lượt chơi. Khi quảng cáo
  mở, nhạc nền menu tạm dừng.
- **Banner**: chỉ ở menu chính (dưới đáy), hủy khi rời menu.
- **Rewarded**: chưa làm — chờ quyết định khóa bài (GD3-242: mở thử bài khóa hay bắt đầu với 1 lá chắn).
- Settings → Ads → **AD PRIVACY** hiện khi UMP yêu cầu (EEA/UK) để người chơi đổi lựa chọn.
- Bản debug luôn dùng ad unit thử của Google.

## Việc người dùng làm trước khi phát hành
1. Tạo tài khoản AdMob, thêm app Android (package `com.sntgames.beatglide`), tạo 2 ad unit: Interstitial, Banner.
2. Project Settings → `admob/general/android/app_id` = App ID thật (`ca-app-pub-…~…`), và thêm
   `geodash/ads/interstitial_unit`, `geodash/ads/banner_unit` = ad unit ID thật (bản release đọc ở đây; thiếu thì
   không hiện quảng cáo và báo lỗi).
3. AdMob → Privacy & messaging: tạo thông báo GDPR (UMP) cho app.
4. Liên kết AdMob với Firebase (để có `ad_impression` kèm doanh thu trong Analytics).
5. Play Console: khai báo "có quảng cáo", form Data safety (mã quảng cáo, IP, tương tác quảng cáo).

## Cài lại / nâng cấp plugin
Thư mục `addons/admob` là bản phát hành nguyên vẹn; nhị phân Android `addons/admob/android/bin/ads` được commit (export
không cần mạng). Nhị phân iOS do plugin tự tải khi mở editor headless (gitignore). Phần mẫu, C#, tài liệu và nhị phân bị
loại khỏi gói game trong `export_presets.cfg`.
