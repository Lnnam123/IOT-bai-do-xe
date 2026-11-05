/*
 * ======================================================================================
 * DỰ ÁN: HỆ THỐNG ĐẾM XE & ĐIỀU KHIỂN CỔNG BÃI ĐỖ THÔNG MINH BẰNG ESP32
 * 
 * NGUYÊN LÝ HOẠT ĐỘNG:
 *   1. Cảm biến IR Cổng Vào (GPIO 13): 
 *      - Khi có xe đến: Kiểm tra số lượng xe hiện tại với Giới hạn tối đa (Max Capacity).
 *      - Nếu CÒN CHỖ (< Max): Đếm xe +1, Mở Barie Vào (90 độ), tự đóng sau 3 giây.
 *      - Nếu ĐÃ ĐẦY (>= Max): KHÓA BARIE VÀO (0 độ), từ chối mở, báo động "FULL".
 * 
 *   2. Cảm biến IR Cổng Ra (GPIO 14):
 *      - Khi có xe ra: Đếm xe -1, Mở Barie Ra (90 độ), tự đóng sau 3 giây.
 * 
 *   3. Giao diện Web:
 *      - Cài đặt số lượng xe tối đa (Max Capacity) gửi trực tiếp xuống ESP32.
 *      - Giám sát số xe thời gian thực, điều khiển cổng thủ công nếu cần.
 * ======================================================================================
 */

#include <WiFi.h>
#include <WebServer.h>
#include <ESP32Servo.h>

// ==================== 1. CẤU HÌNH WIFI ====================
const char* ssid     = "YOUR_WIFI_NAME";       // Điền tên WiFi của bạn
const char* password = "YOUR_WIFI_PASSWORD";   // Điền mật khẩu WiFi

// ==================== 2. MÁY CHỦ WEB ======================
WebServer server(80);

// ==================== 3. CHÂN KẾT NỐI PHẦN CỨNG ==========
const int PIN_SENSOR_IN  = 13;   // Cảm biến hồng ngoại Cổng Vào
const int PIN_SENSOR_OUT = 14;   // Cảm biến hồng ngoại Cổng Ra

const int PIN_SERVO_IN   = 18;   // Servo Barie Cổng Vào
const int PIN_SERVO_OUT  = 19;   // Servo Barie Cổng Ra

// ==================== 4. BIẾN QUẢN LÝ XE & BARIE =========
int maxCapacity      = 4;        // Sức chứa tối đa (Web có thể chỉnh sửa)
int currentCarCount  = 0;        // Số xe hiện có trong bãi

Servo inGateServo;
Servo outGateServo;

const int ANGLE_CLOSED = 0;      // Góc đóng barie nằm ngang
const int ANGLE_OPEN   = 90;     // Góc mở barie dựng đứng

bool inGateOpen  = false;
bool outGateOpen = false;

unsigned long inGateOpenedTime  = 0;
unsigned long outGateOpenedTime = 0;
const unsigned long GATE_AUTO_CLOSE_MS = 3500; // Tự đóng sau 3.5 giây

// Biến lưu trạng thái trước đó để bắt xung (edge detection - tránh đếm nhiều lần cho 1 xe)
int lastSensorInVal  = HIGH;
int lastSensorOutVal = HIGH;

// ==================== 5. HỖ TRỢ CORS CHO TRÌNH DUYỆT =====
void setCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void handleOptions() {
  setCorsHeaders();
  server.send(204);
}

// ==================== 6. API: LẤY TRẠNG THÁI HIỆN TẠI ====
// Endpoint: GET /api/status
void handleGetStatus() {
  setCorsHeaders();

  bool isFull = (currentCarCount >= maxCapacity);
  int available = max(0, maxCapacity - currentCarCount);

  String json = "{";
  json += "\"currentCount\":" + String(currentCarCount) + ",";
  json += "\"maxCapacity\":" + String(maxCapacity) + ",";
  json += "\"available\":" + String(available) + ",";
  json += "\"isFull\":" + String(isFull ? "true" : "false") + ",";
  json += "\"gates\":{";
  json += "\"in\":" + String(inGateOpen ? "true" : "false") + ",";
  json += "\"out\":" + String(outGateOpen ? "true" : "false");
  json += "},";
  json += "\"sensors\":{";
  json += "\"inDetected\":" + String((digitalRead(PIN_SENSOR_IN) == LOW) ? "true" : "false") + ",";
  json += "\"outDetected\":" + String((digitalRead(PIN_SENSOR_OUT) == LOW) ? "true" : "false");
  json += "}}";

  server.send(200, "application/json; charset=utf-8", json);
}

// ==================== 7. API: CÀI ĐẶT SỨC CHỨA TỐI ĐA ===
// Endpoint: POST /api/set-limit?limit=5
void handleSetLimit() {
  setCorsHeaders();

  if (server.hasArg("limit")) {
    int newLimit = server.arg("limit").toInt();
    if (newLimit > 0) {
      maxCapacity = newLimit;
      Serial.printf("[CẤU HÌNH] -> Đã cập nhật sức chứa tối đa mới: %d xe\n", maxCapacity);
      server.send(200, "application/json", "{\"success\":true,\"maxCapacity\":" + String(maxCapacity) + "}");
      return;
    }
  }
  server.send(400, "application/json", "{\"error\":\"Giá trị limit không hợp lệ\"}");
}

// ==================== 8. API: ĐẶT LẠI BỘ ĐẾM VỀ 0 =======
// Endpoint: POST /api/reset-count
void handleResetCount() {
  setCorsHeaders();
  currentCarCount = 0;
  Serial.println("[RESET] -> Đã đặt lại số xe trong bãi về 0");
  server.send(200, "application/json", "{\"success\":true,\"currentCount\":0}");
}

// ==================== 9. API: ĐIỀU KHIỂN CỔNG THỦ CÔNG ===
// Endpoint: POST /api/gate?gate=in&action=open
void handleManualGate() {
  setCorsHeaders();

  String gate = server.arg("gate");
  String action = server.arg("action");

  if (gate == "in") {
    if (action == "open") {
      // Nếu bãi đã đầy thì từ chối mở cổng vào
      if (currentCarCount >= maxCapacity) {
        server.send(403, "application/json", "{\"success\":false,\"error\":\"Bãi xe đã đầy! Không thể mở cổng vào.\"}");
        return;
      }
      inGateServo.write(ANGLE_OPEN);
      inGateOpen = true;
      inGateOpenedTime = millis();
    } else {
      inGateServo.write(ANGLE_CLOSED);
      inGateOpen = false;
    }
  } else if (gate == "out") {
    if (action == "open") {
      outGateServo.write(ANGLE_OPEN);
      outGateOpen = true;
      outGateOpenedTime = millis();
    } else {
      outGateServo.write(ANGLE_CLOSED);
      outGateOpen = false;
    }
  }

  server.send(200, "application/json", "{\"success\":true}");
}

// ==================== SETUP ==============================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n========================================================");
  Serial.println("  HỆ THỐNG ĐẾM XE & KHÓA BARIE TỰ ĐỘNG (ESP32)");
  Serial.println("========================================================");

  // Cấu hình chân cảm biến
  pinMode(PIN_SENSOR_IN, INPUT_PULLUP);
  pinMode(PIN_SENSOR_OUT, INPUT_PULLUP);
  Serial.printf("[SETUP] Cảm biến Vào -> GPIO %d | Cảm biến Ra -> GPIO %d\n", PIN_SENSOR_IN, PIN_SENSOR_OUT);

  // Cấu hình Servo MG90S
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  inGateServo.setPeriodHertz(50);
  outGateServo.setPeriodHertz(50);

  inGateServo.attach(PIN_SERVO_IN, 500, 2400);
  outGateServo.attach(PIN_SERVO_OUT, 500, 2400);

  // Đóng cả 2 barie ban đầu
  inGateServo.write(ANGLE_CLOSED);
  outGateServo.write(ANGLE_CLOSED);

  // Kết nối WiFi
  Serial.printf("[WIFI] Đang kết nối tới: %s ", ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] -> KẾT NỐI THÀNH CÔNG!");
    Serial.print("[WIFI] -> ĐỊA CHỈ IP ESP32: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n[!] WiFi thất bại, khởi động Access Point:");
    WiFi.softAP("ESP32_Smart_Parking", "12345678");
    Serial.print("[WIFI] -> IP AP: ");
    Serial.println(WiFi.softAPIP());
  }

  // Khai báo các API Route
  server.on("/api/status", HTTP_GET, handleGetStatus);
  server.on("/api/status", HTTP_OPTIONS, handleOptions);
  server.on("/api/set-limit", HTTP_POST, handleSetLimit);
  server.on("/api/set-limit", HTTP_OPTIONS, handleOptions);
  server.on("/api/reset-count", HTTP_POST, handleResetCount);
  server.on("/api/reset-count", HTTP_OPTIONS, handleOptions);
  server.on("/api/gate", HTTP_POST, handleManualGate);
  server.on("/api/gate", HTTP_OPTIONS, handleOptions);

  server.begin();
  Serial.printf("[SẴN SÀNG] Sức chứa ban đầu: %d xe | Số xe hiện tại: %d xe\n\n", maxCapacity, currentCarCount);
}

// ==================== LOOP ===============================
void loop() {
  server.handleClient();

  int currentInVal  = digitalRead(PIN_SENSOR_IN);
  int currentOutVal = digitalRead(PIN_SENSOR_OUT);

  // 1. XỬ LÝ CẢM BIẾN CỔNG VÀO (Bắt cạnh xuống: HIGH -> LOW)
  if (lastSensorInVal == HIGH && currentInVal == LOW) {
    delay(50); // Chống dội tín hiệu (debounce)
    if (digitalRead(PIN_SENSOR_IN) == LOW) {
      Serial.println("\n>>> [CỔNG VÀO] Phát hiện xe tiến tới cổng!");

      // Kiểm tra sức chứa
      if (currentCarCount < maxCapacity) {
        currentCarCount++;
        Serial.printf("    -> ĐỒNG Ý CHO VÀO! Số xe: %d/%d\n", currentCarCount, maxCapacity);

        // Mở Barie vào
        inGateServo.write(ANGLE_OPEN);
        inGateOpen = true;
        inGateOpenedTime = millis();
      } else {
        // ĐÃ ĐẦY -> TỪ CHỐI MỞ CỔNG!
        Serial.printf("    [CẢNH BÁO] BÃI ĐÃ ĐẦY (%d/%d xe)! KHÓA BARIE VÀO, KHÔNG CHO VÀO!\n", currentCarCount, maxCapacity);
        inGateServo.write(ANGLE_CLOSED);
        inGateOpen = false;
      }
    }
  }
  lastSensorInVal = currentInVal;

  // 2. XỬ LÝ CẢM BIẾN CỔNG RA (Bắt cạnh xuống: HIGH -> LOW)
  if (lastSensorOutVal == HIGH && currentOutVal == LOW) {
    delay(50);
    if (digitalRead(PIN_SENSOR_OUT) == LOW) {
      Serial.println("\n<<< [CỔNG RA] Phát hiện xe tiến tới cổng ra!");
      if (currentCarCount > 0) {
        currentCarCount--;
      }
      Serial.printf("    -> XE ĐÃ RA! Số xe còn lại trong bãi: %d/%d\n", currentCarCount, maxCapacity);

      // Mở Barie ra
      outGateServo.write(ANGLE_OPEN);
      outGateOpen = true;
      outGateOpenedTime = millis();
    }
  }
  lastSensorOutVal = currentOutVal;

  // 3. TỰ ĐỘNG ĐÓNG BARIE VÀO SAU KHI MỞ
  if (inGateOpen && (millis() - inGateOpenedTime > GATE_AUTO_CLOSE_MS)) {
    inGateServo.write(ANGLE_CLOSED);
    inGateOpen = false;
    Serial.println("    -> Barie Cổng Vào: ĐÃ ĐÓNG");
  }

  // 4. TỰ ĐỘNG ĐÓNG BARIE RA SAU KHI MỞ
  if (outGateOpen && (millis() - outGateOpenedTime > GATE_AUTO_CLOSE_MS)) {
    outGateServo.write(ANGLE_CLOSED);
    outGateOpen = false;
    Serial.println("    -> Barie Cổng Ra: ĐÃ ĐÓNG");
  }

  delay(20);
}
