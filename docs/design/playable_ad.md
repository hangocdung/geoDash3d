# Playable ad cho BeatGlide (đề xuất 2026-10-16, chưa bắt đầu)

Mục tiêu: một quảng cáo chơi được (playable ad) khoảng 20–30 giây, dùng **đúng một đoạn màn chơi thật** (chart, nhạc,
màu, vật cản), chạy trong WebView của các mạng quảng cáo, kết thúc bằng nút cài game. Task: `GD3-310`–`GD3-317` trong
`docs/todo.md` mục 7c.

Ưu tiên giữ nguyên tinh thần của game: **khớp nhạc tuyệt đối > dễ đọc > đẹp**, một thao tác chạm, mọi thứ là hàm của
thời gian bài.

---

## 1. Tóm tắt quyết định đề xuất
1. **Không xuất từ Godot sang web.** Bản web quá nặng so với giới hạn của các mạng quảng cáo (mục 2).
2. **Viết một bản riêng nhỏ bằng TypeScript + Three.js** trong thư mục `playable/`, đóng gói bằng esbuild thành
   **một file HTML tự chứa** cho mỗi mạng. Đây là thư viện ngoài, cần người dùng duyệt trước (CLAUDE.md §7).
3. **Godot bake dữ liệu, JS chỉ đọc.** Một tool headless chạy chart thật qua `ChartLoader` + `ReferenceRun` + `Autoplay`,
   rồi xuất đường ray, chuyển động chuẩn, cue, vật cản và hậu quả khi lỡ từng cue ra JSON. Chart vẫn chỉ có một nguồn,
   JS không tự tính lại `beat → time → s`.
4. **Luật chơi mức 1, "theo cue"** (mục 5): người chơi đi theo đường chuẩn của autoplay. Chạm trúng cue thì chấm điểm.
   Lỡ cue thì phát lại đoạn "lỡ cue" đã bake (dẫn tới chết hoặc vỡ lá chắn). Không phải port bộ mô phỏng sang JS.
5. **Đồng hồ duy nhất là `AudioContext`**, như `SongClock` trong game. Hướng dẫn chơi kiểu "đóng băng" chỉ cần
   `suspend()` âm thanh.
6. **Ngân sách kích thước: ≤ 2 MB mỗi file** để vừa cả mạng chặt nhất; giới hạn cứng 5 MB.

## 2. Vì sao không xuất từ Godot
- Template `web_nothreads_release` của Godot 4.6.1: `godot.wasm` **37,7 MB** (zip ~9,5 MB). Nhúng base64 vào một
  file HTML còn tăng thêm ~33 %. Kể cả build template rút gọn (tắt module, `optimize=size`) thì vẫn vượt giới hạn.
- Web chỉ có renderer Compatibility (WebGL2), nên 10 shader hiện tại (`neon_track`, `neon_box`, trời, LED…) đều phải
  kiểm tra lại.
- WebView máy yếu mất vài giây để biên dịch wasm, trong khi quảng cáo mất người xem ngay ở mấy giây đầu.
- Bản web Godot vẫn hợp cho **demo trên web** (itch.io, trang giới thiệu), nhưng không phải cho playable ad.

## 3. Ràng buộc của mạng quảng cáo
Các số dưới đây là mốc thường gặp (ghi 2026-10-16). Quy định đổi thường xuyên, **phải đọc lại tài liệu của từng mạng
lúc làm** GD3-315.

| Mạng | Định dạng | Giới hạn | Gọi mở store | Ghi chú |
|---|---|---|---|---|
| AppLovin | 1 file HTML | ~5 MB | `mraid.open(url)` | MRAID; chờ `ready` trước khi chạy |
| Unity Ads | 1 file HTML | ~5 MB | `mraid.open(url)` | MRAID; nghe `viewableChange` để tạm dừng |
| ironSource | 1 file HTML | ~5 MB | `mraid.open(url)` | MRAID (hoặc DAPI) |
| Mintegral | zip | ~5 MB | `window.install()` | có các hàm báo trạng thái riêng (vd. `gameEnd`) |
| Google Ads (App campaign) | zip HTML5 | ~5 MB | `ExitApi.exit()` | thẻ meta kích thước/hướng; script `exitapi.js` của Google |
| Meta (FB/IG/Audience Network) | 1 file HTML | ~2–5 MB | `FbPlayableAd.onCTAClick()` | không MRAID, cấm request ra ngoài |
| TikTok / Pangle | zip | ~5 MB | SDK playable riêng | kèm file cấu hình của TikTok |

Quy tắc chung cho mọi mạng:
- **Không có request mạng nào.** JS, dữ liệu, nhạc và font đều nhúng vào file (ngoại lệ duy nhất là script bắt buộc
  của mạng, vd. `exitapi.js` của Google).
- Chỉ mở store khi người xem **tự bấm** nút CTA, không tự chuyển hướng.
- Tạm dừng khi quảng cáo bị ẩn (`viewableChange` của MRAID, `visibilitychange`) và chạy tiếp khi hiện lại.
- Chạy được cả màn ngang lẫn dọc, xoay giữa chừng không vỡ khung.

## 4. Kiến trúc
```
Godot (headless)
  <id>.chart.json ─► ChartLoader + ReferenceRun ─► tools/playable/bake_segment.gd ─► playable/data/<seg>.segment.json
                                                         │                         playable/data/<seg>.golden.json
  <id>.mp3 ─► ffmpeg (cắt + fade) ───────────────────────┴───────────────────────► playable/data/<seg>.clip.mp3

playable/src (TypeScript) ─► esbuild ─► nhúng JS + JSON + nhạc base64 ─► playable/dist/<mạng>/index.html (hoặc .zip)
```

Cấu trúc thư mục đề xuất (theo quy ước CLAUDE.md §5: code tiếng Anh, mỗi file ≤ 300 dòng, có header 2–3 dòng):
```
playable/
  package.json, tsconfig.json, build.mjs   phiên bản thư viện ghim cứng (vd. three@0.170.0), không dùng "^"
  src/main.ts          vòng lặp requestAnimationFrame, trạng thái WAITING → TUTORIAL → RUNNING → DEAD / END
  src/clock.ts         AudioClock: thời gian bài từ AudioContext
  src/segment.ts       đọc segment.json, nội suy frame đường ray và chuyển động chuẩn theo beat
  src/run.ts           luật theo cue: chấm điểm, combo, lá chắn, chết (logic thuần, không đụng Three.js)
  src/view/            track, player, hazards, cue rings, sky, camera, end card (chỉ đọc state của run.ts)
  src/networks/        adapter CTA và vòng đời cho từng mạng
  src/i18n.ts          chuỗi vi/en theo navigator.language
  data/                file do tool bake sinh ra
  test/                test chạy bằng Node: so run.ts với golden.json
src/authoring/playable/segment_baker.gd   logic bake (class_name SegmentBaker, test được headless)
tools/playable/bake_segment.gd            lệnh CLI mỏng: đọc tham số, gọi SegmentBaker, ghi file, gọi ffmpeg
```
`node_modules/` và `dist/` vào `.gitignore`. File trong `data/` nhỏ (≤ ~0,5 MB) nên commit, để build không cần Godot.
Tách logic và trình bày như bất biến §1.6: `run.ts` không import gì từ `view/`.

## 5. Luật chơi trong quảng cáo (mức 1: theo cue)
### Đồng hồ
- `song_time = clip_start + (ctx.currentTime − ctx_start) − output_latency`, với `output_latency` lấy từ
  `ctx.outputLatency` (thiếu thì `ctx.baseLatency` cộng giá trị mặc định trong config, đo trên máy thật).
- Mỗi frame đọc lại đồng hồ, không cộng dồn `delta`. Thời gian không chạy lùi (làm mượt như `SongClock` nếu cần).
- `beat = beat_at_time(song_time)` dùng bảng tempo đã bake. Mọi thứ hiển thị là hàm của `beat`.

### Chạm và chấm điểm
- Chạm ghi thời điểm bằng đồng hồ ở trên (sự kiện `pointerdown`), tìm cue chưa chấm gần nhất trong `cue_window_sec`.
  Bậc PERFECT / GREAT / GOOD theo `perfect_window_sec`, `great_window_sec`. Mọi cửa sổ lấy từ `GameplayConfig` qua dữ
  liệu bake, nhân với `ad_window_scale` (đặt trong config của playable, không rải số trong code).
- Chạm ngoài mọi cửa sổ thì **bỏ qua** (chỉ có hiệu ứng nhỏ). Đây là chỗ đơn giản hóa so với game thật (game sẽ nhảy
  mặc định), để người xem lần đầu không tự giết mình bằng cú chạm thừa.
- Combo và lá chắn giữ luật `ComboShield`, nhưng bắt đầu với 1 lá chắn để người mới ít chết trước giây ~15.

### Lỡ cue
- Tool bake chạy lại mô phỏng cho **từng cue**: `Autoplay` bỏ đúng cue đó (như `--autoplay-miss`), không bất tử, không
  lá chắn. Kết quả gồm beat chết, vật cản gây chết và đường đi của người chơi từ cue tới lúc chết (`miss_trace`).
- Khi lỡ, JS phát `miss_trace`. Còn lá chắn thì vật cản vỡ, người chơi chuyển mượt về đường chuẩn trong ~0,25 beat
  (game thật đi tiếp theo đường riêng: thêm một chỗ đơn giản hóa nữa). Hết lá chắn thì hiện hiệu ứng chết, sau ~1 giây
  chơi lại từ đầu đoạn. Chết 2 lần thì chuyển sang màn kết.
- Cue lỡ mà không gây hậu quả gì (vd. nhảy không có vật cản): tool bake **cảnh báo**. Khi chọn đoạn, ưu tiên đoạn mà
  mọi cue đều có vật cản.

### Hướng dẫn kiểu "đóng băng"
- Tới **đúng thời điểm** cue đầu tiên (và cue đầu của mỗi loại hành động mới) thì `ctx.suspend()`. Đồng hồ dừng nên cả
  thế giới đứng yên, vòng cue khép đúng vạch, hiện bàn tay "CHẠM!".
- Người chơi chạm thì `ctx.resume()`. Lần chạm đó lấy thời gian đang dừng, tức đúng thời điểm cue, nên được PERFECT.
  Vẫn tất định và khớp nhạc.
- Để tiếng không bị bụp khi dừng, giảm gain về 0 trong vài chục ms ngay trước thời điểm dừng.

### Mức 2 (tùy chọn, GD3-317)
Port bộ mô phỏng thật (`VerticalMotion`, `PlayerBody`, `ActionResolver`, `HazardChecker`, `Terrain`, có thể cả
`FlightCorridor`) sang TS, chừng 1–1,5 nghìn dòng. Kiểm tra bằng golden trace với chuỗi chạm ngẫu nhiên sinh từ Godot.
Chỉ làm nếu người chơi thử thấy mức 1 "giả".

## 6. Dữ liệu bake (`<seg>.segment.json`)
Tool: `"$GODOT" --headless --path . -s res://tools/playable/bake_segment.gd -- --chart=res://assets/music/<id>.chart.json
--start-beat=<b> --seconds=<s> --out=playable/data/<seg>`

| Trường | Nội dung | Nguồn trong game |
|---|---|---|
| `meta` | id chart, `chart_revision`, beat đầu/cuối, `clip_start` (giây trong bài), độ dài | `LevelChart` |
| `tempo` | các điểm beat ⇄ giây trong đoạn | `chart.time_at` / `TempoMap` |
| `distance` | các điểm beat ⇄ khoảng cách `s` | `chart.distance_at` |
| `path` | mỗi 0,5 đơn vị: vị trí + quaternion, từ đầu đoạn tới cuối đoạn + tầm nhìn phía trước | `TrackPath.transform_at` |
| `terrain` | bậc độ cao, hố, bệ trong đoạn (để dựng mặt đường) | `chart.terrain` |
| `reference` | mỗi 1/48 beat: offset ngang, độ cao, cờ (trên không / bay / mặt dưới), tiến độ hành động | autoplay `player_offset_at`, `is_airborne`, `action_progress_at` |
| `cues` | beat, loại hành động, độ cao vòng (`cue_heights`), có vật cản không, hậu quả khi lỡ + `miss_trace` | `chart.cues`, chạy lại với `Autoplay(missed_beats)` |
| `hazards` | loại hiển thị, hộp theo `s` / ngang / độ cao, mặt (trên/dưới), `appear_beat`, kiểu vào sân | `HazardDefinition`, `HazardChecker` |
| `config` | cửa sổ timing, `shield_combo`, `max_shields`, kích thước đường/người chơi | `GameplayConfig` |
| `palette` | màu các phase trong đoạn (đổi sang sRGB) | `PhasePalettes`, `PaletteLibrary` |
| `pulse` | beat đầu ô nhịp + energy section, cho nhịp sáng | `chart.section_at` |
| `spectrum` (tùy chọn) | phần LED của đoạn, RG8 base64 | `<id>.spectrum.json` |

- Số thực làm tròn 3 chữ số (vị trí) / 4 chữ số (quaternion) để file nhỏ. Ước lượng ~50 beat ⇒ vài chục KB.
- `<seg>.golden.json`: kết quả Godot cho vài chuỗi chạm mẫu (autoplay; lỡ cue k khi còn lá chắn; lỡ cue k khi hết lá
  chắn) gồm bậc của từng cue, beat chết, lá chắn đã dùng. Test của `playable/` phải ra đúng như vậy.
- Clip nhạc: ffmpeg (`D:/ffmpeg-8.1-essentials_build/bin/ffmpeg.exe`) cắt từ `clip_start − 0,5 s` tới cuối đoạn
  `+ 1 s`, fade vào/ra, **mp3** stereo ~96 kbps (mp3 giải mã được trên mọi WebView; ogg không chắc trên iOS cũ).
  Khoảng 25 s ≈ 300 KB.

Đề xuất đoạn đầu tiên: `pulse_drive_led` từ beat 64, 20 giây. Đây là đoạn đã dùng cho clip quảng cáo
(`record_clip.sh pulse_drive_led 64 20`), nên video và playable trông giống nhau. Chốt ở GD3-310.

## 7. Hình ảnh (Three.js)
Giữ nhận diện của game với chi phí thấp. Màu dành riêng vẫn như trong game: hồng = gai/nhảy, cam = tường/lách làn,
lime = cổng/lộn, nền chỉ tông lạnh.
- **Đường ray:** một dải mesh dựng từ `path` (chia chunk để culling), `ShaderMaterial` nhỏ chép ý tưởng `neon_track`
  (lưới, viền ray, sóng năng lượng mỗi beat theo uniform `run_beat`). LED mặt hông nếu còn dư ngân sách.
- **Người chơi:** khối lập phương viền sáng, lăn khi trên không như `PlayerView`. Có tàu lượn nếu đoạn có bay.
- **Vật cản:** `InstancedMesh` theo loại (gai = chóp 4 cạnh, tường = hộp, cổng = vòng). Kiểu vào sân RISE/DROP làm trong
  vertex shader theo `appear_beat`, giống trong game.
- **Vòng cue:** billboard có vòng ngoài co lại, khép đúng vạch tại beat của cue (như GD3-101).
- **Trời:** quad gradient + sao theo palette, sáng nhẹ theo nhịp.
- **Glow:** mặc định không dùng hậu kỳ. Glow giả bằng viền emissive + sprite halo additive. Bloom nửa độ phân giải chỉ
  bật khi đo 60 frame đầu thấy máy dư sức (tự chọn chất lượng, tương tự `QualityAutoTuner`).
- **Camera:** bám frame đường như shot `side` khi ngang; màn dọc dùng góc từ sau/trên như biến thể dọc của `CameraShots`.
  Làm mượt phần xoay của frame.
- **Hiệu năng:** `pixelRatio = min(devicePixelRatio, 2)` (máy yếu 1,5), không đổ bóng, mục tiêu < 30 draw call, 60 FPS
  trên máy tầm thấp (đo trên máy Mali-G72 đang dùng để đo game).

## 8. Âm thanh
- Lúc tải: base64 → `ArrayBuffer` → `decodeAudioData`, xong mới hiện "Chạm để chơi".
- Lần chạm đầu gọi `ctx.resume()` ngay trong handler (iOS bắt buộc phải nằm trong cử chỉ người dùng), rồi phát bằng
  `source.start(when, offset)`. Đây cũng là lúc lượt chơi bắt đầu.
- Có nút bật/tắt tiếng ở góc. Khi tắt tiếng (hoặc iPhone gạt im lặng, Web Audio không ra tiếng), màn chơi vẫn phải đọc
  được nhịp bằng hình: vòng cue khép, đường sáng theo phách, trời đập nhịp.
- Bản đầu không có SFX. Tiếng nhạc là đủ, lại tiết kiệm dung lượng.

## 9. Luồng quảng cáo
1. **Mở:** cảnh đường ray đã chạy sẵn kiểu attract (người chơi tự chạy theo autoplay, nhạc chưa phát), chữ
   "Chạm để chơi".
2. **Chạm đầu:** nhạc bắt đầu, lượt chơi bắt đầu từ đầu đoạn. 1–2 giây sau là cue đầu tiên.
3. **Hướng dẫn:** đóng băng ở cue đầu và cue đầu của mỗi loại hành động mới (mục 5).
4. **Chơi:** HUD gọn gồm chữ PERFECT/GREAT, combo, biểu tượng lá chắn. Không có điểm số dài dòng.
5. **Chết:** vỡ vụn, "THỬ LẠI" ~1 giây rồi chơi lại. Chết lần 2 thì sang màn kết.
6. **Màn kết** (hết đoạn hoặc chết 2 lần): tên game **BeatGlide — Ride the Rhythm**, kết quả ngắn ("PERFECT ×12"),
   nút **CÀI ĐẶT / INSTALL** lớn gọi adapter, nút chơi lại nhỏ. Tổng thời gian ≤ 30 giây.
7. Chữ vi/en chọn theo `navigator.language`, dùng cùng cách viết với `assets/i18n/vi.json`.

## 10. Adapter mạng và build
- Mỗi mạng một file trong `src/networks/` cùng một giao diện: `ready(callback)`, `openStore()`, `onPause/onResume`,
  `gameEnd()`. Adapter MRAID dùng chung cho AppLovin / Unity / ironSource.
- `node build.mjs --network=<tên>|all`: bundle bằng esbuild (minify, tree-shake, `define` tên mạng), nhúng vào template
  HTML, đóng zip cho mạng cần zip, **in kích thước và báo lỗi nếu vượt ngân sách**.
- URL store Android: `https://play.google.com/store/apps/details?id=com.sntgames.beatglide` (package trong
  `export_presets.cfg`). iOS làm khi có GD3-262.
- Mỗi mạng có công cụ xem thử playable riêng. Chạy qua công cụ của mạng đó trước khi nộp.

## 11. Kiểm tra
- `npm test`: `run.ts` phải khớp `golden.json` (bậc từng cue, beat chết, lá chắn), `segment.ts` nội suy đúng.
- Tool bake có test GDScript (`tests/authoring/test_segment_baker.gd`): đoạn ngắn, đếm cue, hậu quả lỡ cue khớp với
  chạy `Autoplay(missed_beats)` trực tiếp.
- Trình duyệt trong app ở khung 375×812 và ngang: chụp ảnh lúc mở, đóng băng hướng dẫn, chết, vỡ lá chắn, màn kết.
  Console không lỗi, tab network **không có request nào**.
- Điện thoại thật: mở file HTML trên Android (Chrome + một app WebView thử), đo FPS và chạm theo nhạc để kiểm tra độ trễ.
- Báo cáo kích thước từng bản theo mạng.

## 12. Rủi ro và việc người dùng quyết
- **Giấy phép nhạc (GD3-200):** mọi bài đang "chưa xác nhận dùng thương mại", mà quảng cáo là dùng thương mại. **Không
  nộp lên mạng nào khi chưa xong.** Làm prototype thì không bị chặn.
- **Thư viện ngoài:** `three`, `esbuild`, `typescript` (chỉ trong `playable/`, không đụng game Godot) cần được duyệt.
- **Chọn mạng đầu tiên:** đề xuất AppLovin + Unity (chung MRAID, một bản dùng cho cả hai), sau đó Google, Meta.
- **Chính sách quảng cáo:** playable phải giống game thật. Đoạn bake từ chart thật nên đạt, nhưng màn kết không được
  hứa tính năng chưa có.
- **Độ trễ âm thanh trên WebView** khác nhau nhiều giữa các máy. Cửa sổ rộng hơn (`ad_window_scale`) che được phần lớn;
  đo trên máy thật trước khi chốt.
