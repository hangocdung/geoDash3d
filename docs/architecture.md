# Kiến trúc BeatGlide (mã nguồn: GeoDash3D)

> Trạng thái: prototype chơi được với 1 bài (`the_dawn_assembly`). Mục 7 ghi những gì chưa làm.

## 1. Luồng dữ liệu

```
AudioStreamPlayer ─► SongClock ─ song_time ─► LevelRunner ── beat ──► RunSimulation (logic thuần, theo beat)
                        ▲                         │  ▲                    │ signals: action_started/finished,
 InputEvent "tap" ─ now() ┘                        │  └─ tap(beat) ─────────┘ cue_judged, player_died, run_completed
                                                  ▼
 *.chart.json ─► ChartLoader ─► LevelChart ─► TrackPath   Presentation: PlayerView, CameraDirector, ObstacleView,
                                                         VfxDirector, EnvironmentDirector, Hud
```
- Gameplay (`src/gameplay/`) là `RefCounted` thuần, không có Node, nên test được hoàn toàn headless.
- Presentation chỉ đọc state (`player_height_at`, `action_progress_at`…) và nghe signal. Không ghi ngược vào logic.
- `LevelRunner` là nơi duy nhất nối hai phía.

## 2. Thời gian (`src/core/`)
- **SongClock** (Node con của level, *không phải autoload*):
  - Ba chế độ: `AUDIO_SYNC` khi chơi thật; `FRAME_DELTA` khi chụp ảnh hoặc quay phim (tất định); `MANUAL` khi test.
  - Thời gian người chơi nghe thấy = `playback_position + time_since_last_mix − (output_latency + calibration) × rate`.
    Latency và calibration là độ trễ theo đồng hồ thật, nên khi phát chậm (`playback_rate` < 1) chúng phủ ít thời
    gian bài hơn; trước GD3-034 phần này không nhân `rate` nên luyện tập/ghi ở tốc độ chậm bị bù lố.
  - Lệch dưới 50 ms thì kéo dần về 12% mỗi frame; lệch hơn thì nhảy thẳng. Thời gian không bao giờ chạy lùi.
  - Audio được phát *sớm* đúng bằng latency + calibration để âm thanh khớp với hình.
  - SFX tiếp đất cũng phát sớm đúng độ trễ đó (GD3-258): `PresentationRouter` hỏi `LandingPredictor` (bước thử một
    bản sao `VerticalMotion` trên lưới mô phỏng, chỉ đọc) xem có tiếp đất trong khoảng độ trễ tới không, phát tiếng
    kick ngay, rồi bỏ qua tiếng của chính lần tiếp đất đó. Tiếng chạm phát ngay lúc chạm (không đoán trước được).
  - Đếm ngược trước nhạc: thời gian bắt đầu âm và chạy theo đồng hồ hệ thống cho tới 0.
  - Đã đo thực tế: lệch ±7 ms trên PC (`--debug-clock`).
- **TempoMap**: beat ⇄ giây, hỗ trợ đổi BPM. Xây trên `PiecewiseLinearMap`, cấu trúc này cũng dùng cho beat → khoảng cách.
- **AutoOffsetLearner / SyncLearning** (GD3-054): học độ trễ từ độ lệch các lần chạm (`tap_timed`), chỉ áp dụng
  giữa các lượt chơi để mô phỏng trong một lượt luôn tất định; `begin_run` nạp lại offset vào SongClock.
- **UserSettings** (autoload duy nhất): `audio_offset_sec`, `quality_tier`, `music_volume_db`, `reduce_flashing`…, lưu ở
  `user://settings.cfg`.

## 3. Gameplay (`src/gameplay/`)
- **Cấu hình** (`defs/`): `GameplayConfig` gồm cửa sổ timing, kích thước đường/người chơi, bước mô phỏng và thư viện
  vật cản `HazardLibrary`, cùng `ActionDefinition` (`kind` JUMP / DODGE / FLIP, `offset_at(progress) → (lateral, height)`) và `HazardDefinition`
  (hộp va chạm 3 trục + kiểu hiển thị SPIKE/WALL/GATE + kiểu vào sân RISE/DROP/UNFOLD, `appear_beat`).
  Chi tiết thông số: `docs/design/gameplay_v2.md`.
- **Chart** (`chart/`): `ChartLoader` gom *mọi* lỗi validate rồi báo một lượt. `LevelChart` lưu cue (theo beat),
  vật cản (theo khoảng cách), camera, vfx, section, phase (`phase_index_at`, tên palette chỉ là dữ liệu: phần trình
  bày tra cứu), track. Hàm `safe_start_beat()` lùi điểm bắt đầu để không
  kẹt trước vật cản có cue đã bị bỏ qua. Định dạng chi tiết: `docs/chart_format.md`.
- **RunSimulation** (`simulation/`):
  - Va chạm chỉ kiểm tra trên lưới cố định 1/96 beat, nên kết quả không phụ thuộc FPS (có test chứng minh).
  - Xử lý một lần chạm: `ActionResolver` tìm cue gần nhất trong ±150 ms rồi chấm điểm. Không có cue nào thì
    thực hiện hành động mặc định (jump).
  - Jump/orb/pad là **parabol** trong `VerticalMotion` (y = y0 + v·t − ½·g·t², theo beat), kết thúc khi tiếp đất.
    Dodge/flip vẫn là hành động thời lượng cố định (`ActionState`), cộng offset lên độ cao nền.
  - Chạy mặt dưới (GD3-112): `ActionState.underside` bật khi `flip_down` kết thúc, tắt khi `flip_up` bắt đầu. Khi đó
    mặt đất là mặt dưới phẳng của đường (độ cao 0, loader đã kiểm tra đường liền), `player_offset_at` trả
    −(độ dày đường + cạnh khối) − độ cao nhảy (nhảy là đi xa khỏi mặt dưới). Vật cản trong đoạn chạy mặt dưới
    (`LevelChart.underside_ranges`, theo `HazardDefinition.face`: `FOLLOW_RUN` / `TOP` / `UNDERSIDE`) có
    `HazardPlacement.underside`, hộp va chạm lật xuống dưới mặt dưới đường trong `HazardChecker`. Va chạm được tha
    (lá chắn, bất tử) đưa người chơi về đúng mặt của lượt hoàn hảo (`ActionState.follow_run`), để lỡ `flip_up`
    không kẹt dưới đường cả màn.
  - Đang bay chỉ chạm được cue `orb` (`ActionDefinition.air_allowed`). Lần chạm khác được *buffer* và chỉ thực
    hiện nếu tiếp đất trong ≤ 100 ms sau đó (dodge/flip: ≤ 100 ms trước khi kết thúc).
  - Địa hình: mỗi bước so độ cao người chơi với `Terrain.support_height` (đất cao nhất dưới hộp ±0.38).
    Đâm hông bệ (cao hơn chân quá `step_snap`) hoặc rơi dưới `fall_death_height` → chết với
    `TERRAIN_HIT` (−2). Chạy khỏi mép → rơi tự do. Bệ bật (`chart.pads`) tự phóng khi đang đứng chạm vào.
  - Signal `player_landed(beat, airtime)` cho mọi lần tiếp đất; `action_finished` chỉ còn cho dodge/flip.
  - `PlayerBody` gói chuyển động lên xuống (`VerticalMotion`), đất dưới chân, rơi khỏi mép và bệ bật.
  - Điểm (`ScoreKeeper`, GD3-111): mỗi cue được điểm theo bậc (`GameplayConfig.grade_points` 300/150/50/0) × (1 + 0.01 ×
    min(combo, 100)); `max_score` = tổng khi mọi cue PERFECT (độ chính xác). Combo **chỉ đếm PERFECT**
    (`perfect_only_combo`): GREAT/GOOD làm đứt combo (về 0) như MISS; MISS hoặc va chạm được lá chắn đỡ thì về 0.
    Kỷ lục từng chart: `HighScores` (`user://scores.cfg`: điểm, % xa nhất, max combo, đã hoàn thành), ghi bởi
    `RunRecords` chỉ cho lượt thường (không luyện tập/autoplay/attract/chụp/bất tử); HUD hiện điểm, màn kết thúc hiện
    điểm + độ chính xác + NEW BEST / BEST, lần thử sau khi chết hiện BEST %, danh sách bài hiện BEST.
  - Combo và lá chắn (`ComboShield`, đọc qua `simulation.streak`): mọi cú va chạm chết người đi qua
    `_survive_hit` — bất tử thì ghi lại, có lá chắn thì vật cản vỡ (thêm vào `hit_hazards`) hoặc, với địa hình,
    `VerticalMotion.restore()` về trạng thái của lượt hoàn hảo (`chart.reference_motion_at`). Signal
    `combo_changed`, `shield_changed`, `shield_used`.
  - `HazardChecker` xét chồng lấn hộp (khoảng cách × ngang × độ cao), hộp vật cản đặt trên mặt đất tại chỗ
    (`HazardPlacement.base_height`), có cursor vì người chơi chỉ đi tới.
  - `invincible` ghi lại các lần trúng thay vì chết (đâm bệ thì đặt lên mặt bệ), dùng cho luyện tập và soạn màn.
- **ReferenceRun**: lúc nạp chart, chạy autoplay một lượt (invincible) để ghi `chart.cue_heights` (độ cao người chơi
  ở mỗi cue: vòng cue và vòng nhảy vẽ ở đó), `chart.airborne_ranges` (khoảng đang bay: `safe_start_beat` không
  bao giờ chọn điểm bắt đầu giữa không trung) và `reference_beats/motions` (trạng thái lên xuống, cho lá chắn).
  Chart phẳng (không địa hình/bệ bật/vòng nhảy) bỏ qua bước này.
- **Autoplay**: chạm đúng mọi cue. Dùng cho test, chụp ảnh và chế độ demo.
- **TrackPath** (`track/`): bảng frame mỗi 0.5 đơn vị (quaternion + hướng yaw), tích phân từ các đoạn
  straight/turn (có thể nghiêng)/slope/helix/loop/roll/wave (dùng midpoint). Loop đi theo cung thật trong mặt phẳng
  dọc và dịch ngang; helix/wave/slope cộng độ cao lên bước ngang (độ cao chính xác). Trục của frame: X = hướng đi,
  Y = lên, Z = bên phải (phía camera side). Ngoài hai đầu thì ngoại suy thẳng. `upright_transform_at` chỉ theo hướng
  (cho cảnh nền), `is_upright_at` (cột đỡ, cầu gai). `TrackClearance`: lưới ô 8 đơn vị để tìm chỗ đường tự cắt
  (test) và kiểm tra cột đỡ không xuyên qua đoạn đường bên dưới. Camera bám frame (xoay theo vòng lộn/cuộn, người
  dùng chọn 2026-10-14). Ở LOW `LevelRunner` dựng đường với `flatten` (`TrackPath.flattened_segments`, theo
  `QualityTier.uses_spectacle_track`): đo trên Mali-G72, xoắn ốc tốn 5–7 FPS ở LOW.
- **Terrain** (`track/terrain.gd`, gameplay v3): độ cao mặt đất theo quãng đường, dạng bậc, có `GAP`. Xây trong
  `LevelChart.finalize()` từ mục `terrain` của chart. Truy vấn: `support_height`, `surface_height_at` (cho hình ảnh),
  `smoothed_height_at` (trung bình chính xác, liên tục, cho camera). Chi tiết: `docs/design/gameplay_v3.md`.

## 4. Trình bày (`src/presentation/`)
- **LevelRunner** + `level.tscn`: các trạng thái `WAITING → RUNNING ⇄ PAUSED → DEAD (tự restart sau 0.9 s) / COMPLETE`.
  Lần chạm được ghi bằng `song_clock.now()` khi có input, rồi đưa vào simulation đầu frame kế tiếp.
- **CameraDirector**: shot là hàm thuần của beat, blend smoothstep giữa các cue. Khi `flip` camera hạ xuống góc dưới đường;
  khi `roll` (GD3-106) camera xoay quanh tâm đường cùng người chơi (MEDIUM/HIGH; LOW như `flip`). Đoạn chạy mặt dưới
  (GD3-112): MEDIUM/HIGH xoay theo `flip_down`, giữ lộn ngược (π, bám cú nhảy xuống), xoay tiếp theo `flip_up`; LOW
  giữ góc nhìn dưới đường (không xoay). Phần trình bày đặt vật dưới đường bằng `LevelContext.underside_frame_at`
  (vật cản, vòng cue, icon, vòng dưới chân, cổng portal; không đặt cột đỡ gần đoạn chạy). Shot được định nghĩa trong frame
  của người chơi (`CameraShots`). Riêng phần xoay của frame được làm mượt khi qua khúc cua. Frame được nâng theo
  độ cao địa hình đã làm mượt (±9 đơn vị, nhìn trước 4) cộng 35% độ cao người chơi so với mặt đất.
  Có thêm rung (trauma) và FOV kick.
  Ngang + dọc trong một bản (GD3-210): điện thoại mở ở mọi hướng (`handheld/orientation` = sensor). Ở menu
  (`MainMenu` gọi `DisplayOrientation.allow_rotation`) màn hình xoay theo máy; `Scenes.go_to` sang bất kỳ scene nào khác
  (level, calibration, recorder) khóa hướng hiện tại (`lock_current`, vẫn cho lật 180°) tới khi về menu. Canvas UI
  1920×1080 hoặc 1080×1920 theo cửa sổ (cập nhật khi đổi kích thước). Khi viewport cao hơn rộng,
  `CameraShots.get_shot(name, true)` thay mọi shot của chart bằng biến thể nhìn từ sau/trên. Chart không đổi.
  Ở màn dọc, `CameraDirector._keep_in_frame` xoay camera (yaw rồi pitch) vừa đủ để khối player nằm trong vùng an toàn
  (40 % nửa góc nhìn ngang, 45 % lên / 55 % xuống) — lách làn, lộn, cua gắt không đẩy player ra mép.
  Kiểm tra: `tools/capture/portrait_framing.gd` (autoplay mọi chart ở 720×1280, không render, báo khung hình sát mép).
  `--portrait` (cả qua `user://debug_args.txt`) ép dọc: cửa sổ 720×1280 trên PC, khóa dọc trên điện thoại.
- **EnvironmentDirector**:
  - Trời là shader (gradient, sao, hành tinh có vành), dùng `AT_CUBEMAP_PASS` để radiance không cập nhật mỗi frame.
    Phần nền nhìn thấy (pass nửa độ phân giải) sáng lên theo `beat_pulse`, mạnh nhất ở chân trời (~6–8% ở đầu phách);
    radiance không đọc giá trị này. Tắt ở LOW (đo trên Mali-G72: trời đổi mỗi frame tốn ~3 FPS ở LOW, miễn phí ở
    MEDIUM). "Reduce flashing" (`UserSettings.reduce_flashing`) tắt nhịp trời và giảm nhịp đập/lóe sáng của vật thể
    neon còn 35%.
  - Glow additive, ACES, fog exponential cộng height fog.
  - **Phase và palette** (GD3-100): `PhasePalettes` (hàm thuần của beat) cho palette đang dùng (`ScenePalette`, thư
    viện `PaletteLibrary`); khi đổi phase thì blend trong 1 beat (LOW: đổi ngay trong một frame). Palette được đẩy ra
    global `pal_*` (vec4, màu linear) **chỉ khi thay đổi**. Các shader nền chọn màu theo `palette_role`: đường/bệ
    (`neon_track` 1/2), cảnh nền/cột (`neon_box` 1/2, `neon_wire` 1), decor (`neon_model` 1). Vật cản và người chơi
    giữ màu dành riêng. Trời: pass nền đọc global (blend mượt), pass cubemap đọc uniform của material, chỉ đổi một lần
    khi phase đã ổn định (radiance render lại đúng một lần). Fog, ambient, đèn chính và bụi (`VfxDirector.set_palette`)
    cũng theo palette. Trời có thêm mặt trời sọc ở chân trời cho palette ấm (`sky_style.y`).
    `PresentationRouter` bắn hiệu ứng đổi phase (lóe, sóng vòng, FOV kick, rung nhẹ, toast "PHASE n · SPEED ×k");
    `DecorView` đặt cổng vòng lớn màu palette mới ở đầu mỗi phase.
  - Đẩy global shader uniform `beat_pulse`: nhịp đầu ô nhịp mạnh hơn, tỉ lệ theo energy của section; cùng
    `run_beat`, `player_distance`, `player_position` (vị trí người chơi trên đường, theo beat). Danh sách global
    khai báo trong `tools/setup/configure_project.gd`.
- **Shader** (`shaders/`):
  - `neon_track`: lưới gạch và viền ray; mỗi beat một sóng năng lượng chạy từ người chơi ra phía trước (mặt sóng
    ngang đường + đuôi trên đường kẻ làn), là hàm thuần của `run_beat` và `player_distance`.
  - `neon_box`: viền sáng có độ rộng cố định theo world, dùng được cho MultiMesh đã scale; vẽ mặt cho player.
    `neon_box`/`neon_wire` có `proximity_gain`: vật cản (và bệ bật) sáng dần khi người chơi tới gần.
  - `neon_wire`: viền tam giác theo barycentric trong `COLOR`.
  - `energy_barrier`, `glyph` (ring / ^ / » / shock ring), `neon_sky`.
- **Texture chi tiết** (GD3-103): ảnh nguồn tạo bằng Codex (`tools/textures/generate_sources.sh`, lưu ở
  `art_source/textures/`, không commit), `tools/textures/build_textures.py` cắt theo chu kỳ lặp + hòa mép cho liền
  rồi gộp kênh: `assets/textures/track_detail.png` (R tấm đường, G mạch, B tấm hông, A tấm lục giác cho bệ) và
  `scenery_detail.png` (R cửa sổ sáng, G gờ cột, B mặt tiền). Xám, 512 px, import nén VRAM + mipmap
  (`importer_defaults/texture` trong `configure_project.gd`). Mỗi pixel đường/bệ/cột/cảnh nền lấy mẫu **một lần**;
  shader có hai biến thể biên dịch riêng: `neon_track` / `neon_box` không có
  code texture, `neon_track_detail` / `neon_box_detail` (`#define DETAIL_TEXTURES`, thân chung trong `.gdshaderinc`) —
  chỉ dùng ở HIGH (`QualityTier.uses_detail_textures`: đo trên Mali-G72, texture tốn ~1.6 FPS ở MEDIUM). Global
  `detail_textures` còn là công tắc runtime trong biến thể detail (cờ `--perf=nodetail`). Màu vẫn từ palette (texture chỉ
  là độ sáng/mặt nạ), mạch trên đường đập theo `beat_pulse`.
- **Mesh** sinh bằng code (`meshes/procedural_meshes.gd`): đoạn đường (chia chunk 48 đơn vị để culling, có thể nâng
  lên và đóng nắp hai đầu) và kim tự tháp. Thứ tự đỉnh được tự sửa sang chiều kim đồng hồ.
- **Dàn LED equalizer** (GD3-109): mặt hông đường phía camera (`ProceduralMeshes.CAMERA_SIDE_FACE`, `COLOR.b` = 1)
  vẽ các cột LED theo 16 dải tần, đoạn sáng tới mức VU, chấm peak trắng, màu từ màu lưới tới màu cảnh nền thứ hai của
  palette. Dữ liệu tính trước theo bài (`tools/audio/build_spectrum.py` → `<id>.spectrum.json`, RG8 base64, 30 khung/s,
  khối 2048 khung mỗi dòng), nạp bởi `SpectrumTexture`; shader đọc bằng `texelFetch` theo global `song_seconds`
  (EnvironmentDirector, `chart.time_at(beat)`) nên là hàm của thời gian bài, đúng cả khi tua/chụp. Ở xa (cột < ~2 px)
  LED mờ thành dải sáng đều. Không áp lên bệ (địa hình gameplay). Bài không có file phổ: mặt hông như cũ.
- **TrackView**: đường bị cắt ở hố (mép hố đóng nắp), bệ là đoạn đường nâng lên (vật liệu riêng); nắp mặt đứng
  có viền sáng (`COLOR.g` = 1 trong `neon_track`). Cột đỡ tránh mép hố.
- **ObstacleView**: vật cản và bệ bật đặt trên mặt đất; vòng cue ở độ cao `cue_heights` (GD3-101: quad to gấp
  `CUE_APPROACH_SCALE`, một vòng ngoài co dần trong 2 beat cuối và chạm khít vạch đúng beat của cue — instance uniform
  `cue_beat` so với global `run_beat` —, vạch sáng lên đúng lúc đó và đập theo `beat_pulse` mạnh hơn glyph khác; vòng
  nhảy cũng vậy); icon lơ lửng chỉ khi cue có
  vật cản (`ActionCue.has_hazard`); vòng nhảy là billboard glyph 6 (vòng lớn glyph 8, vòng lao xuống glyph 7).
  Vật cản: gai / hàng gai (`HazardDefinition.repeat`), lưỡi cưa, trần gai, tường, cổng, và (GD3-104, `ObstacleModels`,
  model Blender) hàng rào laser, rìu con lắc, mìn gai, máy dập, tường laser, cổng vòng. Phần chuyển động là node con
  `MovingPart`, đặt theo beat (cưa xoay, rìu lắc buông thẳng đúng lúc người chơi tới, mìn nhấp nhô, máy dập đập mỗi beat). Vòng lao xuống là JUMP có `ActionDefinition.dive_speed` > 0 (vận tốc ban đầu hướng xuống).
- **Decor từ Blender** (`track/decor_view.gd`): cổng vòng tại đầu mỗi section, cầu gai treo đung đưa theo
  ô nhịp (hàm thuần của beat). Model `.glb` sinh bằng script; vai trò mặt (thân tối / sáng chính / sáng phụ) nằm trong
  vertex color, một vật liệu `neon_model` duy nhất (`NeonModel`) → **mỗi model 1 draw call** (GD3-105, trước đây 2–3).
- **Cảnh nền** (`track/scenery_view.gd`): 2 MultiMesh (tháp, chóp) sinh theo seed. Tránh hành lang đường và
  tầm nhìn của camera side. Chỉ dùng tông lạnh.
- **VFX** (`vfx/`): pool (`EffectPools`) để không tạo node hay biên dịch shader giữa màn. Gồm vệt pixel,
  bung hạt khi cất cánh, vòng sóng khi tiếp đất, bóng mờ khi dash, lấp lánh khi PERFECT, vỡ vụn khi chết, bụi lơ lửng,
  hiệu ứng lá chắn, speed lines (chỉ MEDIUM/HIGH: 18/32 vệt, phát ở phía nền sau đường, dày theo energy đoạn nhạc).
- **Vòng dưới chân** (`PlayerView`, glyph 10): nằm trên mặt đất dưới người chơi (không bay theo cú nhảy, ẩn trên hố và
  khi lộn xuống mặt dưới), mỗi beat phát một sóng vòng, đổi dần sang màu hành động của cue kế tiếp trong 2 beat trước nó.
- **HUD** (`src/ui/hud`): thanh tiến độ, %, chữ chấm điểm, combo, thanh nạp lá chắn, ATTEMPT, thông báo. Có xử lý
  safe area trên mobile.

## 4b. UI và luồng màn hình
- `MainMenu` (main scene): instance `level.tscn` với `LaunchOptions.attract()` (autoplay, ẩn HUD, lặp khi hết nhạc)
  làm nền, các nút PLAY / PRACTICE (đều qua `SongListPanel`: quét mọi `*.chart.json` trong `assets/music`, trừ
  `*.classic.chart.json`, xếp từ dễ đến khó theo `ChartDifficulty`) / CALIBRATE AUDIO / SYNC TEST / SETTINGS / QUIT
  (ẩn trên mobile). Bản debug có thêm một hàng RECORD (DEV) | AUTOPLAY (DEV): AUTOPLAY chọn bài rồi để bot chơi trọn
  màn với HUD, SFX và menu kết thúc như lượt thường (`LaunchOptions.autoplay_run`, HUD ghi "AUTOPLAY").
  Trang chủ là `HomePage` (logo, thẻ bài đang phát, nút icon + mũi tên; ngang: cột trái trên nền tối dần, dọc: giữa).
- Giao diện (GD3-259, 2026-10-15): `src/ui/theme/` — `UiTheme` (theme dựng bằng code: panel kính tối viền cyan có
  glow, vai trò qua `theme_type_variation`: PrimaryButton hồng, TabButton, RowButton, IconButton, SmallButton, Card,
  Dialog, Row, Pill, Badge, HeaderTitle…), `UiIcons` (icon vector SVG trong code, vẽ ra `ImageTexture` theo cỡ/màu,
  có cache; công tắc + núm thanh trượt), `UiKit` (nút có icon, header BACK + icon + tiêu đề + phụ đề, badge, lề safe
  area), `UiScreen` (khung trang toàn màn: header + body, gọi `_layout(portrait)` khi xoay), `UiDialog` (hộp thoại).
  `SettingsPanel` / `SongListPanel` / `ShopPanel` kế thừa `UiScreen`; cài đặt chia tab CHUNG / ÂM THANH / HÌNH ẢNH /
  GIỚI THIỆU (`SettingsRows`), danh sách bài là các `SongRow` (ảnh bìa `assets/covers/<id>.jpg` — bản LED dùng chung
  ảnh — badge độ khó, điểm cao nhất) lọc theo độ khó; tab nằm dọc bên trái khi ngang, thành hàng ngang khi dọc.
  Ảnh bìa/logo/icon sinh bằng Codex: `tools/branding/generate_sources.sh` → `build_brand.py`.
- `CalibrationScreen`: click 100 BPM (`ClickTrack` sinh WAV trong code), đo lệch so với beat gần nhất,
  `CalibrationMath.estimate` (median + MAD loại outlier, cần ≥ 8 lần gõ hợp lệ) → lưu `audio_offset_sec`.
- `Metronome` (SYNC TEST): `AudioStreamSynchronized` [nhạc, click] khóa mẫu, nháy theo beat, ←/→ chỉnh offset;
  cùng các thao tác dưới dạng nút cảm ứng.
- Trong level: nút tạm dừng (icon, cảm ứng), `RunMenu` (thẻ hộp thoại RESUME / RESTART / MENU) khi tạm dừng hoặc hoàn thành.
  Nút HUD không nhận focus để Space luôn là "tap". `PresentationRouter` chuyển signal simulation → hiệu ứng.

## 4c. Telemetry và phản hồi rung
- `Telemetry` (`src/core/telemetry.gd`): mọi event analytics đi qua đây; kiểm tra luật Firebase (tên ≤ 40 ký tự,
  ≤ 25 tham số, chuỗi ≤ 100 ký tự, không tiền tố `firebase_`/`google_`/`ga_`), giữ 32 event gần nhất (`history`),
  gửi cho singleton `GeoDashFirebase` của plugin Android (GD3-230, chưa có) hoặc in `TELEMETRY ...` ở bản debug.
- `RunTelemetry` (`src/presentation/level/`): một `level_start` khi chuẩn bị lượt, một `level_end` khi chết/qua màn/bỏ
  (restart, MENU), kèm `new_best`/`first_clear` cho lượt tính kỷ lục. Không gửi trong attract, autoplay, capture.
  Khác: `calibration_done` (thủ công/tự học), `song_select`. Chưa có: `perf_sample`, `shop_view`, `iap_click`,
  `rate_prompt_shown` (chờ GD3-235/241/244).
- Firebase (GD3-230): plugin Android v2 tự viết `android_plugins/geodash_firebase` (Java, AAR commit ở
  `addons/geodash_firebase/bin/`), singleton `GeoDashFirebase`: `log_event`, `set_user_property`, `record_error`,
  `crash_log`, `set_custom_key`, `fetch_remote_config` / `remote_config_json`, `get_app_instance_id`,
  `set_collection_enabled`. Export plugin (`addons/geodash_firebase/export_plugin.gd`) thêm AAR + Firebase BOM 34.0.0
  (analytics 23.0.0, crashlytics-ndk 20.0.0, config 23.0.0) vào Gradle build. `Telemetry.start()` (gọi từ
  `UserSettings`) cài `TelemetryLogger`: `push_error` → non-fatal Crashlytics (mỗi thông điệp 1 lần, tối đa 25/phiên).
  Thiếu `google-services.json` → plugin không khởi tạo Firebase, mọi lệnh là no-op.
- `Haptics` (`src/core/haptics.gd`): rung ngắn khi PERFECT, vỡ lá chắn, chết; tắt trong Settings (`UserSettings.haptics`),
  không rung trong attract. Android cần quyền `vibrate` (đã bật trong preset).

- `Locale` (`src/core/locale.gd`): ngôn ngữ giao diện; khóa là chữ tiếng Anh, bản dịch ở `assets/i18n/<mã>.json`
  nạp lúc chạy vào `TranslationServer`. Control tự dịch chữ tĩnh; chuỗi có định dạng gọi `Locale.t(...)` trước khi `%`.

- Khóa bài (GD3-242): `SongCatalog` (danh sách chart, dễ → khó) + `SongUnlocks` (luật mở, tính từ `HighScores` và
  `Entitlements`, chơi thử qua `trial_path`) ở `src/core`. Chỉ menu bị ảnh hưởng; chart và gameplay không đổi.
- Kiếm tiền: `Ads` (AdMob: UMP, interstitial giữa các lượt, banner menu, rewarded cho chơi thử), `Store` +
  `Entitlements` (Play Billing: remove_ads, unlock_all_songs, khôi phục). Chỉ chạy trên Android; PC/test là no-op.

## 5. Công cụ
- `tools/setup/configure_project.gd` ghi input map (`tap`, `pause`, `restart`), autoload, shader global và
  main scene qua API `ProjectSettings`. Không sửa tay các object này trong `project.godot`.
- `tools/audio/analyze_song.py`: chạy bằng Python của Blender (`aud` giải mã MP3, `numpy`), không cần cài gì thêm.
- `tools/audio/draft_chart.py`: plan + phân tích → chart.
- `tools/charting/auto_level.py` (GD3-220): mp3 → level LED một lệnh. `song_tempo.py` đo BPM (tự tương quan của độ
  tăng âm lượng × prior quanh 125 BPM, tinh chỉnh trên cú đánh mạnh) và offset (`hit_level.fit_offset`); dừng hỏi khi
  hai ứng viên BPM sát nhau. Kiểm tra `hit_grid.standout_share` ≥ 50 %, đo lưới, sinh LED, chọn độ khó/bảng màu, ghi
  `tools/charting/levels/<id>.py`, dựng bằng `led_level.build`, rồi `tap_salience`, `check_chart.gd` (autoplay một
  chart) và `tolerance_report.gd`.
- Chụp ảnh: `LaunchOptions` + `CaptureController`.
- Test runner riêng (`tests/framework/`): bắt cả `push_error` qua `Logger` (Godot 4.5+), dùng `expect_errors(n)`.

## 6. Khác biệt PC / Mobile
| Mảng | PC | Mobile |
|---|---|---|
| Renderer | Forward+ | Mobile (`rendering_method.mobile`), Vulkan |
| Tier (`QualityTier`) | HIGH: glow, render 100%, MSAA 2x | MEDIUM: glow, render 60%, cảnh nền 80%. LOW: **không glow** (shader `soft_glow` vẽ quầng sáng), render 70%, cảnh nền 55% |
| Chọn tier | AUTO (thường giữ HIGH) | AUTO: `QualityAutoTuner` đo FPS ở menu, hạ dần tới khi đạt 55 FPS |
| Độ trễ audio | ~10 ms đo được | Android báo 0 → **bắt buộc CALIBRATE AUDIO** |
| Shader | — | Sky nửa độ phân giải; VFX được làm nóng trong count-in |
| Input | Space / W / ↑ / chuột trái | Chạm (giả lập chuột trái, không bị kích hoạt hai lần) |

## 7. Chưa làm / giới hạn đã biết
- Chưa có model Blender: mọi hình khối hiện là primitive hoặc mesh sinh bằng code.
- Chạm khi đang bay mà không trúng vòng nhảy và không trong vùng buffer sẽ bị bỏ qua (giống Geometry Dash, không có
  double jump, không có giữ để nhảy).
- Gameplay v3 (địa hình): chưa có địa hình theo làn, trần/bệ treo; `draft_chart.py` chưa sinh địa hình; map chính mới
  phủ 116/224 beat.
- Hành động mới (trượt, đổi làn) sẽ cần thêm trục lệch ngang trong `HazardChecker`. Mặt dưới chỉ cho nhảy thường
  (không vòng nhảy, bệ bật, hố, né làn).
