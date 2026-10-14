# Gameplay v3: địa hình, vòng nhảy, bệ bật, bậc thang nhanh

> Nguồn: yêu cầu của người dùng ngày 2026-10-14. **Đã duyệt** (2026-10-14): map địa hình là map chính
> `assets/music/the_dawn_assembly.chart.json`, sinh bằng `tools/charting/the_dawn_assembly_level.py`.
> Map cũ (đủ bài, có dodge/flip, không địa hình) giữ ở `the_dawn_assembly.classic.chart.json` để so sánh.

## 1. Mục tiêu và luật đã chốt
- Màn có **địa hình** như Geometry Dash: bệ nhiều độ cao, hố, bậc thang, khối lơ lửng. Không chỉ chạy trên một mặt phẳng.
- Có **chuỗi chạm liên tục** (2–3 lần), có đoạn nhịp nhanh hơn chu kỳ rơi (đáp lên bậc cao hơn thì tiếp đất sớm hơn).
- Vẫn **một thao tác chạm**. **Không có giữ để nhảy liên tục.**
- **Chỉ nhảy tiếp được sau khi đã chạm mặt đất / mặt bệ, hoặc chạm một vòng nhảy (orb).**
  Chạm khi đang bay mà không có vòng nhảy thì chỉ được giữ lại nếu còn ≤ 100 ms là tiếp đất (input buffer như cũ).
- **Ưu tiên dễ đọc màn chơi vẫn giữ nguyên.** Vài điểm khó nhận ra do lỗi thiết kế thì chấp nhận được (người chơi
  nhớ để chơi lại), nhưng không cố tình làm khó nhận biết.

## 2. Mô hình
- **Terrain** (`src/gameplay/track/terrain.gd`): độ cao mặt đất theo quãng đường, dạng bậc (piecewise-constant).
  0 = mặt đường. Có thể là `GAP` (không có đất). Chart đặt theo **beat**, quy ra quãng đường qua `speed`.
  Chart không có `terrain` thì mặt đất phẳng ở 0: chart cũ chạy y hệt trước (test chứng minh).
- **VerticalMotion** (`src/gameplay/simulation/vertical_motion.gd`): người chơi đứng trên đất ở một độ cao, hoặc
  bay theo parabol `y = y0 + v·t − ½·g·t²` (t tính bằng beat). Mọi cú nhảy (jump, orb, pad) và cú rơi khi chạy
  khỏi mép đều là một parabol. Vẫn là công thức giải tích, kiểm tra trên lưới cố định 1/96 beat → tất định.
- **Tiếp xúc** mỗi bước lưới, với `support` = mặt đất cao nhất dưới hộp người chơi (dài ±0.38):
  - Đang đứng: đất cao lên quá `step_snap` (0.2) → **đâm vào hông bệ = chết**. Đất thấp xuống / hố → bắt đầu rơi.
  - Đang bay: rơi qua mặt bệ từ trên xuống (hoặc chân thấp hơn mép không quá 0.2) → tiếp đất. Còn lại → đâm hông = chết.
  - Rơi thấp hơn `fall_death_height` (−4) → chết (rơi xuống hố).
- **Vật cản đứng trên đất**: hộp va chạm của gai/tường được nâng theo độ cao mặt đất tại đó (`base_height`).
- **Bệ bật (pad)**: khi người chơi đang đứng chạm vào bệ → tự bật lên, **không cần chạm**. Chạm trước khi tới bệ
  thì nhảy thường và lỡ bệ (giống GD), vì vậy bệ không có icon "chạm".
- **Vòng nhảy (orb)**: một cue `orb` có thể chạm **khi đang bay**: bật một parabol mới từ độ cao hiện tại.
  Cửa sổ thời gian giống cue thường (±150 ms). Vị trí vẽ = vị trí người chơi khi autoplay tới đúng beat đó.
- **ReferenceRun** (`src/gameplay/simulation/reference_run.gd`): chạy autoplay một lượt lúc nạp chart để biết
  độ cao người chơi ở mỗi cue (đặt vòng cue, vòng nhảy) và các khoảng đang bay (điểm bắt đầu khi luyện tập
  không bao giờ rơi vào lúc đang bay).

## 3. Thông số (trong `GameplayConfig`, ở 120 BPM)
| | Thời lượng trên đất phẳng | Đỉnh | v0 (đơn vị/beat) | g (đơn vị/beat²) |
|---|---|---|---|---|
| `jump` | 1 beat | 2.0 | 8 | 16 |
| `orb` | 1 beat | +2.0 từ chỗ chạm | 8 | 16 |
| bệ bật (`pad_launch`) | 1.5 beat | 4.5 | 12 | 16 |
| rơi khỏi mép | — | — | 0 | 16 (= jump) |

Tiếp đất sau khi nhảy (từ đất), theo độ cao bậc: 0 → 1 beat · +1.0 → 0.854 beat · +1.5 → **0.75 beat** ·
+2.0 → 0.5 beat (đúng đỉnh, không dung sai, không dùng).

## 4. Các mẫu màn (trong `the_dawn_assembly_level.py`) và dung sai đo được
Mép bệ đặt dưới đỉnh parabol (cộng nửa chiều dài người chơi) để dung sai sớm/trễ đối xứng.

| Mẫu | Nhịp chạm | Dung sai (đo bằng `tolerance_report.gd`) |
|---|---|---|
| Gai đơn, nhảy lên bậc +1.5, nhảy qua hố | 1 lần | ±140–150 ms |
| Chuỗi gai 2–3 lần cách 1 beat | 1, 1 | ±90 ms (giới hạn bởi input buffer 100 ms) |
| Bậc thang 1 beat (+1.0 mỗi bậc) | 1, 1 | ±140 ms |
| **Bậc thang nhanh** 3 bậc +1.5 | 0.75, 0.75 | ±90 ms |
| **Bậc thang lơ lửng** (giữa các khối là hố) | 0.75, 0.75 | ±90 ms |
| Nhảy + vòng nhảy ở đỉnh → bệ +2 | 0.5 | ±120–150 ms |
| Nhảy + 2 vòng nhảy qua hố → bệ +4 | 0.5, 0.5 | ±120–150 ms |
| Bệ bật → bệ +4 | không chạm | — |
| Chạy khỏi mép xuống thấp | không chạm | — |

Vòng nhảy luôn đặt **ở đỉnh parabol**: ở đó chạm lệch giờ gần như không đổi độ cao. Bản nháp có mẫu vòng nhảy ở đoạn
đang rơi (nhịp 0.75): chạm trễ 75 ms là không lên nổi bệ → đã bỏ, thay bằng bậc thang lơ lửng.
Demo 116 beat: 58 lần chạm, dung sai tệ nhất ±90 ms.

## 5. Hiển thị
- Bệ: cùng vật liệu đường (lưới + ray), thân sáng hơn đường một chút. **Mặt đứng của bậc được viền sáng** để thấy
  bức tường từ xa. Hố: đường bị cắt, mép hố có viền.
- Vòng cue nằm trên mặt đất tại chỗ chạm (ở đúng độ cao bệ). **Icon lơ lửng chỉ có khi có vật cản đi kèm**
  (gai, tường, cổng). Bậc thang và hố không có icon, để không nhầm với vòng nhảy.
- Vòng nhảy: billboard hồng, lõi sáng đặc trong hai vòng tròn (glyph 6), không có mũi tên.
- Bệ bật: tấm hồng phát sáng, mũi tên phẳng chỉ về phía trước.
- Camera bám độ cao mặt đất (trung bình chính xác trên ±9 đơn vị, nhìn trước 4 đơn vị), cộng 35% độ cao cú nhảy.
- Khối xoay 90° mỗi beat khi bay, tiếp đất thì khớp về mặt gần nhất (ease ~0.1 s).

### Hiệu năng (Note10 Lite, Mali-G72, máy nguội, 2026-10-14)
Đo bằng `perf_matrix.sh` + `EXTRA_ARGS` (autoplay, cùng đoạn nhạc từ beat 64, mỗi cấu hình 3 mẫu × 5 s, đo lặp lại
theo thứ tự ngược):

| Tier | Chart gốc | Demo địa hình |
|---|---|---|
| LOW | 55.7 / 55.4 FPS, 90 draw call | 57.2 / 57.1 FPS, 49 draw call |
| MEDIUM | 40.3 FPS | 40.3 FPS |

Đoạn từ beat 20 và 84 (2 mẫu): chênh lệch trong khoảng ±1.3 FPS, tùy mật độ vật cản chứ không do địa hình.
Frame tệ nhất 42–47 ms, 1–2 lần khựng mỗi 15 s ở **cả hai** chart (có từ trước). Game vẫn nghẽn ở GPU (glow).

## 6. Định dạng chart (mở rộng, tương thích ngược, đã duyệt)
```json
"terrain": [{ "beat": 12.55, "height": 1.5 }, { "beat": 17.75, "gap": true }, { "beat": 18.25, "height": 0 }],
"events":  [{ "beat": 12, "type": "jump", "hazard": "none" },
            { "beat": 34, "type": "orb" },
            { "beat": 48, "type": "pad" }]
```
Mỗi mục `terrain` đặt mặt đất từ beat đó tới mục kế tiếp. Validate: dodge/flip cần đường phẳng ở độ cao 0;
bệ bật và vật cản không được đặt trên hố.

## 7. Giới hạn của demo
- Dodge/flip chỉ dùng trên đường phẳng. Địa hình chưa chia theo làn, chưa có trần/bệ treo để chạy bên dưới.
- `draft_chart.py` chưa sinh địa hình; map chính được viết bằng mẫu trong `the_dawn_assembly_level.py` và mới phủ
  116/224 beat (đầu bài tới hết nửa đầu điệp khúc), chưa có dodge/flip.
- Orb và bệ bật dùng tạm âm `player.jump`.
- Chuỗi chạm nhanh bị giới hạn ±90 ms bởi `input_buffer_sec` (100 ms); có thể nới lên 150 ms nếu thấy gắt.

## 8. Combo và lá chắn (GD3-090, 2026-10-14)
- **Combo** = số cue chạm trúng liên tiếp (PERFECT/GREAT/GOOD). MISS hoặc một cú va chạm được lá chắn đỡ → về 0.
  Chạm không trúng cue (nhảy mặc định) không tính. HUD hiện "N COMBO" từ 2 trở lên; màn kết thúc có MAX COMBO.
- **Lá chắn**: mỗi `shield_combo` (16) lần trúng liên tiếp nạp 1 lá chắn, giữ tối đa `max_shields` (1). Nguồn duy nhất
  là combo (tất định, thưởng cho chơi đúng nhịp, không thêm vật thể phải đọc trên đường).
- **Đỡ một cú chết, không lệch nhịp**. Vị trí theo thời gian không bao giờ đổi (không đẩy lùi, không slow-mo):
  - Gai / tường / cổng: vật cản vỡ vụn (bị bỏ qua), người chơi chạy tiếp như cũ.
  - Đâm hông bệ hoặc rơi xuống hố: người chơi được đặt lại vào **trạng thái của lượt chơi hoàn hảo** ở đúng beat
    đó (ReferenceRun lưu mọi lần cất cánh/tiếp đất). Vì vậy cue kế tiếp vẫn chạm được đúng beat của nó.
  - Cue bị lỡ vẫn tính MISS; lá chắn không chạm hộ. Chế độ bất tử (luyện tập/soạn màn) không dùng lá chắn.
- Hiển thị: vòng sáng xanh nhạt quanh khối khi có lá chắn; thanh nạp dưới nút pause ("SHIELD" / "SHIELD READY");
  khi vỡ: lóe sáng, vòng sóng, vật cản vỡ thành mảnh, âm `player.shield_break` (nạp đầy: `player.shield`).
- Công cụ kiểm tra: `--autoplay-miss=44,74` (autoplay cố tình bỏ cue) và `--capture-continuous` (một lượt chơi
  liên tục cho mọi thời điểm chụp).

## 9. Chướng ngại vật mới (GD3-095, 2026-10-14)
Người dùng thấy map đơn điệu → thêm loại vật cản/vòng nhảy, vẫn **một thao tác chạm**, định dạng chart chỉ mở rộng
(giá trị mới cho `type` / `hazard`, chart cũ chạy y hệt).

| Loại | Chart | Cách vượt | Ghi chú |
|---|---|---|---|
| Hàng 2 gai | `"hazard": "spike_double"` | 1 cú nhảy | hộp dài 1.5, cao 0.75 |
| Hàng 3 gai | `"hazard": "spike_triple"` | 1 cú nhảy | hộp dài 2.1, cao 0.65 (thấp hơn để giữ dung sai) |
| Lưỡi cưa | `"hazard": "saw"` | 1 cú nhảy | xoay nửa vòng mỗi beat (hàm của beat) |
| Trần gai | `"type": "hazard", "hazard": "ceiling"` | ở trên mặt đất | phủ cả đường, dài 4.8, đáy 1.3: đang bay là chết |
| Vòng nhảy lớn | `"type": "orb_big"` | chạm khi bay | parabol bệ bật (đỉnh +4.5, 1.5 beat) |
| Vòng lao xuống | `"type": "orb_drop"` | chạm khi bay | vận tốc −12 đơn vị/beat, g = 16 |

Màu: tất cả thuộc họ nhảy nên là hồng. Vòng lớn: to hơn 1.3×, hai vòng + mũi tên lên (glyph 8); vòng lao xuống:
mũi tên xuống (glyph 7).

Mẫu màn mới (`terrain_patterns.py` / `handmade.py`):
- `spike2`, `spike3`, `saw`: như `spike`.
- `borb`: nhảy, vòng lớn ở đỉnh (+0.5), hố từ +0.3, bệ +2 từ +1.0; tiếp đất ở +2.0 beat (thay được `orb`, chỉ cần
  thêm 0.5 beat trống).
- `dive`: nhảy qua hố nhỏ (+0.15 → +0.4), vòng lao xuống ở đỉnh (+0.5), trần gai bắt đầu ở +0.9. Không chạm vòng
  thì cung nhảy còn cao ~1 đơn vị khi tới trần → chết; chạm đúng thì chạm đất ở ~+0.65.

Dung sai đo bằng `tolerance_report.gd` (test `test_obstacles.gd` kiểm tra ±0.15 beat ở 120 BPM): mọi chart vẫn có
dung sai tệ nhất ±90 ms; `dive` ở 150 BPM: nhảy −150/+90 ms, lao xuống ±110 ms.
