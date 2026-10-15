# Pháp lý & thương hiệu (GD3-200 … 203)

Tài liệu làm việc cho giai đoạn A của `docs/todo.md`. Không phải tư vấn pháp lý; trước khi phát hành có quảng cáo/IAP
nên nhờ người có chuyên môn đọc lại điều khoản đang áp dụng cho tài khoản của bạn.

## GD3-200 — Giấy phép nhạc

### Điều khoản Google đã đọc (2026-10-15)
Nguồn: [Google Terms of Service](https://policies.google.com/terms) (áp dụng chung cho mọi dịch vụ Google, gồm Flow Music).

| Điểm | Nội dung | Ý nghĩa với game |
|---|---|---|
| Quyền sở hữu | "Your content remains yours"; Google không nhận quyền sở hữu nội dung gốc bạn tạo bằng dịch vụ. | Google không đòi quyền với bài nhạc. |
| Giấy phép cho Google | Bạn cấp cho Google giấy phép toàn cầu, không độc quyền, miễn phí với nội dung của bạn (để vận hành/cải thiện dịch vụ). | Không cản việc bạn dùng bài trong game. |
| Hạn chế AI | Không dùng nội dung AI của Google để huấn luyện mô hình ML; không làm người khác tin nội dung AI là do người tạo. | Không ghi "sáng tác bởi <tên người>" cho các bài này; nên ghi rõ "nhạc tạo bằng AI (Google Flow Music)". |
| Điều khoản riêng | Điều khoản riêng của từng dịch vụ (vd. Generative AI Prohibited Use Policy) **được ưu tiên** khi mâu thuẫn. | Phải xem cả điều khoản/gói của Flow Music, không chỉ trang chung. |

Thông tin thêm (nguồn thứ ba, cần đối chiếu với trang gói trong tài khoản):
- Quyền **dùng thương mại** được Google liệt kê là quyền lợi của các gói trả phí: Flow Music Starter (Google AI Plus),
  Plus (Google AI Pro), Member (Google AI Ultra). Gói miễn phí **không thấy ghi rõ** có quyền thương mại.
- Nhạc Lyria có watermark SynthID (không tắt được). Không ảnh hưởng tới game, nhưng nền tảng video có thể nhận ra là AI.
- Đang có vụ kiện (2026) cáo buộc Lyria 3 huấn luyện trên bản ghi có bản quyền → rủi ro pháp lý chưa ngã ngũ, thấp với
  game nhưng nên biết.
- Quyền thương mại ≠ được đăng ký Content ID; bài AI thường không được bảo hộ bản quyền đầy đủ → người khác có thể
  dùng lại bài, không ngăn được.

### Việc người dùng cần làm (chặn phát hành)
1. **Chụp lại bằng chứng** cho từng bài: gói Flow Music lúc tạo bài (phải là gói có quyền thương mại), ngày tạo,
   prompt, tài khoản. Lưu ở `art_source/licenses/` (không commit, có thông tin tài khoản).
2. **Bài của hdgstudio86** (8 bài, CLAUDE.md §8): nếu hdgstudio86 là bạn → làm như mục 1. Nếu là người khác → cần
   văn bản (email cũng được) cho phép dùng trong game thương mại có quảng cáo/IAP, không giới hạn thời gian, mọi
   nền tảng, kèm cả quyền dùng trong video quảng cáo (TikTok/Shorts — GD3-212).
3. Bài nào không có bằng chứng → thay bằng bài tạo lại ở gói trả phí (prompt: `docs/design/music_prompts.md`) rồi
   làm lại level bằng `auto_level.py` (GD3-220).
4. Khi xong: sửa cột "Giấy phép" ở CLAUDE.md §8 thành "Thương mại — gói X, bằng chứng ngày Y".

Ghi công trong game (màn credits/cài đặt) và mô tả store: "Music generated with Google Flow Music (AI)".

## GD3-201 — Tên game

"GeoDash3D" chỉ là tên mã. Rủi ro: "Geometry Dash" là thương hiệu của RobTop; tên chứa "Geo"+"Dash" dễ bị khiếu nại
hoặc bị store từ chối vì gây nhầm lẫn. Cũng tránh các từ "Geometry", "Dash" đứng cạnh nhau trong mô tả store.

Ứng viên (đã tra nhanh web 2026-10-15; **chưa** tra trực tiếp Google Play/App Store và cơ sở dữ liệu nhãn hiệu):

| Tên | Ý | Ghi chú tra cứu |
|---|---|---|
| **Pulse Rail** | đường ray chạy theo nhịp — đúng cơ chế game | không thấy game trùng |
| **Beat Rail** | ngắn, dễ nhớ | không thấy game trùng |
| **Rhythm Rail** | rõ thể loại | không thấy game trùng |
| Neon Cadence | hợp phong cách neon | **đã có** game PC cùng tên (itch.io) → loại |
| Pulse Runner | | **nhiều** game trùng → loại |

Đề xuất: **Pulse Rail** (có thể thêm phụ đề store: "Pulse Rail: Neon Rhythm Run"). Việc của người dùng: tìm tên trên
cả hai store, tra nhãn hiệu (WIPO Global Brand Database, USPTO), kiểm tra tên miền/tài khoản mạng xã hội còn trống.
Sau khi chốt, Claude đổi `config/name`, tên gói Android (`package/unique_name`), icon và chữ trên menu.

## GD3-202 — Quyền riêng tư & điều khoản
Bản nháp: [`privacy_policy.md`](privacy_policy.md). Cần URL công khai (vd. GitHub Pages hoặc trang Google Sites) trước
khi điền form Data safety. Bản nháp viết theo trạng thái **sau** khi có Firebase + AdMob + IAP; trước đó game không
gửi dữ liệu nào ra ngoài (chỉ lưu cài đặt/kỷ lục trong `user://`).

## GD3-203 — Đối tượng người chơi
Quyết định đề xuất: **13+, không nhắm tới trẻ em**.
- Play Console → Target audience: chọn 13–15, 16–17, 18+ (không chọn nhóm dưới 13) → không vào chương trình Families,
  AdMob không cần chế độ child-directed.
- AdMob: đặt `max_ad_content_rating = T` (Teen), `tag_for_child_directed_treatment = false`,
  `tag_for_under_age_of_consent` theo kết quả UMP.
- Store listing và icon không dùng hình ảnh/ngôn ngữ nhắm vào trẻ nhỏ (Google xét cả "appeal to children").
- Xếp hạng nội dung (IARC) dự kiến: Everyone / PEGI 3 (không bạo lực, chỉ hình học) — độ tuổi xếp hạng khác với độ
  tuổi đối tượng; vẫn khai đối tượng 13+.
