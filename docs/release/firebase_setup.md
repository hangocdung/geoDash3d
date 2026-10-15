# Firebase cho bản Android (GD3-230)

Plugin tự viết `GeoDashFirebase` (Godot Android plugin v2) bọc Firebase Analytics, Crashlytics (kèm crash native của
engine qua `firebase-crashlytics-ndk`) và Remote Config. Code game chỉ gọi `Telemetry` (`src/core/telemetry.gd`).
Không có file cấu hình Firebase thì bản Android vẫn chạy bình thường, chỉ là không gửi gì.

## Việc người dùng làm một lần
1. Vào <https://console.firebase.google.com> → **Add project** (tắt/bật Google Analytics: **bật**, chọn tài khoản
   Analytics).
2. Trong project → **Add app → Android**, package name `com.dunghn.geodash3d` (nếu đổi tên game ở GD3-201 thì đăng ký
   thêm app với package mới, tải lại file ở bước 3).
3. Tải `google-services.json`, đặt vào `android_plugins/google-services.json` (đã gitignore).
4. Console → **Crashlytics** → bật. **Analytics → Data settings → Data retention**: 14 tháng (khớp chính sách quyền
   riêng tư). **Remote Config**: chưa cần tạo tham số.
5. Báo Claude để dựng lại bản Android và đo FPS.

## Dựng bản Android
```bash
bash tools/android/build_firebase_plugin.sh   # chỉ khi sửa android_plugins/geodash_firebase (AAR đã commit)
bash tools/android/setup_gradle_build.sh      # tạo android/build từ template Godot, vá Gradle, chép google-services.json
"$GODOT" --headless --path . --export-debug "Android" build/GeoDash3D.apk
```
Preset Android dùng Gradle build (`gradle_build/use_gradle_build=true`), nên bắt buộc chạy `setup_gradle_build.sh`
trước lần export đầu và sau mỗi lần nâng Godot. JDK: JBR của Android Studio (đường dẫn trong editor settings).

## Kiểm tra trên máy
- `adb logcat -s GeoDashFirebase:V godot:V` — khi thiếu cấu hình sẽ có dòng "no Firebase config in this build".
- Bật DebugView của Analytics: `adb shell setprop debug.firebase.analytics.app com.dunghn.geodash3d`, rồi chơi một
  lượt → thấy `level_start` / `level_end` trong Console → Analytics → DebugView.
- Crashlytics: lỗi `push_error` đầu tiên của mỗi loại hiện thành non-fatal (tối đa 25 / phiên).

## Đã biết
- Crash trong engine C++ được ghi nhận nhưng không có symbol (godot-lib đã strip) → chỉ thấy địa chỉ.
- ANR không do Crashlytics báo; xem Android vitals trên Play Console.
