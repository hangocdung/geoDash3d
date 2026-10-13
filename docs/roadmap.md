# Roadmap GeoDash3D

Trạng thái: `[ ]` chưa làm · `[~]` đang làm / làm một phần · `[x]` xong. Mỗi task kết thúc khi có test hoặc ảnh chụp kiểm chứng.

## Phase 0 — Khởi tạo
- [x] **GD3-001** `project.godot`, renderer override PC/Mobile, input `tap/pause/restart`, cấu trúc thư mục, git.
- [x] **GD3-002** Test runner headless tự viết (thay cho GUT, để không phụ thuộc addon ngoài).
- [x] **GD3-003** Chụp ảnh: `--capture=t1,t2` (autoplay, đồng hồ frame-delta), `--capture-manual`.

## Phase 1 — Lõi nhịp điệu
- [x] **GD3-010** `SongClock` (bù độ trễ, làm mượt, count-in, pause). Đo thực tế lệch ±7 ms.
- [x] **GD3-011** `TempoMap` + test.
- [x] **GD3-012** Đo BPM/offset `the_dawn_assembly`: 120 BPM, offset 0.058 s (`tools/audio/analyze_song.py`).
- [x] **GD3-013** Scene metronome / SYNC TEST: click khóa mẫu với nhạc (`AudioStreamSynchronized`), nháy theo beat, chỉnh offset trực tiếp.
- [x] **GD3-014** Màn hiệu chỉnh độ trễ: 4 nhịp đếm + 16 nhịp gõ, ước lượng bền (median/MAD) → `UserSettings.audio_offset_sec`.

## Phase 2 — Prototype gameplay
- [x] **GD3-020** Chart JSON v1 + loader + validate + test.
- [x] **GD3-021** `TrackPath` (straight/turn/slope) + test.
- [x] **GD3-022** Chuyển động jump/dash (ActionDefinition).
- [x] **GD3-023** `ActionResolver` + chấm timing + input buffer + test.
- [x] **GD3-024** `HazardChecker`, chết → tự chơi lại, thanh tiến độ.
- [x] **GD3-025** Autoplay + test "mọi chart đều qua được".
- [x] **GD3-026** Màn đầu tiên đủ bài (84 hành động). **→ Cần người chơi thật đánh giá cảm giác.**

## Phase 3 — Công cụ xếp màn
- [x] **GD3-030** Record mode (menu RECORD (DEV)): gõ theo nhạc 3 làn, timeline, undo/xóa đoạn, chậm 50–75%, lưu `<id>.recording.json`; `draft_chart.py` lượng tử hóa (`recording`, `fixed`).
- [x] **GD3-031** `tools/charting/sm_to_recording.py`: `.sm` (ArrowVortex/StepMania) → recording → chart.
- [x] **GD3-032** Script dò onset gợi ý sự kiện (`analyze_song.py` + `draft_chart.py`).
- [x] **GD3-033** Luyện tập (menu PRACTICE): checkpoint mỗi 16 beat + đầu mỗi đoạn, chết → chạy lại trước checkpoint, tốc độ 100/75/50%.

## Phase 4 — Trình bày
- [x] **GD3-040** `CameraDirector` (shot theo beat, blend, shake, FOV kick).
- [x] **GD3-041** Model bằng Blender script (`assets/blender/generate_models.py`, quy ước material Body/Glow/GlowAlt → `NeonModel`): cổng vòng ở đầu mỗi đoạn nhạc, cầu gai treo đung đưa theo nhịp (`DecorView`).
- [x] **GD3-042** Vật liệu neon, fog, bầu trời, màu theo section.
- [x] **GD3-043** `VfxDirector`: trail, nhảy, tiếp đất, dash, perfect, chết, cue flash/shockwave/burst.
- [x] **GD3-044** Beat pulse (global shader uniform) + quality tiers.
- [~] **GD3-045** Đã có: menu chính (nền attract autoplay), cài đặt (chất lượng, âm lượng, offset), menu tạm dừng/kết thúc, nút pause cảm ứng. Chưa: chọn bài (mới có 1 bài).
- [~] **GD3-046** SFX: autoload `Sfx` (catalog, bus Music/SFX/UI, random biến thể + pitch, giới hạn polyphony), gắn vào nhảy/tiếp đất/chết/perfect/checkpoint/hoàn thành/UI; âm **tạm** tổng hợp bằng code. Prompt video: `docs/design/sfx/sfx_video_prompts.md`; xử lý: `tools/audio/build_sfx.py`. **Chờ người dùng tạo video Flow.**

## Phase 4.5 — Mở rộng gameplay (yêu cầu playtest 2026-10-13)
Thiết kế đã chốt: `docs/design/gameplay_v2.md`.
- [x] **GD3-070** Bỏ dash (vì gây cảm giác đổi tốc độ). Thêm `dodge_left/right`: lách sang làn trống để né tường 2 làn. Va chạm có thêm trục ngang.
- [x] **GD3-071** Thêm `flip`: lộn qua mép xuống chạy ở mặt dưới đường để qua `gate`. Camera tự hạ xuống (flip assist), môi trường không lật.
- [x] **GD3-072** Vật cản vào sân đúng nhịp: gai trồi lên, tường rơi xuống, cổng bung ngang. Kèm VFX khi tiếp đất.
- [x] **GD3-073** Độ khó tăng dần về cuối: tốc độ chỉ tăng, mở khóa hành động dần, đoạn `finale` dày nhất. Có test kiểm tra.
- [x] **GD3-074** Ký hiệu cue mới (↔ lách, ↻ lộn), dải sáng ở làn trống.

## Phase 5 — Mobile
- [x] **GD3-050** Export Android (`export_presets.cfg`, arm64, debug keystore), cài và đo trên Galaxy Note10 Lite
      (Mali-G72, Vulkan Mobile). Đo bằng `PerfProbe` + `tools/device/perf_matrix.sh`. Kết quả, khi máy đang ấm
      (thermal status 1): LOW khoảng 53 FPS, MEDIUM khoảng 38 FPS. Glow tốn cố định khoảng 14 FPS trên Mali.
      Android báo output latency = 0, nên **bắt buộc calibrate**.
- [x] **GD3-051** Tối ưu mobile:
      - Bầu trời tính ở nửa độ phân giải, không đổi tham số sky mỗi frame.
      - Tier LOW: không glow, quầng sáng giả trong shader (`soft_glow`), render 70%.
      - Cảnh nền chia đoạn MultiMesh có visibility range, mật độ theo tier.
      - Tự chọn tier ở menu (`QualityAutoTuner`, mục tiêu 55 FPS).
      - Làm nóng VFX trong count-in.
- [~] **GD3-052** Đo lại khi máy nguội (Note10 Lite, thermal 0):
      - LOW: 57–58 FPS ổn định, không frame khựng sau khi tải màn.
      - MEDIUM: khoảng 41 FPS. HIGH: khoảng 35 FPS.
      - Bản release (preset `Android Release Perf`) nhanh hơn debug khoảng 1 FPS, vì game nghẽn ở GPU.
      - **Còn lại:** đo trên 1–2 máy tầm trung đời mới.
- [ ] **GD3-053** Bản release: keystore release, icon, tên app, AAB cho Google Play (cần quyết định của người dùng).

## Phase 6 — Vertical slice
- [ ] **GD3-060** Hoàn thiện màn `the_dawn_assembly` sau playtest (nếu giấy phép nhạc cho phép phát hành).
