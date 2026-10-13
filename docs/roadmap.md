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
- [~] **GD3-030** Record mode + lượng tử hóa. Hiện có `draft_chart.py` sinh từ onset; chưa có ghi bằng phím.
- [ ] **GD3-031** Importer `.sm` (ArrowVortex/StepMania).
- [x] **GD3-032** Script dò onset gợi ý sự kiện (`analyze_song.py` + `draft_chart.py`).
- [~] **GD3-033** Luyện tập: đã có `--start-beat`, `--invincible`; chưa có UI checkpoint và phát chậm.

## Phase 4 — Trình bày
- [x] **GD3-040** `CameraDirector` (shot theo beat, blend, shake, FOV kick).
- [ ] **GD3-041** Model bằng Blender script: nhân vật chi tiết hơn, cổng, bệ nhảy, cầu gai treo.
- [x] **GD3-042** Vật liệu neon, fog, bầu trời, màu theo section.
- [x] **GD3-043** `VfxDirector`: trail, nhảy, tiếp đất, dash, perfect, chết, cue flash/shockwave/burst.
- [x] **GD3-044** Beat pulse (global shader uniform) + quality tiers.
- [~] **GD3-045** Đã có: menu chính (nền attract autoplay), cài đặt (chất lượng, âm lượng, offset), menu tạm dừng/kết thúc, nút pause cảm ứng. Chưa: chọn bài (mới có 1 bài).
- [ ] **GD3-046** Âm thanh hiệu ứng (chết, perfect) không làm lệch nhạc.

## Phase 4.5 — Mở rộng gameplay (yêu cầu playtest 2026-10-13)
Thiết kế đã chốt: `docs/design/gameplay_v2.md`.
- [ ] **GD3-070** Bỏ dash (vì gây cảm giác đổi tốc độ). Thêm `dodge_left/right`: lách sang làn trống để né tường 2 làn. Va chạm có thêm trục ngang.
- [ ] **GD3-071** Thêm `flip`: lộn qua mép xuống chạy ở mặt dưới đường để qua `gate`. Camera tự hạ xuống (flip assist), môi trường không lật.
- [ ] **GD3-072** Vật cản vào sân đúng nhịp: gai trồi lên, tường rơi xuống, cổng bung ngang. Kèm VFX khi tiếp đất.
- [ ] **GD3-073** Độ khó tăng dần về cuối: tốc độ chỉ tăng, mở khóa hành động dần, đoạn `finale` dày nhất. Có test kiểm tra.
- [ ] **GD3-074** Ký hiệu cue mới (↔ lách, ↻ lộn), dải sáng ở làn trống.

## Phase 5 — Mobile
- [ ] **GD3-050** Export Android, đo độ trễ và FPS trên máy thật.
- [ ] **GD3-051** Pre-warm shader/particles ở màn loading, tối ưu draw call.

## Phase 6 — Vertical slice
- [ ] **GD3-060** Hoàn thiện màn `the_dawn_assembly` sau playtest (nếu giấy phép nhạc cho phép phát hành).
