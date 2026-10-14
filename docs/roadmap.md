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
- [x] **GD3-014** Màn hiệu chỉnh độ trễ (AUDIO SYNC), làm lại sau phản hồi 2026-10-13:
      - Chỉ một loại click; chạm ngay từ tiếng đầu (4 lần đầu tự bỏ qua).
      - Vòng tròn nháy theo 6 click đầu rồi chỉ nghe; tự kết thúc sau 16 lần đo.
      - Ước lượng bền (median/MAD) → `UserSettings.audio_offset_sec`.
      - Sửa lỗi Android: Control gốc phủ toàn màn hình nuốt mọi cú chạm.
      - Đo thật trên Note10 Lite (loa ngoài): −6 ms, ±31 ms → mặc định 0 ms là hợp lý.

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
- [x] **GD3-034** Xếp màn bằng recording: màn RECORD chậm tới 25% (giữ cao độ), sửa từng note, lặp A–B, chọn bài;
  `tools/charting/recording_level.py` dựng level địa hình từ các điểm gõ (`<id>.rec.chart.json`). SongClock bù độ
  trễ theo `playback_rate`. Đã thử bằng recording giả lập (nhịp level Tribal/Cyber Rush ±30 ms) → qua autoplay.
  Làm lại giao diện: chia đoạn 16 beat theo section, timeline cố định cả đoạn (click để phát từ đó, kéo-thả/
  double-click/chuột phải để sửa note), nút bấm cho mọi chức năng, undo/redo, ALIGN TIMING, BUILD & PLAY SEGMENT
  (chơi thử rồi quay lại màn RECORD).
  Một loại đánh dấu duy nhất (tool tự chọn cả tường/cổng). Mỗi đoạn hiện thời gian + số note gợi ý theo độ khó
  (EASY/NORMAL/HARD, lấy mật độ của `the_dawn_assembly` làm mức HARD).
  **→ Cần người dùng thử ghi thật (âm thanh ở 25%, thao tác chuột).**

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

## Phase 4.6 — Gameplay v3: địa hình (yêu cầu 2026-10-14)
Thiết kế: `docs/design/gameplay_v3.md`. **Đã duyệt 2026-10-14: map địa hình thành map chính.**
- [x] **GD3-080** `Terrain` + chart `terrain` (bệ, hố) + validate; vật cản đứng trên mặt đất.
- [x] **GD3-081** Nhảy thành parabol tới khi tiếp đất (`VerticalMotion`): đâm hông bệ/rơi hố = chết, chạy khỏi mép = rơi,
      chỉ nhảy tiếp khi đã chạm đất; vòng nhảy `orb` (chạm khi đang bay), bệ bật `pad`; `ReferenceRun`; test.
- [x] **GD3-082** Hiển thị: bệ/hố/mặt đứng có viền, vòng nhảy, bệ bật, camera bám địa hình, khối xoay khi bay.
      Đo trên Note10 Lite (máy nguội): LOW 57 FPS (chart gốc cùng đoạn 55.5), MEDIUM 40 FPS như chart gốc.
- [x] **GD3-083** Map chính `the_dawn_assembly.chart.json` (116 beat, 58 lần chạm) từ
      `tools/charting/the_dawn_assembly_level.py`; `tools/charting/tolerance_report.gd` (dung sai tệ nhất ±90 ms).
      Map cũ giữ ở `the_dawn_assembly.classic.chart.json`.
- [x] **GD3-084** Bộ sinh level địa hình tự động `tools/charting/terrain_level.py` (thư viện mẫu chung
      `terrain_patterns.py`, có dodge/flip ở đoạn phẳng): 4 bài mới (cyber_rush, cyber_rush_take2, neon_arcade_dash,
      neon_arcade_dash_take2), mỗi bài 79–147 lần chạm, dung sai tệ nhất ±90 ms, qua mọi test. Menu chọn bài.
      Người dùng thấy bản tự sinh không khớp nhạc → **4 bài được đặt tay theo câu nhạc** (`tools/charting/levels/`,
      `handmade.py`): 135–179 lần chạm, 89–100% lần chạm trong 35 ms quanh onset thật, dung sai tệ nhất ±90 ms.
      Sửa kèm lỗi: cú nhảy được buffer lúc kết thúc lộn/lách làn bị "tiếp đất" ngay (VerticalMotion).
      Còn lại: map the_dawn_assembly mới phủ 116/224 beat, SFX riêng cho orb/pad.

## Phase 4.7 — Cảm giác chơi (đề xuất 2026-10-14, theo thứ tự)
- [x] **GD3-090** Combo + lá chắn nạp theo combo (16 lần trúng → 1 lá chắn): vật cản vỡ, rơi/đâm bệ thì về quỹ đạo
      chuẩn để không lệch nhịp; HUD combo + thanh nạp, MAX COMBO; SFX tạm `player.shield(_break)`; test.
      Công cụ: `--autoplay-miss`, `--capture-continuous`.
- [x] **GD3-091** Sóng năng lượng chạy dọc đường theo beat (mặt sóng + đuôi trên đường kẻ làn) + vật cản sáng dần
      khi tới gần (`proximity_gain`, sáng lên chứ không nhấp nháy). Chỉ là shader, theo `run_beat`/`player_distance`.
- [x] **GD3-092** Speed lines ở MEDIUM (18) / HIGH (32), không có ở LOW; phát ở phía nền sau đường để không che
      đường chạy; mật độ theo energy đoạn nhạc; tắt khi chết.
- Đo A/B trên Note10 Lite (`tools/device/perf_ab.sh`, bản `main` trước GD3-090 so với sau GD3-092, đo A-B-B-A):
  LOW 56.3/56.0 → 56.1/57.9 FPS, MEDIUM 40.5/40.8 → 40.7/40.7 FPS, draw call +6. Không đo được chi phí.
  Số frame khựng ở MEDIUM nhỉnh hơn (5/5 so với 1/4 trong 15 s) — trong ngưỡng nhiễu, cần theo dõi.
- [x] **GD3-094** Bầu trời sáng nhẹ theo nhịp (chỉ phần nền, mạnh ở chân trời) + tùy chọn Settings → Reduce flashing.
      Đo Note10 Lite: MEDIUM không đổi (40.3 → 40.2), nhưng LOW tụt ~3 FPS (56.4 → 53.2, điệp khúc xuống 43–48).
      Cùng bản build, biên độ 0 thì về 56.0 → chi phí do trời đổi mỗi frame (nhiều khả năng mất transaction
      elimination của Mali), không phải do radiance. Quyết định: tắt nhịp trời ở LOW.
- [ ] **GD3-093** Biome theo đoạn nhạc (bảng màu tông lạnh + bộ hình khối cảnh nền) — cần chọn chủ đề.

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
- [x] **GD3-054** Tự chỉnh độ trễ khi đang chơi (Settings → Auto sync, mặc định bật):
      - `RunSimulation.tap_timed` báo độ lệch của mọi lần chạm trong ±400 ms quanh cue, kể cả lần trượt cửa sổ.
      - `AutoOffsetLearner` dùng median + MAD; chỉ chỉnh **giữa các lượt**.
      - Ba mức chỉnh: ≥100 ms (3 mẫu, 90%), ≥30 ms (8 mẫu, 70%), ≥12 ms (20 mẫu, 50%).
      - Không học khi autoplay, attract, capture hoặc luyện tập chậm. HUD báo "ATTEMPT n · SYNC +x ms".
- [ ] **GD3-053** Bản release: keystore release, icon, tên app, AAB cho Google Play (cần quyết định của người dùng).

## Phase 6 — Vertical slice
- [ ] **GD3-060** Hoàn thiện màn `the_dawn_assembly` sau playtest (nếu giấy phép nhạc cho phép phát hành).
