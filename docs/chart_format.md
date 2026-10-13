# Định dạng chart (`*.chart.json`, version 1)

Mọi vị trí tính bằng **beat**. Beat 0 nằm tại `offset_sec` giây trong file nhạc. Khoảng cách trên đường được
suy ra từ `speed`, game không bao giờ lưu tọa độ. Trình đọc: `src/gameplay/chart/chart_loader.gd`.

```json
{
  "version": 1,
  "title": "The Dawn Assembly",
  "artist": "…",
  "song": "res://assets/music/the_dawn_assembly.mp3",
  "offset_sec": 0.058,
  "end_beat": 224,
  "tempo":    [{ "beat": 0, "bpm": 120 }],
  "speed":    [{ "beat": 0, "units_per_beat": 7 }, { "beat": 96, "units_per_beat": 8 }],
  "sections": [{ "beat": 0, "name": "intro", "energy": 0.2 }],
  "track":    [{ "beat": 0, "shape": "straight" },
               { "beat": 40, "shape": "turn", "angle_deg": 30 },
               { "beat": 64, "shape": "slope", "rise": 6 }],
  "events":   [{ "beat": 8, "type": "jump" },
               { "beat": 10, "type": "dash" },
               { "beat": 12, "type": "jump", "hazard": "none" },
               { "beat": 14, "type": "hazard", "hazard": "spike" },
               { "beat": 32, "type": "camera", "shot": "side_low", "blend_beats": 2 },
               { "beat": 96, "type": "vfx", "name": "flash" }]
}
```

| Trường | Ý nghĩa |
|---|---|
| `tempo` | Danh sách điểm đổi BPM. Phải có ít nhất 1 điểm. |
| `speed` | Số đơn vị đường đi được mỗi beat, kể từ beat đó. Tốc độ cao hơn thì vật cản cách xa nhau hơn. |
| `sections` | Đoạn nhạc. `energy` (0..1) điều khiển glow, màu trời, sương mù và nhịp đập ánh sáng. |
| `track` | Hình dạng đường từ beat đó đến điểm kế tiếp: `straight`, `turn` (`angle_deg`, dương = rẽ trái), `slope` (`rise`). |
| `end_beat` | Beat hoàn thành màn. Nhạc vẫn chạy tiếp phần outro. |

## Các loại event
- **Hành động** (`"type": "jump"` / `"dash"`): đây là *thời điểm chạm*. Game tự đặt vật cản đi kèm
  (`jump` → gai tại beat + 0.5, `dash` → rào năng lượng tại beat + 0.375). `"hazard": "none"` để chỉ có cue,
  không có vật cản. Có thể thêm `"hazard_offset": <beats>` để dịch vật cản.
- **`hazard`**: vật cản đứng riêng, không có cue (người chơi tự nhảy bằng thao tác mặc định).
- **`camera`**: chuyển sang shot `shot`, blend trong `blend_beats`. Danh sách shot nằm ở
  `src/presentation/camera/camera_shots.gd`: `side`, `side_low`, `side_high`, `side_far`, `chase`, `chase_low`,
  `high`, `diagonal`, `front`.
- **`vfx`**: `flash` (lóe sáng toàn cảnh), `shockwave` (vòng sóng), `burst` (bung hạt).

## Ràng buộc (được test kiểm tra)
- Cue kế tiếp phải cách cue trước ít nhất bằng thời lượng hành động trước (jump 1 beat, dash 0.75 beat).
  Nên chừa thêm khoảng 0.5 beat: `draft_chart.py` dùng 1.5 beat cho jump và 1.25 beat cho dash.
- Autoplay (chạm đúng mọi cue) phải qua màn: `tests/gameplay/test_shipped_charts.gd`.

## Cửa sổ timing (`GameplayConfig`)
| Kết quả | Độ lệch |
|---|---|
| PERFECT | ≤ 45 ms |
| GREAT | ≤ 90 ms |
| GOOD | ≤ 150 ms (lệch hơn thì lần chạm thành cú nhảy mặc định) |

Với 120 BPM và jump 1 beat, vật lý cho phép sống sót khi lệch tới khoảng ±143 ms. Dash cho phép khoảng ±150 ms.

## Quy trình làm chart cho một bài mới
1. Đặt nhạc vào `assets/music/<id>.mp3`.
2. Phân tích: `blender -b --factory-startup -P tools/audio/analyze_song.py -- assets/music/<id>.mp3 assets/music/<id>.analysis.json`.
   Bước này cho ra BPM, offset (nhịp mạnh đầu tiên), onset theo dải tần và năng lượng từng ô nhịp (để chia đoạn).
3. Viết `assets/music/<id>.plan.json`: các đoạn, luật mật độ cho từng đoạn, tốc độ, hình dạng đường, camera, VFX.
   Xem bài mẫu `the_dawn_assembly.plan.json`.
4. Sinh chart: `python tools/audio/draft_chart.py <analysis> <plan> assets/music/<id>.chart.json`.
5. Chạy test, rồi chụp ảnh hoặc chơi thử: `godot --path . -- --chart=res://assets/music/<id>.chart.json`.
6. Muốn chỉnh thì sửa **plan** rồi sinh lại. Chỉ sửa tay file chart cho những chi tiết cuối cùng.

## Đặt hành động bằng tay: record mode, `.sm`, `fixed`
- **Record mode** (menu RECORD (DEV), chỉ có ở bản debug): bật nhạc rồi gõ theo.
  - Phím: Space/J = làn 0, K = làn 1, L = làn 2.
  - Backspace để undo, X để xóa từ vị trí hiện tại trở đi, G để đổi lưới, `-`/`=` để chỉnh tốc độ 50–100%, ←/→ để tua.
  - Kết quả lưu raw (giây + làn) vào `assets/music/<id>.recording.json`.
- **ArrowVortex/StepMania:**
  `python tools/charting/sm_to_recording.py song.sm assets/music/<id>.recording.json`. Cột i thành làn i.
- Dùng recording trong plan:
  ```json
  "recording": { "file": "<id>.recording.json", "lane_actions": ["jump", "dash", "jump"],
                 "grid": 0.5, "mode": "replace" }
  ```
  - `replace`: chỉ dùng các lần gõ (đã lượng tử hóa theo `grid`).
  - `merge`: giữ các lần gõ rồi tự lấp thêm từ onset.
  - Lần gõ nào quá sát lần trước sẽ bị bỏ, kèm cảnh báo.
- `"fixed": [{"beat": 104, "type": "jump"}]` trong plan: hành động đặt tay, luôn được giữ.
