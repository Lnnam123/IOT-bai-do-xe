# 🚗 HỆ THỐNG ĐẾM XE & KHÓA BARIE TỰ ĐỘNG BẰNG ESP32 (SMART PARKING IOT)
> **Phiên bản chuẩn hóa Node.js & Vite** với kiến trúc module hóa hiện đại, hỗ trợ Hot Module Replacement (HMR) và máy chủ Node.js Gateway.

Hệ thống bãi đỗ xe thông minh sử dụng **NodeMCU-32S ESP32**, **2 Cảm biến hồng ngoại IR** và **2 Động cơ Servo MG90S** với các tính năng:
1. **Đếm xe tự động:**
   - Xe qua **Cảm biến Vào (D2 / GPIO 2)** -> Đếm `+1` -> Mở **Barie Vào (D13 / GPIO 13)** -> Tự đóng sau 0.3 giây.
   - Xe qua **Cảm biến Ra (D4 / GPIO 4)** -> Đếm `-1` -> Mở **Barie Ra (D14 / GPIO 14)** -> Tự đóng sau 0.3 giây.
2. **Cơ chế chống quá tải (Khóa Barie khi bãi đầy):**
   - Cho phép cài đặt **Sức chứa tối đa (Max Capacity)** ngay trên Web (Ví dụ: 3 xe, 4 xe, 10 xe...).
   - Khi số xe đạt mức tối đa (`currentCount >= maxCapacity`):
     - **Barie Cổng Vào lập tức KHÓA (0 độ)**, từ chối mở khi có xe mới tiến tới.
     - Web và còi/đèn cảnh báo hiển thị: **"🚨 BÃI XE ĐÃ ĐẦY"**.
   - Khi có xe ra khỏi bãi (`-1`) -> Cổng vào tự động mở khóa bình thường!
3. **Đa nền tảng điều khiển:**
   - Hỗ trợ **Web Dashboard thời gian thực** (Vite + WebSockets/REST API + mDNS `http://baidoxe.local`).
   - Hỗ trợ **MIT App Inventor**: `B1`/`T1` (Cổng Vào) và `B2`/`T2` (Cổng Ra) kèm HTTP 200 chống lỗi 1101.

---

## 🚀 HƯỚNG DẪN KHỞI CHẠY DỰ ÁN

### 1. Yêu cầu hệ thống
- Đã cài đặt **Node.js** (Phiên bản LTS khuyên dùng: v20+ hoặc v26+).

### 2. Cài đặt thư viện (Dependencies)
Mở terminal tại thư mục dự án và chạy:
```bash
npm install
```

### 3. Các lệnh chạy dự án

| Lệnh | Chức năng | Địa chỉ truy cập |
| :--- | :--- | :--- |
| `npm run dev` | Khởi chạy **Vite Dev Server** (HMR, sửa code nhận ngay) | `http://localhost:3000` |
| `npm run build` | Đóng gói tối ưu hóa cho sản xuất vào thư mục `dist/` | N/A |
| `npm run preview` | Xem trước bản build tĩnh của Vite | `http://localhost:4173` |
| `npm start` hoặc `npm run server` | Chạy **Node.js Backend & ESP32 Proxy Server** | `http://localhost:5000` (Web) & `/app` (App) |
| `npm run app:run` | Chạy ứng dụng **Flutter Mobile / Desktop** | Cửa sổ ứng dụng / Thiết bị |
| `npm run app:web` | Chạy ứng dụng **Flutter Web trên Chrome** | `http://localhost:port` |
| `npm run app:build` | Đóng gói bản **Flutter Web** vào thư mục `app/build/web` | `http://localhost:5000/app` |
| `npm run app:apk` | Đóng gói file cài đặt **Android APK** | `app/build/app/outputs/flutter-apk` |

> 💡 **Khởi chạy nhanh trên Windows:** Bạn có thể nhấp đúp chuột vào file **`start.bat`** hoặc chạy **`start_server.ps1`** trong PowerShell để chọn chế độ chạy tiện lợi!

---

## 📂 CẤU TRÚC THƯ MỤC DỰ ÁN

```text
IOT-bai-do-xe/
├── app/                         # ỨNG DỤNG FLUTTER MOBILE & WEB (Layout Cointap / 24CT1)
│   ├── lib/
│   │   ├── backend/
│   │   │   ├── models/models.dart           # Model Bãi xe, Ô đỗ, Lịch sử, Thông báo
│   │   │   └── services/esp32_service.dart  # REST API ESP32 & Polling Realtime
│   │   ├── frontend/
│   │   │   ├── chu_de/mau_sac.dart          # Design Tokens (MauSac chuẩn Cointap)
│   │   │   ├── man_hinh/                    # 4 Tab chính (Tổng quan, Sơ đồ ô đỗ, Lịch sử, Cài đặt)
│   │   │   └── thanh_phan/                  # Modal chi tiết ô, Cài đặt sức chứa, FAB action
│   │   └── main.dart                        # BottomAppBar CircularNotched & Screen Switcher
│   ├── build/web/               # Bản build Web hoàn chỉnh (tích hợp sẵn vào server.js)
│   └── pubspec.yaml             # Cấu hình Flutter dependencies
├── dist/                        # Bản build production đóng gói hoàn chỉnh Web Vite
├── esp32/
│   └── esp32_parking.ino        # Mã nguồn nạp vi điều khiển ESP32
├── src/                         # Mã nguồn giao diện Web tĩnh Vite
├── index.html                   # Trang Dashboard giám sát bãi xe thời gian thực
├── package.json                 # Cấu hình dự án Node.js & dependencies
├── server.js                    # Máy chủ Node.js Express (REST API + CORS Proxy + Flutter /app)
├── so_do_ket_noi.html           # Sơ đồ đấu dây chi tiết & Sa bàn in nộp báo cáo (A4)
├── start.bat                    # Phím tắt khởi động 1-click cho Windows
├── start_server.ps1             # Script PowerShell hỗ trợ khởi chạy
├── vite.config.js               # Cấu hình Vite (Multi-page rollup & proxy)
└── README.md
```

---

## 🔌 SƠ ĐỒ ĐẤU NỐI PHẦN CỨNG (ESP32)

| Thiết bị | Chân trên Thiết bị | Chân trên NodeMCU-32S | Chức năng hoạt động |
| :--- | :--- | :--- | :--- |
| **Cảm biến IR Cổng Vào** | VCC / GND / **OUT** | **3V3** / **GND** / **GPIO 13** | Phát hiện xe tới lối vào (Đếm +1) |
| **Servo MG90S Cổng Vào** | Nâu / Đỏ / **Cam** | **GND** / **VIN (5V)** / **GPIO 18** | Barie lối vào (Mở 90°, Khóa 0° khi đầy) |
| **Cảm biến IR Cổng Ra** | VCC / GND / **OUT** | **3V3** / **GND** / **GPIO 14** | Phát hiện xe tới lối ra (Đếm -1) |
| **Servo MG90S Cổng Ra** | Nâu / Đỏ / **Cam** | **GND** / **VIN (5V)** / **GPIO 19** | Barie lối ra (Mở 90° rồi tự đóng) |

---

## 🌐 DANH SÁCH REST API (BACKEND NODE.JS & ESP32)

- **`GET /api/status`**: Lấy trạng thái số xe hiện có, sức chứa tối đa, trạng thái barie cổng vào/ra.
- **`POST /api/set-limit?limit=X`**: Cập nhật giới hạn sức chứa tối đa.
- **`POST /api/gate?gate=in|out&action=open|close`**: Ra lệnh đóng/mở barie (Tự động từ chối nếu mở cổng vào khi bãi đầy).
- **`POST /api/reset-count`**: Đặt lại số đếm xe trong bãi về 0.
- **`ALL /api/esp32/proxy?target=URL`**: Trạm trung chuyển CORS giúp trình duyệt gửi lệnh tới IP ESP32 mượt mà không bị chặn.
