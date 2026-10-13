# Kiến trúc GeoDash3D

> Trạng thái: **bản nháp đề xuất**, chưa có code. Các mục đánh dấu (?) là quyết định còn mở.

## 1. Luồng dữ liệu tổng quát

```
 AudioStreamPlayer ──► SongClock ──song_time──►  Gameplay (logic thuần)            Presentation
                         ▲                         ├─ TempoMap     beat ⇄ time      ├─ PlayerVisual
 InputEvent "tap" ──► InputTimer ──tap_time──►     ├─ TrackPath    time ⇄ s ⇄ T3D   ├─ CameraDirector
                                                   ├─ ActionResolver (judgement)    ├─ VfxDirector
 LevelChart (.chart.json) ─────────────────────►   ├─ PlayerMotion  offset(t)       ├─ BeatPulse
                                                   └─ HazardChecker  chết/sống      └─ HUD
                                                        │ signals ─────────────────────►
```
Gameplay không biết Presentation tồn tại. Presentation đọc state + nghe signal.

## 2. Hệ thống lõi (`src/core/`)

### SongClock (autoload)
- Nguồn thời gian duy nhất: `song_time: float` (giây, có thể âm trong đoạn đếm ngược trước khi nhạc chạy).
- Công thức mỗi frame:
  `raw = player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()`
  `song_time = raw - chart_offset - user_calibration_offset`
- Làm mượt: `get_playback_position()` nhảy theo khối mix → nội suy bằng đồng hồ hệ thống và chỉ "kéo" dần về giá trị audio
  khi lệch nhỏ; lệch lớn (> 50 ms) thì snap.
- Trạng thái: `STOPPED → COUNT_IN → PLAYING → PAUSED → FINISHED`. Resume sau pause có đếm ngược.

### TempoMap
- Danh sách `TempoPoint { beat: float, bpm: float }` (hỗ trợ đổi BPM).
- `beat_to_time(beat)`, `time_to_beat(time)` — có test đầy đủ, kể cả nhiều điểm đổi BPM.

### QualitySettings (autoload)
- Tier Low/Medium/High; mặc định theo platform. Presentation đọc tier để bật/tắt glow, số hạt, SSR, fog…

## 3. Gameplay (`src/gameplay/`)

### LevelChart — định dạng `*.chart.json` (?)
Chọn JSON thay vì `.tres` để: diff dễ, tool Python/record mode/importer ghi trực tiếp được. Có `version` để migrate.
```json
{
  "version": 1,
  "song": "res://assets/music/The_Dawn_Assembly.mp3",
  "offset_sec": 0.0,
  "tempo": [{ "beat": 0, "bpm": 128 }],
  "speed": [{ "beat": 0, "units_per_beat": 4.0 }],
  "sections": [{ "beat": 0, "name": "intro" }, { "beat": 64, "name": "drop" }],
  "track": [{ "beat": 0, "shape": "straight" }, { "beat": 32, "shape": "curve_left", "angle": 45 }],
  "events": [
    { "beat": 16.0, "kind": "action", "action": "jump" },
    { "beat": 17.0, "kind": "hazard", "hazard": "spike", "lane_offset": 0 },
    { "beat": 32.0, "kind": "camera", "shot": "side_low", "blend_beats": 2 },
    { "beat": 64.0, "kind": "vfx", "name": "drop_flash" }
  ]
}
```

### TrackPath
- Sinh `Path3D`/`Curve3D` từ `track` + `speed`: khoảng cách `s(t) = ∫ speed(t) dt`.
- API: `distance_at(time)`, `transform_at(distance)` (dùng `Curve3D.sample_baked_with_rotation`).

### ActionResolver
- Mỗi sự kiện `action` tạo một **vùng hành động** quanh beat đó. Khi `tap` đến: tìm vùng gần nhất trong cửa sổ timing,
  chấm `PERFECT / GOOD / MISS` theo độ lệch (ms). Cửa sổ timing nằm trong `TimingConfig` (Resource).
- Tap ngoài mọi vùng: hành động mặc định (?) — đề xuất: nhảy cơ bản, để cảm giác vẫn "phản hồi".

### PlayerMotion
- Hàm thuần: `offset(time) -> Vector3` (độ cao, lệch ngang, nghiêng) từ danh sách hành động đã kích hoạt.
- Mỗi hành động là một Resource có `duration_beats` và đường cong (parabol nhảy, dash tăng tốc tạm thời theo `s`, …).
  Thời lượng tính theo beat nên tự co giãn theo BPM.

### HazardChecker
- Vật cản mô tả bằng khoảng `[s_start, s_end]` × hộp offset. Mỗi frame so với `(s, offset)` của player → `player_died`.
- Có hitbox "khoan dung" nhỏ hơn hình hiển thị (cấu hình được).

### Autoplay & Replay
- Autoplay: bot "chạm" đúng beat của mọi sự kiện `action`. Dùng trong test để **chứng minh chart qua được**.
- Replay: lưu chuỗi `tap_time`; nhờ tính tất định có thể phát lại chính xác.

## 4. Trình bày (`src/presentation/`)
- **CameraDirector:** danh sách shot theo beat (từ chart + mặc định theo section), blend giữa các shot; shake/FOV kick
  phản ứng signal. Ràng buộc: luôn thấy trước ≥ 1 giây đường phía trước.
- **VfxDirector:** map signal → hiệu ứng (`action_performed`, `judgement`, `player_died`, `section_changed`, `beat`).
- **BeatPulse:** phát signal mỗi beat/nửa beat để vật thể, đèn, glow nhấp nháy theo nhạc.
- **Model:** sinh từ script Blender (`assets/blender/`) hoặc primitive/shader trong Godot.

## 5. Authoring (`src/authoring/`, `tools/`)
- **Record mode:** phát nhạc, nhấn phím ghi thời điểm → lượng tử hóa theo lưới (1/1, 1/2, 1/4) → xuất `events`.
- **Importer `.sm`** (ArrowVortex/StepMania) → `*.chart.json`.
- **Phân tích audio (Python, tùy chọn):** đo BPM/offset, dò onset theo dải tần để gợi ý sự kiện.
- **Công cụ luyện tập:** bắt đầu tại beat bất kỳ, lặp đoạn, phát chậm (chỉ cho chế độ editor/luyện tập).

## 6. Khác biệt PC / Mobile
| Mảng | PC | Mobile |
|---|---|---|
| Renderer | Forward+ | Mobile (Vulkan); cân nhắc Compatibility cho máy cũ (?) |
| Hậu kỳ | Glow, fog, có thể SSR/SSAO (High) | Glow + depth fog |
| Độ trễ audio | thấp (~10–30 ms) | cao, khác nhau theo máy (~50–200 ms) → **bắt buộc màn hiệu chỉnh** |
| Shader | — | Biên dịch lần đầu gây giật → pre-warm khi loading |
| Màn hình | 16:9, ultrawide | 16:9 → 21:9, tai thỏ → safe area |
| Input | Space/chuột | Touch |
| Build | Windows trực tiếp | Android: JDK + Android SDK; iOS: cần máy Mac |
