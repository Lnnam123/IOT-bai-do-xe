# HỆ THỐNG ĐẾM XE & KHÓA BARIE TỰ ĐỘNG BẰNG ESP32 (SMART PARKING IOT)

Hệ thống bãi đỗ xe thông minh sử dụng **NodeMCU-32S ESP32**, **2 Cảm biến hồng ngoại IR** và **2 Động cơ Servo MG90S** với các tính năng:
1. **Đếm xe tự động:**
   - Xe qua **Cảm biến Vào (GPIO 13)** -> Đếm `+1` -> Mở **Barie Vào (GPIO 18)** -> Tự đóng sau 3.5 giây.
   - Xe qua **Cảm biến Ra (GPIO 14)** -> Đếm `-1` -> Mở **Barie Ra (GPIO 19)** -> Tự đóng sau 3.5 giây.
2. **Cơ chế chống quá tải (Khóa Barie khi bãi đầy):**
   - Cho phép cài đặt **Sức chứa tối đa (Max Capacity)** ngay trên Web (Ví dụ: 3 xe, 4 xe, 10 xe...).
   - Khi số xe đạt mức tối đa (`currentCount >= maxCapacity`):
     - **Barie Cổng Vào lập tức KHÓA (0 độ)**, từ chối mở khi có xe mới tiến tới.
     - Web và còi/đèn cảnh báo hiển thị: **"🚨 BÃI XE ĐÃ ĐẦY"**.
   - Khi có xe ra khỏi bãi (`-1`) -> Cổng vào tự động mở khóa bình thường!

---

## 🔌 SƠ ĐỒ ĐẤU NỐI PHẦN CỨNG

| Thiết bị | Chân trên Thiết bị | Chân trên NodeMCU-32S | Chức năng hoạt động |
| :--- | :--- | :--- | :--- |
| **Cảm biến IR Cổng Vào** | VCC / GND / **OUT** | **3V3** / **GND** / **GPIO 13** | Phát hiện xe tới lối vào (Đếm +1) |
| **Servo MG90S Cổng Vào** | Nâu / Đỏ / **Cam** | **GND** / **VIN (5V)** / **GPIO 18** | Barie lối vào (Mở 90°, Khóa 0° khi đầy) |
| **Cảm biến IR Cổng Ra** | VCC / GND / **OUT** | **3V3** / **GND** / **GPIO 14** | Phát hiện xe tới lối ra (Đếm -1) |
| **Servo MG90S Cổng Ra** | Nâu / Đỏ / **Cam** | **GND** / **VIN (5V)** / **GPIO 19** | Barie lối ra (Mở 90° rồi tự đóng) |

---

## 🖥️ CÁC TRANG WEB ĐÃ XÂY DỰNG

1. **[index.html](file:///D:/WebIOT/index.html)**: Trang giám sát chính:
   - Hiển thị số xe lớn, thanh tiến trình lấp đầy (Xanh lá -> Vàng -> Đỏ).
   - Ô cài đặt sức chứa tối đa và nút **Lưu giới hạn** (gửi lệnh xuống ESP32).
   - Banner cảnh báo nhấp nháy khi bãi đầy.
   - Nút mô phỏng xe vào (+1) và xe ra (-1).

2. **[so_do_ket_noi.html](file:///D:/WebIOT/so_do_ket_noi.html)**: Trang hướng dẫn sa bàn & chạy thử mô phỏng:
   - Bản vẽ sa bàn vị trí đặt 2 cảm biến trước 2 barie.
   - Bộ mô phỏng tương tác: Thử nghiệm tăng/giảm sức chứa và xem trực tiếp Barie bị khóa khi bãi đầy!
   - Hỗ trợ bấm **In Sơ Đồ (A4)** nộp báo cáo.

3. **[esp32/esp32_parking.ino](file:///D:/WebIOT/esp32/esp32_parking.ino)**:
   - Mã nguồn nạp vào ESP32 bằng Arduino IDE.
   - Tự động bắt xung chống dội tín hiệu (edge detection + debounce), tự động đếm xe, khóa servo khi đầy và cung cấp REST API cho web.
