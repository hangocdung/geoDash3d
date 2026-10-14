# Kiến trúc GeoDash3D

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
  - Thời gian người chơi nghe thấy = `playback_position + time_since_last_mix − output_latency − calibration`.
  - Lệch dưới 50 ms thì kéo dần về 12% mỗi frame; lệch hơn thì nhảy thẳng. Thời gian không bao giờ chạy lùi.
  - Audio được phát *sớm* đúng bằng latency + calibration để âm thanh khớp với hình.
  - Đếm ngược trước nhạc: thời gian bắt đầu âm và chạy theo đồng hồ hệ thống cho tới 0.
  - Đã đo thực tế: lệch ±7 ms trên PC (`--debug-clock`).
- **TempoMap**: beat ⇄ giây, hỗ trợ đổi BPM. Xây trên `PiecewiseLinearMap`, cấu trúc này cũng dùng cho beat → khoảng cách.
- **AutoOffsetLearner / SyncLearning** (GD3-054): học độ trễ từ độ lệch các lần chạm (`tap_timed`), chỉ áp dụng
  giữa các lượt chơi để mô phỏng trong một lượt luôn tất định; `begin_run` nạp lại offset vào SongClock.
- **UserSettings** (autoload duy nhất): `audio_offset_sec`, `quality_tier`, `music_volume_db`, lưu ở `user://settings.cfg`.

## 3. Gameplay (`src/gameplay/`)
- **Cấu hình** (`defs/`): `GameplayConfig` gồm cửa sổ timing, kích thước đường/người chơi, bước mô phỏng và thư viện
  `ActionDefinition` (`kind` JUMP / DODGE / FLIP, `offset_at(progress) → (lateral, height)`) và `HazardDefinition`
  (hộp va chạm 3 trục + kiểu hiển thị SPIKE/WALL/GATE + kiểu vào sân RISE/DROP/UNFOLD, `appear_beat`).
  Chi tiết thông số: `docs/design/gameplay_v2.md`.
- **Chart** (`chart/`): `ChartLoader` gom *mọi* lỗi validate rồi báo một lượt. `LevelChart` lưu cue (theo beat),
  vật cản (theo khoảng cách), camera, vfx, section, track. Hàm `safe_start_beat()` lùi điểm bắt đầu để không
  kẹt trước vật cản có cue đã bị bỏ qua. Định dạng chi tiết: `docs/chart_format.md`.
- **RunSimulation** (`simulation/`):
  - Va chạm chỉ kiểm tra trên lưới cố định 1/96 beat, nên kết quả không phụ thuộc FPS (có test chứng minh).
  - Xử lý một lần chạm: `ActionResolver` tìm cue gần nhất trong ±150 ms rồi chấm điểm. Không có cue nào thì
    thực hiện hành động mặc định (jump).
  - Jump/orb/pad là **parabol** trong `VerticalMotion` (y = y0 + v·t − ½·g·t², theo beat), kết thúc khi tiếp đất.
    Dodge/flip vẫn là hành động thời lượng cố định (`_active_action`), cộng offset lên độ cao nền.
  - Đang bay chỉ chạm được cue `orb` (`ActionDefinition.air_allowed`). Lần chạm khác được *buffer* và chỉ thực
    hiện nếu tiếp đất trong ≤ 100 ms sau đó (dodge/flip: ≤ 100 ms trước khi kết thúc).
  - Địa hình: mỗi bước so độ cao người chơi với `Terrain.support_height` (đất cao nhất dưới hộp ±0.38).
    Đâm hông bệ (cao hơn chân quá `step_snap`) hoặc rơi dưới `fall_death_height` → chết với
    `TERRAIN_HIT` (−2). Chạy khỏi mép → rơi tự do. Bệ bật (`chart.pads`) tự phóng khi đang đứng chạm vào.
  - Signal `player_landed(beat, airtime)` cho mọi lần tiếp đất; `action_finished` chỉ còn cho dodge/flip.
  - `PlayerBody` gói chuyển động lên xuống (`VerticalMotion`), đất dưới chân, rơi khỏi mép và bệ bật.
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
- **TrackPath** (`track/`): bảng frame mỗi 0.5 đơn vị, tích phân từ các đoạn straight/turn/slope (dùng midpoint).
  Trục của frame: X = hướng đi, Y = lên, Z = bên phải (phía camera side). Ngoài hai đầu thì ngoại suy thẳng.
- **Terrain** (`track/terrain.gd`, gameplay v3): độ cao mặt đất theo quãng đường, dạng bậc, có `GAP`. Xây trong
  `LevelChart.finalize()` từ mục `terrain` của chart. Truy vấn: `support_height`, `surface_height_at` (cho hình ảnh),
  `smoothed_height_at` (trung bình chính xác, liên tục, cho camera). Chi tiết: `docs/design/gameplay_v3.md`.

## 4. Trình bày (`src/presentation/`)
- **LevelRunner** + `level.tscn`: các trạng thái `WAITING → RUNNING ⇄ PAUSED → DEAD (tự restart sau 0.9 s) / COMPLETE`.
  Lần chạm được ghi bằng `song_clock.now()` khi có input, rồi đưa vào simulation đầu frame kế tiếp.
- **CameraDirector**: shot là hàm thuần của beat, blend smoothstep giữa các cue. Shot được định nghĩa trong frame
  của người chơi (`CameraShots`). Riêng phần xoay của frame được làm mượt khi qua khúc cua. Frame được nâng theo
  độ cao địa hình đã làm mượt (±9 đơn vị, nhìn trước 4) cộng 35% độ cao người chơi so với mặt đất.
  Có thêm rung (trauma) và FOV kick.
- **EnvironmentDirector**:
  - Trời là shader (gradient, sao, hành tinh có vành), dùng `AT_CUBEMAP_PASS` để radiance không cập nhật mỗi frame.
  - Glow additive, ACES, fog exponential cộng height fog.
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
- **Mesh** sinh bằng code (`meshes/procedural_meshes.gd`): đoạn đường (chia chunk 48 đơn vị để culling, có thể nâng
  lên và đóng nắp hai đầu) và kim tự tháp. Thứ tự đỉnh được tự sửa sang chiều kim đồng hồ.
- **TrackView**: đường bị cắt ở hố (mép hố đóng nắp), bệ là đoạn đường nâng lên (vật liệu riêng); nắp mặt đứng
  có viền sáng (`COLOR.g` = 1 trong `neon_track`). Cột đỡ tránh mép hố.
- **ObstacleView**: vật cản và bệ bật đặt trên mặt đất; vòng cue ở độ cao `cue_heights`; icon lơ lửng chỉ khi cue có
  vật cản (`ActionCue.has_hazard`); vòng nhảy là billboard glyph 6.
- **Decor từ Blender** (`track/decor_view.gd`): cổng vòng tại đầu mỗi section, cầu gai treo đung đưa theo
  ô nhịp (hàm thuần của beat). Model `.glb` sinh bằng script, material theo tên `Body/Glow/GlowAlt` → `NeonModel`.
- **Cảnh nền** (`track/scenery_view.gd`): 2 MultiMesh (tháp, chóp) sinh theo seed. Tránh hành lang đường và
  tầm nhìn của camera side. Chỉ dùng tông lạnh.
- **VFX** (`vfx/`): pool (`EffectPools`) để không tạo node hay biên dịch shader giữa màn. Gồm vệt pixel,
  bung hạt khi cất cánh, vòng sóng khi tiếp đất, bóng mờ khi dash, lấp lánh khi PERFECT, vỡ vụn khi chết, bụi lơ lửng.
- **HUD** (`src/ui/hud`): thanh tiến độ, %, chữ chấm điểm, combo, thanh nạp lá chắn, ATTEMPT, thông báo. Có xử lý
  safe area trên mobile.

## 4b. UI và luồng màn hình
- `MainMenu` (main scene): instance `level.tscn` với `LaunchOptions.attract()` (autoplay, ẩn HUD, lặp khi hết nhạc)
  làm nền, các nút PLAY / PRACTICE / CALIBRATE AUDIO / SYNC TEST / SETTINGS / QUIT (ẩn trên mobile).
  Theme chung: `UiTheme`.
- `CalibrationScreen`: click 100 BPM (`ClickTrack` sinh WAV trong code), đo lệch so với beat gần nhất,
  `CalibrationMath.estimate` (median + MAD loại outlier, cần ≥ 8 lần gõ hợp lệ) → lưu `audio_offset_sec`.
- `Metronome` (SYNC TEST): `AudioStreamSynchronized` [nhạc, click] khóa mẫu, nháy theo beat, ←/→ chỉnh offset.
- Trong level: nút "II" (cảm ứng), `RunMenu` (RESUME / RESTART / MENU) khi tạm dừng hoặc hoàn thành.
  Nút HUD không nhận focus để Space luôn là "tap". `PresentationRouter` chuyển signal simulation → hiệu ứng.

## 5. Công cụ
- `tools/setup/configure_project.gd` ghi input map (`tap`, `pause`, `restart`), autoload, shader global và
  main scene qua API `ProjectSettings`. Không sửa tay các object này trong `project.godot`.
- `tools/audio/analyze_song.py`: chạy bằng Python của Blender (`aud` giải mã MP3, `numpy`), không cần cài gì thêm.
- `tools/audio/draft_chart.py`: plan + phân tích → chart.
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
- Chưa có chọn bài, luyện tập (checkpoint), record mode, importer `.sm`.
- Chưa có model Blender: mọi hình khối hiện là primitive hoặc mesh sinh bằng code.
- Chạm khi đang bay mà không trúng vòng nhảy và không trong vùng buffer sẽ bị bỏ qua (giống Geometry Dash, không có
  double jump, không có giữ để nhảy).
- Gameplay v3 (địa hình): chưa có địa hình theo làn, trần/bệ treo; `draft_chart.py` chưa sinh địa hình; map chính mới
  phủ 116/224 beat.
- Hành động mới (trượt, đổi làn, đảo trọng lực) sẽ cần thêm trục lệch ngang/lộn ngược trong `HazardChecker`.
