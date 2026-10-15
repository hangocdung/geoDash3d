# Prompt tạo nhạc cho BeatGlide (GD3-107, 2026-10-15)

## 1. Vì sao cần prompt riêng cho game
Cảm giác "chạm là trống nổ" chỉ có khi **mỗi lần chạm trùng một cú đánh to hơn hẳn mọi thứ xung quanh** (memory
`tap-on-standout-hits`). Đo bằng `tools/charting/hit_grid.py` (tỉ lệ ô nhịp có ít nhất một cú đánh đáng chạm "X"):

| Bài | Ô nhịp có "X" | Kết quả |
|---|---|---|
| the_dawn_assembly (bài chuẩn) | 79 % | giữ |
| pulse_drive | 63 % | giữ |
| fault_line | 60 % | giữ |
| neon_arcade_dash | 28 % | bỏ |
| tribal_battle_awakening | 14 % | bỏ |
| cyber_rush | 7 % | bỏ |

`tap_salience.py` trên chart đã đặt cũng cho cùng kết quả (bài giữ: nổi ×1.8–2.0, attack ×3.2–6.2; bài bỏ: ×0.9–1.3,
×1.6–2.9). Bài bỏ được sao lưu ở `art_source/removed_songs/` (không commit) và vẫn còn trong lịch sử git.

**Bài tribal chính là phong cách prompt bạn thích** (cinematic tribal 150 BPM). Nó hỏng ở hai câu trong prompt gốc:
*"rolling percussion and urgent string ostinatos"* và *"energetic drum patterns"* — trống lăn liên tục + string chạy
nốt móc kép lấp kín mọi khoảng trống, nên không cú đánh nào nổi lên. Prompt dưới đây giữ nguyên chất nhạc nhưng đổi
cách viết nhịp: **cú đánh lớn, rời rạc, có khoảng lặng giữa các cú**.

## 2. Yêu cầu kỹ thuật chung (đã viết sẵn vào mỗi prompt)
- **Tempo cố định tuyệt đối**, 4/4, không rubato/ritardando/fermata, không intro tự do, bắt đầu ngay bằng một cú đánh
  lớn ở phách 1 (không fade-in). Lý do: chart viết theo beat với một BPM duy nhất (`TempoMap`).
- **Cú đánh rời rạc**: trống/brass/dây đánh cùng nhau thành từng "stab" ngắn, giữa các cú gần như im lặng. Không trống
  lăn liên tục, không hi-hat/shaker chạy nốt móc kép, ostinato (nếu có) nhỏ và nằm sau.
- **Motif nhịp lặp lại** kiểu bài chuẩn: cú đánh ở **phách 1, "và" của phách 2, phách 3**. Người chơi học được motif, màn
  chơi đọc được.
- **Cấu trúc theo khối 8/16 ô nhịp**, mỗi đoạn kết thúc bằng **một ô nhịp gần như lặng** rồi đoạn sau mở bằng một cú
  đánh hợp xướng toàn dàn: đúng chỗ game đổi phase (đổi màu trời, tăng tốc).
- **Mỗi đoạn dày hơn đoạn trước** bằng cách *thêm cú đánh* (không phải thêm lớp âm thanh): đoạn cuối nhiều cú nhất.
- Mix có dải động, không nén quá tay, bộ gõ đứng trước mix.
- Dài khoảng 2:30–3:00.

## 3. Prompt 1 — phong cách của bạn, đã chỉnh cho game ("Ascension of the Mountain Clans", 150 BPM)
```
Compose an original epic indigenous-inspired cinematic orchestral battle soundtrack, written as a rhythm-game level:
every important moment is a big, isolated hit that clearly stands out from the music around it.

Musical style: a powerful fusion of traditional mountain-tribal textures and grand symphonic film scoring. Raw,
primal, heroic, adventurous, uplifting and deeply connected to nature.

Instrumentation: deep resonant war drums, a few sharp hand-percussion accents, rhythmic wooden clicks, traditional
jaw harp with its twanging resonance, sparse breathy nose-flute passages, short staccato violin and cello stabs,
powerful French horns, dramatic low brass, and layered wordless warrior calls used as accents on the big hits.

Tempo and meter: exactly 150 BPM, constant from the very first beat to the last, 4/4 time. No tempo changes, no
rubato, no ritardando, no fermatas, no free-time introduction. The song starts directly on beat 1 with a big war-drum
hit, with no pickup and no fade-in.

Rhythm: the drums, low brass and string stabs strike together as short, punchy hits with clear silence between them.
The core signature, repeated in almost every bar, is a hit on beat 1, on the "and" of beat 2, and on beat 3. Every hit
must be clearly louder than everything around it. No continuous drum rolls, no running shakers or sixteenth-note
percussion, no constant string ostinato; any background ostinato stays soft and far behind the hits.

Structure (bars of 4 beats):
- Bars 1-8: lone war-drum hits on beats 1 and 3, distant warrior calls between them, otherwise near silence.
- Bars 9-24: the jaw harp states a mysterious modal motif; the drums play the signature hits (1, 2-and, 3).
- Bars 25-32: strings and horns join each hit; the hits come on every beat. Bar 32 is silent except three strong hits
  on beats 2, 3 and 4.
- Bars 33-48: full battle theme; brass stabs land on the signature hits, plus an extra hit on the "and" of beat 4.
- Bar 48 is almost silent, then bar 49 opens with a huge unison hit.
- Bars 49-56: break: drums stop, nose flute melody over soft sustained strings, one deep drum hit on beat 1 every
  second bar.
- Bars 57-60: the drums return one distinct hit per beat, each louder than the last; bar 60 ends in silence.
- Bars 61-76: climax: sweeping horns and wordless choir; the hits double (beats 1, 1-and, 2-and, 3, 4), still
  distinct with space between them.
- Bars 77-92: final and most intense passage: call and response, drums hit on beats 1 and 3, brass answers on the
  "and" of beat 2 and on beat 4.
- Bars 93-96: four enormous unison hits on beat 1 of each bar, then a final hit that rings out.

Melody: a memorable, completely original heroic melody from short modal and pentatonic phrases, strong ascending
gestures and bold orchestral answers. Ancient, noble, untamed and adventurous rather than modern or sentimental. The
melody always sits underneath the rhythm hits and never masks them.

Production: rich acoustic orchestral sound, organic percussion with sharp, punchy transients, natural voices,
cinematic dynamics, wide stereo image, a dynamic mix that is not over-compressed, percussion clearly in front.

Completely original composition, original melodic themes and harmonic progressions. No quotation or reproduction of
any existing soundtrack. Avoid EDM, electronic dance beats, modern pop drums, rock guitars, excessive synthesizers,
generic trailer impacts, continuous drum rolls, dense wall-of-sound mixing and overly dark horror atmospheres.
```
Phase của game dự kiến (beat = (ô nhịp − 1) × 4): 0, 128 (ô 33), 192 (ô 49), 240 (ô 61), 304 (ô 77).

## 4. Prompt 2 — điện tử neon hợp với hình ảnh game ("Neon Overdrive", 128 BPM)
```
Compose an original high-energy synthwave and electro-orchestral track for a rhythm game, built from big, isolated
hits that clearly stand out: every important moment is a punchy stab, with space between stabs.

Style: retro-futuristic synthwave meets cinematic electronic, neon night drive, bold, euphoric, heroic.

Instrumentation: huge gated snare, deep punchy kick hits, analog brass-like synth stabs, a bright arpeggiated lead
that stays soft, warm pad underneath, orchestral hits and taiko accents layered on the biggest stabs.

Tempo and meter: exactly 128 BPM, constant for the whole track, 4/4. No tempo changes, no fade-in; the track starts on
beat 1 with a full stab.

Rhythm: no constant four-on-the-floor kick and no running sixteenth-note hi-hats. The drums and synth stabs play an
accent pattern: hits on beat 1, the "and" of beat 2 and beat 3, with near silence between hits. Each hit must be
clearly louder than everything around it. Sidechain pumping is subtle or absent.

Structure: 8-bar intro of lone stabs on beats 1 and 3; 16-bar theme with the accent pattern; 8-bar build where a stab
lands on every beat, ending with one silent bar broken only by three stabs on beats 2, 3 and 4; 16-bar drop with the
accent pattern doubled; an almost silent bar; 8-bar breakdown with pads and one stab every second bar; 16-bar final
drop, the most intense, call and response between drums (beats 1 and 3) and synth stabs (2-and and 4); four huge
final stabs on beat 1 of the last four bars.

Production: punchy transients, dynamic mix, not over-compressed, drums and stabs in front, clean low end.

Completely original melody and harmony, no samples or quotes of existing songs. Avoid vocals with lyrics, dubstep
wobble, continuous risers and dense wall-of-sound mixing.
```

## 5. Prompt 3 — taiko và hợp xướng, nhịp vừa cho màn mở đầu ("Iron Monastery", 120 BPM)
```
Compose an original cinematic taiko and choir piece for a rhythm game, in the spirit of a grand temple ceremony that
turns into a battle. Every important moment is one big, isolated drum hit with silence around it.

Instrumentation: massive taiko drums, odaiko, wood blocks, temple bells, shakuhachi, low male choir, deep brass,
sparse string stabs.

Tempo and meter: exactly 120 BPM, constant from start to end, 4/4, no rubato, no free intro, no fade-in. Start on beat
1 with a single huge taiko hit.

Rhythm: hits on beat 1, the "and" of beat 2 and beat 3 of most bars, played by taiko with brass and choir accents on
the biggest ones; near silence between hits; no continuous drum rolls and no running percussion.

Structure: 8 bars of lone hits on beat 1; 16 bars of the signature pattern with shakuhachi melody; 8-bar build with a
hit on every beat ending in a silent bar broken by three hits on beats 2, 3 and 4; 16-bar battle section with brass and
choir on every hit; one almost silent bar; 8-bar ceremony break with bells and one hit every second bar; 16-bar final
section with the most hits (beats 1, 1-and, 2-and, 3, 4), still distinct; four final unison hits.

Production: huge but clear acoustic drums with sharp transients, natural hall reverb that decays quickly between hits,
dynamic mix, not over-compressed.

Completely original composition. Avoid electronic beats, rock drums, trailer braams and long reverb tails that blur
the hits.
```

## 6. Khi có nhạc: dựng level chính xác
1. Lưu `assets/music/<id>.mp3`. Phân tích:
   `"D:/Programs/Blender/blender.exe" -b --factory-startup -P tools/audio/analyze_song.py -- assets/music/<id>.mp3 assets/music/<id>.analysis.json`
   (BPM nhạc 150 có thể bị báo nhầm 100: kiểm tra với BPM trong prompt).
2. Kiểm tra bài: `python tools/charting/hit_grid.py assets/music/<id>.mp3 <bpm> <offset>`. Cột đầu tiên của các ô
   nhịp có nhạc phải là "X" (đúng phách 1), và dòng cuối **≥ 50 %** ô nhịp có "X". Thấp hơn thì tạo lại nhạc.
3. Viết `tools/charting/levels/<id>.py` (mẫu: `pulse_drive.py`): `phases` đặt ở các ô nhịp mở đoạn (bảng ở mục 3),
   `STEPS` chỉ đặt lần chạm trên ô "X" (vòng nhảy / lần chạm thứ hai của chuỗi có thể ở "x").
4. `python tools/charting/levels/<id>.py`, rồi `python tools/charting/tap_salience.py assets/music/<id>.chart.json`
   phải ra **OK**, `tolerance_report.gd` ≥ ±90 ms, test pass, chụp ảnh.

Hoặc chỉ cần đưa file mp3 và tên bài: các bước trên do agent làm.

## 7. Kết quả 6 bài đầu tiên tạo từ các prompt này (2026-10-15)
Neon Rhythm Stabs (+ Alt), Temple Battle Taiko (+ Alt), Tribal Battle Rhythm (+ Alt), hdgstudio86. Level dựng bằng
`hit_level.py` (độ khó 1–5: Temple Alt 1, Temple 2, Neon 3, Neon Alt 3, Tribal 4, Tribal Alt 5).

| | Ô nhịp có cú đánh nổi bật (đo theo thời điểm thật) | Lần chạm: nổi so với xung quanh / attack |
|---|---|---|
| the_dawn_assembly (chuẩn) | 84 % | ×1.95 / ×6.2 |
| pulse_drive / fault_line | 51 % / 40 % | ×2.0 / ×3.2, ×1.8 / ×4.4 |
| 6 bài mới | 4–20 % | ×1.5–1.9 / ×2.0–2.4 |

Các bài mới **nổi so với xung quanh gần bằng bài chuẩn nhưng attack yếu** (cú đánh không bùng lên từ khoảng lặng):
nhạc tạo ra vẫn có lớp nền liên tục (pad, drone, ostinato, reverb dài). Level vẫn chơi được (mọi lần chạm là cú
đánh nổi nhất quanh đó), nhưng cảm giác "chạm là trống nổ" sẽ kém Dawn. Ngoài ra AI không giữ BPM của prompt (Neon
130 thay vì 128, Temple 130 thay vì 120) và cú đánh không khít lưới, nên level đặt chạm theo thời điểm thật.
Lần tạo nhạc sau nên thêm vào prompt:
- "Before every main hit there is at least half a beat of near silence; no sustained pads, drones or held chords
  under the hits."
- "Dry, close mix with short reverb that dies away before the next hit; staccato articulation only."
- "Exactly N BPM, every hit precisely on the beat grid (quantized), no swing, no humanization."
