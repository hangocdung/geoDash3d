# TODO — Kế hoạch phát hành BeatGlide (mã nguồn: GeoDash3D)

Danh sách việc **để lên kế hoạch**, chưa bắt đầu (lập 2026-10-15). Khi bắt đầu một mục, chuyển nó sang
`docs/roadmap.md` (giữ nguyên mã `GD3-2xx`) và cập nhật trạng thái ở đó.

- **Ai làm:** Claude = code/tool/tài liệu · Người dùng = tài khoản, tiền, pháp lý, quyết định, chơi thử · Cả hai.
- **Công sức (phần code, ước lượng thô):** S ≤ 1 ngày · M 2–5 ngày · L 1–2 tuần · XL > 2 tuần.
- Mọi SDK/plugin bên ngoài (Firebase, AdMob, Billing, In-App Review…) **cần người dùng duyệt trước** (CLAUDE.md §7),
  và phải đo FPS/bộ nhớ trên máy thật sau khi thêm (ưu tiên tối thượng: giữ FPS).

## 0. Việc chặn phát hành — quyết định sớm
- [x] **GD3-200** (→ roadmap Phase 7) Giấy phép nhạc (Người dùng). 2026-10-16: người dùng xác nhận có toàn quyền dùng và
      phát hành nhạc tạo trên Flow (tài khoản hdgstudio86, gói Member), áp dụng cho mọi bài Flow (CLAUDE.md §8 đã sửa);
      12 bài GD3-320 đã lên production. Ghi chú cũ: mọi bài trong `assets/music/` từng **chưa xác nhận dùng thương mại**
      (Google Flow Music, hdgstudio86 — CLAUDE.md §8). Phải có xác nhận quyền dùng trong game bán/quảng cáo, hoặc
      thay bài. Không lên store khi chưa xong.
- [x] **GD3-201** (→ roadmap Phase 7, chốt **BeatGlide — Ride the Rhythm** 2026-10-15) Tên game, icon, thương hiệu (Người dùng quyết, Claude gợi ý). "GeoDash" dễ bị coi là gần
      "Geometry Dash" (RobTop) → rủi ro bị gỡ/khiếu nại; nên chọn tên riêng, kiểm tra trùng tên trên cả hai store.
- [~] **GD3-202** (→ roadmap Phase 7) Chính sách quyền riêng tư + điều khoản sử dụng, có URL công khai (Cả hai, S). Bắt buộc khi có
      Firebase/quảng cáo/IAP; nội dung phải khớp với form Data safety (Play) và Privacy labels (Apple).
- [~] **GD3-203** (→ roadmap Phase 7) Đối tượng người chơi: đặt 13+ (không nhắm trẻ em) để tránh ràng buộc Families/COPPA với quảng cáo.

## 1. Thử màn hình dọc (dễ làm video marketing)
- [~] **GD3-210** (→ roadmap Phase 7) Prototype dọc (Claude, M): tùy chọn hướng màn hình theo build, bộ shot camera cho 9:16 (góc nhìn
      ngang hiện tại quá hẹp khi dọc → thử nhìn từ sau/trên cao), HUD và safe area dọc, chụp ảnh 720×1280, đo FPS trên máy.
- [ ] **GD3-211** Tiêu chí quyết định (Cả hai): thấy trước được ≥ 1.5 s đường phía trước; người chơi thử chết không
      nhiều hơn bản ngang ở cùng màn; FPS không kém bản ngang; dàn LED và vật cản dưới đường vẫn đọc được.
- [x] **GD3-212** (→ roadmap Phase 7) Phương án rẻ nếu dọc không hợp (Claude, S–M): giữ gameplay ngang, thêm chế độ quay video dọc
      (camera dọc + xuất chuỗi ảnh/clip) chỉ để làm TikTok/Shorts/Reels.

## 2. Công cụ làm level
- [x] **GD3-220** (→ roadmap Phase 7) Một lệnh sinh level (Claude, M): `python tools/charting/auto_level.py <bài.mp3>` tự đo BPM/offset,
      kiểm tra bài có hợp game (`hit_grid` ≥ 50 % ô nhịp) và có nằm trên lưới nhịp, tạo dữ liệu LED, chọn độ khó theo
      mật độ cú đánh và bảng màu, sinh level LED, tự kiểm tra (nạp chart, autoplay qua màn, dung sai) và in báo cáo;
      chỉ dừng hỏi khi không chắc (2 ứng viên BPM sát nhau, bài không đạt).
- [ ] **GD3-221** Sinh level ngay trong game từ nhạc của người chơi (Claude, XL): chuyển phần phân tích (FFT, onset,
      bước nhảy LED) sang GDScript hoặc GDExtension C++, chạy ở thread nền, lưu chart vào `user://`. Phân tích một bài
      3 phút trên điện thoại có thể mất vài chục giây đến vài phút; bài nào cũng thành màn (kể cả bài không hợp).
      Là điều kiện của gói IAP "tự tạo level" (GD3-243).

## 3. Firebase: tìm lỗi và chỉ số
Firebase **không có SDK chính thức cho Godot**. Plugin cộng đồng dạng REST không có Crashlytics → nên tự viết plugin
Android (Godot Android plugin v2 bọc Firebase Android SDK), iOS làm sau (GD3-262).
- [~] **GD3-230** (→ roadmap Phase 7) Plugin Firebase Android (Claude, L): Crashlytics (crash + ANR; `push_error` của GDScript gửi thành
      lỗi non-fatal), Analytics, Remote Config. Lớp GDScript `Telemetry` để code game không gọi thẳng plugin
      (PC/test: không gửi gì). Không gửi gì trong attract mode/autoplay/capture.
- [~] **GD3-231** (→ roadmap Phase 7) Bộ event (Claude, M) — gửi **một event mỗi lượt chơi**, không gửi theo từng lần chạm:

  | Event | Tham số chính |
  |---|---|
  | `level_start` | song_id, chart_version, mode (normal/practice), attempt, quality_tier |
  | `level_end` | song_id, result (dead/complete/quit), progress_pct, death_beat, death_cue, hazard_id, duration_sec, perfect/great/good/miss, max_combo, score, mean_error_ms, shields_used, miss_cues (chuỗi ≤ 100 ký tự) |
  | `new_best`, `first_clear` | song_id, score, attempts |
  | `calibration_done` | offset_ms, cách (thủ công/tự học) |
  | `perf_sample` (1 lần/phiên) | tier, fps_p50, fps_p10, scene (model máy Firebase tự ghi) |
  | `song_select`, `shop_view`, `iap_click`, `rate_prompt_shown` | song_id / product_id |

  User property: quality_tier, no_ads, songs_unlocked, songs_cleared. Quảng cáo và mua hàng: dùng event tự động
  khi liên kết AdMob/Play (`ad_impression` có doanh thu, `in_app_purchase`).
- [~] **GD3-232** (→ roadmap Phase 7) Phân tích độ khó level (Cả hai, M) — phương pháp:
      1. Mỗi chart: tỉ lệ qua màn (complete/start), số lần thử tới lần qua đầu (trung vị), phân bố % xa nhất, tỉ lệ
         bỏ chơi sau khi chết, biểu đồ chỗ chết theo ô 4 beat và theo cue/vật cản.
      2. **Điểm nghẽn:** cue có tỉ lệ chết cao bất thường trong số lượt tới được nó → xem lại (vật cản hiện muộn,
         lệch nhạc, quá khó) và sửa chart hoặc làm mềm.
      3. **Lệch nhạc theo cue:** độ lệch trung bình có dấu của từng cue; cue nào người chơi luôn chạm sớm/muộn
         (vd. +40 ms) trong khi tổng thể ~0 → cue đặt lệch tiếng, đặt lại (phản hồi cho tool làm level).
      4. So độ khó thật với công thức `ChartDifficulty` → chỉnh trọng số, sắp lại danh sách bài và nhãn EASY…EXPERT.
      5. Phễu: % người chơi tới bài 2, 3, … → thứ tự bài và nhịp mở khóa.
- [~] **GD3-233** (→ roadmap Phase 7) Remote Config + A/B (Claude, M): cửa sổ timing, số PERFECT để nạp lá chắn, bậc tốc độ, tần suất
      quảng cáo, thứ tự bài — đổi không cần cập nhật app. Giữ tất định: giá trị chốt lúc bắt đầu lượt.
- [~] **GD3-234** (→ roadmap Phase 7) Dashboard (Cả hai, S–M): Firebase console + xuất BigQuery (phân tích theo cue; gói miễn phí có
      giới hạn) + Looker Studio cho các bảng ở mục 7.
- [~] **GD3-235** (→ roadmap Phase 7) Hiệu năng ngoài thực tế (Claude, S): FPS p50/p10 theo model máy và tier từ `PerfProbe`, thời gian
      tải màn; chỉnh ngưỡng tự chọn tier (`QualityAutoTuner`) theo dữ liệu thật.

## 4. Kiếm tiền
- [~] **GD3-240** (→ roadmap Phase 7) Quảng cáo AdMob (Claude, L; ứng viên plugin: Poing Studios `godot-admob-plugin`, cần duyệt):
      - **Chính sách mới (người dùng quyết 2026-10-16, thay hai dòng dưới):**
        - Không quảng cáo nào (banner, interstitial) trước khi người chơi **đã được mời đánh giá app** (GD3-244 đã gọi
          hộp thoại đánh giá ít nhất một lần, lưu cờ trong `UserSettings`). Rewarded tự nguyện không bị chặn.
        - Banner **chỉ trong gameplay** (màn chơi), không ở home, danh sách bài, cài đặt, cửa hàng hay màn khác. Đặt ở
          mép không che đường/HUD (trên cùng hoặc dưới cùng tùy hướng màn), tôn trọng safe area; đo FPS trên máy
          LOW trước/sau (memory `fps-is-top-priority`). Bỏ chỗ chừa banner ở menu (`UiKit` margins, `banner_height_pixels`).
        - Interstitial chỉ ở **hộp thoại Game Over / kết quả** (GD3-245), hiện **trước khi** chuyển trạng thái theo
          nút người chơi bấm; vẫn giữ giới hạn tần suất `ads_interstitial_gap_sec` (180 s chơi). Bỏ interstitial khi về menu.
      - ~~Interstitial chỉ giữa các lượt: sau khi qua màn hoặc khi về menu … không hiện sau mỗi lần chết (game tự chơi
        lại sau 0.9 s).~~ (thay bằng chính sách trên)
      - Rewarded (tự nguyện): vd. mở thử 1 bài bị khóa, hoặc bắt đầu lượt với 1 lá chắn.
      - ~~Banner: chỉ ở menu, không bao giờ trong lúc chơi.~~ (thay bằng chính sách trên)
      - Khi quảng cáo mở: dừng nhạc và `SongClock`, khôi phục đúng khi quay lại. Không bao giờ chen giữa lượt chơi.
      - Đồng ý dữ liệu: Google UMP (bắt buộc với EEA/UK), ATT trên iOS. Đo FPS và bộ nhớ trước/sau khi thêm SDK.
- [~] **GD3-241** (→ roadmap Phase 7) IAP (Claude, L; Google Play Billing — plugin chính thức Godot; iOS StoreKit — cần duyệt):
      - `remove_ads` (non-consumable): bỏ interstitial và banner, giữ rewarded tự nguyện.
      - `unlock_all_songs` (non-consumable), có thể gộp gói `remove_ads + unlock_all` giá ưu đãi.
      - `creator_mode` (non-consumable): tự tạo level bằng nhạc riêng (GD3-243).
      - Nút **Restore purchases** (Apple bắt buộc), quyền lợi lưu cục bộ + kiểm tra lại với store khi mở app.
- [x] **GD3-242** (→ roadmap Phase 7) Chính sách khóa bài (Người dùng quyết, Claude làm S–M): bao nhiêu bài miễn phí, bài khóa mở bằng
      tiến độ / xem quảng cáo / IAP; hiển thị khóa và giá trong danh sách bài.
- [ ] **GD3-243** Chế độ tự tạo level (Claude, L, cần GD3-221): chọn file nhạc trên máy → phân tích → chơi, lưu
      kỷ lục riêng. Nhạc người chơi chỉ dùng cục bộ, không có chia sẻ (tránh vấn đề bản quyền và kiểm duyệt).
- [ ] **GD3-244** Mời đánh giá (Claude, S–M): Google Play In-App Review API, `SKStoreReviewController` trên iOS
      (Apple chỉ hiện tối đa 3 lần/365 ngày; Google có quota, có thể không hiện). Chỉ gọi sau khoảnh khắc vui
      (qua màn lần đầu, NEW BEST, ≥ 3 phiên), không bao giờ sau khi chết. **Không** hỏi "bạn thích game không?" để lọc
      trước khi mời (review gating bị cấm).
      - **Hiện chưa làm gì** (2026-10-16): chưa có plugin In-App Review, chưa có mã gọi hộp thoại đánh giá app. Thứ duy
        nhất đang có là chấm sao **từng bài** trong game (GD3-271/272, `SongRatingWidget`), không liên quan store.
      - Từ chính sách quảng cáo mới (GD3-240): mọi banner/interstitial chỉ bật **sau** lần mời đánh giá đầu tiên → cần
        cờ `review_prompted` (lưu khi đã gọi API, kể cả khi Google/Apple không hiện hộp thoại vì quota) và hàm
        `Ads.allowed()` kiểm tra cờ này cùng `enabled` (remove_ads).
      - Cần duyệt: plugin Google Play In-App Review cho Godot (thêm vào `android_plugins/` hoặc mở rộng plugin
        `geodash_firebase`), bản iOS sau.

- [ ] **GD3-245** Hộp thoại Game Over và interstitial khi chuyển trạng thái (Claude, M; người dùng yêu cầu 2026-10-16):
      - Hiện tại: chết thì game **tự chơi lại sau 0,9 s** (`LevelRunner.RESTART_DELAY_SEC`), không có hộp thoại; chỉ khi
        qua màn mới có thẻ kết quả (`RunMenu.open_results`: hạng, điểm, NEXT SONG, RESTART, MENU).
      - Mới: khi chết hiện hộp thoại Game Over: điểm, % tiến độ, kỷ lục, và các nút **CHƠI LẠI**, **VỀ TRANG CHỦ**,
        **CHỌN BÀI KHÁC** (mở thẳng danh sách bài). Thẻ kết quả khi qua màn dùng cùng bộ nút (+ BÀI TIẾP).
      - Khi người chơi bấm một nút: nếu được phép (GD3-240: đã mời đánh giá, chưa mua remove_ads, đủ khoảng cách tần
        suất) và interstitial đã tải sẵn thì hiện interstitial **trước**, đóng quảng cáo xong mới chuyển trạng thái;
        không tải được thì chuyển ngay, không bắt chờ.
      - **Đã chốt (người dùng, 2026-10-16):** mỗi lần chết đều hiện hộp thoại Game Over, bỏ tự chơi lại sau 0,9 s;
        riêng **practice** giữ tự chơi lại từ checkpoint như hiện tại.
      - Telemetry: `level_end` đã có; thêm event nút được chọn (`game_over_action`) và `ad_shown` placement `game_over`.
      - Test: luồng hộp thoại (không quảng cáo trong test), bất biến SongClock dừng khi quảng cáo mở và chơi lại đúng.

## 5. Tối ưu UI/UX
- [~] **GD3-250** (→ roadmap Phase 7) Lần chơi đầu (Claude, M): hướng dẫn 1 thao tác chạm (nhảy, né, lộn, chạy mặt dưới) trong một màn ngắn,
      gộp bước hiệu chỉnh độ trễ vào luồng này.
- [~] **GD3-251** (→ roadmap Phase 7) Màn hình (Claude, M–L): danh sách bài (khóa/giá/BEST/độ khó), kết quả (điểm, sao/hạng, NEW BEST, nút
      chơi lại/bài tiếp), cửa hàng (IAP + restore), cài đặt, tạm dừng; nút đủ lớn cho ngón tay, safe area.
- [x] **GD3-252** (→ roadmap Phase 7) Ngôn ngữ vi/en (Claude, S–M), chuẩn bị chỗ cho ngôn ngữ khác.
- [x] **GD3-253** (→ roadmap Phase 7) Rung phản hồi (haptics) khi PERFECT/chết, tùy chọn tắt; tùy chọn giảm nhấp nháy đã có.
- [x] **GD3-254** (→ roadmap Phase 7) Chụp ảnh mọi màn hình ở 19.5:9, 16:9 và 4:3 (tablet), dọc nếu chọn GD3-210; tự xem trước khi xong.

## 5b. Làm lại âm thanh hiệu ứng (SFX) theo kiểu trống (thêm 2026-10-15)
Mọi âm trong game vẫn là âm tạm sinh bằng code (`status: placeholder` trong `assets/audio/audio_catalog.json`) và
không hợp game. Quy trình tạo âm thật đã có sẵn (prompt → Google Flow tạo video có tiếng → tải về → tách âm bằng
`tools/audio/build_sfx.py`); chỉ cần đổi phong cách sang **tiếng trống**, nhất là tiếng chạm và tiếng chạm đất.
- [x] **GD3-255** (→ roadmap Phase 7) Chốt bộ âm (Claude đề xuất, Người dùng duyệt, S): một bộ trống thống nhất hợp nhạc synthwave/EDM và
      tribal. Đề xuất bộ trống điện tử kiểu 808/909, kèm vài take trống taiko để so. Âm ngắn, khô, không thành giai điệu:
      - Lần chạm: `player.jump` rimshot hoặc snare ngắn; `player.dodge` clap hoặc tom nhỏ; `player.flip` (cả lộn tròn và
        chạy mặt dưới) 2 nhát tom nhanh.
      - Chạm đất `player.land`: kick hoặc floor tom trầm, ngắn, nhỏ hơn kick của nhạc (tiếp đất rất thường xuyên).
      - `judge.perfect` clave/woodblock cao, nhỏ; `judge.great` nhẹ hơn.
      - `player.death` trống lớn + crash; `player.shield_break` cymbal choke; vật cản vào sân: tom/taiko nhẹ;
        `run.complete` fill trống + crash.
      - Rà lại danh sách ID trong `tools/audio/sfx_spec.py`: thêm ID nếu cần âm riêng cho vòng nhảy, bệ bật, chạy mặt dưới.
- [x] **GD3-256** (→ roadmap Phase 7) Viết lại prompt (Claude, S): sửa `docs/design/sfx/sfx_video_prompts.md` theo phong cách trống (đuôi prompt
      kiểu "single close-miked drum hit, dry, short decay, no melody, no music, no speech"). Giữ quy tắc cũ: mỗi clip một
      loại âm lặp 3–4 lần cách nhau 1,5–2 giây, camera đứng yên; chụp lại ảnh đầu vào từ game hiện tại nếu cần.
- [x] **GD3-257** (→ roadmap Phase 7) Tạo video (Claude qua trình duyệt): Google Flow, 2–3 take mỗi ID, tải về `art_source/sfx/<ID>_take<N>.mp4`
      (không commit). Ghi lại gói/ngày tạo để chứng minh quyền dùng thương mại.
- [x] **GD3-258** (→ roadmap Phase 7) Tách âm và đưa vào game (Claude, S–M):
      - Chạy `python tools/audio/build_sfx.py` (tách âm, cắt, chuẩn hóa), nghe thử ở `tools/audio/out/sfx_review.html`.
      - Chỉnh mức to theo nhóm trong `sfx_spec.py` so với nhạc; thêm tùy chọn tắt riêng tiếng chạm nếu người chơi thấy rối.
      - Cân nhắc phát tiếng chạm đất **đúng beat tiếp đất**: thời điểm này biết trước nhờ parabol, nên có thể phát sớm
        bù độ trễ âm thanh để tiếng trống trùng phách. Tiếng chạm phát ngay lúc chạm (không đoán trước được), nên phải
        thật ngắn và attack gắt.
      - Chơi thử trên điện thoại.

## 6. Xuất bản store
- [~] **GD3-260** (→ roadmap Phase 7) Bản release Android (Claude + Người dùng, M; thay cho GD3-053): keystore release + Play App Signing,
      AAB, target API theo mốc yêu cầu hiện hành của Google Play, version code tự tăng, icon adaptive.
- [~] **GD3-261** (→ roadmap Phase 7) Trang store (Người dùng, Claude hỗ trợ): ảnh chụp, feature graphic, video, mô tả vi/en, xếp hạng nội
      dung, form Data safety (Firebase + AdMob), khai báo có quảng cáo.
- [ ] **GD3-262** iOS (Cả hai, L): **cần máy Mac + Xcode** (Windows không build/upload được), Apple Developer
      99 USD/năm; plugin iOS cho Firebase/AdMob/StoreKit/review; Privacy labels; ATT; TestFlight.
- [ ] **GD3-263** Thử kín (Người dùng): tài khoản Play cá nhân tạo sau 11/2023 phải chạy thử kín với **≥ 12 người
      trong 14 ngày liên tục** trước khi lên production (kiểm tra lại quy định lúc làm). Chạy song song với mục 4.
- [ ] **GD3-264** Soft launch Android ở 1–3 thị trường nhỏ (Cả hai): đo giữ chân và doanh thu (mục 7), chỉnh độ khó và
      quảng cáo bằng Remote Config, rồi mới ra toàn cầu.
- [ ] **GD3-265** Sau ra mắt: theo dõi Android vitals (ANR, crash), cập nhật đều (vd. thêm bài mỗi tháng nhờ GD3-220).

## 7. Chỉ số cần theo dõi
Mốc tham khảo thường dùng cho game casual — chỉnh theo dữ liệu thật của game.

| Nhóm | Chỉ số | Nguồn | Mốc tham khảo |
|---|---|---|---|
| Kỹ thuật | Crash-free users; tỉ lệ ANR / crash (Android vitals) | Crashlytics, Play Console | ≥ 99.5 %; ANR < 0.47 %, crash < 1.09 % |
| Kỹ thuật | FPS p50/p10 theo máy và tier; thời gian tải màn | `perf_sample` | p10 ≥ 50 FPS ở tier tự chọn |
| Gameplay | Tỉ lệ qua màn, số lần thử tới lần qua, chỗ chết, lệch nhạc theo cue | `level_end` | xem GD3-232 |
| Gắn bó | Retention D1 / D7 / D30; số phiên/ngày; thời lượng phiên; DAU/MAU | Analytics | D1 35–40 %, D7 ~15 %, D30 ~5 % |
| Kiếm tiền | ARPDAU; số quảng cáo/DAU; eCPM; fill rate | AdMob + Analytics | interstitial ≤ 1 lần / 3 phút chơi |
| Kiếm tiền | Tỉ lệ người trả tiền; ARPPU; doanh thu theo gói; LTV D7/D30 | Play Billing + Analytics | người trả tiền 1–3 % |
| Marketing | Lượt cài theo nguồn; CPI; tỉ lệ xem trang store → cài; ROAS; điểm đánh giá | Play Console, Google Ads, Analytics | điểm ≥ 4.3; ROAS D30 > chi phí |

## 7b. Nội dung online: đánh giá sao + tải bài nhạc từ Cloudflare (thêm 2026-10-15)
Hai việc dùng chung một backend nhẹ. **Đề xuất:** Cloudflare (R2 chứa bài + Worker làm API) cho cả hai; Firebase giữ
vai trò hiện tại (Analytics, Crashlytics, Remote Config). Lý do: bài nhạc đằng nào cũng ở Cloudflare; Worker gọi được
bằng `HTTPRequest` của Godot trên mọi nền tảng (PC, Android, iOS) mà không phải sửa plugin Java; R2 không tính phí băng
thông tải về.

**Firebase có làm được đánh giá sao không?** Có, nhưng có 3 điểm vướng:
1. Plugin `GeoDashFirebase` hiện chỉ có Analytics/Crashlytics/Remote Config, phải thêm Firestore + Anonymous Auth vào
   plugin Java (chỉ chạy được trên Android). Cách khác là gọi Firestore REST + Identity Toolkit REST từ GDScript.
2. Điểm trung bình (tổng/số lượt) nên do server tính. Firestore Security Rules không kiểm được tổng cộng dồn có đúng
   không, nên cần Cloud Functions, mà Cloud Functions bắt buộc gói **Blaze** (trả theo dùng, vẫn có hạn mức miễn phí).
3. Chống gian lận (mỗi máy chỉ một phiếu cho mỗi bài) cần Auth + App Check; Worker làm được tương đương bằng ID cài
   đặt + Play Integrity (Android) / giới hạn tần suất.
→ Firebase hợp lý nếu không muốn dùng Cloudflare. Phương án này cần: Firestore `ratings/{song}/votes/{uid}` + Function
cập nhật `songs/{song}.sum/count`.

- [x] **GD3-270** Đã chọn sntgames-api riêng, Python/SQLite trên sv129 trong `/mnt/app/sntgames-api`; R2 cho snapshot/nội dung.
- [x] **GD3-271** API đánh giá sao (Claude, M; cần GD3-270). Thiết kế:
      - `POST /v1/beatglide/ratings {song_id, stars 1–5, install_id}` ghi đè phiếu cũ của cùng máy (khóa `song_id + install_id`).
      - `GET /v1/beatglide/ratings` trả `{song_id: {avg, count}}` cho mọi bài, cache CDN ~5 phút.
      - SQLite: bảng phiếu lưu HMAC của install_id, cập nhật và tính tổng trong cùng giao dịch.
      - Giới hạn tần suất theo IP/ID; bản Android gửi kèm token Play Integrity (bước sau).
      - `install_id` là UUID ngẫu nhiên lưu ở `user://`, là định danh giả danh cần khai báo. Ghi vào `privacy_policy.md` và
        form Data safety.
- [x] **GD3-272** Đánh giá trong game (Claude, M; cần GD3-271):
      - Sau khi **qua màn** (không hỏi khi chết), thẻ kết quả hiện 5 sao.
      - Cùng bài hỏi tối đa 1 lần; người chơi tự sửa được ở danh sách bài.
      - Danh sách bài hiện `★ 4.2 (128)` lấy từ `GET /v1/beatglide/ratings` (cache ở `user://`, không có mạng thì ẩn).
      - Thêm event `song_rate` vào Analytics.
      - Không được lẫn với GD3-244 (đánh giá app trên store).
- [x] **GD3-273** Mục yêu thích (Claude, S): lưu cục bộ trong `UserSettings`, thêm tab YÊU THÍCH ở danh sách bài. Không cần server.

**Tải bài nhạc từ Cloudflare.** Một vài bài khởi đầu vẫn nằm trong APK (chơi offline ngay lần đầu, store review
thấy nội dung). Các bài còn lại tải khi cần, sau đó chơi offline được.
- [x] **GD3-275** Định dạng gói bài và manifest (Claude, M; **người dùng đã duyệt thực hiện tự động** 2026-10-15):
      - Gói bài `<id>/<version>/` gồm `song.mp3` (hoặc `.ogg`), `chart.json` (và chart LED nếu có), `spectrum.json`, `cover.jpg`.
      - Đường dẫn trong gói là **tương đối** (chart hiện ghi `"song": "res://…"` → cần cho phép đường dẫn tương đối
        hoặc ghi đè lúc nạp). Cập nhật `docs/chart_format.md`.
      - `manifest.json` gồm `catalog_version`, `min_app_version` và mỗi bài: `id, title, artist, bpm, length, difficulty,
        version, size, sha256` cho từng file, `unlock` (miễn phí / chuỗi mở khóa / IAP), `license` (GD3-200), cờ `enabled`.
      - URL bất biến (có version trong đường dẫn), nên CDN cache vĩnh viễn được; chỉ `manifest.json` cache ngắn.
- [x] **GD3-276** Hạ tầng Cloudflare (Cả hai, S–M):
      - Người dùng tạo tài khoản, bucket R2, tên miền phụ (vd. `cdn.<tên miền>`) và API token.
      - Claude viết `tools/content/publish_song.py`: kiểm tra chart (autoplay qua headless, `tap_salience.py` OK,
        `tolerance_report`), tính sha256, đẩy lên R2 qua S3 API, cập nhật manifest. **Không đẩy** bài chưa qua kiểm tra.
      - Môi trường `staging` / `prod` tách bucket hoặc thư mục để thử trước.
- [x] **GD3-277** Tải và quản lý bài trong game (Claude, L; cần GD3-275, 276):
      - `ContentCatalog` lấy manifest bằng `HTTPRequest`, lưu bản cuối vào `user://content/`; không có mạng thì dùng bản cũ.
      - `SongCatalog` gộp bài có sẵn + bài đã tải; bài chưa tải hiện nút TẢI (dung lượng MB) và thanh tiến độ.
      - Tải vào file tạm → kiểm tra sha256 → đổi tên; tải lại được nếu đứt giữa chừng; có giới hạn dung lượng và nút XÓA BÀI ĐÃ TẢI.
      - Nạp lúc chạy, không qua import: mp3 bằng `AudioStreamMP3.load_from_file`, ảnh bìa bằng `Image.load_jpg_from_buffer`.
        `LevelRunner`, `SpectrumTexture`, `Metronome`, `Recorder` đang `load(res://…)`, cần một hàm nạp chung cho cả
        `res://` lẫn `user://`.
      - Đổi bài khi bài đang chạy thì giữ bản cũ tới hết lượt. Mỗi kết quả lưu kèm `version` bài để `HighScores` /
        `RunRecords` không trộn kỷ lục giữa các phiên bản chart.
- [x] **GD3-278** Cấu hình level từ xa (Claude, M; cần GD3-277):
      - Manifest quyết định thứ tự bài, bài nổi bật, khóa/mở; tắt được một bài lỗi mà không phát hành bản mới.
      - Tham số gameplay chung (cửa sổ timing, lá chắn, …) vẫn đi qua Remote Config (GD3-233), không lặp lại trong manifest.
      - Chart tải về vẫn phải **tất định** (bất biến §1.5); mỗi chart có `version` nên replay/telemetry biết đang chơi bản nào.
- [~] **GD3-279** Kiểm thử (Claude, M):
      - Test giải mã manifest, kiểm tra hash, gộp catalog, nạp chart từ `user://` (dùng thư mục giả, không cần mạng).
      - `test_shipped_charts.gd` mở rộng: chạy cả các gói trong `tools/content/staging/` trước khi publish.
      - Thử trên máy thật: tắt mạng giữa lúc tải, đầy bộ nhớ, đổi manifest giữa phiên.

Đã kiểm tra 161 test game và 6 test backend; desktop tải 4 chart, sửa file hỏng, chấm sao và khôi phục backup đạt.
Android đã tải/chấm sao/chơi offline và thử ngắt mạng; menu LOW đo ngắn 41,7 → 41,2 FPS trước/sau cache. Hạn mức cache 0 từ chối an toàn; chưa lấp đầy ổ để thử ENOSPC thực tế. Chi tiết: `D:/sntgames-api/docs/verification.md`.

**Việc phát sinh sau review nhánh `codex/beatglide-online` (2026-10-16).** (Đánh số lại 2026-10-16: lúc đầu ghi
GD3-280–282, trùng mã gameplay v4 ở roadmap Phase 4.10; commit `4448dfe` còn ghi số cũ.) Manifest prod hiện rỗng nên người chơi
chưa bị ảnh hưởng; GD3-300 phải xong **trước khi đưa bất kỳ bài nào lên manifest prod**.
- [x] **GD3-300** Bug chặn: bài remote chưa tải phá chuỗi mở khóa (Claude, S; xong 2026-10-16):
      - Đã tái hiện: người chơi qua cả 12 bài, manifest thêm 1 bài chưa tải (độ khó 45) → `SongUnlocks.unlocked` chỉ
        còn 3/13 bài mở; NEXT SONG sau Temple Battle Taiko trỏ tới `user://content/new_song/…` chưa có file.
      - Nguyên nhân: `SongCatalog.list_songs()` trả cả bài chưa tải; `SongUnlocks` / `RunRecords` dùng danh sách đó làm
        chuỗi mở khóa và tra `HighScores.best` của bài chưa chơi bao giờ.
      - Sửa: bài chưa tải không được chặn chuỗi (không tính là "chưa qua"); NEXT SONG bỏ qua bài chưa tải.
      - Bản revision mới thay bài có sẵn (kỷ lục chuyển sang khóa `@r2`) cũng làm mất tiến độ mở khóa: mở khóa phải tính
        kỷ lục tốt nhất qua mọi revision, còn kỷ lục hiển thị vẫn tách theo revision.
      - Test trong `tests/core/test_content.gd` (manifest giả + `HighScores.path` tạm).
      - Đã sửa: `SongCatalog.pending()` = bài chưa tải; `SongUnlocks.unlocked/requirement` nhận tập này, bài chưa tải
        nhận trạng thái chuỗi tại chỗ nhưng không đổi nó (không chiếm suất miễn phí, không chặn bài sau);
        `RunRecords.next_song` bỏ qua bài chưa tải; mở khóa đọc `HighScores.best_any_revision` (tốt nhất qua mọi
        `@rN`), hiển thị vẫn `HighScores.best`. Test tái hiện ca trên (13/13 bài mở, NEXT SONG nhảy qua bài mới) đạt;
        178 test đạt. Còn ngỏ (ngoài phạm vi): sau khi **tải** bài mới chen giữa chuỗi, bài ngay sau nó bị khóa lại tới
        khi qua bài mới (luật chuỗi hiện tại).
- [ ] **GD3-301** Lag ở home khi tải nhạc; chỉ tải khi người chơi chọn, có giao diện loading (Claude, M; đo trên máy thật):
      - Hiện tượng: menu home giật trong lúc tải bài (người dùng báo 2026-10-16).
      - Khi nạp config (manifest), bài chưa có trên máy chỉ hiện trong danh sách kèm nút TẢI (dung lượng MB);
        **không tự tải** gì ngoài manifest nhỏ.
      - Chỉ tải khi người chơi chọn tải bài đó (bấm PLAY một bài chưa có → hỏi xác nhận tải, không tải ngầm).
      - Trong lúc tải: giao diện loading riêng (thanh tiến độ MB, hủy được), chặn PLAY bài đó tới khi cài xong; xong thì
        chọn sẵn bài và cho chơi ngay.
      - Nghi vấn cần đo (chưa xác nhận): `changed` → `SongListPanel._reload_content` dựng lại toàn bộ danh sách và
        `SongCatalog.list_songs()` đọc/parse mọi chart trên main thread; `HighScores.best` parse cả chart để lấy
        `chart_revision`; `ContentCatalog.installed` mở mọi file mỗi lần dựng row/cover; giải mã JPG cover trên main
        thread; băm SHA256 64 KB mỗi frame trong khi nền menu đang chạy level 3D.
      - Hướng: dồn I/O và parse sang worker (như `LevelLoader`), cache revision/trạng thái cài, chỉ cập nhật row bị đổi.
        Đo A/B bằng `tools/device/perf_ab.sh` và logcat PERF trước/sau.
- [ ] **GD3-302** Dọn dẹp sau review nội dung online (Claude, S):
      - Bài có sẵn trong APK chỉ thắng bản đã tải khi `chart_revision` của nó **lớn hơn** `version` của gói
        (`SongCatalog.merge_remote`). Kiểm tra 2026-10-16 trên máy dev (staging): `pulse_drive` gói v2 (không có đoạn
        bay) đè lên bản APK → đã đặt `chart_revision` 3 cho bản có đoạn bay (`levels/pulse_drive.py`, `revision`). Quy
        tắc: mỗi lần sửa chart có sẵn phải tăng `revision`, và gói đẩy lên phải lấy chart mới nhất với version cao hơn.
      - Chuỗi UI mới chưa có trong `assets/i18n/vi.json` (Refresh songs, Delete downloads, FAVORITES, ★ Favorite, Rate
        this song, Your rating…, FEATURED, thông báo tải); chuỗi ghép `%s · Download %.1f MB` cần `Locale.t`. Viết hoa
        thống nhất với phần UI còn lại.
      - Nút "Refresh songs" / "Delete downloads" luôn hiện ở danh sách bài kể cả khi manifest prod rỗng; "Delete
        downloads" xóa hết không hỏi lại → ẩn khi không có bài tải về hoặc chuyển vào Settings, thêm hộp xác nhận.
      - `SongRatings.suspend()`: `HTTPRequest.cancel_request()` không phát `request_completed`, coroutine cũ treo rồi chạy
        tiếp khi request kế tiếp xong → đọc nhầm phản hồi, gửi lại phiếu trùng.
      - Telemetry `chart_version` đổi từ md5 sang `chart_revision`: chart có sẵn luôn báo "1" kể cả khi sửa giữa các bản
        app → tăng `chart_revision` khi sửa chart có sẵn, hoặc gửi kèm md5.
      - Gói version cũ không bị xóa khi đã cài bản mới; chạm 512 MB thì phải xóa hết → dọn version cũ sau khi cài xong.
      - `main_menu.gd` / `SongOnlinePanel` đọc thành viên private (`_song_list._online.downloader`, `downloader._http`)
        → thêm API công khai (đang tải, tiến độ).
      - `chart_loader.gd`, `level_runner.gd` bị xóa dòng trống giữa các hàm (đổi định dạng ngoài phạm vi) → trả lại.
- [~] **GD3-303** Lỗi thấy khi thử 12 bài mới trên điện thoại (SM-N770F, màn dọc, 2026-10-16) (Claude, S):
      - [x] Bài đã tải vẫn hiện "Download" và bấm vào thì tải lại thay vì chơi: `ContentCatalog.installed` so cả URL
        của file, nên gói tải qua prod bị coi là chưa cài khi manifest đổi URL (staging ↔ prod). Sửa: chỉ so tên, dung
        lượng, sha256; tải xong thì chọn sẵn bài vừa tải và phát demo của nó.
      - Danh sách đổi thứ tự ngay lúc bấm (manifest nạp xong → `_reload_content` dựng lại các dòng): định bấm Neon
        Highway nhưng lại tải Steel Factory. Giữ vị trí cuộn và dòng dưới ngón tay, hoặc khóa chạm trong lúc dựng lại
        (gần với GD3-301).
      - Chuỗi chưa dịch nhìn thấy trên máy: "Refresh songs", "Delete downloads", "%s · Download %.1f MB", "Rate this
        song", "FAVORITES", "★ Favorite", "Download complete" (cùng mục chuỗi của GD3-302).
      - Màn dọc: dòng gợi ý "Xoay ngang điện thoại để có trải nghiệm tốt nhất" chồng lên tiêu đề "CHƠI" ở trang danh
        sách bài (trang chủ thì không chồng).
      - Nhãn độ khó lấy từ điểm `ChartDifficulty` của chart, không theo độ khó 1–5 của script level (Steel Factory đặt 3
        nhưng hiện EASY). Xem lại cách chọn `difficulty` cho `hit_level.py` hoặc ghi rõ bảng trong
        `docs/design/music_prompts_batch2.md` là độ khó trong script.

## 7c. Playable ad (thêm 2026-10-16)
Quảng cáo chơi được ~20–30 giây từ một đoạn màn thật, chạy trong WebView của mạng quảng cáo. Hướng dẫn chi tiết:
`docs/design/playable_ad.md`. **Không xuất từ Godot**: `godot.wasm` bản web đã 37,7 MB, trong khi mạng quảng cáo chỉ nhận
một file HTML ~2–5 MB. Thay vào đó viết bản TypeScript + Three.js nhỏ trong `playable/`, đọc dữ liệu do Godot bake từ
chart thật. Nộp lên mạng thì **chờ GD3-200**; làm prototype thì không bị chặn.
- [ ] **GD3-310** Quyết định (Người dùng, S):
      - Duyệt thư viện ngoài `three`, `esbuild`, `typescript`. Chỉ dùng trong `playable/`, game Godot không đổi.
      - Chọn mạng đầu tiên (đề xuất AppLovin + Unity: chung MRAID, một bản dùng cho cả hai).
      - Chọn bài và đoạn (đề xuất `pulse_drive_led` từ beat 64, 20 s, giống clip của `record_clip.sh`).
      - Giấy phép nhạc dùng cho quảng cáo đi cùng GD3-200.
- [ ] **GD3-311** Tool bake (Claude, M; cần GD3-310):
      - `SegmentBaker` (`src/authoring/playable/`) và lệnh `tools/playable/bake_segment.gd --chart= --start-beat= --seconds= --out=`.
      - Xuất `segment.json`: tempo, `s` theo beat, frame đường ray, địa hình, chuyển động chuẩn mỗi 1/48 beat, cue,
        vật cản, config, palette, nhịp.
      - Với từng cue: chạy lại `Autoplay` bỏ đúng cue đó để lấy beat chết và `miss_trace`. Cảnh báo cue lỡ mà không có
        hậu quả.
      - Xuất `golden.json` (vài chuỗi chạm mẫu) và cắt clip mp3 bằng ffmpeg.
      - Test `tests/authoring/test_segment_baker.gd`.
- [ ] **GD3-312** Khung `playable/` và luật theo cue (Claude, M; cần GD3-311):
      - TypeScript, esbuild, phiên bản ghim cứng.
      - `AudioClock` từ `AudioContext` là đồng hồ duy nhất, không cộng dồn delta.
      - `run.ts` thuần logic: chấm điểm theo cửa sổ của `GameplayConfig` × `ad_window_scale`, combo, lá chắn, phát
        `miss_trace` khi lỡ cue.
      - `npm test` khớp `golden.json`.
- [ ] **GD3-313** Hình ảnh Three.js (Claude, M–L):
      - Đường ray neon có sóng theo beat, khối người chơi lăn, vật cản `InstancedMesh` đúng màu dành riêng, vòng cue khép
        đúng vạch, trời theo palette.
      - Camera ngang (shot `side`) và dọc (từ sau/trên).
      - Glow giả bằng emissive + halo. Bloom chỉ bật khi máy dư sức.
      - < 30 draw call, `pixelRatio` ≤ 2.
- [ ] **GD3-314** Luồng quảng cáo (Claude, S–M):
      - Màn mở chạy sẵn kiểu attract, chạm để chơi (mở khóa âm thanh).
      - Đóng băng hướng dẫn bằng `ctx.suspend()` đúng thời điểm cue.
      - HUD gọn; chết thì chơi lại; chết 2 lần hoặc hết đoạn thì sang màn kết có nút CÀI ĐẶT.
      - Nút tắt tiếng, chữ vi/en, tạm dừng khi bị ẩn, xoay màn hình không vỡ khung.
- [ ] **GD3-315** Adapter mạng và build (Claude, S–M):
      - `src/networks/`: MRAID chung, Google `ExitApi`, Meta `FbPlayableAd`, Mintegral; đọc lại tài liệu từng mạng lúc làm.
      - `node build.mjs --network=<tên>|all` ra HTML/zip, in kích thước, báo lỗi khi vượt 2 MB (cứng 5 MB).
      - URL Play Store `com.sntgames.beatglide`.
- [ ] **GD3-316** Kiểm tra (Cả hai, S–M):
      - Claude: ảnh chụp ở 375×812 và ngang (mở, hướng dẫn, chết, lá chắn, màn kết); console không lỗi; không có request
        mạng nào.
      - Người dùng: chạy qua công cụ xem thử của mạng; mở trên máy Android thật, đo FPS và độ trễ chạm.
- [ ] **GD3-317** Sau bản đầu (Cả hai, tùy chọn):
      - A/B biến thể (bài, đoạn, có/không hướng dẫn, độ dài), xem CTR/IPM trên dashboard của mạng.
      - Nếu người chơi thử thấy luật theo cue "giả": port bộ mô phỏng thật sang TS (mức 2, L), kiểm bằng golden trace
        với chuỗi chạm ngẫu nhiên.

## 8. Lộ trình đề xuất
Thứ tự theo phụ thuộc: đo lường có trước khi có người chơi bên ngoài; quyết định màn dọc trước khi làm UI; 14 ngày thử
kín chạy song song với phần kiếm tiền.

| Giai đoạn | Thời gian (ước) | Việc | Kết quả để đi tiếp |
|---|---|---|---|
| A. Quyết định nền | tuần 1–2 | GD3-200, 201, 202, 203; GD3-210–212; GD3-220 | Nhạc được phép dùng, tên mới, chốt ngang/dọc, lệnh sinh level |
| B. Đo lường | tuần 3–4 | GD3-230, 231, 235 (232–234 dựng khung) | Crash và event về Firebase từ bản test nội bộ |
| C. UI + âm thanh + bản release | tuần 4–6 | GD3-250–254, GD3-255–258 (tạo video Flow song song), GD3-260 | Bản AAB ký release có SFX trống, thử nội bộ |
| D. Kiếm tiền + store | tuần 6–8 | GD3-240, 241, 242, 244, GD3-261; bắt đầu GD3-263 (14 ngày) | Quảng cáo/IAP chạy ở thử kín, trang store xong |
| E. Soft launch | tuần 9–12 | GD3-264, GD3-232–234 với dữ liệu thật, GD3-233 A/B; GD3-262 nếu có Mac | Chỉ số mục 7 đạt mốc → ra toàn cầu |
| E2. Nội dung online | song song E | GD3-270 (quyết định), GD3-275–279 (tải bài), GD3-271–273 (đánh giá sao), GD3-300–302 (sửa sau review; GD3-300 trước bài prod đầu tiên) | Thêm bài mới không cần phát hành bản mới; điểm sao hiện trong danh sách bài |
| E3. Gameplay v4 | song song D–E | GD3-280–289 (roadmap Phase 4.10, `docs/design/gameplay_v4.md`): dạng bay, vật cản mới, camera lách; còn GD3-288 đo trên máy, GD3-289 vật cản đợt 2 | Gameplay đa dạng hơn, FPS không giảm quá ngân sách (LOW −0,5, MEDIUM −1) |
| E4. Playable ad | xong trước E (dùng cho quảng cáo cài đặt lúc soft launch) | GD3-310–316 (prototype làm được ngay; nộp mạng sau GD3-200), GD3-317 sau khi có số liệu | Một file HTML ≤ 2 MB mỗi mạng, chơi được trên Android thật, qua công cụ xem thử của mạng |
| F. Sau ra mắt | từ tháng 4 | GD3-221 + GD3-243 (tự tạo level, IAP), GD3-265 | Gói creator, bài mới đều đặn |
