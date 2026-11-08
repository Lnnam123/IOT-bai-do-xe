/*
 * ==============================================================================
 * DU AN: HE THONG DEM XE & DIEU KHIEN 2 CONG BAI DO THONG MINH BANG ESP32
 * ------------------------------------------------------------------------------
 * CAU HINH PHAN CUNG ESP32:
 *   1. CONG VAO (IN GATE):
 *      - Cam bien hong ngoai IR Vao: Chan D2  (GPIO 2)
 *      - Dong co Servo Barie Vao:    Chan D18 (GPIO 18)
 *   2. CONG RA (OUT GATE):
 *      - Cam bien hong ngoai IR Ra:  Chan D4  (GPIO 4)
 *      - Dong co Servo Barie Ra:     Chan D19 (GPIO 19)
 *   3. MAN HINH LCD 1602 I2C (4 CHAN):
 *      - Chan SDA: Chan D21 (GPIO 21)
 *      - Chan SCL: Chan D22 (GPIO 22)
 *      - Chan VCC: Chan VIN (5V)
 *      - Chan GND: Chan GND
 *
 * NGUYEN LY HOAT DONG:
 *   - Man hinh LCD 1602 hien thi so xe hien co, so cho trong theo thoi gian
 * thuc
 *   - Xe vao qua IR D2 -> Dem +1 -> Mo Barie Vao D18 (0 do) -> Tu dong sau 0.5s
 *     (Neu bai day >= Max: Khoa Barie Vao, LCD bao: "! BAI DA DAY !")
 *   - Xe ra qua IR D4  -> Dem -1 -> Mo Barie Ra D19 (0 do)  -> Tu dong sau 0.5s
 *   - Dieu khien tu xa qua MIT App Inventor (B1/T1/B2/T2)
 *   - Dong bo thoi gian thuc voi Web Dashboard qua REST API
 * ==============================================================================
 */

#include <ESP32Servo.h>
#include <ESPmDNS.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <Wire.h>

// ==================== 1. KHAI BAO CHAN THIET BI ====================
// Cong Vao (IN)
const int PIN_SENSOR_IN = 2; // Cam bien hong ngoai IR Cong Vao (chan D2)
const int PIN_SERVO_IN = 18; // Dong co Servo Barie Cong Vao (chan D18)

// Cong Ra (OUT)
const int PIN_SENSOR_OUT = 4; // Cam bien hong ngoai IR Cong Ra (chan D4)
const int PIN_SERVO_OUT = 19; // Dong co Servo Barie Cong Ra (chan D19)

// Man hinh LCD 1602 I2C (Chan SDA = D21, SCL = D22 tren ESP32)
// Dia chi I2C pho bien nhat la 0x27 (mot so loai la 0x3F)
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ==================== 2. CAU HINH WIFI ====================
const char *ssid = ".....";          // <-- Dien ten WiFi cua ban
const char *password = "nhatnam222"; // Mat khau WiFi cua ban

WiFiServer server(80);

// ==================== 3. KHAI BAO SERVO & THONG SO ====================
Servo inGateServo;
Servo outGateServo;

// Cau hinh goc quay khi Servo dung doc:
// - Binh thuong DONG: Thanh barie nam ngang chan duong (90 do)
// - Khi co xe MO: Thanh barie dung thang cho xe vao (0 do)
const int GOC_DONG = 90;                // Goc dong barie (nam ngang chan xe)
const int GOC_MO = 0;                   // Goc mo barie (dung dung cho xe qua)
const unsigned long THOI_GIAN_MO = 500; // Tu dong dong sau 0.5 giay (500ms)

// Quan ly so luong xe & Trang thai bai
int maxCapacity = 10;    // Suc chua toi da (Web co the chinh sua)
int currentCarCount = 0; // So xe hien tai trong bai (khoi tao 0 xe)

bool isInGateOpen = false;
bool isOutGateOpen = false;

unsigned long inGateOpenedTime = 0;
unsigned long outGateOpenedTime = 0;

int lastSensorInVal = HIGH;
int lastSensorOutVal = HIGH;

// ==================== 4. HAM HIEN THI MAN HINH LCD 1602 ====================
void updateLcd(String line1, String line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);
}

// Hien thi trang thai mac dinh cua bai xe len LCD
void showDefaultLcd() {
  lcd.clear();
  if (currentCarCount >= maxCapacity) {
    lcd.setCursor(0, 0);
    lcd.print("! BAI DA DAY !");
    lcd.setCursor(0, 1);
    lcd.print("KHOA CONG VAO");
  } else {
    int available = maxCapacity - currentCarCount;
    // Dong 1: XE: 0/10 XE
    lcd.setCursor(0, 0);
    lcd.print("XE: ");
    lcd.print(currentCarCount);
    lcd.print("/");
    lcd.print(maxCapacity);
    lcd.print(" XE");

    // Dong 2: CON TRONG: 10 CHO
    lcd.setCursor(0, 1);
    lcd.print("CON TRONG: ");
    lcd.print(available);
    lcd.print(" CHO");
  }
}

// ==================== 5. CAC HAM DIEU KHIEN BARIE ====================
// Dieu khien Cong Vao
void openInGate() {
  inGateServo.write(GOC_MO);
  isInGateOpen = true;
  inGateOpenedTime = millis();
  Serial.println(">>> [CONG VAO] Barie: DANG MO");
  if (currentCarCount >= maxCapacity) {
    updateLcd(">> MO CONG VAO", "XE CUOI (DA DAY)");
  } else {
    updateLcd(">> MO CONG VAO", "XIN MOI VAO!");
  }
}

void closeInGate() {
  inGateServo.write(GOC_DONG);
  isInGateOpen = false;
  Serial.println("<<< [CONG VAO] Barie: DA DONG");
  showDefaultLcd();
}

// Dieu khien Cong Ra
void openOutGate() {
  outGateServo.write(GOC_MO);
  isOutGateOpen = true;
  outGateOpenedTime = millis();
  Serial.println(">>> [CONG RA] Barie: DANG MO");
  updateLcd("<< MO CONG RA", "HEN GAP LAI!");
}

void closeOutGate() {
  outGateServo.write(GOC_DONG);
  isOutGateOpen = false;
  Serial.println("<<< [CONG RA] Barie: DA DONG");
  showDefaultLcd();
}

// ==================== 6. SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(10);
  Serial.println("\n========================================================");
  Serial.println("  HE THONG DEM XE 2 CONG ESP32 (VAO: D2/D18, RA: D4/D19)");
  Serial.println("  TICH HOP MAN HINH LCD 1602 I2C (SDA: D21, SCL: D22)");
  Serial.println("========================================================");

  // 1. Khoi dong man hinh LCD 1602 qua I2C (SDA: GPIO 21, SCL: GPIO 22)
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  updateLcd("BAI DO XE SMART", "Khoi dong...");

  // 2. Cau hinh chan cam bien hong ngoai
  pinMode(PIN_SENSOR_IN, INPUT_PULLUP);
  pinMode(PIN_SENSOR_OUT, INPUT_PULLUP);

  // 3. Cau hinh PWM cho 2 Servo tren ESP32
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  inGateServo.setPeriodHertz(50);
  outGateServo.setPeriodHertz(50);

  inGateServo.attach(PIN_SERVO_IN, 500, 2400);
  outGateServo.attach(PIN_SERVO_OUT, 500, 2400);

  // Dong ca 2 Barie ban dau (90 do)
  inGateServo.write(GOC_DONG);
  outGateServo.write(GOC_DONG);

  // 4. Ket noi WiFi
  updateLcd("DANG KET NOI...", ssid);
  Serial.print("[WIFI] Dang ket noi toi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    MDNS.begin("baidoxe");

    Serial.println(
        "\n========================================================");
    Serial.println("  [WIFI] -> KET NOI THANH CONG!");
    Serial.print("  [IP]   -> DIA CHI IP:       http://");
    Serial.println(WiFi.localIP());
    Serial.println("  [mDNS] -> TRUY CAP BANG TEN: http://baidoxe.local");
    Serial.println("========================================================");

    // Hien thi IP len LCD trong 2 giay
    updateLcd("WIFI KET NOI OK!", String(WiFi.localIP().toString()));
    delay(2000);
  } else {
    Serial.println(
        "\n[!] WiFi chua ket noi duoc. Vui long kiem tra lai SSID/Password!");
    updateLcd("WIFI THAT BAI!", "KIEM TRA SSID");
    delay(2000);
  }

  server.begin();
  showDefaultLcd();
  Serial.printf(
      "[HE THONG] San sang! Suc chua: %d xe | So xe hien tai: %d xe\n\n",
      maxCapacity, currentCarCount);
}

// ==================== 7. LOOP ====================
void loop() {
  // 1. Lang nghe va xu ly yeu cau dieu khien tu App / Web
  checkClient();

  int currentInVal = digitalRead(PIN_SENSOR_IN);
  int currentOutVal = digitalRead(PIN_SENSOR_OUT);

  // 2. XU LY CONG VAO (IR chan D2: Bat canh xuong HIGH -> LOW)
  if (lastSensorInVal == HIGH && currentInVal == LOW) {
    delay(50); // Debounce
    if (digitalRead(PIN_SENSOR_IN) == LOW) {
      Serial.println("\n>>> [CONG VAO] Phat hien xe tien toi cong!");

      // Kiem tra suc chua bai xe (Xe cuoi cung van cho phep vao de lap day bai)
      if (currentCarCount < maxCapacity) {
        currentCarCount++;
        Serial.printf("    -> DONG Y CHO VAO! So xe trong bai: %d/%d\n",
                      currentCarCount, maxCapacity);
        openInGate();
      } else {
        // Da day (>= maxCapacity) -> Tu choi khong mo cong vao!
        Serial.printf("    [CANH BAO] BAI DA DAY (%d/%d xe)! KHOA BARIE VAO, "
                      "KHONG CHO VAO!\n",
                      currentCarCount, maxCapacity);
        closeInGate();
        updateLcd("! BAI DA DAY !", "TU CHOI CHO VAO");
      }
    }
  }
  lastSensorInVal = currentInVal;

  // 3. XU LY CONG RA (IR chan D4: Bat canh xuong HIGH -> LOW)
  if (lastSensorOutVal == HIGH && currentOutVal == LOW) {
    delay(50); // Debounce
    if (digitalRead(PIN_SENSOR_OUT) == LOW) {
      Serial.println("\n<<< [CONG RA] Phat hien vat the tai cong ra!");

      // Chi mo cong ra neu trong bai DANG CO XE (> 0)
      if (currentCarCount > 0) {
        currentCarCount--;
        Serial.printf("    -> DONG Y CHO RA! So xe con lai: %d/%d\n",
                      currentCarCount, maxCapacity);
        openOutGate();
      } else {
        // Trong bai dang 0 xe -> TU CHOI MO CONG RA!
        Serial.println(
            "    [CANH BAO] BAI KHONG CO XE (0 xe)! TU CHOI MO BARIE RA!");
        closeOutGate();
        updateLcd("BAI KHONG CO XE!", "TU CHOI MO CONG");
      }
    }
  }
  lastSensorOutVal = currentOutVal;

  // 4. TU DONG DONG BARIE CONG VAO (An toan: Xe da qua khoi IR D2)
  if (isInGateOpen && (millis() - inGateOpenedTime >= THOI_GIAN_MO)) {
    if (digitalRead(PIN_SENSOR_IN) == HIGH) {
      closeInGate();
      Serial.println("    -> Barie Cong Vao: Da dong an toan.");
    } else {
      // Xe van dang de mat cam bien, hoan dong de tranh kep xe
      inGateOpenedTime = millis();
    }
  }

  // 5. TU DONG DONG BARIE CONG RA (An toan: Xe da qua khoi IR D4)
  if (isOutGateOpen && (millis() - outGateOpenedTime >= THOI_GIAN_MO)) {
    if (digitalRead(PIN_SENSOR_OUT) == HIGH) {
      closeOutGate();
      Serial.println("    -> Barie Cong Ra: Da dong an toan.");
    } else {
      // Xe van dang de mat cam bien ra
      outGateOpenedTime = millis();
    }
  }
}

// ==================== 8. XU LY KET NOI CLIENT (APP / WEB) ====================
void checkClient() {
  WiFiClient client = server.available();
  if (!client)
    return;

  unsigned long timeout = millis();
  while (!client.available() && (millis() - timeout < 150)) {
    delay(1);
  }

  if (!client.available()) {
    client.stop();
    return;
  }

  String request = client.readStringUntil('\r');
  Serial.print("[HTTP REQUEST]: ");
  Serial.println(request);

  // 1. Ho tro CORS Preflight cho trinh duyet Web
  if (request.indexOf("OPTIONS") != -1) {
    client.println("HTTP/1.1 204 No Content");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    client.println("Access-Control-Allow-Headers: Content-Type");
    client.println("Connection: close");
    client.println();
    client.stop();
    return;
  }

  // 2. API Trang thai thoi gian thuc cho Web Dashboard: GET /api/status
  if (request.indexOf("/api/status") != -1) {
    bool isFull = (currentCarCount >= maxCapacity);
    int available = max(0, maxCapacity - currentCarCount);
    bool inDetected = (digitalRead(PIN_SENSOR_IN) == LOW);
    bool outDetected = (digitalRead(PIN_SENSOR_OUT) == LOW);

    String json = "{";
    json += "\"currentCount\":" + String(currentCarCount) + ",";
    json += "\"maxCapacity\":" + String(maxCapacity) + ",";
    json += "\"available\":" + String(available) + ",";
    json += "\"isFull\":" + String(isFull ? "true" : "false") + ",";
    json += "\"gates\":{";
    json += "\"in\":" + String(isInGateOpen ? "true" : "false") + ",";
    json += "\"out\":" + String(isOutGateOpen ? "true" : "false");
    json += "},";
    json += "\"sensors\":{";
    json += "\"inDetected\":" + String(inDetected ? "true" : "false") + ",";
    json += "\"outDetected\":" + String(outDetected ? "true" : "false");
    json += "}}";

    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json; charset=utf-8");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    client.println(json);
    client.stop();
    return;
  }

  // 3. API Dieu khien cong tu Web Dashboard:
  // /api/gate?gate=in|out&action=open|close
  if (request.indexOf("/api/gate") != -1) {
    if (request.indexOf("gate=in") != -1) {
      if (request.indexOf("action=open") != -1) {
        if (currentCarCount < maxCapacity) {
          openInGate();
        } else {
          Serial.println("[CANH BAO Web] Bai xe da day! Tu choi mo cong vao.");
          updateLcd("! BAI DA DAY !", "TU CHOI CHO VAO");
        }
      } else if (request.indexOf("action=close") != -1) {
        closeInGate();
      }
    } else if (request.indexOf("gate=out") != -1) {
      if (request.indexOf("action=open") != -1) {
        if (currentCarCount > 0) {
          openOutGate();
        } else {
          Serial.println("[CANH BAO Web] Bai khong co xe! Tu choi mo cong ra.");
          updateLcd("BAI KHONG CO XE!", "TU CHOI MO CONG");
        }
      } else if (request.indexOf("action=close") != -1) {
        closeOutGate();
      }
    }

    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    client.println("{\"success\":true}");
    client.stop();
    return;
  }

  // 4. API Cai dat suc chua toi da tu Web: /api/set-limit?limit=X
  if (request.indexOf("/api/set-limit") != -1) {
    int idx = request.indexOf("limit=");
    if (idx != -1) {
      int val = request.substring(idx + 6).toInt();
      if (val > 0) {
        maxCapacity = val;
        Serial.printf("[CAU HINH] Da cap nhat suc chua toi da: %d xe\n",
                      maxCapacity);
        showDefaultLcd();
      }
    }
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    client.println("{\"success\":true,\"maxCapacity\":" + String(maxCapacity) +
                   "}");
    client.stop();
    return;
  }

  // 5. API Dieu chinh so xe hien tai tu Web: /api/set-count?count=X
  if (request.indexOf("/api/set-count") != -1) {
    int idx = request.indexOf("count=");
    if (idx != -1) {
      int val = request.substring(idx + 6).toInt();
      if (val >= 0) {
        currentCarCount = val;
        Serial.printf("[CAU HINH] Da cap nhat so xe trong bai: %d xe\n",
                      currentCarCount);
        showDefaultLcd();
      }
    }
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    client.println(
        "{\"success\":true,\"currentCount\":" + String(currentCarCount) + "}");
    client.stop();
    return;
  }

  // 6. API Dat lai so dem xe: /api/reset-count
  if (request.indexOf("/api/reset-count") != -1) {
    currentCarCount = 0;
    Serial.println("[RESET] Dat lai so luong xe trong bai ve 0");
    showDefaultLcd();
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    client.println("{\"success\":true,\"currentCount\":0}");
    client.stop();
    return;
  }

  // 7. Xu ly lenh tu MIT App Inventor / Trinh duyet thong thuong:
  // - Cong Vao: B1 (Mo) / T1 (Dong)
  // - Cong Ra:  B2 (Mo) / T2 (Dong)
  if (request.indexOf("B1") != -1 || request.indexOf("/OPEN_IN") != -1) {
    if (currentCarCount < maxCapacity) {
      openInGate();
    } else {
      Serial.println("[CANH BAO App] Bai xe da day! Tu choi mo cong vao.");
      updateLcd("! BAI DA DAY !", "TU CHOI CHO VAO");
    }
  } else if (request.indexOf("T1") != -1 ||
             request.indexOf("/CLOSE_IN") != -1) {
    closeInGate();
  } else if (request.indexOf("B2") != -1 ||
             request.indexOf("/OPEN_OUT") != -1) {
    if (currentCarCount > 0) {
      openOutGate();
    } else {
      Serial.println("[CANH BAO App] Bai khong co xe! Tu choi mo cong ra.");
      updateLcd("BAI KHONG CO XE!", "TU CHOI MO CONG");
    }
  } else if (request.indexOf("T2") != -1 ||
             request.indexOf("/CLOSE_OUT") != -1) {
    closeOutGate();
  }

  client.flush();

  // Phan hoi HTTP 200 OK "Da xu ly" chuan dinh dang cho MIT App Inventor
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html; charset=utf-8");
  client.println("Access-Control-Allow-Origin: *");
  client.println("Connection: close");
  client.println();
  client.println("Da xu ly");
  client.stop();
}
