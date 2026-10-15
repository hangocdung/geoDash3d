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
  "phases":   [{ "beat": 0, "palette": "indigo" }, { "beat": 96, "palette": "sunset" }],
  "sections": [{ "beat": 0, "name": "intro", "energy": 0.2 }],
  "track":    [{ "beat": 0, "shape": "straight" },
               { "beat": 40, "shape": "turn", "angle_deg": 30 },
               { "beat": 64, "shape": "slope", "rise": 6 }],
  "terrain":  [{ "beat": 20.55, "height": 1.5 }, { "beat": 24, "gap": true }, { "beat": 24.5, "height": 0 }],
  "events":   [{ "beat": 8, "type": "jump" },
               { "beat": 10, "type": "dodge_left" },
               { "beat": 13, "type": "flip" },
               { "beat": 12, "type": "jump", "hazard": "none" },
               { "beat": 14, "type": "hazard", "hazard": "spike" },
               { "beat": 20, "type": "jump", "hazard": "none" },
               { "beat": 34, "type": "orb" },
               { "beat": 48, "type": "pad" },
               { "beat": 32, "type": "camera", "shot": "side_low", "blend_beats": 2 },
               { "beat": 96, "type": "vfx", "name": "flash" }]
}
```

| Trường | Ý nghĩa |
|---|---|
| `tempo` | Danh sách điểm đổi BPM. Phải có ít nhất 1 điểm. |
| `speed` | Số đơn vị đường đi được mỗi beat, kể từ beat đó. Tốc độ cao hơn thì vật cản cách xa nhau hơn. |
| `phases` | *(tùy chọn, GD3-100)* Phase của màn: từ `beat` đó màn mang palette `palette` (`indigo`, `ocean`, `sunset`, `aurora`, `ultraviolet`, `ember`, `glacier`, `void` — `src/presentation/environment/palette_library.gd`). Đặt ở đầu ô nhịp (test kiểm tra beat chia hết cho 4) và mỗi phase phải nhanh hơn phase trước (thêm một khóa `speed` ở cùng beat). Đổi phase: lóe sáng, sóng vòng, FOV kick, cổng lớn, chữ "PHASE n · SPEED ×k". Không có `phases` thì cả màn dùng `indigo` (giao diện cũ). |
| `sections` | Đoạn nhạc. `energy` (0..1) điều khiển glow, màu trời, sương mù và nhịp đập ánh sáng. |
| `track` | Hình dạng đường từ beat đó đến điểm kế tiếp: `straight`, `turn` (`angle_deg`, dương = rẽ trái; tùy chọn `bank_deg` ≤ 45: nghiêng vào trong cua), `slope` (`rise`), và từ GD3-102: `helix` (xoắn ốc: `angle_deg` + `rise`, mỗi vòng phải lên ≥ 16.5), `loop` (vòng lộn dọc 360°, `lateral` ≥ 5 dịch ngang để không tự cắt, mặc định 6; nên dài ≥ 12 beat), `roll` (cuộn quanh hướng đi, `roll_deg` mặc định 360; nên dài ≥ 8 beat), `wave` (`count` ngọn đồi cao `amplitude`). Chỉ là hình ảnh: va chạm tính trong không gian đường nên hình dạng đường không đổi gameplay. Ở tier LOW các hình làm camera xoay liên tục được duỗi (xoắn ốc thành dốc, vòng lộn/cuộn thành đường thẳng, cua không nghiêng) vì đo trên máy tốn 5–7 FPS. Test `test_track_shapes.gd` kiểm tra đường của mọi chart không tự cắt (chừa 12 phía trên, 4.5 phía dưới mặt đường). |
| `terrain` | *(tùy chọn, gameplay v3)* Mặt đất từ beat đó tới mục kế tiếp: `height` (0 = mặt đường, tối đa 12) hoặc `"gap": true` (hố). Không có thì đường phẳng. Xem `docs/design/gameplay_v3.md`. |
| `end_beat` | Beat hoàn thành màn. Nhạc vẫn chạy tiếp phần outro. |

## Các loại event
- **Hành động** (`"type"`): đây là *thời điểm chạm*. Game tự đặt vật cản đi kèm:

  | type | Chuyển động | Vật cản (beat + offset) | Vào sân |
  |---|---|---|---|
  | `jump` | nhảy 1 beat | `spike` (+0.5) | trồi lên |
  | `dodge_left` / `dodge_right` | lăn sang làn trái / phải 1.25 beat rồi về | `wall_gap_left` / `wall_gap_right` (+0.625), tường chắn làn giữa và làn còn lại | rơi xuống |
  | `flip` | lộn qua mép xuống mặt dưới 2 beat rồi lên | `gate` (+1.0), cổng chắn cả bề ngang | bung ngang |
  | `roll` | lộn trọn vòng quanh đường 2 beat (GD3-106): qua mép phải, chạy dưới đường, lên lại mép trái | `mace_sweep` (+1.0), quả cầu gai lia dọc hướng chạy, buông thẳng đúng lúc người chơi tới; biến thể `falling_block` (khối rơi chặn cả đường) | rơi xuống |
  | `flip_down` | lộn qua mép phải xuống mặt dưới 1 beat và **ở lại** dưới đường (GD3-112) | `gate` (+1.25), trên mặt đường | bung ngang |
  | `flip_up` | từ mặt dưới lộn lên mép trái về mặt đường 1 beat | `gate_under` (+1.25), cổng treo dưới đường | bung ngang |
  | `orb` | vòng nhảy giữa không trung: chạm được cả khi đang bay, bật parabol mới (như jump) | không có | — |
  | `orb_big` | vòng nhảy lớn: như `orb` nhưng bật parabol của bệ bật (đỉnh +4.5, 1.5 beat) | không có | — |
  | `orb_drop` | vòng lao xuống: chạm khi đang bay thì lao thẳng xuống (12 đơn vị/beat, từ đỉnh +2 chạm đất sau ~0.15 beat) | không có | — |

  `"hazard"` có thể đổi vật cản đi kèm sang biến thể (GD3-095): `spike_double` (2 gai, thấp hơn),
  `spike_triple` (3 gai, thấp hơn nữa), `saw` (lưỡi cưa xoay theo nhịp). Mọi biến thể vượt qua bằng một cú nhảy,
  dung sai ≥ ±90 ms ở 150 BPM. GD3-104 thêm (model Blender, cùng cách vượt và hộp va chạm bằng hoặc rộng hơn bản gốc):
  `laser_fence` (hàng rào laser thấp), `pendulum` (rìu con lắc, buông thẳng đúng lúc người chơi tới), `spike_mine`
  (mìn gai lơ lửng) cho `jump`; `laser_gap_left` / `laser_gap_right` (lưới laser) cho `dodge_*`; `ring_gate` (cổng vòng)
  cho `flip`; `crusher` (máy dập, như `ceiling`) chỉ đặt bằng `"type": "hazard"`. `ceiling` (trần gai phủ cả đường, đáy cao 1.3) chỉ đặt bằng `"type": "hazard"`:
  chạy bên dưới thì an toàn, đang bay thì chết — dùng với `orb_drop`.
  Cú nhảy kết thúc khi tiếp đất (sớm hơn nếu đáp lên bệ cao hơn). Vật cản đứng trên mặt đất tại chỗ nó đứng (`terrain`). Vật cản luôn vào sân đúng **nguyên beat** `floor(beat_vật_cản − lead)` (lead: spike 2, tường/cổng 3). `"hazard": "none"` để chỉ có cue,
  không có vật cản. Có thể thêm `"hazard_offset": <beats>` để dịch vật cản.
- **`hazard`**: vật cản đứng riêng, không có cue (người chơi tự nhảy bằng thao tác mặc định).
- **`pad`**: bệ bật trên mặt đất. Người chơi đang đứng chạm vào là tự bật lên (đỉnh 4.5, 1.5 beat), không cần chạm.
- **`camera`**: chuyển sang shot `shot`, blend trong `blend_beats`. Danh sách shot nằm ở
  `src/presentation/camera/camera_shots.gd`: `side`, `side_low`, `side_high`, `side_far`, `chase`, `chase_low`,
  `high`, `diagonal`, `front`.
- **`vfx`**: `flash` (lóe sáng toàn cảnh), `shockwave` (vòng sóng), `burst` (bung hạt).

## Ràng buộc (được test kiểm tra)
- Mọi cue phải chơi được **đúng beat** của nó: hành động trước đã xong và người chơi đang đứng trên đất (trừ `orb`).
  Autoplay không bao giờ phải dựa vào input buffer. Trên đất phẳng nghĩa là cue cách nhau ít nhất bằng thời lượng
  hành động trước (jump 1, dodge 1.25, flip 2 beat); lên bậc +1.5 thì 0.75 beat là đủ.
  `draft_chart.py` chừa thêm ~0.5 beat: jump 1.5, dodge 1.75, flip 2.5.
- Dodge/flip cần đường phẳng ở độ cao 0 cho tới khi kết thúc; bệ bật và vật cản không được đặt trên hố (loader báo lỗi).
- Đoạn chạy mặt dưới (GD3-112): mỗi `flip_down` phải có `flip_up` sau nó; ở giữa chỉ có `jump` (vật cản đi kèm treo
  dưới đường, cùng hộp va chạm lật ngược); đường phẳng độ cao 0, không hố, không bệ bật từ `flip_down` tới 1 beat sau
  `flip_up` (loader báo lỗi). Vật cản đặt riêng (`"type": "hazard"`) nằm trong đoạn cũng treo dưới đường; `gate`
  luôn ở trên, `gate_under` luôn ở dưới. Tool đặt màn còn giữ đường liền tới 1.75 beat sau `flip_up` (cổng dưới đường).
- Tốc độ không được giảm; mỗi phase nhanh hơn phase trước (bậc thang chuẩn của các màn đặt tay: 7 → 7.75 → 8.5 →
  9.25 → 10, hoặc 7 → 8 → 8.75/9 → 9.5/10 với 4 phase); độ khó có trọng số (jump 1, dodge 1.25, flip 1.75, × tốc độ) của 1/4 cuối phải > 1.5 lần 1/4 đầu.
- Autoplay (chạm đúng mọi cue) phải qua màn: `tests/gameplay/test_shipped_charts.gd`.

## Cửa sổ timing (`GameplayConfig`)
| Kết quả | Độ lệch |
|---|---|
| PERFECT | ≤ 45 ms |
| GREAT | ≤ 90 ms |
| GOOD | ≤ 150 ms (lệch hơn thì lần chạm thành cú nhảy mặc định) |

Ở 120 BPM, vật lý cho phép lệch khoảng ±143 ms (jump), ±157 ms (dodge), rộng hơn nhiều với flip; test kiểm tra biên ±140 ms ở tốc độ 7 và 10.
Đo dung sai từng cue của một chart:
`"$GODOT" --headless --path . -s res://tools/charting/tolerance_report.gd -- --chart=res://assets/music/<id>.chart.json`.

## Quy trình làm chart cho một bài mới
Tạo nhạc bằng các prompt ở `docs/design/music_prompts.md` (tempo cố định, cú đánh rời rạc, motif 1 / 2-và / 3).

**Một lệnh (GD3-220):** `python tools/charting/auto_level.py <bài.mp3> --title "Tên" --artist "Nguồn"` chép nhạc vào
`assets/music/<id>.mp3`, đo BPM/offset, kiểm tra độ hợp (≥ 50 % ô nhịp có "X"), sinh LED, chọn độ khó theo số cú đánh
đáng chạm mỗi ô nhịp (< 1 → 2, < 2 → 3, còn lại 4; 1 và 5 chỉ qua `--difficulty`), chọn 4 bảng màu + `void`, ghi
`tools/charting/levels/<id>.py` (sửa rồi chạy lại được), dựng level LED và tự kiểm tra (độ nổi, autoplay qua màn, dung
sai). Mã thoát: 2 = BPM không chắc (chạy lại với `--bpm`), 3 = bài không hợp (`--force` để vẫn dựng), 1 = kiểm tra
Godot hỏng. Các bước tay bên dưới dùng khi cần chăm chút.
1. Đặt nhạc vào `assets/music/<id>.mp3`, chạy `python tools/audio/build_spectrum.py <id>` (dữ liệu dàn LED mặt hông). Kiểm tra bài bằng `python tools/charting/hit_grid.py assets/music/<id>.mp3
   <bpm> <offset>`: dòng cuối phải ≥ 50 % ô nhịp có "X" (cú đánh vừa nổi so với ±1 beat vừa có attack mạnh); lưới in
   ra chính là chỗ đặt chạm. Sau khi dựng chart, `python tools/charting/tap_salience.py assets/music/<id>.chart.json`
   phải ra OK.
2. Phân tích: `blender -b --factory-startup -P tools/audio/analyze_song.py -- assets/music/<id>.mp3 assets/music/<id>.analysis.json`.
   Bước này cho ra BPM, offset (nhịp mạnh đầu tiên), onset theo dải tần và năng lượng từng ô nhịp (để chia đoạn).
3. Viết `assets/music/<id>.plan.json`: các đoạn, luật mật độ cho từng đoạn, tốc độ, hình dạng đường, camera, VFX.
   Xem bài mẫu `the_dawn_assembly.plan.json`.
4. **Dựng từ cú đánh nổi bật** (GD3-107, nhanh nhất cho bài mới): viết `tools/charting/levels/<id>.py` gồm `bpm`,
   `difficulty` 1–5, `palettes` rồi gọi `hit_level.build(SONG)`. Tool chọn đúng thời điểm thật của các cú đánh nổi bật
   nhất (trên trung vị của bài, không làm tròn vào lưới), mật độ/khoảng cách/cặp chạm theo phase và độ khó
   (`hit_level.DIFFICULTY`), tỉa đầu bài để cuối khó hơn ≥ 1.7 lần, khớp offset trên cú đánh mạnh (`fit_tempo.py` khi
   phân tích báo sai BPM), chia đoạn theo ô nhịp gần lặng và độ to, đặt phase ngay sau ô lặng, tự xếp hình đường /
   camera / vfx; vật cản do `recording_level.Builder` chọn (cùng ràng buộc với level viết tay).
   Biến thể theo dàn LED: `tools/charting/led_level.py` (vd. `levels/pulse_drive_led.py`) chạm lúc LED bật vọt và thêm
   đoạn dồn dập; `"audio"` dùng chung mp3 với chart gốc, `"grid": 0.25` khi bài nằm đúng lưới.
5. **Đặt tay** (cách chính cho bài cần chăm chút, người dùng yêu cầu 2026-10-14 vì bản tự sinh không khớp nhạc): in lưới onset theo dải
   tần (kick / snare / hi-hat) từng ô nhịp, tìm motif của mỗi đoạn, viết `tools/charting/levels/<id>.py` là danh sách
   `beat:mẫu` (khai báo `"phases": [(beat, palette, units_per_beat)]` trong `SONG`, tool tự sinh `speed`; xem `tools/charting/handmade.py`: bộ kiểm tra báo lỗi nếu người chơi chưa tiếp đất, quá cao, hay lách
   làn/lộn khi không ở đường phẳng). `build()` mặc định thêm biến thể (giữ nguyên nhịp chạm và độ cao đất):
   `spike` xoay vòng gai / cưa / hàng gai theo energy, cứ 2 `orb` đủ chỗ thì 1 thành `borb`, cứ 2 lần `orb` + `drop`
   từ mặt đường thì 1 thành `dive`. Tắt bằng `build(SONG, STEPS, variety=False)`. Bài nhịp trôi thì đặt chạm theo thời điểm onset thật.
   Cuối cùng đo độ lệch cố định giữa lần chạm và onset để chỉnh `offset`.
   Bản nháp tự sinh (tham khảo):
   `python tools/charting/terrain_level.py assets/music/<id>.analysis.json --title "<Tên>" --seed 1`.
   Bộ sinh chia đoạn theo năng lượng ô nhịp, đặt mẫu (gai, bậc, hố, chuỗi, vòng nhảy, bệ bật, bậc thang, lách làn,
   lộn) sao cho mọi lần chạm rơi đúng **thời điểm onset thật** (không làm tròn vào lưới nhịp: nhạc AI có thể trôi
   nhịp), chỉ chọn nhịp nhấn rõ (đầu bài top 20% onset mạnh nhất, cuối bài top 40%), độ khó tăng theo tiến độ, tự hạ
   độ cao. BPM/offset được khớp lại với onset nếu tốt hơn rõ rệt.
   Tự thử seed kế tiếp tới khi độ khó cuối ≥ 1.6× đầu. Đổi `--seed` để có bản khác.
   (`the_dawn_assembly` viết tay bằng cùng thư viện mẫu; `draft_chart.py` + plan chỉ còn cho map classic.)
6. Chạy test, rồi chụp ảnh hoặc chơi thử: `godot --path . -- --chart=res://assets/music/<id>.chart.json`.
7. Kiểm tra dung sai bằng `tolerance_report.gd`; muốn chỉnh thì sửa bộ sinh/seed rồi sinh lại, chỉ sửa tay chart cho
   chi tiết cuối cùng. Bài mới tự xuất hiện trong menu chọn bài (PLAY / PRACTICE), xếp từ dễ đến khó theo `ChartDifficulty`
   (lần chạm có trọng số × tốc độ mỗi phút; nhãn EASY / NORMAL / HARD / HARDER / EXPERT).

## Đặt hành động bằng tay: record mode, `.sm`, `fixed`
- **Record mode** (menu RECORD (DEV) → chọn bài, chỉ có ở bản debug), mọi chức năng đều có nút trên màn hình:
  - Bài được chia thành **đoạn** (mỗi section cắt thành khúc 16 beat, khúc lẻ < 6 beat gộp vào khúc trước), chọn
    trên dải đoạn ở trên. Timeline hiển thị trọn đoạn đang soạn; LOOP lặp đoạn, PRE-ROLL phát trước 1 ô nhịp.
  - Mỗi nút đoạn hiện: tên, **thời gian** (giờ trong file nhạc, `m:ss.s`), **số note / số gợi ý** theo độ khó
    EASY/NORMAL/HARD (chọn ở hàng DIFFICULTY, lưu vào recording là `"difficulty"`). Màu: xám = chưa có note,
    xanh dương = ít hơn 70% gợi ý, xanh lá = vừa, cam = nhiều hơn 130% gợi ý.
    Gợi ý (`TapDensityGuide`) = thời lượng đoạn × mật độ chạm của **bài chuẩn** `the_dawn_assembly` (xếp mức HARD):
    mật độ chạm/giây được khớp thành đường thẳng theo `energy` của section, rồi nhân 0.5 (EASY) / 0.75 (NORMAL) /
    1.0 (HARD). Đổi bài chuẩn: `TapDensityGuide.REFERENCE_CHART`.
  - Tốc độ 25/50/75/100% (mặc định 50%). Khi chậm, nhạc vẫn giữ cao độ (`PitchKeeper`: hiệu ứng pitch shift trên
    bus `Music`, độ trễ của hiệu ứng được cộng vào calibration).
  - Chỉ có **một loại đánh dấu**: chỗ người chơi sẽ chạm (nghe tiếng nhạc nổi bật thì gõ). Đang phát: Space/J hoặc pad TAP;
    REC tắt thì chỉ nghe. Vật cản gì (gai, hố, bệ, tường, cổng…) do tool dựng level tự chọn.
    Đang dừng: pad/phím thêm một đánh dấu tại đầu phát (đã snap lưới).
  - Timeline: click hoặc kéo chỗ trống để tua (phát tiếp từ đó nếu đang phát), kéo note để dời (theo lưới),
    double-click để thêm note, chuột phải để xóa.
  - Sửa: UNDO/REDO (Ctrl+Z/Y), DELETE, CLEAR SEGMENT, **ALIGN TIMING** (dời các note trong đoạn sao cho
    lệch trung bình so với lưới bằng 0; dùng khi gõ trễ/sớm đều, nên chọn lưới 1/1 hoặc 1/2).
  - Phím tắt: P/Enter phát/dừng, ←/→ 1 beat, Shift+←/→ dời note, PgUp/PgDn đổi đoạn, Home về đầu đoạn, Tab chọn note,
    G lưới, `-`/`=` tốc độ, S lưu, Esc lưu và thoát.
  - **BUILD & PLAY SEGMENT** (desktop, cần `python` trong PATH): lưu, chạy `recording_level.py`, rồi chơi thử
    `<id>.rec.chart.json` từ đầu đoạn. Nút MENU của level quay lại màn RECORD (`LaunchOptions.return_scene`).
  - Kết quả lưu raw (giây + lưới đang chọn; trường `lane` luôn 0) vào `assets/music/<id>.recording.json`.
- **Dựng level địa hình từ recording (cách nhanh nhất để có level theo ý mình):**
  `python tools/charting/recording_level.py pulse_drive` (id bài; chạy không tham số để xem danh sách) → `assets/music/<id>.rec.chart.json`
  (tên bài thêm "(Rec)", tự hiện trong menu chọn bài). Lần gõ quyết định *khi nào* nhảy, tool chọn *vật cản gì*:
  - Lượng tử hóa theo lưới đã lưu trong recording (`"grid"`; file cũ không có thì dùng 1/4), giống hình thoi trên timeline.
  - 3 lần gõ cách nhau 0.5 beat thành `trip`, cách nhau 0.75 beat thành `stairs` (`fstairs` ở đoạn mạnh); 2 lần
    cách nhau 0.5 beat xoay vòng `orb dive orb borb` (lao xuống dưới trần gai, vòng nhảy lớn; cần nhiều chỗ trống
    phía sau hơn, không đủ thì lùi về mẫu khác). Mỗi lần gõ còn lại là một vật cản, xoay vòng theo `energy` của đoạn:
    đoạn êm `spike saw step spike2 gap wall spike step1`, đoạn mạnh (≥ 0.8)
    `spike2 gap wall step saw flip spike3 gap wall spike`; `wall` là `dl`/`dr` xen kẽ. Mẫu ưu tiên không đặt được
    (cần mặt đường, cần khoảng trống phía sau) thì thử lần lượt spike, gap, step, step1, saw, wall, flip.
    Trường `lane` trong recording cũ bị bỏ qua.
  - Tool tự thêm `drop` để xuống bệ khi có chỗ trống và luôn xuống trước tường/cổng. Mọi lựa chọn đều qua
    `handmade.Checker`, nên tuân cùng ràng buộc như level viết tay.
  - Lần gõ không đặt được vật cản nào (quá sát, gõ đúp) sẽ bị bỏ, kèm `WARN` ghi rõ beat. Sửa trong màn RECORD rồi
    chạy lại tool. Header (tempo, tốc độ, section, track, camera, vfx) được chép từ chart nguồn; chart `.rec` dùng
    chung recording với chart nguồn (`Recording.path_for_chart`).
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
