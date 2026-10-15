# Bản phát hành Android (GD3-260)

## Đã có
- Preset **"Android Release"** (`export_presets.cfg`, preset.2): Gradle build, xuất **AAB**, arm64-v8a, cùng package
  `com.dunghn.geodash3d`, loại addon/tài liệu khỏi gói như bản debug.
- **Target API 36** cho mọi preset Android (Google Play bắt buộc với app mới và bản cập nhật từ 31/08/2026; gia hạn tới
  01/11/2026 phải xin trong Play Console). Template Godot 4.6.1 biên dịch với SDK 35 → `setup_gradle_build.sh` nâng
  `compileSdk` lên 36 (cần SDK Platform android-36 + build-tools 36.0.0). Đã thử: APK target 36 chạy trên Note10 Lite.
- `bash tools/android/build_release.sh 1.0.0`: version code = số commit (luôn tăng), version name = tham số, dựng
  Gradle, xuất `build/GeoDash3D.aab`. Chỉ chạy khi cây git sạch; sau đó commit `export_presets.cfg` để ghi version.
  Đã thử xuất AAB (65 MB) bằng keystore debug.

## Việc người dùng làm (một lần)
1. Tạo **upload key** (giữ kỹ, không commit):
   ```bash
   keytool -genkeypair -v -keystore geodash-upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Đặt biến môi trường trước khi build: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` (đường dẫn file), `..._USER` (alias,
   vd. `upload`), `..._PASSWORD`.
3. Play Console: tạo app, bật **Play App Signing** (Google giữ khóa ký app, bạn chỉ giữ upload key), tải AAB đầu tiên
   lên kênh **Internal testing**.
4. Icon: chờ chốt tên game (GD3-201) rồi Claude làm icon adaptive (lớp nền + lớp hình 432×432, vùng an toàn 66 %).

## Ghi chú
- Chỉ build arm64-v8a (mọi máy Android 64-bit; Play không bắt buộc 32-bit). Thêm armeabi-v7a nếu cần máy rất cũ (+~20 MB).
- Bản release không có `PerfProbe` log (trừ preset Release Perf), nhưng vẫn gửi `perf_sample` qua Telemetry.
