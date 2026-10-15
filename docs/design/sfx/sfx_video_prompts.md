# Âm thanh hiệu ứng (SFX): bộ trống và prompt tạo video để tách âm

Phong cách (GD3-255, 2026-10-15): **một bộ trống thống nhất**: trống phòng thu gọn, khô, đánh mạnh, hợp nhạc
synthwave/EDM. Các cú lớn dùng trống taiko để bắc cầu sang các bài tribal. Âm arcade tương lai của bộ prompt cũ
không hợp game nên đã bỏ.

Quy trình: **prompt → Google Flow (text-to-video, có âm thanh) → tải video → đặt tên theo ID →
`tools/audio/build_sfx.py` tự tách âm, cắt, chuẩn hóa, ghi vào game.** Trong lúc chờ, game dùng bộ trống tạm tổng hợp
bằng code (`tools/audio/synth_placeholder_sfx.py`, cùng vai trò như bảng dưới, `status: placeholder` trong catalog).
Âm thật tự thay thế khi build.

## 0. Quy tắc chung (đọc trước)

**Vì sao cho thấy cảnh đánh trống:** model video tạo âm khớp với hành động nhìn thấy. Cảnh cận một cú dùi đập vào
đúng chiếc trống cho ra tiếng trống sạch, đúng lúc chạm. Cảnh khối nhảy trong game (cách cũ) kéo âm về tiếng "vút"
khó đoán. Vì vậy **dùng text-to-video, không cần ảnh đầu vào**; ảnh trong `inputs/` là của bộ prompt cũ.

**Thiết lập video:** 8 giây, 16:9. Bộ đang dùng (2026-10-15) tạo bằng **Omni 1.1 Flash, 360p, x2** (12 credit mỗi
prompt): độ phân giải không ảnh hưởng âm thanh. Script gom biến thể từ mọi take (tối đa 4 cú đánh to và sạch nhất
mỗi ID). Âm có cú mạnh nằm giữa clip (vd. roll rồi rimshot) thì cắt bằng `art_source/sfx/cuts.json` để cú mạnh ở đầu,
vì âm phát đúng beat.

**Mẹo lấy âm sạch:**
- Mỗi clip chỉ **một loại âm**, đánh **từng cú riêng lẻ** 3–4 lần, nghỉ 1,5–2 giây giữa các cú (không thành điệu trống).
- Luôn có "no music, no melody, no speech". Model rất hay tự chèn nhạc nền hoặc đánh thành nhịp.
- Âm **khô, ngắn, không vang phòng**: tiếng chạm phát ngay khi chạm màn hình nên phải tắt nhanh, tiếng vang làm
  rối nhịp nhạc.
- Take có tiếng nhạc, giọng nói, vang dài hoặc dùi đánh thành chuỗi: bỏ, tạo lại.

**Đuôi gắn vào mọi prompt** (các prompt bên dưới đã ghép sẵn, chỉ cần copy cả khối):
`Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.`

**Negative prompt** (nếu công cụ hỗ trợ):
`music, drum beat, groove, rhythm pattern, melody, bass line, singing, speech, dialogue, crowd, reverb, echo, room ambience, camera shake, scene cut, text, subtitles, watermark, distorted audio`

**Đặt tên file tải về:** `art_source/sfx/<ID>_take<N>.mp4`, ví dụ `art_source/sfx/player.jump_take1.mp4`
(`art_source/` không commit). Sau đó chạy:
```bash
python tools/audio/build_sfx.py
```
Script in ra ID đã xử lý, ID còn là âm tạm, và tạo trang nghe thử `tools/audio/out/sfx_review.html`. Một cú đánh dính
tạp âm: cắt tay bằng `art_source/sfx/cuts.json` (xem đầu file `build_sfx.py`).

**Mức to** (tự chuẩn hóa, `tools/audio/sfx_spec.py`): nhạc của game đỉnh khoảng −15…−11 LUFS. Tiếng chạm −18,
chạm đất −21 (nằm dưới tiếng kick của nhạc), chấm điểm −23, vật cản −22, chết/vỡ lá chắn −15. Game phát tiếng chạm
đất **sớm đúng bằng độ trễ âm thanh** (độ trễ máy + hiệu chỉnh) nên nghe trùng beat tiếp đất. Tiếng chạm thì phát
ngay lúc chạm.

**License:** chỉ dùng gói Flow có quyền thương mại. Ghi lại gói và ngày tạo; script lưu sha256 nguồn vào
`assets/audio/sfx_manifest.json`.

## 1. Bảng tổng hợp

| # | ID (tên file) | Ưu tiên | Trống | Dùng khi |
|---|---|---|---|---|
| A1 | `player.jump` | P1 | snare rimshot | chạm để nhảy (cả vòng nhảy, bệ bật) |
| A2 | `player.land` | P1 | kick | tiếp đất |
| A3 | `player.death` | P1 | taiko + crash | va chạm chết |
| A4 | `judge.perfect` | P1 | clave | chạm PERFECT |
| A5 | `run.checkpoint` | P1 | snare flam + crash nhẹ | qua checkpoint (luyện tập) |
| A6 | `run.complete` | P1 | fill tom + kick + crash | hoàn thành màn |
| A7 | `ui.tap` | P1 | gõ hai dùi | bấm nút |
| A8 | `ui.confirm` | P1 | 2 tom thấp → cao | bấm PLAY / START |
| B1 | `ui.back` | P2 | 2 tom cao → thấp | quay lại / đóng |
| B2 | `fx.shockwave` | P2 | trống lớn (taiko) | sóng xung kích lúc đổi phase |
| B3 | `fx.flash` | P2 | cymbal swell + chặn | lóe sáng đổi đoạn |
| B4 | `player.dodge` | P2 | vỗ tay (clap) | lách làn (cả vòng lao xuống) |
| B5 | `player.flip` | P2 | 2 tom nhanh | lộn, lộn tròn, chạy mặt dưới |
| B6 | `hazard.rise` | P2 | hi-hat đóng | gai/cưa/mìn trồi lên |
| B7 | `hazard.drop` | P2 | floor tom | vật cản rơi xuống |
| B8 | `hazard.unfold` | P2 | snare roll ngắn | cổng bung ra |
| C1 | `judge.great` | P3 | mõ gỗ (woodblock) | chạm GREAT |
| C2 | `run.attempt` | P3 | 2 tiếng gõ dùi | bắt đầu lượt chơi |
| C3 | `ui.pause` | P3 | hi-hat mở rồi đóng | tạm dừng |
| D1 | `player.shield` | P2 | chuông ride cymbal | combo nạp đầy một lá chắn |
| D2 | `player.shield_break` | P2 | crash + snare, chặn cymbal | lá chắn đỡ một cú va chạm |

---

## A. Bộ cốt lõi (P1)

### A1 · `player.jump` · P1
```
Close-up of a drumstick striking the rim and the head of a snare drum at the same moment (a rimshot), one single hit at a time, four hits in total with about two seconds of stillness between hits. Sound of each hit: a crisp, tight, dry snare rimshot crack, very short. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### A2 · `player.land` · P1
```
Close-up of a bass drum pedal: the felt beater hits the kick drum head, one single hit at a time, four hits in total with about two seconds of stillness between hits. Sound of each hit: a deep, tight, punchy kick drum thump, short and dry, no boom tail. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### A3 · `player.death` · P1
```
A drummer strikes a large taiko drum hard with a thick wooden stick while hitting a crash cymbal at the same moment, three times in total with about three seconds of stillness between hits. Sound of each hit: a massive deep drum boom together with a bright crash cymbal splash, fading out within about one second. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### A4 · `judge.perfect` · P1
```
Close-up of two wooden claves clicked together, one single click at a time, four clicks in total with about two seconds of stillness between clicks. Sound of each click: a bright, high, dry wooden clave click, very short. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### A5 · `run.checkpoint` · P1
```
A drummer plays a quick snare drum flam followed immediately by a light crash cymbal hit, three times in total with about three seconds of stillness in between. Sound of each: a short snare flam into a soft crash cymbal that fades quickly. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### A6 · `run.complete` · P1
```
A drummer plays one short energetic drum fill down the toms, four quick hits from the high tom to the floor tom, and ends on a big kick drum and crash cymbal hit together, then stops completely and holds still while the cymbal rings out. This happens only once. Sound: a two-second triumphant drum fill ending on a big crash cymbal that rings and fades, then silence. Static locked-off camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drums shown, close-miked studio recording, punchy, no music, no melody, no speech, no voice, no ambience, silence after the cymbal fades.
```

### A7 · `ui.tap` · P1
```
Close-up of two drumsticks tapped together lightly, one single tap at a time, four taps in total with about two seconds of stillness between taps. Sound of each tap: a soft, light, dry wooden stick click, subtle. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### A8 · `ui.confirm` · P1
```
A drummer hits a low tom and then a high tom in quick succession ("ba-dum", low then high), four times in total with about two seconds of stillness in between. Sound of each: two quick bright tom hits rising in pitch, short and confident. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

## B. Bổ sung (P2)

### B1 · `ui.back` · P2
```
A drummer softly hits a high tom and then a low tom in quick succession (high then low), four times in total with about two seconds of stillness in between. Sound of each: two quick soft tom hits falling in pitch, short. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### B2 · `fx.shockwave` · P2
```
A drummer strikes a huge taiko drum once with both heavy sticks, three times in total with about three seconds of stillness between hits. Sound of each hit: a deep, powerful, booming drum hit with a short low rumble that fades within about one second. Static locked-off camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked studio recording, punchy, short natural decay, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### B3 · `fx.flash` · P2
```
A percussionist rolls soft mallets on a suspended cymbal, the sound swelling louder for about one second, then grabs the cymbal with one hand to stop it dead; this happens three times with about two seconds of stillness in between. Sound of each: a rising shimmering cymbal swell that cuts off abruptly. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the cymbal shown, close-miked dry studio recording, no music, no melody, no speech, no voice, no ambience, clean silence in between.
```

### B4 · `player.dodge` · P2
```
Close-up of two hands clapping once sharply, one single clap at a time, four claps in total with about two seconds of stillness between claps. Sound of each clap: a tight, crisp, dry hand clap, like a drum machine clap, very short. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the claps shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between claps.
```

### B5 · `player.flip` · P2
```
A drumstick hits a high tom and then a mid tom very quickly (two fast hits), four times in total with about two seconds of stillness in between. Sound of each: two fast punchy tom hits, high then lower, short and dry. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### B6 · `hazard.rise` · P2
```
Close-up of a closed hi-hat cymbal tapped once with the tip of a drumstick, one single tap at a time, four taps in total with about two seconds of stillness between taps. Sound of each tap: a short, tight closed hi-hat tick. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### B7 · `hazard.drop` · P2
```
Close-up of a floor tom struck hard once with a drumstick, one single hit at a time, four hits in total with about two seconds of stillness between hits. Sound of each hit: a deep, heavy floor tom thud, short. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### B8 · `hazard.unfold` · P2
```
A drummer plays a short snare drum buzz roll that swells for half a second and ends with one sharp rimshot, three times in total with about two seconds of stillness in between. Sound of each: a quick rising snare roll ending in a crisp crack. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

## C. Trau chuốt (P3)

### C1 · `judge.great` · P3
```
Close-up of a wooden woodblock struck once with a drumstick, one single hit at a time, four hits in total with about two seconds of stillness between hits. Sound of each hit: a soft, hollow woodblock knock, short. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### C2 · `run.attempt` · P3
```
A drummer clicks two drumsticks together twice, like a quick count-in ("click-click"), three times in total with about three seconds of stillness in between. Sound of each: two quick light wooden stick clicks. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### C3 · `ui.pause` · P3
```
Close-up of an open hi-hat struck once and immediately closed with the foot pedal, four times in total with about two seconds of stillness in between. Sound of each: a short open hi-hat "tsss" cut off quickly. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

## D. Lá chắn (P2)

### D1 · `player.shield` · P2
```
Close-up of the bell of a ride cymbal struck with the shoulder of a drumstick, one single hit at a time, four hits in total with about two seconds of stillness between hits. Sound of each hit: a clear, bright ride cymbal bell ping with a short ring. Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```

### D2 · `player.shield_break` · P2
```
A drummer hits a crash cymbal hard together with the snare drum, then immediately grabs the cymbal with one hand to choke it, three times in total with about two seconds of stillness in between. Sound of each: a loud crash cymbal and snare hit that is cut off abruptly (cymbal choke). Static locked-off close-up camera, no cuts, no text, dark studio lit by cyan and magenta neon. Audio: only the drum hits shown, close-miked dry studio recording, tight and punchy, short natural decay, no reverb, no music, no melody, no speech, no voice, no ambience, clean silence between hits.
```
