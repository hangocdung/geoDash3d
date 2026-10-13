# Roadmap GeoDash3D

Trạng thái: `[ ]` chưa làm · `[~]` đang làm · `[x]` xong. Mỗi task kết thúc khi có test/ảnh chụp kiểm chứng.

## Phase 0 — Khởi tạo
- [ ] **GD3-001** Tạo `project.godot` (renderer override PC/Mobile, input action `tap`, landscape, cảnh báo untyped),
      cấu trúc thư mục, `.gitignore`, `git init`, chuyển nhạc vào `assets/music/`.
- [ ] **GD3-002** Cài GUT, lệnh chạy test headless, một test mẫu.
- [ ] **GD3-003** Tool capture: chạy chart tới thời điểm T, lưu ảnh PNG để kiểm tra hình ảnh.

## Phase 1 — Lõi nhịp điệu
- [ ] **GD3-010** `SongClock` (bù độ trễ, làm mượt, các trạng thái, count-in).
- [ ] **GD3-011** `TempoMap` + test (BPM thay đổi).
- [ ] **GD3-012** Đo BPM/offset của `The_Dawn_Assembly` (ArrowVortex hoặc script Python), ghi vào `CLAUDE.md` mục 8.
- [ ] **GD3-013** Scene metronome debug: tiếng click + nháy sáng mỗi beat để kiểm tra đồng bộ bằng tai/mắt.
- [ ] **GD3-014** Màn hiệu chỉnh độ trễ (người chơi gõ theo nhịp → tính offset).

## Phase 2 — Prototype gameplay (hộp xám)
- [ ] **GD3-020** `LevelChart` loader + validate JSON + test.
- [ ] **GD3-021** `TrackPath` sinh từ chart (thẳng, cong, dốc) + test `distance_at`.
- [ ] **GD3-022** `PlayerMotion`: jump, dash (Resource hành động).
- [ ] **GD3-023** `ActionResolver` + chấm timing + test.
- [ ] **GD3-024** `HazardChecker`, chết/chơi lại, thanh tiến độ.
- [ ] **GD3-025** Autoplay + test "chart qua được".
- [ ] **GD3-026** Màn thử nghiệm đầu tiên ~30 giây với hộp xám → **đánh giá cảm giác chơi trước khi đi tiếp**.

## Phase 3 — Công cụ xếp màn
- [ ] **GD3-030** Record mode + lượng tử hóa.
- [ ] **GD3-031** Importer `.sm` (ArrowVortex/StepMania).
- [ ] **GD3-032** Script Python dò onset gợi ý sự kiện (tùy chọn).
- [ ] **GD3-033** Luyện tập: bắt đầu tại beat, lặp đoạn, phát chậm.

## Phase 4 — Trình bày
- [ ] **GD3-040** `CameraDirector` (shot theo beat/section, blend, shake, FOV kick).
- [ ] **GD3-041** Bộ model hình học bằng Blender script (khối, gai, bệ nhảy, cổng, cầu gai).
- [ ] **GD3-042** Vật liệu neon (emission + glow), fog, bảng màu theo section.
- [ ] **GD3-043** `VfxDirector` + hiệu ứng: trail, nhảy, tiếp đất, dash, chết, drop.
- [ ] **GD3-044** `BeatPulse` + `QualitySettings` tiers.

## Phase 5 — Mobile
- [ ] **GD3-050** Export Android, đo độ trễ và FPS trên máy thật.
- [ ] **GD3-051** Pre-warm shader, tối ưu draw call/hạt.

## Phase 6 — Vertical slice
- [ ] **GD3-060** Màn hoàn chỉnh đầu tiên với `The_Dawn_Assembly` (nếu giấy phép cho phép phát hành).
