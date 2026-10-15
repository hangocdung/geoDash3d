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
- [x] **GD3-095** Đa dạng chướng ngại (người dùng thấy map đơn điệu): hàng 2/3 gai, lưỡi cưa xoay theo nhịp, trần gai,
      vòng nhảy lớn, vòng lao xuống; mẫu `spike2 spike3 saw borb dive`; `handmade.build` tự xen biến thể (giữ nhịp),
      `recording_level.py` xoay vòng các loại mới. Sinh lại mọi chart đặt tay/tool, dung sai tệ nhất vẫn ±90 ms.
      Thiết kế: `docs/design/gameplay_v3.md` mục 9. Chưa có SFX riêng cho vòng lớn/lao xuống.
- [x] **GD3-096** Vì sao The Dawn Assembly "khớp nhạc" còn các bài sau thì không: ở bài chuẩn, mỗi lần chạm trùng một cú
      đánh to gấp ~×5 các vị trí 1/4 phách xung quanh (motif 1 / 2 rưỡi / 3, giữa các cú gần như im lặng); các bài
      EDM/tribal dày chỉ ×1.1–2.6. Hai bài test tạo theo prompt "cú đánh nổi bật": `fault_line` (128 BPM, 134 lần
      chạm, ×5.5; điệp khúc 172–268 là khối âm dày, chỉ tiếng vỗ phách 4 nổi → ×2.4) và `pulse_drive` (122 BPM, 148
      lần chạm, ×4.4), đặt tay chỉ trên cú nổi bật (`tools/charting/levels/`), dung sai tệ nhất ±90 ms.
      Phát hiện kèm: `loudness_onsets.py`/`phrase_level.py` lấy khung 110 mẫu nhưng tính thời gian 5 ms (lệch 0.23%)
      → `cyber_rush.chart.json` bị khớp sai 134.72 BPM (đúng ~135), `.rec` chép header sai. **Đã sửa:** thời gian khung
      = 110 mẫu / 22050 Hz; `cyber_rush` (phrase) về 135 / 1.767 (×1.07 → ×1.41), sinh lại `cyber_rush.rec` và 2 chart
      `tribal_*_tool` (×1.17 → ×2.44, ×1.10 → ×1.58). Recording `cyber_rush` gõ trễ đều ~70 ms so với nhạc (lưới đúng
      với onset thật) → bản `.rec` còn lệch (×0.72) tới khi dùng ALIGN TIMING (lưới 1/2) trong màn RECORD.
- [ ] **GD3-093** Biome theo đoạn nhạc (bảng màu tông lạnh + bộ hình khối cảnh nền) — cần chọn chủ đề.

## Phase 4.8 — Đa dạng hình ảnh và nhịp độ (yêu cầu 2026-10-14, người dùng duyệt toàn bộ)
Ưu tiên tối thượng: **giữ FPS gần như hiện tại** (mọi chi phí hình ảnh mới theo tier, LOW giữ nguyên nếu chưa đo).
Người dùng cho phép **trời tông ấm** ở vài phase; camera trong vòng lộn/cuộn **bám theo đường**.
- [x] **GD3-100** Phase theo beat: chart `phases` (palette), mỗi phase nhanh hơn (bậc 7 → 10, trước đây 7 → 8.5–9),
      8 palette (`PaletteLibrary`, 2 palette trời ấm `sunset`/`ember` có mặt trời sọc), mọi vật liệu nền theo palette
      qua global `pal_*`, blend 1 beat (LOW đổi ngay), hiệu ứng đổi phase + cổng lớn + toast tốc độ. Sinh lại mọi chart;
      nhịp chạm không đổi, dung sai tệ nhất như cũ (±90 ms; `fault_line` ±80 ms như trước). Test: `test_phase_palettes.gd`.
- [x] **GD3-101** Vạch chạm (vòng cue, vòng nhảy) đập theo nhạc, vòng ngoài co dần chạm khít vạch đúng beat phải chạm
      (kiểu osu!), vạch lóe sáng đúng lúc đó; vòng dưới chân người chơi phát sóng mỗi beat, đổi màu theo hành động sắp tới.
      Thuần shader (glyph), +1 draw call.
- [x] **GD3-102** Đường đua đa dạng: `helix` (xoắn ốc 360°, lên 18), `loop` (vòng lộn dọc 12 beat, dịch ngang 7),
      `roll` (cuộn 360° trong 8 beat), `wave` (đồi), cua nghiêng `bank_deg`. Mỗi màn có 1 xoắn ốc, 1–3 vòng lộn, 2–3
      vòng cuộn, sóng và cua nghiêng (vòng lộn thường ở đầu phase/đoạn drop). Chỉ là hình ảnh, không đổi gameplay.
      Cột đỡ/cầu gai tránh chỗ không thẳng đứng hoặc có đường bên dưới; cảnh nền theo frame thẳng đứng.
      Test `test_track_shapes.gd` (hình học + mọi chart không tự cắt). **→ Cần người chơi thử cảm giác vòng lộn/cuộn.**
- [x] **GD3-103** Texture Codex (6 ảnh: tấm sàn, tấm lục giác, tấm hông, mặt tiền tháp, mạch, gờ cột) → 2 texture gộp kênh
      512 px. Đường: rãnh tấm sáng nhẹ + mạch đập theo beat; bệ: tấm lục giác; hông: tấm thông gió; tháp nền: cửa sổ
      sáng theo palette; cột: gờ dọc. MEDIUM/HIGH, mỗi pixel 1 lần lấy mẫu; **LOW giữ y như cũ** (ảnh so sánh lệch 1/255).
- [x] **GD3-104** 6 model chướng ngại mới (Blender): hàng rào laser, rìu con lắc, mìn gai, máy dập, tường lưới laser,
      cổng vòng — biến thể của gai / trần gai / tường / cổng (cùng cách vượt), chuyển động theo beat. Tool đặt màn tự xen
      kẽ; sinh lại mọi chart: nhịp chạm và dung sai không đổi. Test trong `test_obstacles.gd`. Thiết kế:
      `docs/design/gameplay_v3.md` mục 10. Dùng lại SFX vào sân có sẵn (`hazard.rise/drop/unfold`).
- [x] **GD3-105** Hiệu năng.
      - PC (Mobile renderer, A-B-B-A): draw call đo tất định tại 34 thời điểm của Pulse Drive. Trước phiên: 51.6. Bản đầu
        của phiên cao hơn 12–35 ở đoạn xoắn ốc. Sau tối ưu (model 1 draw call nhờ vai trò mặt trong vertex color + shader
        `neon_model`, lưới/hàng rào laser một mesh, mặt đường giữa các hố và bệ gộp theo đoạn 48 đơn vị): **54.1**.
      - Note10 Lite (máy nguội, `perf_ab.sh`, Pulse Drive từ beat 128, A-B-B-A): bản đầu tụt ở LOW 57.6 → 52.5 FPS, chỉ
        trong xoắn ốc (49.5 so với 56.5). Đo bằng cờ: trời (+4 FPS so với bản cũ — camera xoay liên tục làm mất transaction
        elimination) và đường (+4, thấy nhiều vòng xoắn). Vật cản, vòng co dần, hạt: không đáng kể.
        → Ở LOW `TrackPath.build(..., flatten)` duỗi xoắn ốc (giữ độ cao), vòng lộn, cuộn, bỏ nghiêng cua
        (`QualityTier.uses_spectacle_track`). Kết quả: **LOW 57.05 → 56.8 FPS, MEDIUM 40.4 → 40.05 FPS** (trong nhiễu),
        frame tệ nhất tốt hơn (33–38 ms so với 33–50 ms). Cờ `--perf=nodetail` để đo riêng texture chi tiết.
      - Đoạn Pulse Drive từ beat 72 (2026-10-15): MEDIUM 47.0 → 43.4 FPS; `nodetail` +1.6 FPS → texture chi tiết chỉ còn
        ở HIGH, shader tách biến thể không có code texture (`neon_track` / `neon_box` vs `*_detail`). Còn phải đo lại
        MEDIUM sau thay đổi này (`build/ab_new4.apk`).

## Phase 4.9 — Vật cản lộn tròn, nhạc mới (yêu cầu 2026-10-15)
- [x] **GD3-106** Hành động `roll` (lộn trọn vòng quanh đường) + vật cản `mace_sweep` (quả cầu gai lia dọc đường dưới khung
      cao) và `falling_block` (khối rơi chặn đường); camera xoay theo người chơi ở MEDIUM/HIGH. `HazardLibrary` tách khỏi
      `GameplayConfig`. Fault Line / Pulse Drive: một nửa số `flip` thành `roll`. Thiết kế: `gameplay_v3.md` mục 11.
- [x] **GD3-107** Đã bỏ 6 bài có lần chạm không nổi bật (cyber_rush(_take2), neon_arcade_dash(_take2),
      tribal_battle_awakening(_take2): `hit_grid.py` 7–28 % ô nhịp có cú đánh đáng chạm, `tap_salience.py` ×0.9–1.3; bài
      giữ 60–79 %, ×1.8–2.0). Bản sao ở `art_source/removed_songs/`. Công cụ mới: `tools/charting/tap_salience.py`
      (chấm chart), `tools/charting/hit_grid.py` (lưới cú đánh để đặt chạm + kiểm tra bài). 3 prompt nhạc trong
      `docs/design/music_prompts.md` (prompt tribal của người dùng đã chỉnh: tempo cố định, cú đánh rời rạc, motif
      1 / 2-và / 3, khối 8/16 ô nhịp có ô lặng trước mỗi phase). Người dùng tạo 6 bài (Neon Rhythm Stabs, Temple Battle
      Taiko, Tribal Battle Rhythm, mỗi bài 2 bản) → level bằng `tools/charting/hit_level.py` (chạm đúng thời điểm thật
      của các cú đánh nổi nhất, độ khó 1–5) + `fit_tempo.py`; dung sai tệ nhất ±90–110 ms; độ nổi ×1.5–1.9 nhưng attack
      chỉ ×2.0–2.4 (nhạc vẫn dày, xem `music_prompts.md` mục 7). Menu xếp bài từ dễ đến khó (`ChartDifficulty`, nhãn
      EASY … EXPERT). **→ Cần người chơi thử cảm giác khớp nhạc của 6 màn mới.**

- [x] **GD3-108** AUTOPLAY (DEV) trong menu bản debug (cùng hàng với RECORD (DEV)): bot chơi trọn màn đã chọn, HUD ghi
      "AUTOPLAY". Sửa kèm: nhãn chế độ HUD (PRACTICE / AUTOPLAY) bị tràn đè lên nút tạm dừng.

- [x] **GD3-109** Dàn LED equalizer trên mặt hông đường phía camera (16 dải tần tính trước theo bài, VU + chấm peak, màu
      theo palette, mờ thành dải sáng ở xa); `tools/audio/build_spectrum.py`, `SpectrumTexture`, global `song_seconds`.
      Đo Note10 Lite (Pulse Drive từ beat 72, A-B-C-C-B-A, máy nguội): LOW 59.65 → 59.15 FPS, MEDIUM 45.85 → 45.0 FPS.
      Bật ở mọi tier (`QualityTier.uses_led_wall`, người dùng chốt 2026-10-15).
      Cùng lần đo, bản trước phiên: LOW 59.75, MEDIUM 47.7 FPS → MEDIUM thấp hơn ~1.9 FPS khi chưa có LED (đã bỏ texture
      chi tiết ở MEDIUM); người dùng chấp nhận, không tìm tiếp (2026-10-15).

- [x] **GD3-110** Bài test "Pulse Drive (LED)" (`tools/charting/led_level.py`): chạm đúng lúc dàn LED bật vọt (tổng mức
      tăng của 16 dải so với ~20–80 ms trước, 100 khung/s, khớp vào onset gần nhất, bài nằm đúng lưới thì đặt vào ô 1/4
      phách) + đoạn dồn dập: chuỗi 3 lần bật vọt cách đều 1/2, 3/4 hoặc 1 phách ở đoạn mạnh được giữ nguyên (chuỗi vòng
      nhảy, bậc thang, nhảy liên tiếp), tối đa 1 chuỗi mỗi 8 beat. 252 lần chạm (bản đặt tay 148), 29 chuỗi, dung sai
      ±90 ms; độ nổi ×1.58 / attack ×2.50 (bản đặt tay ×2.03 / ×3.16). **→ Cần người dùng chơi thử so với bản đặt tay.**

- [x] **GD3-111** Điểm số + kỷ lục từng bài (điểm, % xa nhất, max combo, CLEARED) trong menu chọn bài, HUD, màn kết thúc
      (NEW BEST) và lần thử sau khi chết (BEST %). Combo chỉ đếm PERFECT (GREAT/GOOD không cộng, không làm đứt; đổi bằng
      `GameplayConfig.perfect_only_combo`). Lá chắn vẫn nạp theo combo (giờ là chuỗi PERFECT). Test `test_score.gd`.

- [x] **GD3-112** Chạy mặt dưới đường: `flip_down` lộn xuống và ở lại dưới đường, nhảy qua vật cản treo ngược, `flip_up`
      lộn lên (cổng `gate_under`). `ActionState` (tách khỏi `RunSimulation` vì giới hạn 300 dòng), `HazardDefinition.face`,
      `LevelChart.underside_ranges`, loader kiểm tra đoạn chạy; camera xoay ngược ở MEDIUM/HIGH, góc nhìn dưới đường ở
      LOW. Tool đặt màn biến cổng `flip` ở đoạn mạnh thành đoạn chạy mặt dưới; sinh lại 6 màn hit-level và Pulse Drive
      (LED). Test `test_underside.gd`. Thiết kế: `design/gameplay_v3.md` mục 12. Đo Note10 Lite (cùng APK, Pulse Drive (LED)
      từ beat 142 so với bản đối chứng không có đoạn chạy mặt dưới, A-B-B-A, thermal 1): LOW 59.4 vs 59.3 FPS,
      MEDIUM 45.3 vs 43.1 FPS → không tốn thêm (MEDIUM còn nhỉnh hơn khi camera lộn ngược).

- [x] **GD3-113** Thêm 2 màn test theo LED: "The Dawn Assembly (LED)" (121 lần chạm, 4 đoạn chạy mặt dưới) và "Fault
      Line (LED)" (191 lần chạm, 3 đoạn), `tools/charting/levels/*_led.py`. **→ Cần người dùng chơi thử.**

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
      Đã gộp vào GD3-260 trong `docs/todo.md`.

Kế hoạch phát hành (màn dọc, Firebase, quảng cáo, IAP, đánh giá app, UI, store, chỉ số): `docs/todo.md`
(GD3-200 … GD3-265). Các mục đã bắt đầu nằm ở Phase 7 bên dưới.

## Phase 6 — Vertical slice
- [ ] **GD3-060** Hoàn thiện màn `the_dawn_assembly` sau playtest (nếu giấy phép nhạc cho phép phát hành).

## Phase 7 — Phát hành (giai đoạn A của `docs/todo.md`)
- [~] **GD3-200** Giấy phép nhạc: đã đọc Google Terms (2026-10-15), tóm tắt và việc cần làm ở
      `docs/release/legal_and_brand.md` (quyền thương mại của Flow Music gắn với gói trả phí; bài hdgstudio86 cần văn
      bản cho phép). **→ Người dùng: gom bằng chứng gói/ngày tạo cho từng bài, hoặc thay bài.**
- [~] **GD3-201** Tên game: đề xuất "Pulse Rail" (+ Beat Rail, Rhythm Rail) trong `docs/release/legal_and_brand.md`.
      **→ Người dùng chốt tên sau khi tra store + nhãn hiệu**; sau đó Claude đổi tên app, package, icon.
- [~] **GD3-202** Bản nháp chính sách quyền riêng tư vi/en: `docs/release/privacy_policy.md`. **→ Người dùng điền tên,
      email, đăng ở URL công khai** (khi có Firebase/AdMob).
- [~] **GD3-203** Đề xuất 13+, không nhắm trẻ em, cấu hình AdMob/Play tương ứng (`legal_and_brand.md`). **→ Người dùng duyệt.**
- [~] **GD3-210** Ngang + dọc trong một bản (người dùng yêu cầu 2026-10-15): menu xoay theo máy, vào màn chơi thì
      khóa hướng tới khi về menu (`DisplayOrientation`, `Scenes.go_to`); canvas UI 1920×1080 / 1080×1920 theo cửa sổ;
      bộ shot sau/trên cho 9:16 (`CameraShots._portrait_shot`); `--portrait` ép dọc để chụp/đo. Ảnh 720×1280: đường phía trước thấy rõ, HUD vừa. Sửa player sát/mất
      mép ở màn dọc (phản hồi 2026-10-15): bỏ lệch ngang của camera dọc + `_keep_in_frame` giữ khối player trong vùng an
      toàn; `tools/capture/portrait_framing.gd` đo 13 chart × tier LOW/MEDIUM/HIGH: trước 1112 khung hình bị cắt (riêng
      The Dawn Assembly), sau 0; player luôn trong 14–85 % ngang, 22–85 % dọc. **Còn lại:** đo FPS trên máy
      (`EXTRA_ARGS="--portrait --start-beat=64" bash tools/device/perf_matrix.sh baseline` so với không `--portrait`),
      người chơi thử theo tiêu chí GD3-211.
- [x] **GD3-220** Một lệnh sinh level: `tools/charting/auto_level.py` (+ `song_tempo.py`, `check_chart.gd`). Đo BPM đúng
      9/9 bài đang có (sai số ≤ 0.05 BPM; Tribal 100/150 và Temple Alt 120/160 bị báo "không chắc" → hỏi). Chạy thử trên
      Pulse Drive: 122 BPM, 66 % ô nhịp có X, 77 % cú bật LED trên lưới → snap, độ khó 4, 253 chạm, autoplay qua, dung
      sai ±90 ms, độ nổi ×1.60 / ×2.41 (WEAK như mọi bản LED). Ghi chú: theo `hit_grid` ở offset hiện tại, 6 bài
      hdgstudio86 thêm ngày 2026-10-15 chỉ đạt 3–30 % ô nhịp có X (ngưỡng 50 %).
- [~] **GD3-231** Bộ event: lớp `Telemetry` (kiểm tra luật Firebase, log ở bản debug) + `RunTelemetry` (level_start,
      level_end đủ tham số trong `docs/todo.md`, new_best, first_clear), `calibration_done`, `song_select`. Test
      `tests/core/test_telemetry.gd`. **Còn lại:** plugin Firebase thật (GD3-230, cần duyệt), `perf_sample` (GD3-235),
      event cửa hàng/đánh giá (theo GD3-241/244), user property.
- [x] **GD3-253** Rung phản hồi: `Haptics` (PERFECT 12 ms, vỡ lá chắn 35 ms, chết 70 ms), tùy chọn Settings →
      Vibration, quyền `vibrate` trong preset Android. **→ Cần thử cảm giác trên máy.**
- [x] **GD3-252** Ngôn ngữ vi/en: `Locale` nạp `assets/i18n/<mã>.json` lúc chạy (khóa = chữ tiếng Anh, không cần import),
      Settings → Language (AUTO theo máy / English / Tiếng Việt), `-- --lang=vi` để chụp ảnh. Chuỗi có định dạng dùng
      `Locale.t("ATTEMPT %d") % n`; tên điểm chấm (PERFECT…), COMBO, nhãn độ khó và công cụ DEV giữ tiếng Anh. Test
      `tests/core/test_locale.gd` (mọi `Locale.t` có bản dịch, placeholder khớp). Thêm ngôn ngữ: thêm mã vào
      `Locale.LANGUAGES` + file json.
