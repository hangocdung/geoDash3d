# Bản nháp chính sách quyền riêng tư (GD3-202)

Bản nháp để đăng ở URL công khai. Phần tiếng Anh là bản chính (store yêu cầu), tiếng Việt bên dưới. Trước khi đăng,
người dùng điền các mục trong `«…»` (tên nhà phát triển, email liên hệ, ngày hiệu lực) và xóa các mục không còn đúng
(vd. chưa có IAP thì bỏ đoạn mua hàng). Nội dung phải khớp form Data safety (Play) và Privacy labels (Apple).

---

## Privacy Policy — «Game name»

Effective date: «YYYY-MM-DD» · Developer: «developer name» · Contact: «email»

**What the game stores on your device.** Settings (volume, graphics quality, audio offset), best scores and progress
are saved only on your device. They are deleted when you uninstall the game.

**Data collected by third-party services.** The game uses the following Google services, which collect data under
their own policies:

| Service | Purpose | Data |
|---|---|---|
| Firebase Crashlytics | Find and fix crashes | Crash traces, device model, OS version, app version, installation ID |
| Google Analytics for Firebase | Understand how levels are played and improve difficulty | Gameplay events (level started/finished, progress, score, timing accuracy), device model, country, app-instance ID |
| Firebase Remote Config | Tune game settings without an update | App-instance ID |
| Google AdMob | Show ads | Advertising ID, IP address, device information, ad interactions |
| Google Play Billing / Apple App Store | Process purchases | Handled by the store; the game only receives which products you own |

We do not collect your name, email, contacts, location (beyond country derived from IP), photos or files. Gameplay
data is not linked to your identity and is not sold.

**Ads and consent.** In the EEA, UK and Switzerland you are asked for consent before personalised ads are shown (Google
User Messaging Platform). On iOS the game asks for tracking permission (App Tracking Transparency). You can change your
choice in the game's settings, and reset your advertising ID in your device settings.

**Children.** The game is not directed to children under 13 and we do not knowingly collect their data.

**Retention.** Crash reports are kept for 90 days; analytics data for 14 months (Firebase default), then deleted.

**Your rights.** You can ask us to delete analytics data linked to your app-instance ID by emailing «email» with the
ID shown in Settings → About. Uninstalling the game removes all local data.

**Changes.** We will update this page and its effective date when the policy changes.

Third-party policies: [Google Privacy Policy](https://policies.google.com/privacy),
[How Google uses data from partner apps](https://policies.google.com/technologies/partner-sites).

---

## Chính sách quyền riêng tư (tiếng Việt)

Ngày hiệu lực: «YYYY-MM-DD» · Nhà phát triển: «tên» · Liên hệ: «email»

- **Dữ liệu trên máy:** cài đặt, kỷ lục, tiến độ chỉ lưu trên máy bạn, mất khi gỡ game.
- **Dịch vụ bên thứ ba:** Firebase Crashlytics (báo lỗi), Google Analytics for Firebase (sự kiện chơi: bắt đầu/kết
  thúc màn, tiến độ, điểm, độ chính xác), Firebase Remote Config, Google AdMob (quảng cáo, mã quảng cáo), Google Play /
  App Store (thanh toán). Không thu thập tên, email, danh bạ, vị trí chính xác, ảnh hay tệp. Không bán dữ liệu.
- **Quảng cáo & đồng ý:** EEA/UK/Thụy Sĩ hỏi đồng ý qua Google UMP; iOS hỏi quyền theo dõi (ATT). Có thể đổi trong
  cài đặt game.
- **Trẻ em:** game không dành cho trẻ dưới 13 tuổi.
- **Lưu trữ:** báo lỗi 90 ngày, dữ liệu phân tích 14 tháng.
- **Quyền của bạn:** gửi email kèm mã cài đặt (Cài đặt → Giới thiệu) để yêu cầu xóa dữ liệu phân tích.

## Hệ quả cho code (ghi chú cho GD3-230/240)
- Settings → About phải hiện app-instance ID của Firebase (để người chơi yêu cầu xóa) và nút mở lại form đồng ý UMP.
- Thời hạn lưu Analytics đặt 14 tháng trong Firebase console (mặc định 2 tháng nếu không đổi).
