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
- **UserSettings** (autoload duy nhất): `audio_offset_sec`, `quality_tier`, `music_volume_db`, lưu ở `user://settings.cfg`.

## 3. Gameplay (`src/gameplay/`)
- **Cấu hình** (`defs/`): `GameplayConfig` gồm cửa sổ timing, hitbox, bước mô phỏng, cùng thư viện
  `ActionDefinition` (jump: 1 beat, cao 2.0; dash: 0.75 beat, miễn nhiễm `barrier`) và
  `HazardDefinition` (spike, barrier). Hitbox nhỏ hơn hình hiển thị.
- **Chart** (`chart/`): `ChartLoader` gom *mọi* lỗi validate rồi báo một lượt. `LevelChart` lưu cue (theo beat),
  vật cản (theo khoảng cách), camera, vfx, section, track. Hàm `safe_start_beat()` lùi điểm bắt đầu để không
  kẹt trước vật cản có cue đã bị bỏ qua. Định dạng chi tiết: `docs/chart_format.md`.
- **RunSimulation** (`simulation/`):
  - Va chạm chỉ kiểm tra trên lưới cố định 1/96 beat, nên kết quả không phụ thuộc FPS (có test chứng minh).
  - Xử lý một lần chạm: `ActionResolver` tìm cue gần nhất trong ±150 ms rồi chấm điểm. Không có cue nào thì
    thực hiện hành động mặc định (jump).
  - Chạm khi hành động trước sắp kết thúc (≤ 100 ms) thì được *buffer*, kích hoạt ngay khi tiếp đất.
  - `HazardChecker` xét chồng lấn hộp (khoảng cách × độ cao), có cursor vì người chơi chỉ đi tới.
  - `invincible` ghi lại các lần trúng thay vì chết, dùng cho luyện tập và soạn màn.
- **Autoplay**: chạm đúng mọi cue. Dùng cho test, chụp ảnh và chế độ demo.
- **TrackPath** (`track/`): bảng frame mỗi 0.5 đơn vị, tích phân từ các đoạn straight/turn/slope (dùng midpoint).
  Trục của frame: X = hướng đi, Y = lên, Z = bên phải (phía camera side). Ngoài hai đầu thì ngoại suy thẳng.

## 4. Trình bày (`src/presentation/`)
- **LevelRunner** + `level.tscn`: các trạng thái `WAITING → RUNNING ⇄ PAUSED → DEAD (tự restart sau 0.9 s) / COMPLETE`.
  Lần chạm được ghi bằng `song_clock.now()` khi có input, rồi đưa vào simulation đầu frame kế tiếp.
- **CameraDirector**: shot là hàm thuần của beat, blend smoothstep giữa các cue. Shot được định nghĩa trong frame
  của người chơi (`CameraShots`). Riêng phần xoay của frame được làm mượt khi qua khúc cua.
  Có thêm rung (trauma) và FOV kick.
- **EnvironmentDirector**:
  - Trời là shader (gradient, sao, hành tinh có vành), dùng `AT_CUBEMAP_PASS` để radiance không cập nhật mỗi frame.
  - Glow additive, ACES, fog exponential cộng height fog.
  - Đẩy global shader uniform `beat_pulse`: nhịp đầu ô nhịp mạnh hơn, tỉ lệ theo energy của section.
- **Shader** (`shaders/`):
  - `neon_track`: lưới gạch và viền ray.
  - `neon_box`: viền sáng có độ rộng cố định theo world, dùng được cho MultiMesh đã scale; vẽ mặt cho player.
  - `neon_wire`: viền tam giác theo barycentric trong `COLOR`.
  - `energy_barrier`, `glyph` (ring / ^ / » / shock ring), `neon_sky`.
- **Mesh** sinh bằng code (`meshes/procedural_meshes.gd`): đoạn đường (chia chunk 48 đơn vị để culling) và kim tự tháp.
  Thứ tự đỉnh được tự sửa sang chiều kim đồng hồ.
- **Cảnh nền** (`track/scenery_view.gd`): 2 MultiMesh (tháp, chóp) sinh theo seed. Tránh hành lang đường và
  tầm nhìn của camera side. Chỉ dùng tông lạnh.
- **VFX** (`vfx/`): pool (`EffectPools`) để không tạo node hay biên dịch shader giữa màn. Gồm vệt pixel,
  bung hạt khi cất cánh, vòng sóng khi tiếp đất, bóng mờ khi dash, lấp lánh khi PERFECT, vỡ vụn khi chết, bụi lơ lửng.
- **HUD** (`src/ui/hud`): thanh tiến độ, %, chữ chấm điểm, ATTEMPT, thông báo. Có xử lý safe area trên mobile.

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
| Renderer | Forward+ | Mobile (`rendering_method.mobile`) |
| Hậu kỳ | Glow 4 level, fog | Glow, fog (tier Low: ít level glow hơn, ít hạt hơn) |
| Độ trễ audio | ~10 ms đo được | cao và khác nhau theo máy → **cần màn hiệu chỉnh (GD3-014)** |
| Shader | — | Biên dịch lần đầu gây giật → cần pre-warm (GD3-051) |
| Input | Space / W / ↑ / chuột trái | Chạm (giả lập chuột trái, không bị kích hoạt hai lần) |

## 7. Chưa làm / giới hạn đã biết
- Chưa có menu, chọn bài, màn hiệu chỉnh độ trễ, luyện tập (checkpoint), record mode, importer `.sm`.
- Chưa có model Blender: mọi hình khối hiện là primitive hoặc mesh sinh bằng code.
- Chạm khi đang nhảy mà không trong vùng buffer sẽ bị bỏ qua (giống Geometry Dash, không có double jump).
- Hành động mới (trượt, đổi làn, đảo trọng lực) sẽ cần thêm trục lệch ngang/lộn ngược trong `HazardChecker`.
