# Mua trong ứng dụng (GD3-241)

Plugin chính thức `godot-google-play-billing` 3.3.0 (Billing Library 9.1.0, MIT; người dùng duyệt 2026-10-15), cài ở
`addons/GodotGooglePlayBilling`. Code game chỉ gọi `Store` (`src/core/store.gd`) và `Entitlements`
(`src/core/entitlements.gd`); trên PC và trong test cửa hàng báo "chỉ có ở bản Google Play".

## Sản phẩm (one-time, không tiêu hao)
| Product ID (Play Console) | Quyền lợi | Tác dụng hiện tại |
|---|---|---|
| `remove_ads` | `remove_ads` | Tắt interstitial và banner ngay khi mua (`Ads.enabled = false`) |
| `unlock_all_songs` | `unlock_all_songs` | Lưu lại; có tác dụng khi có khóa bài (GD3-242, chưa quyết) |

Gói gộp hoặc `creator_mode` (GD3-243): thêm một dòng vào `Store.PRODUCTS` + tên trong `ShopPanel.PRODUCT_NAMES`.

## Luồng
- Khởi động (menu): kết nối Play → lấy giá + danh sách đã mua → cấp quyền lợi cho giao dịch hoàn tất, **acknowledge**
  giao dịch chưa xác nhận (Play tự hoàn tiền sau 3 ngày nếu không acknowledge). Như vậy cài lại máy cũng tự khôi phục.
- Menu → **SHOP**: mỗi sản phẩm có giá theo vùng của Play, nút MUA / ĐÃ MUA; **RESTORE PURCHASES** hỏi lại Play.
- Quyền lợi lưu ở `user://entitlements.cfg` (chơi offline vẫn giữ). Chưa có kiểm tra giao dịch phía server.
- Event: `shop_view`, `iap_click`; doanh thu (`in_app_purchase`) do Firebase tự ghi khi liên kết Play.

## Việc người dùng làm
1. Play Console → app → Monetize → In-app products: tạo `remove_ads`, `unlock_all_songs`, đặt giá, kích hoạt.
2. Thêm tài khoản thử vào **License testing**. Mua thử chỉ chạy với bản đã tải lên Play (internal testing), cùng
   package và chữ ký.
3. Quyết định giá (vd. bỏ quảng cáo ~ 49.000 đ, mở khóa mọi bài ~ 69.000 đ) và chính sách khóa bài (GD3-242).
