# Khóa / mở bài (GD3-242) — ĐÃ DUYỆT 2026-10-15, đã làm

Lập 2026-10-15. Mục tiêu: lần chơi đầu có đủ bài để thấy vui (không gặp tường trả tiền), người chơi luôn có một bài
mới "sắp mở" để quay lại, quảng cáo thưởng có chỗ dùng tự nhiên, và `unlock_all_songs` (GD3-241) có giá trị rõ.

## Danh sách hiện có (xếp theo `ChartDifficulty`, dễ → khó)
| # | Chart | Độ khó | Dài |
|---|---|---|---|
| 1 | Temple Battle Taiko (Alt Take) | EASY 30.8 | 2:50 |
| 2 | Temple Battle Taiko | NORMAL 40.6 | 2:55 |
| 3 | Neon Rhythm Stabs | HARD 48.7 | 2:57 |
| 4 | Neon Rhythm Stabs (Alt Take) | HARD 50.7 | 2:45 |
| 5 | Tribal Battle Rhythm (Alt Take) | HARDER 55.8 | 2:48 |
| 6 | Tribal Battle Rhythm | HARDER 57.4 | 2:51 |
| 7 | Pulse Drive | HARDER 63.0 | 2:55 |
| 8 | Fault Line | EXPERT 66.1 | 2:35 |
| 9 | The Dawn Assembly | EXPERT 70.3 | 0:58 |
| 10–12 | The Dawn Assembly / Fault Line / Pulse Drive **(LED)** | EXPERT 78–110 | |

Bài (LED) là bản khó của cùng bài nhạc → đề xuất coi là **"bản EXPERT"** của bài gốc, không phải bài riêng.

## Luật đề xuất
1. **Miễn phí ngay từ đầu: 3 bài dễ nhất** (#1–#3, ~9 phút chơi) — đủ cho phiên đầu và để học 1 thao tác chạm.
2. **Mở bằng tiến độ:** bài kế tiếp mở khi **qua màn bài ngay trước nó** *hoặc* đạt **≥ 80 %** ở bài đó (tránh kẹt
   vĩnh viễn ở một bài khó). Mỗi lần mở có thông báo "MỞ KHÓA: <tên bài>" ở màn kết quả.
3. **Quảng cáo thưởng (tự nguyện): "Chơi thử"** một bài đang khóa — xem 1 quảng cáo được chơi bài đó **không giới hạn số
   lần thử cho tới khi rời màn** (về menu). Kỷ lục vẫn được lưu; qua màn khi chơi thử *không* tự mở bài (vẫn theo luật 2).
   Không có quảng cáo thưởng nào khác.
4. **Bản EXPERT (LED)** của một bài mở khi **qua màn bài gốc**. Không chơi thử bằng quảng cáo (giữ làm phần thưởng).
5. **IAP `unlock_all_songs`:** mở mọi bài và mọi bản EXPERT ngay, **kể cả bài thêm sau này**.
   `remove_ads` không mở bài (hai thứ tách rời; có thể bán gói gộp sau).
6. **Luyện tập** (PRACTICE) chỉ cho bài đã mở hoặc đang chơi thử.
7. **Bài mới thêm sau ra mắt** (GD3-265) xếp vào chuỗi theo độ khó; người đã mở bài kề trước nó thì mở luôn (không bắt
   chơi lại).
8. Remote Config (GD3-233) sau này chỉnh được: số bài miễn phí, ngưỡng % (80), bật/tắt chơi thử.

## Hiển thị trong danh sách bài
- Bài khóa: biểu tượng ổ khóa + dòng "Qua <bài trước> hoặc đạt 80 % để mở" + nút **CHƠI THỬ (QC)** + nút
  **MỞ TẤT CẢ <giá>** (mở cửa hàng).
- Bài sắp mở (bài kế tiếp) đánh dấu nổi bật để người chơi có mục tiêu.

## Giá tham khảo (người dùng quyết; Play tự đổi theo vùng)
| Sản phẩm | VN | US |
|---|---|---|
| `remove_ads` | 49.000 đ | 1,99 USD |
| `unlock_all_songs` | 69.000 đ | 2,99 USD |
| (sau) gói gộp | 99.000 đ | 3,99 USD |

## Kỹ thuật (khi được duyệt)
- `SongUnlocks` (src/core): thứ tự bài (theo độ khó), tính bài nào mở từ `HighScores` (cleared / progress) +
  `Entitlements` + phiên chơi thử; không đụng logic gameplay (khóa chỉ ở menu, chart không đổi).
- `Ads`: thêm rewarded (tải sẵn khi vào danh sách bài, chỉ hiện khi người chơi bấm).
- Event: `unlock` (song_id, cách mở: progress / iap / trial), `rewarded_trial` (song_id); phễu mở bài cho GD3-232.
- Test: luật mở theo tiến độ, ngưỡng 80 %, IAP mở tất cả, chơi thử hết hạn khi về menu.

## Người dùng chốt (2026-10-15)
1. **3 bài miễn phí.** 2. **Qua màn hoặc ≥ 80 %.** 3. **Alt Take là bài riêng trong chuỗi.**
4. **The Dawn Assembly là bài thưởng**, mở khi qua màn Fault Line; bản (LED) của nó mở khi qua màn nó.

## Khác với bản đề xuất khi làm
- Luật 8: bản debug **không** mở tất cả (để thử được khóa trên máy); công cụ DEV (RECORD / AUTOPLAY) luôn thấy mọi bài,
  `-- --unlock-all` mở tất cả. Remote Config cho các ngưỡng chưa làm (GD3-233).
- Kỷ lục của lượt chơi thử vẫn lưu, nhưng không giúp nhảy cóc: bài kế chỉ mở khi bài trước đã mở *và* qua màn / 80 %.
