# Food & Herb Blog Setup

Tự động dựng cấu trúc blog thực phẩm – dược liệu – trà thảo mộc với các trang, taxonomy, menu, permalink và block pattern mẫu.

## Tính năng
- Tạo sẵn các trang nền (Trang chủ, Blog, Bắt đầu từ đây, Tra nhanh, Thư viện kiến thức, Review & Gợi ý mua, Disclaimer, Chính sách affiliate, Liên hệ).
- Thiết lập cây chuyên mục, thẻ phổ biến và menu dropdown "Main Menu" (gán vị trí `primary` nếu theme hỗ trợ).
- Trang công cụ hiển thị trạng thái cây category, nút mở trang quản lý Category/Menu để chỉnh sửa nhanh.
- Đặt trang chủ tĩnh, trang blog và permalink `/%postname%/`.
- Thêm block pattern cho bố cục Trang chủ: Hero, Theo nhu cầu, Tra nhanh, Công thức nổi bật, Review/Affiliate, Email opt-in.
- Idempotent: chạy lại không tạo trùng (dựa trên slug).

## Cài đặt
1. Sao chép thư mục `food-herb-blog-setup` vào `wp-content/plugins/`.
2. Kích hoạt plugin trong **Plugins** hoặc chạy lệnh WP-CLI (nếu môi trường đã cài WP-CLI):
   ```bash
   wp plugin activate food-herb-blog-setup
   ```

## Chạy thiết lập
- Sau khi kích hoạt, plugin tự động chạy setup một lần (tạo trang, taxonomy, menu, permalink).
- Để chạy lại bất cứ lúc nào: vào **Tools → Blog Setup** và bấm **Run Setup**.
- Nếu dùng WP-CLI, bạn vẫn cần mở trang admin để chạy lại (plugin không thêm lệnh WP-CLI riêng).

## Kiểm tra kết quả
- **Pages:** đã tạo đúng slug, Trang chủ và Blog được gán trong *Settings → Reading*.
- **Categories/Tags:** có đầy đủ cây danh mục và các thẻ phổ biến.
- **Menu:** menu "Main Menu" chứa dropdown "Theo nhu cầu" và "Chủ đề" cùng các liên kết trang.
- **Permalinks:** cấu trúc `/%postname%/` đã được cập nhật.
- **Block patterns:** xuất hiện trong danh mục pattern "Food Herb Blog" khi chỉnh sửa trang bằng Gutenberg.
