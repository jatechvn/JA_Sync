# JA Sync Manager - Ứng dụng Đồng bộ Hóa Dữ liệu Hai chiều

JA Sync là ứng dụng desktop hiện đại, hiệu năng cao được xây dựng bằng **Flutter 3.x / Dart 3.x**, hỗ trợ đồng bộ hóa hai chiều (Bidirectional Sync) và một chiều (One-Way Mirror) cho Windows 10 & 11, macOS và Linux.

## 🚀 Tính Năng Nổi Bật

- **Đồng bộ hai chiều thông minh**: Tự động phát hiện thay đổi trên cả Source và Target dựa vào Manifest và timestamp.
- **An toàn dữ liệu & Ghi file nguyên tử (Atomic Copy)**: Ghi dữ liệu vào file tạm `.ja_sync_tmp` trước khi đổi tên chính thức, bảo đảm file không bao giờ bị hỏng khi mất điện hay ngắt kết nối.
- **Tự động bỏ qua thư mục rác**: Tự động loại trừ các thư mục rác hệ thống & lập trình (`.git`, `node_modules`, `__pycache__`, `$recycle.bin`, `.idea`, `.vscode`, v.v.).
- **Giao diện Glassmorphism Windows 10/11**: Hỗ trợ hiệu ứng kính mờ Acrylic trên Windows 11 và Aero Blur trên Windows 10.
- **Tự động chọn lịch trình & Giới hạn băng thông**: Hỗ trợ chế độ thời gian thực (Real-time), 15 phút, 1 giờ, 12 giờ, 24 giờ và tùy chỉnh tốc độ đồng bộ.
- **Nhập/Xuất cấu hình JSON**: Dễ dàng sao lưu và chuyển giao cấu hình đồng bộ giữa các máy tính.

## 🛠️ Yêu Cầu Hệ Thống

- **Hệ điều hành**: Windows 10/11, macOS 10.14+, hoặc Linux (Ubuntu 20.04+).
- **Bộ nhớ**: Tối thiểu 2GB RAM.
