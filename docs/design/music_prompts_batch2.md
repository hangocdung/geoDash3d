# Prompt nhạc đợt 2: 14 bài nhiều phong cách (2026-10-16, người dùng đã duyệt)

Mỗi prompt = **phần riêng của bài** (mục 2) + **khối kỹ thuật chung** (mục 1) dán liền phía sau. Khối chung gom các
yêu cầu đã rút ra từ đợt 1 (`music_prompts.md` mục 2 và 7): cú đánh rời rạc nổi bật, BPM cố định khít lưới, khoảng lặng
trước mỗi cú, mix khô, cấu trúc khối 8/16 ô nhịp để game đổi phase. Mỗi bài tạo 2–3 bản, giữ bản qua `hit_grid.py`
(≥ 50 % ô nhịp có "X"); không bản nào qua thì sửa prompt và tạo lại.

## 1. Khối kỹ thuật chung (thay `{BPM}` bằng BPM của bài)
```
Written as a rhythm-game level: every important moment is a big, isolated hit that clearly stands out from the
music around it.
Tempo and meter: exactly {BPM} BPM, constant from the first beat to the last, 4/4. Every hit precisely on the beat
grid (quantized), no swing, no humanization, no tempo changes, no rubato, no fermatas, no free-time intro. The
track starts directly on beat 1 with a big hit, no pickup, no fade-in.
Rhythm: the core signature, repeated in almost every bar, is a hit on beat 1, on the "and" of beat 2 and on beat 3.
Before every main hit there is at least half a beat of near silence. No continuous drum rolls, no running
sixteenth-note hi-hats or shakers, no constant four-on-the-floor kick, no sustained pads, drones or held chords under
the hits. Staccato articulation.
Structure: 8-bar intro of lone hits on beats 1 and 3; 16-bar theme with the signature; 8-bar build with a hit on
every beat, ending with a silent bar broken only by three hits on beats 2, 3 and 4; 16-bar main section with the
signature plus a hit on the "and" of beat 4; one almost silent bar; 8-bar break with one hit every second bar; 16-bar
final section, the most hits (beats 1, 1-and, 2-and, 3, 4), still distinct; four huge final hits on beat 1 of the
last four bars. Each section adds hits, not layers. Length about 2:30 to 3:00.
Production: dry, close mix, short reverb that dies away before the next hit, sharp punchy transients, dynamic mix,
not over-compressed, percussion and stabs in front.
Completely original composition, no quotes or samples of existing songs, no vocals with lyrics.
```

## 2. Phần riêng từng bài
| # | id (dự kiến) | Phong cách | BPM |
|---|---|---|---|
| 1 | `neon_highway` | Synthwave lái xe đêm | 118 |
| 2 | `bass_reactor` | Drum & bass (stab nửa nhịp) | 172 → chart 86 |
| 3 | `pixel_rush` | Chiptune 8-bit arcade | 140 |
| 4 | `festival_stabs` | Big-room EDM | 128 |
| 5 | `808_district` | Trap / hip-hop 808 | 140 |
| 6 | `brass_funk` | Funk kèn đồng | 112 |
| 7 | `carnival_drums` | Samba / batucada | 125 |
| 8 | `riddim_drop` | Dubstep riddim | 150 |
| 9 | `titan_march` | Orchestral hùng ca | 120 |
| 10 | `power_chord_run` | Rock / metal | 160 |
| 11 | `idol_pulse` | K-pop / J-pop dance | 124 |
| 12 | `drift_phonk` | Phonk drift | 135 |
| 13 | `savanna_drums` | Afrobeat / trống châu Phi | 110 |
| 14 | `steel_factory` | Industrial techno | 132 |

**1. Neon Highway (118)**
```
Compose an original retro synthwave track, a neon night drive along an empty coastal highway: nostalgic, confident,
cinematic. Instrumentation: huge gated-reverb snare, deep punchy kick hits, bright analog brass-like synth stabs, a
soft arpeggio far in the background, a short plucked bass on the hits, a singing lead synth melody between hits.
```
**2. Bass Reactor (172, half-time feel)**
```
Compose an original liquid-to-neuro drum and bass track in half-time feel: futuristic, high-energy, sleek. The
drums play big half-time hits (kick and huge snare) instead of fast breakbeats. Instrumentation: punchy kick, cracking
snare, short growling reese bass stabs that land with the drums, glassy synth chords as short stabs, a sparse
atmospheric melody between hits. No fast amen breaks, no rolling hi-hats.
```
**3. Pixel Rush (140)**
```
Compose an original chiptune 8-bit arcade track, like the final level of a retro platformer: playful, heroic,
fast. Instrumentation: square-wave lead melody, triangle-wave bass hits, noise-channel snare hits, short pulse-wave
chord stabs, occasional arpeggio flourishes only between hits. Clean, bright, NES-style sound palette.
```
**4. Festival Stabs (128)**
```
Compose an original big-room festival EDM track: euphoric, massive, main-stage energy. Instrumentation: huge
detuned supersaw chord stabs, massive punchy kick hits, clap and snare on the hits, short pitched-down vocal chops
without words, a catchy lead melody in the build. Drops are built from separated stabs with silence between them,
not a continuous four-on-the-floor kick.
```
**5. 808 District (140)**
```
Compose an original hard trap instrumental: dark, confident, street-night energy. Instrumentation: booming 808 bass
hits that land with the kick, a cracking snare on the hits, short orchestral stabs and bells, a dark plucked melody
between hits. Hi-hats are sparse and quiet, never running triplets or rolls.
```
**6. Brass Funk (112)**
```
Compose an original funk instrumental with a big brass section: groovy, joyful, tight like a live funk band.
Instrumentation: tight punchy kick and snare, trumpet, trombone and saxophone section playing short stabs together
with the drums, slap bass hits on the stabs, short clavinet chops, a short brass melody line between hits.
```
**7. Carnival Drums (125)**
```
Compose an original samba and batucada carnival track: festive, sunny, explosive. Instrumentation: surdo bass drums,
repinique and snare drum hits played as big unison accents, agogo bells and whistles as accents only, short brass
stabs, a cavaquinho melody between hits. The whole bateria hits together on the accents, with near silence between
them, no constant shaker or tamborim groove.
```
**8. Riddim Drop (150)**
```
Compose an original riddim dubstep track: heavy, aggressive, bouncy, with half-time drops. Instrumentation: huge
sub-bass and square-wave riddim bass stabs that hit with the kick and snare, cracking snare, short metallic growls,
a short eerie melody in the intro and break. Every bass stab is short and separated by silence, no wobble held
across the bar, no continuous risers.
```
**9. Titan March (120)**
```
Compose an original epic orchestral march: heroic, triumphant, grand, like titans marching to battle.
Instrumentation: massive orchestral bass drums and timpani hits, full brass section (horns, trumpets, trombones,
tuba) playing short stabs together with the drums, staccato string hits, a wordless choir on the biggest hits, a
noble horn melody between hits. No trailer braams, no long reverb tails.
```
**10. Power Chord Run (160)**
```
Compose an original instrumental rock and metal track: fast, driving, adrenaline. Instrumentation: palm-muted
distorted guitar power chord stabs played together with kick and snare as tight accents, choked crash cymbals on the
biggest hits, a bass guitar locked to the stabs, a short guitar lead melody between hits. No continuous double-kick,
no tremolo picking, no ride cymbal pattern.
```
**11. Idol Pulse (124)**
```
Compose an original K-pop and J-pop dance instrumental: bright, catchy, energetic, idol choreography style.
Instrumentation: punchy kick and clap hits, short funky synth brass stabs, plucked synth chords, short wordless
vocal chops ("hey", "ah") on the hits, a catchy synth lead hook between hits. Choreography-style hit points: every
stab is a dance move.
```
**12. Drift Phonk (135)**
```
Compose an original drift phonk instrumental: dark, gritty, aggressive, night street racing. Instrumentation:
distorted cowbell melody played as short separated hits, booming saturated 808 hits with the kick, hard snare,
short dark synth stabs. The cowbell notes land on the hits, not running constantly. No vocal samples.
```
**13. Savanna Drums (110)**
```
Compose an original Afrobeat and West African drum instrumental: warm, joyful, powerful, celebration in the open
savanna. Instrumentation: djembe and dunun bass drum hits played together as big accents, talking drum accents,
short horn section stabs, a kalimba and guitar melody between hits. The whole drum ensemble hits together on the
accents with silence between them, no constant shaker or bell pattern.
```
**14. Steel Factory (132)**
```
Compose an original industrial techno track: mechanical, cold, powerful, like a giant robotic factory.
Instrumentation: distorted kick hits, metallic clanks and anvil hits on the accents, short noisy synth stabs, a
cold detuned melody between hits, machine-like hydraulic hiss only as short accents. No constant four-on-the-floor
kick, no rolling hi-hats, no long drones.
```

## 3. Kết quả (2026-10-16)
Tạo trên Google Flow Music (tài khoản hdgstudio86), mỗi bài một session Producer, mỗi lượt 2 bản. Producer rút gọn
prompt thành mô tả ngắn và **không giữ BPM** (vd. 118 → 115, 172 → 150). Bản đầu đạt 7–78 % ô nhịp có "X"; câu nhắn
thêm (`"Make two new takes… much sparser… real near silence until the next hit…"`) đẩy nhiều bài lên 53–99 %.
Level dựng bằng `hit_level.py` (chạm đúng thời điểm cú đánh); cổng giữ bài là `tap_salience.py` **OK** (bắt buộc để
`publish_song.py` đẩy lên), autoplay qua và dung sai ≥ ±90 ms.

| id | BPM đo | Ô nhịp có X | Chạm: nổi / attack | Độ khó | Chạm | Dung sai |
|---|---|---|---|---|---|---|
| `neon_highway` | 115 | 53 % | ×2.21 / ×5.7 | 1 | 76 | ±120 ms |
| `titan_march` | 120 | 89 % | ×2.14 / ×6.6 | 1 | 83 | ±120 ms |
| `brass_funk` | 110 | 60 % | ×2.25 / ×4.2 | 2 | 117 | ±110 ms |
| `idol_pulse` | 126.8 | 66 % | ×2.72 / ×27 | 2 | 98 | ±90 ms |
| `savanna_drums` | 110 | 55 % | ×2.13 / ×10.6 | 2 | 95 | ±120 ms |
| `carnival_drums` | 124 | 78 % | ×1.76 / ×3.2 | 3 | 146 | ±90 ms |
| `pixel_rush` | 144 | 99 % | ×3.02 / ×349 | 3 | 137 | ±100 ms |
| `steel_factory` | 130 | 78 % | ×3.20 / ×402 | 3 | 71 | ±100 ms |
| `district_808` | 144 | 63 % | ×2.22 / ×3.9 | 4 | 129 | ±90 ms |
| `bass_reactor` | 150 | 42 % | ×1.93 / ×3.5 | 4 | 131 | ±90 ms |
| `drift_phonk` | 130 | 70 % | ×1.82 / ×8.3 | 4 | 113 | ±90 ms |
| `riddim_drop` | 148 | 50 % | ×2.06 / ×4.8 | 5 | 107 | ±90 ms |

**Bỏ:** `festival_stabs` (supersaw ngân giữa các cú, 8 bản đều WEAK ×1.4–1.7 / ×2.3–3.5) và `power_chord_run` (guitar
méo ngân, 8 bản WEAK). Attack rất cao (×350–400) ở Pixel Rush / Steel Factory là do có lặng thật trước cú đánh (~25 %
thời lượng dưới −40 dB), không phải bài rỗng.

Bài chỉ để **tải về** (không nằm trong APK): `assets/music/remote/<id>.{mp3,chart.json,spectrum.json}` (bị
`exclude_filter` của preset bỏ ra, `SongCatalog` không quét thư mục con), script level có `"dir": "assets/music/remote"`,
ảnh bìa `assets/covers/<id>.jpg`. Bản gốc WAV của mọi lần tạo nằm ở `art_source/music_batch2/<id>/<clip id>.wav`
(không commit). Giấy phép: người dùng xác nhận toàn quyền dùng/phát hành (2026-10-16, gói Member), bằng chứng
`art_source/licenses/batch2_flow_music.json`; đã lên staging mã hóa rồi production.

## 4. Ghi chú
- Bảng mục 2 giữ BPM trong prompt; BPM thật lấy theo đo (`song_tempo.py`), Flow thường lệch 2–20 BPM.
- Lần sau: thêm ngay từ prompt đầu câu "much sparser… real near silence until the next hit" (mục 3); với nhạc dùng
  âm ngân (supersaw, guitar méo) phải đòi "extremely short, choked, stops dead", và vẫn có thể không đạt.
