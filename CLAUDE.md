# GeoDash3D — Agent Guide

Game nhịp điệu 3D lấy cảm hứng từ Geometry Dash. Nhân vật tự chạy trên đường ray định sẵn (`Path3D`).
Người chơi chỉ có **một thao tác: chạm/nhấn**, hành động thực hiện (nhảy, dash, …) do vùng hành động hiện tại quyết định.
Camera và VFX do game điều khiển theo nhạc. Ưu tiên: **khớp nhạc tuyệt đối > dễ đọc màn chơi > đẹp**.

Tài liệu chi tiết (chỉ đọc khi task liên quan):
- `docs/architecture.md` — các hệ thống, luồng dữ liệu, trạng thái hiện thực
- `docs/chart_format.md` — định dạng `*.chart.json` và quy trình làm chart cho một bài nhạc
- `docs/design/` — thiết kế đã chốt cho các phase sắp làm (vd. `gameplay_v2.md`)
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
GODOT="D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe"
# Import + cập nhật class cache — BẮT BUỘC sau khi thêm/đổi tên class_name, trước khi chạy test
"$GODOT" --headless --path . --import
# Test (runner tự viết, không addon). Lọc: thêm `-- --filter=test_tempo`
"$GODOT" --headless --path . -s res://tests/framework/test_runner.gd
# Bắt lỗi runtime: chạy level headless vài trăm frame với autoplay
"$GODOT" --headless --path . --quit-after 300 -- --autoplay
# Chụp ảnh tại các thời điểm bài nhạc (giây) → tools/capture/out/*.png (mở cửa sổ, tự thoát)
"$GODOT" --path . -- --capture=8.1,49,72.2
# Như trên nhưng không autoplay (xem cảnh chết); đo độ lệch audio: --debug-clock
"$GODOT" --path . -- --capture=5 --capture-manual
# Một lượt chơi liên tục cho mọi thời điểm chụp, autoplay cố tình bỏ cue ở beat 44 (xem lá chắn / MISS / chết)
"$GODOT" --path . -- --capture=21.4,22.36 --capture-continuous --autoplay-miss=44
# Chụp ảnh một scene bất kỳ (menu, calibration…) sau N frame
"$GODOT" --path . -s res://tools/capture/scene_shot.gd -- --scene=res://src/ui/menu/main_menu.tscn --frames=240 --out=res://tools/capture/out/menu.png
# Cấu hình project (input map, autoload, shader globals, main scene) — sửa trong script rồi chạy lại
"$GODOT" --headless --path . -s res://tools/setup/configure_project.gd
# Phân tích nhạc (BPM, offset, onset) bằng Python của Blender (có aud + numpy)
"D:/Programs/Blender/blender.exe" -b --factory-startup -P tools/audio/analyze_song.py -- <song.mp3> <out.analysis.json>
# Sinh lại model decor/vật cản (.glb) từ script Blender; vai trò Body/Glow/GlowAlt nằm trong vertex color, NeonModel gán 1 shader
"D:/Programs/Blender/blender.exe" -b --factory-startup -P assets/blender/generate_models.py -- --out assets/models
# Sinh chart từ phân tích + plan (Python hệ thống); plan có thể dùng recording / fixed
python tools/audio/draft_chart.py <analysis.json> <plan.json> <out.chart.json>
# Level đặt tay theo câu nhạc (cách chính): mỗi bài một danh sách beat:mẫu, có bộ kiểm tra ràng buộc
python tools/charting/levels/pulse_drive.py
# Bài mới có hợp game không (≥ 50 % ô nhịp có cú đánh "X"), lưới cú đánh nổi bật để đặt chạm, kiểm tra chart đã đặt
python tools/charting/hit_grid.py assets/music/<id>.mp3 <bpm> <offset_sec>
python tools/charting/tap_salience.py assets/music/<id>.chart.json   # phải ra OK (prompt nhạc: docs/design/music_prompts.md)
# Bản nháp tự sinh (chỉ để tham khảo; khớp nhạc kém hơn bản đặt tay)
python tools/charting/terrain_level.py assets/music/<id>.analysis.json --title "Tên bài" --seed 1
python tools/charting/the_dawn_assembly_level.py
# Dung sai từng lần chạm của một chart
"$GODOT" --headless --path . -s res://tools/charting/tolerance_report.gd -- --chart=res://assets/music/the_dawn_assembly.chart.json
# Level từ recording của màn RECORD (DEV): điểm gõ → level địa hình <id>.rec.chart.json
python tools/charting/recording_level.py pulse_drive   # không tham số: liệt kê bài + số note đã ghi
# .sm (ArrowVortex/StepMania) → recording
python tools/charting/sm_to_recording.py <song.sm> <out.recording.json>
# Texture chi tiết: Codex tạo ảnh nguồn (art_source/textures, không commit) → gộp kênh vào assets/textures
bash tools/textures/generate_sources.sh    # bỏ qua ảnh đã có; xóa file để tạo lại
python tools/textures/build_textures.py
# SFX: video Flow đặt ở art_source/sfx/<ID>_take<N>.mp4 → tách/cắt/chuẩn hóa → assets/audio + catalog
python tools/audio/build_sfx.py            # ffmpeg: D:/ffmpeg-8.1-essentials_build/bin/ffmpeg.exe
python tools/audio/synth_placeholder_sfx.py  # âm tạm cho ID chưa có (không ghi đè ID đã 'generated')
```
Android (máy cắm USB, đã bật USB debugging):
```bash
"$GODOT" --headless --path . --export-debug "Android" build/GeoDash3D.apk
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r build/GeoDash3D.apk
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" logcat -s godot:V   # PERF / QUALITY / CALIBRATION lines
bash tools/device/perf_matrix.sh baseline "tier=low" noglow            # A/B đo FPS trên máy (màn hình phải mở)
bash tools/device/perf_ab.sh build/a.apk build/b.apk                    # so 2 APK ở tier LOW/MEDIUM thật, đo A-B-B-A
```
Trên Android, tham số debug truyền qua `user://debug_args.txt` (perf_matrix tự ghi bằng `run-as`).
Đo bản release: preset `Android Release Perf` (feature `perf_probe`, tham số trong `command_line/extra_args`), ký tạm bằng
debug keystore qua biến môi trường `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD` (chỉ để đo, không phát hành).

Main scene là menu; nếu có tham số level (sau `--`: `--start-beat=96 --autoplay --invincible --practice --rate=0.75 --clock=delta --chart=res://...`,
`--capture…`) menu tự chuyển thẳng vào level. Scene: `Scenes.MAIN_MENU / LEVEL / CALIBRATION / METRONOME / RECORDER` (`src/ui/scenes.gd`).
Menu truyền tùy chọn sang level qua `LaunchOptions.set_next_run()` (vd. practice).

## 3. Nền tảng: PC + Mobile
- Renderer: Forward+ trên desktop, **Mobile** trên Android/iOS (override theo platform trong `project.godot`).
- **Hình ảnh nền tảng phải đẹp với bộ tính năng của Mobile renderer**: emission + glow, depth fog, unshaded/baked lighting.
  SSR, SDFGI, volumetric fog, SSAO chỉ là "extra" của tier High trên PC, không được là thứ bắt buộc để màn chơi dễ đọc.
- Mọi VFX/hậu kỳ đọc `UserSettings.quality_tier` (`QualityTier`: Low/Medium/High). Mục tiêu: 60 FPS ổn định trên mobile tầm trung.
- Input: một action duy nhất `tap` (touch, chuột trái, Space). Không thêm action gameplay khác nếu chưa hỏi.
- Hướng màn hình: ngang (landscape). Tôn trọng safe area (tai thỏ) cho UI.

## 4. Cấu trúc thư mục
```
assets/music/       nhạc + file chart (*.chart.json) cùng tên
assets/models/      .glb đã xuất (KHÔNG sửa tay)
assets/textures/    texture chi tiết gộp kênh (sinh bằng tools/textures/build_textures.py, KHÔNG sửa tay)
assets/blender/     script bpy sinh model (nguồn thật của model)
src/core/           SongClock (node), TempoMap, UserSettings (autoload duy nhất), QualityTier
src/gameplay/       chart/, defs/ (Resource cấu hình), simulation/, track/ — logic thuần, không Node
src/presentation/   level/ (LevelRunner + level.tscn), camera, vfx, environment, track view, shaders/
src/ui/             HUD, menu, màn hiệu chỉnh độ trễ
src/authoring/      record mode, importer .sm, công cụ luyện tập (chưa làm)
tests/              test_*.gd kế thừa TestCase; tests/framework/ là runner
tools/              setup/ (cấu hình project), audio/ (phân tích + sinh chart), capture/out (ảnh, gitignored)
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
- Logic gameplay mới (đặc biệt phép tính thời gian) **phải có test**. Chạy test trước khi báo xong.
  `tests/gameplay/test_shipped_charts.gd` bắt buộc mọi chart trong `assets/music/` qua được bằng autoplay.
- Thay đổi hình ảnh: chụp ảnh bằng tool capture và tự xem trước khi báo xong.
- Thay đổi kiến trúc/định dạng dữ liệu: cập nhật `docs/architecture.md` trong cùng thay đổi.
- Commit: Conventional Commits (`feat(gameplay): ...`, `fix(core): ...`, `docs: ...`), kèm mã task nếu có.
  Được phép commit khi xong một task/milestone (người dùng đã giao toàn quyền, 2026-10-13).

## 7. Không được làm
- Không sửa `.godot/`, file `*.import`, `*.uid`; không tự bịa `uid://` trong `.tscn`/`.tres` (để Godot sinh,
  hoặc tham chiếu bằng đường dẫn `res://`).
- Không sửa tay `assets/models/*.glb` — sửa script trong `assets/blender/` rồi sinh lại.
- Không thêm addon/thư viện ngoài khi chưa hỏi.
- Màu dành riêng cho gameplay: hồng = gai/nhảy, cam = tường/lách làn, lime = cổng/lộn. Cảnh nền (đường, cảnh vật,
  decor) chỉ dùng tông lạnh; riêng **bầu trời** được tông ấm ở vài phase (`sunset`, `ember`; người dùng duyệt 2026-10-14).
- Ưu tiên tối thượng về hình ảnh: **giữ FPS gần như hiện tại** — chi phí mới phải theo `QualityTier`, LOW giữ nguyên nếu
  chưa đo trên máy thật.
- Âm thanh: nhạc luôn ở bus `Music` (âm lượng người dùng đặt trên bus); SFX qua `Sfx.play(id)` với ID có trong
  `tools/audio/sfx_spec.py`. Không phát SFX trong attract mode. Không commit video nguồn (`art_source/` bị ignore).

## 8. Nhạc
| File | Nguồn | Giấy phép | BPM | Offset |
|---|---|---|---|---|
| `assets/music/the_dawn_assembly.mp3` | Google Flow Music (AI) | **Chưa xác nhận dùng thương mại** | 120 | 0.058 s |
| `assets/music/fault_line.mp3` | Người dùng cung cấp 2026-10-14 (AI, hdgstudio86) | **Chưa xác nhận** | 128 | 0.448 s |
| `assets/music/pulse_drive.mp3` | Người dùng cung cấp 2026-10-14 (AI, hdgstudio86) | **Chưa xác nhận** | 122 | 0.5025 s |

Bản trùng audio (chỉ khác metadata) nằm ở `art_source/music_duplicates/` (không commit). Sáu bài cyber_rush(_take2),
neon_arcade_dash(_take2), tribal_battle_awakening(_take2) đã bỏ 2026-10-15 vì lần chạm không trùng cú đánh nổi bật
(`hit_grid.py`: 7–28 % ô nhịp, bài giữ 60–79 %); bản sao ở `art_source/removed_songs/`, chart còn trong lịch sử git.
