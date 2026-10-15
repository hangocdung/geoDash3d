# Gameplay v4: dạng bay, vật cản mới, vật cản xuất hiện đẹp hơn (đề xuất 2026-10-15)

Mục tiêu: màn chơi đa dạng và cuốn hơn, **FPS gần như không đổi** so với hiện tại (đo trên Mali-G72: LOW khoảng
53 FPS, MEDIUM khoảng 40 FPS). Vẫn giữ mọi bất biến trong `CLAUDE.md` §1: `SongClock` là đồng hồ duy nhất, không
physics engine, chart viết theo beat, kết quả tất định, logic tách khỏi trình bày, chỉ một thao tác `tap`.

**Đã duyệt 2026-10-15:** mọi đề xuất mục 7. Thêm theo yêu cầu: khi gặp nhóm lách, camera chuyển sang góc nhìn từ trên
xuống hơi nghiêng và chuyển động liên tục (shot `top_tilt`, `CameraDirector.auto_shot`; tier LOW giữ camera đứng yên vì
camera xoay liên tục tốn 5–7 FPS trên Mali-G72). Đổi so với bản đề xuất: trường `fly` không có `drift` (hình hành lang
đi theo đường bay chuẩn); không có `fly_max_fall` (giữ parabol thuần); định dạng chart vẫn `version` 1 vì `fly` là
trường tùy chọn như `terrain`.

---

## 1. Dạng bay (flight)

### Cảm giác
Người chơi đi qua **cổng biến hình**: khối lập phương gập thành tàu lượn (glider, hợp tên BeatGlide), camera lùi ra
và hạ thấp. Trong đoạn bay **trọng lực kéo xuống liên tục**, mỗi lần chạm thì tàu hất lên. Phải chạm đều theo nhạc
để giữ độ cao, luồn qua hành lang gai ở trên và dưới. Hết đoạn bay thì qua cổng ra: tàu gập lại thành khối, đáp
xuống đường.

### Luật mô phỏng (tất định, theo beat)
- Đoạn bay là khoảng beat `[start, end)` khai báo trong chart. Vào đoạn bay, người chơi giữ nguyên độ cao hiện có.
- Chuyển động dọc dùng lại `VerticalMotion` (parabol theo beat): trọng lực `fly_gravity`; mỗi lần chạm **đặt lại**
  vận tốc lên `flap_velocity` (không cộng dồn); vận tốc rơi tối đa `fly_max_fall`. Mỗi đoạn giữa hai lần chạm là một
  parabol, nên độ cao là hàm của chuỗi thời điểm chạm. Cùng chart và cùng chuỗi chạm thì ra cùng kết quả, không phụ
  thuộc FPS (dùng chung lưới va chạm 1/96 beat).
- Mọi tham số (`fly_gravity`, `flap_velocity`, `fly_max_fall`, độ cao trần, thời gian biến hình) nằm trong
  `GameplayConfig`, không rải số trong code.
- Chết khi chạm gai sàn hoặc gai trần (hoặc vật cản trên không). Lá chắn cứu như hiện nay: đưa về trạng thái của lượt
  hoàn hảo tại beat đó (`reference_motion_at`).

### Giữ đồng bộ nhạc (ưu tiên số 1)
- Đoạn bay vẫn có **cue `flap`** đặt vào các cú đánh nổi bật của nhạc (lấy từ `hit_grid.py` / `tap_salience.py`),
  thường là mỗi phách hoặc mỗi nửa phách. Chạm trúng cue thì được chấm điểm và cộng combo như cue thường.
- **Hành lang được sinh từ đường bay chuẩn**, tức đường bay khi chạm đúng mọi cue `flap`. Khe hở trên và dưới được
  tính đủ rộng để chạm lệch trong cửa sổ GOOD vẫn sống (dùng cách tính của `tolerance_report`). Chạm theo nhạc thì
  an toàn; chạm bừa thì dễ đâm gai. Nhờ vậy autoplay chỉ việc chạm đúng các cue.
- Lần chạm không gần cue nào vẫn hất tàu lên (không bị tính MISS), để người chơi tự cứu khi bị rơi.
  Cue `flap` bị bỏ qua thì tính MISS và đứt combo như cue thường.

### Va chạm hành lang: rẻ dù có hàng trăm gai
Không tạo hàng trăm hộp va chạm. Hành lang là **hai hàm độ cao theo quãng đường**: `floor(s)` và `ceiling(s)`,
bậc thang giống `Terrain`. Mỗi bước mô phỏng chỉ so độ cao tàu với hai giá trị này, chi phí O(1). Gai chỉ là hình
ảnh vẽ theo hai hàm đó. Vật cản trên không (mìn, thanh laser) vẫn dùng `HazardChecker` như hiện nay.

### Trình bày
- **Mô hình tàu**: sinh bằng `assets/blender/generate_models.py`, một vật liệu `neon_model` (một draw call).
  Biến hình bằng scale/squash, dùng hạt có sẵn trong pool, không tạo node mới giữa màn.
- **Cổng vào / ra**: dùng lại hệ cổng vòng của `DecorView`, màu dạng bay.
- **Camera**: shot `fly_side` / `fly_chase` lùi ra để thấy hành lang phía trước ít nhất khoảng 1,5 giây. Ở màn dọc
  dùng biến thể từ sau lưng, như `CameraShots` hiện có.
- **Vệt bay**: dùng lại `TrailParticles` (vệt pixel hiện có), đổi màu. Thêm vạch sáng ở sàn hành lang báo trước nhịp các cue `flap`, giống
  vòng cue.

---

## 2. Vật cản mới

Mọi vật cản mới qua được bằng **hành động đã có** (nhảy / lách / lộn / bay) và giữ **màu dành riêng** cho cách vượt
qua: hồng = nhảy, cam = lách, lime = lộn, cộng một màu mới cho bay (mục 7). Chuyển động của vật cản là **hàm thuần
của beat**: đặt theo beat, tua và restart chính xác, và luôn ở đúng tư thế khi người chơi tới.

### Nhóm A: trên mặt đường (nhảy, màu hồng)
| ID đề xuất | Hình | Nhịp |
|---|---|---|
| `piston_spikes` | Hàng gai thụt lên thụt xuống theo phách, luôn trồi lên đúng lúc người chơi tới | 1 phách |
| `rolling_ball` | Quả cầu gai lăn ngược về phía người chơi, gặp nhau đúng beat của cue | — |
| `shock_ring` | Trụ phát vòng sóng năng lượng tràn sát mặt đường mỗi phách, nhảy qua vòng | 1 phách |
| `laser_sweep` | Tia laser thấp quét ngang qua đường | 2 phách |
| `spike_bed` | Thảm gai dài, dùng cho cú nhảy xa hoặc chuỗi vòng nhảy | — |

### Nhóm B: chắn một làn (lách, màu cam)
| ID đề xuất | Hình | Nhịp |
|---|---|---|
| `sliding_wall` | Tấm tường trượt ngang khép một làn đúng beat | xuất hiện trước 2 phách |
| `falling_pillar` | Cột rơi từ trên trời cắm xuống một làn | DROP |
| `turret_beam` | Tháp pháo bắn tia đỏ dọc theo một làn | 1 phách |

### Nhóm C: chắn cả đường (lộn, màu lime)
| ID đề xuất | Hình |
|---|---|
| `energy_curtain` | Màn năng lượng phủ hết bề ngang, gợn sóng theo nhạc |
| `spinning_blades` | Cánh quạt lưỡi dao quay chắn đường (lộn xuống dưới đường) |

### Nhóm D: trong đoạn bay (màu dạng bay)
| ID đề xuất | Hình |
|---|---|
| `spike_corridor` | Gai sàn và gai trần theo `floor(s)` / `ceiling(s)` (mục 1) |
| `air_mine` | Mìn gai lơ lửng giữa hành lang, nhấp nhô theo phách |
| `laser_bars` | Thanh laser đứng có khe, khe trùng với đường bay chuẩn |
| `crusher_column` | Cột dập từ trần xuống, chừa khe đúng lúc |
| `narrowing` | Hành lang thu hẹp ở đoạn cao trào (drop), nới ra khi nhạc lắng |

**Làm theo đợt** (mục 6): đợt 1 gồm dạng bay, `spike_corridor`, `air_mine`, `piston_spikes`, `rolling_ball`,
`sliding_wall`; các vật cản khác thêm ở đợt sau. Mỗi loại mới phải có cấu hình trong `HazardLibrary` và trọng số
trong `ChartDifficulty`, có trong một chart thử, và qua test autoplay.

---

## 3. Vật cản xuất hiện đẹp hơn

Hiện có ba kiểu vào sân: RISE / DROP / UNFOLD, tính trên CPU cho từng node. Đề xuất thêm (theo `HazardDefinition.Entrance`):

| Kiểu | Mô tả |
|---|---|
| `ASSEMBLE` | Các mảnh bay vào từ hai bên và ráp lại đúng phách |
| `MATERIALIZE` | Hiện dần từ khung dây neon thành khối đặc, có đường quét sáng |
| `BEAT_POP` | Nảy lớn rồi co về kích thước thật đúng phách mạnh |
| `SPIRAL` | Xoáy từ trên cao xuống, chạm đường đúng phách |
| `WAVE` | Một dãy vật cản (hàng gai, hành lang bay) dựng lên lần lượt theo sóng từ gần ra xa, nối đuôi nhau theo nhạc |

**Cách làm để không tốn CPU:** đưa hiệu ứng vào **vertex shader**. Mỗi instance mang `appear_beat` và kiểu vào sân
trong `INSTANCE_CUSTOM` (MultiMesh) hoặc instance uniform; shader so với global `run_beat` (đã có sẵn). Không còn
cập nhật từng node mỗi frame. Đây là cùng cách vòng cue đang làm. `MATERIALIZE` dùng alpha scissor (không pha trộn
trong suốt) để không thêm overdraw.

**Phân tier:** LOW chỉ có RISE/DROP rẻ (cùng shader, nhánh đơn giản). MEDIUM/HIGH có đủ kiểu. "Giảm nhấp nháy" tắt
các đường quét sáng.

---

## 4. Ngân sách hiệu năng (điều kiện để được merge)

1. **Không thêm hậu kỳ, không thêm đèn, không có vật trong suốt kiểu pha trộn** cho vật cản.
2. **Gom draw call:** vật cản tĩnh hoặc lặp nhiều (gai hành lang, `spike_bed`, `piston_spikes`, mìn) vẽ bằng
   **MultiMesh theo loại**, mỗi loại một draw call, chuyển động trong vertex shader. Vật cản có phần động riêng
   (rìu, cưa…) giữ cách hiện tại.
3. **Giới hạn số instance hiển thị:** chỉ vẽ trong `VISIBILITY_RANGE` (240 đơn vị). Gai hành lang ở xa ghép thành dải
   (mesh ít đỉnh). LOW giảm mật độ gai trang trí (va chạm không đổi vì tính theo `floor`/`ceiling`).
4. **Chi phí logic:** va chạm hành lang O(1) mỗi bước; vật cản trên không vẫn dùng cursor của `HazardChecker`. Không
   cấp phát bộ nhớ trong vòng lặp mô phỏng.
5. **Mục tiêu đo (điều kiện chấp nhận):**
   - so A-B-B-A trên máy thật bằng `tools/device/perf_ab.sh` trên một chart có đoạn bay dày gai;
   - LOW giảm ≤ 0,5 FPS, MEDIUM giảm ≤ 1 FPS, không tăng số lần giật (> 33 ms);
   - trên PC so số draw call trong log capture với bản cũ ở cùng beat.
   Vượt ngân sách thì giảm hiệu ứng ở tier đó, không merge.
6. Tải màn: thêm mesh / MultiMesh trong thread nạp màn hiện có (`LevelLoader`, GD3-267), không làm dài màn hình
   chờ quá khoảng 100 ms.

---

## 5. Định dạng chart (đề xuất, cần duyệt)

```json
"fly": [{ "beat": 96, "end": 112, "gap": 3.2, "drift": 0.6 }],
"events": [{ "beat": 96.5, "type": "flap" }, { "beat": 97, "type": "flap" },
           { "beat": 100, "type": "hazard", "hazard": "air_mine" }]
```
- `fly`: các đoạn bay. `gap` là độ rộng khe tối thiểu (mặc định lấy từ `GameplayConfig`), `drift` là độ lượn của
  hành lang.
- `ChartLoader` dựng `floor(s)` / `ceiling(s)` từ đường bay chuẩn của các cue `flap` (`ReferenceRun`) và kiểm tra:
  khe đủ rộng cho cửa sổ GOOD, không có cue khác loại trong đoạn bay, đoạn bay không chồng `terrain` / hố.
- Cổng vào/ra và camera tự sinh theo `fly`, người soạn không phải khai.
- **Phối hợp với kế hoạch tải nhạc của Codex** (GD3-275 đổi đường dẫn `song`, thêm `version`): gộp vào **một lần**
  nâng định dạng (`"version": 2`), ghi trong `docs/chart_format.md`; chart version 1 vẫn chạy.

---

## 6. Các bước (task GD3-280…289, đề xuất)

| Task | Việc | Kiểm tra |
|---|---|---|
| GD3-280 | Người dùng duyệt mục 7 (màu bay, định dạng chart, luật chấm điểm) | — |
| GD3-281 | Mô phỏng bay: `fly` trong chart, `flap`, parabol theo lần chạm, va chạm `floor`/`ceiling`, lá chắn, `ReferenceRun` / autoplay / `safe_start_beat` | Test tất định, không phụ thuộc FPS, autoplay qua được, lá chắn cứu được |
| GD3-282 | Trình bày bay: model tàu, cổng, camera, vệt bay, vạch nhịp `flap`, gợi ý lần đầu (`TutorialHints`) | Ảnh chụp ngang/dọc |
| GD3-283 | Hành lang gai bằng MultiMesh + vertex shader (sóng dựng lên) | Số draw call; FPS trên máy |
| GD3-284 | Hệ vào sân mới (`ASSEMBLE`, `MATERIALIZE`, `BEAT_POP`, `SPIRAL`, `WAVE`) trong shader, phân tier | So ảnh LOW/HIGH; FPS |
| GD3-285 | Vật cản đợt 1: `air_mine`, `piston_spikes`, `rolling_ball`, `sliding_wall` | Test hộp va chạm + autoplay |
| GD3-286 | Công cụ soạn màn: mẫu `fly` trong `tools/charting/levels/*.py` / `auto_level.py`, `tolerance_report` cho đoạn bay, trọng số độ khó | Một bài có đoạn bay qua `tap_salience.py` OK |
| GD3-287 | Áp vào 2 bài có đoạn cao trào hợp (đề xuất `pulse_drive`, `neon_rhythm_stabs`) | Thử chơi + `test_shipped_charts` |
| GD3-288 | Đo A-B-B-A trên máy, chỉnh theo tier | Đạt ngân sách mục 4 |
| GD3-289 | Vật cản đợt 2 (nhóm A–D còn lại) | Như GD3-285 |

Làm trên branch `feat/gameplay-v4` (worktree `D:\godot\GeoDash3d-gameplay`). Rebase lên `main` thường xuyên vì Codex
đang làm phần tải nội dung trên `main`.

---

## 7. Câu hỏi cần người dùng chốt

1. **Màu của dạng bay.** Ba màu gameplay đã có chủ (hồng / cam / lime) và cảnh nền chỉ dùng tông lạnh. Đề xuất
   **vàng kim** (#FFC93C): ấm, khác hẳn ba màu kia, nổi trên nền tím xanh. Phương án khác: trắng bạc.
2. **Định dạng chart:** thêm `fly` + cue `flap` như mục 5, gộp với lần nâng version của Codex. Đồng ý không?
3. **Chấm điểm khi bay:** chạm không gần cue thì không phạt (đề xuất), hay tính MISS để buộc chạm đúng nhịp?
4. **Độ khó:** đoạn bay chỉ xuất hiện từ bậc NORMAL trở lên, hay có cả ở bài EASY (khe rộng hơn)?
5. **Tàu bay:** khối gập thành tàu lượn (đề xuất), hay giữ khối lập phương có thêm cánh sáng?
