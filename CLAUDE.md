# GeoDash3D — Agent Guide

Game nhịp điệu 3D lấy cảm hứng từ Geometry Dash. Nhân vật tự chạy trên đường ray định sẵn (`Path3D`).
Người chơi chỉ có **một thao tác: chạm/nhấn**, hành động thực hiện (nhảy, dash, …) do vùng hành động hiện tại quyết định.
Camera và VFX do game điều khiển theo nhạc. Ưu tiên: **khớp nhạc tuyệt đối > dễ đọc màn chơi > đẹp**.

Tài liệu chi tiết (chỉ đọc khi task liên quan):
- `docs/architecture.md` — các hệ thống, luồng dữ liệu, định dạng chart
- `docs/roadmap.md` — danh sách task `GD3-xxx` và trạng thái

---

## 1. Bất biến kiến trúc (KHÔNG được vi phạm)
1. **`SongClock` là đồng hồ duy nhất.** Mọi trạng thái gameplay (vị trí, cú nhảy, camera, VFX theo nhịp) là hàm của
   `song_time`. Không tích lũy `delta` để di chuyển bất cứ thứ gì đồng bộ với nhạc.
2. **Không dùng physics engine cho nhân vật/vật cản.** Không `RigidBody3D`, không `move_and_slide`. Chuyển động là công thức
   giải tích theo thời gian; va chạm kiểm tra trong "không gian đường" (khoảng cách `s` trên path + offset).
3. **Không dùng `Engine.time_scale`** hay bất cứ thứ gì làm lệch thời gian game so với audio. Slow-mo chỉ là hiệu ứng hình ảnh.
4. **Chart viết theo nhịp (beat), không theo tọa độ.** Tọa độ luôn được tính ra từ `beat → time → s` qua `TempoMap`.
5. **Tất định:** cùng chart + cùng chuỗi thời điểm chạm ⇒ cùng kết quả. Đây là điều kiện để autoplay/replay/test hoạt động.
6. **Tách logic và trình bày:** thư mục `src/gameplay/` không tham chiếu tới camera, VFX, UI. Trình bày chỉ lắng nghe signal
   hoặc đọc state, không ghi ngược vào logic.

Muốn thay đổi bất kỳ điều nào ở trên, hay định dạng chart → **hỏi người dùng trước**.

## 2. Môi trường & lệnh
- Godot 4.6.1 (console, dùng cho CLI): `D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe`
  (lưu ý: `Godot_v4.6.1-stable_win64.exe` là **thư mục**)
- Blender 5.2 LTS: `D:/Programs/Blender/blender.exe`
- Python 3.12 (`python`) cho tool phân tích audio ngoài Godot.

```bash
# Import tài nguyên + bắt lỗi parse script
"$GODOT" --headless --path . --import
# Chạy toàn bộ test (GUT)
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
# Chụp màn hình gameplay tại thời điểm T (cần render, không headless)
"$GODOT" --path . res://tools/capture/capture.tscn -- --chart=<id> --time=<giây> --out=<file.png>
# Sinh model từ script Blender
"D:/Programs/Blender/blender.exe" -b -P assets/blender/<script>.py -- --out assets/models/<name>.glb
```
(`$GODOT` = đường dẫn console ở trên. Lệnh test/capture có hiệu lực sau task GD3-002/GD3-003.)

## 3. Nền tảng: PC + Mobile
- Renderer: Forward+ trên desktop, **Mobile** trên Android/iOS (override theo platform trong `project.godot`).
- **Hình ảnh nền tảng phải đẹp với bộ tính năng của Mobile renderer**: emission + glow, depth fog, unshaded/baked lighting.
  SSR, SDFGI, volumetric fog, SSAO chỉ là "extra" của tier High trên PC, không được là thứ bắt buộc để màn chơi dễ đọc.
- Mọi VFX/hậu kỳ đi qua `QualitySettings` (Low/Medium/High). Mục tiêu: 60 FPS ổn định trên mobile tầm trung.
- Input: một action duy nhất `tap` (touch, chuột trái, Space). Không thêm action gameplay khác nếu chưa hỏi.
- Hướng màn hình: ngang (landscape). Tôn trọng safe area (tai thỏ) cho UI.

## 4. Cấu trúc thư mục
```
assets/music/       nhạc + file chart (*.chart.json) cùng tên
assets/models/      .glb đã xuất (KHÔNG sửa tay)
assets/blender/     script bpy sinh model (nguồn thật của model)
src/core/           SongClock, TempoMap, QualitySettings (autoload)
src/gameplay/       chart, track path, player motion, action resolver, hazard — logic thuần
src/presentation/   camera director, vfx, beat pulse, visual của player/obstacle
src/ui/             HUD, menu, màn hiệu chỉnh độ trễ
src/authoring/      record mode, importer .sm, công cụ luyện tập
tests/              test GUT (test_*.gd)
tools/              capture, script Python phân tích audio
docs/               kiến trúc, roadmap, quyết định thiết kế
```
Mỗi feature để `.gd` và `.tscn` cạnh nhau trong cùng thư mục.

## 5. Quy ước code
- Code, tên, comment: **tiếng Anh**. Trả lời & tài liệu trong `docs/`: **tiếng Việt**.
- Static typing đầy đủ (biến, tham số, return, `Array[T]`, `Dictionary[K, V]`). Bật cảnh báo untyped trong project.
- Mỗi file ≤ 300 dòng; vượt thì tách module và nói rõ lý do.
- Mỗi file mới có header comment 2–3 dòng: trách nhiệm + file liên quan.
- `snake_case` biến/hàm, `PascalCase` class, `SCREAMING_SNAKE_CASE` hằng. Dùng `class_name` cho type dùng lại.
- Lỗi: kiểm tra đầu vào tường minh, `push_error()` với thông điệp rõ, return sớm. Không nuốt lỗi im lặng
  (GDScript không có try/catch).
- Không placeholder (`# TODO`, `pass` tạm, "giữ nguyên code cũ"). Chưa làm được thì nói rõ trong câu trả lời.
- Scene UI lồng tối đa 3 cấp; scene 3D tối đa ~5 cấp.
- Số "ma thuật" về gameplay (cửa sổ timing, độ cao nhảy, …) đặt trong Resource config, không rải trong code.

## 6. Quy trình làm việc
- Làm theo task trong `docs/roadmap.md`. Khi bắt đầu/kết thúc task, cập nhật trạng thái ở đó.
- Logic gameplay mới (đặc biệt phép tính thời gian) **phải có test GUT**. Chạy test trước khi báo xong.
- Thay đổi hình ảnh: chụp ảnh bằng tool capture và tự xem trước khi báo xong.
- Thay đổi kiến trúc/định dạng dữ liệu: cập nhật `docs/architecture.md` trong cùng thay đổi.
- Commit: Conventional Commits (`feat(gameplay): ...`, `fix(core): ...`, `docs: ...`), kèm mã task nếu có.
  Chỉ commit khi người dùng yêu cầu.

## 7. Không được làm
- Không sửa `.godot/`, file `*.import`, `*.uid`; không tự bịa `uid://` trong `.tscn`/`.tres` (để Godot sinh,
  hoặc tham chiếu bằng đường dẫn `res://`).
- Không sửa tay `assets/models/*.glb` — sửa script trong `assets/blender/` rồi sinh lại.
- Không thêm addon/thư viện ngoài khi chưa hỏi.

## 8. Nhạc
| File | Nguồn | Giấy phép | BPM | Offset |
|---|---|---|---|---|
| `The_Dawn_Assembly.mp3` | Google Flow Music (AI) | **Chưa xác nhận dùng thương mại** | chưa đo | chưa đo |
