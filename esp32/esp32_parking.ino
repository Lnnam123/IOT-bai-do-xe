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
 *   4. NUT NHAN VAT LY (FACTORY RESET):
 *      - Nut BOOT tich hop san tren board ESP32: Chan GPIO 0
 *      - Nhan giu nut BOOT 3 giay de xoa sach WiFi da luu va ve che do AP mac dinh!
 *
 * NGUYEN LY HOAT DONG:
 *   - Man hinh LCD 1602 hien thi so xe hien co, so cho trong va IP ket noi
 *   - Xe vao qua IR D2 -> Dem +1 -> Mo Barie Vao D18 (0 do) -> Tu dong dong sau 0.5s
 *     (Neu bai day >= Max: Khoa Barie Vao, LCD bao: "! BAI DA DAY !")
 *   - Xe ra qua IR D4  -> Dem -1 -> Mo Barie Ra D19 (0 do)  -> Tu dong dong sau 0.5s
 *   - Che do WiFi AP (BaiDoXe_ESP32, MK: 123456789, IP: 192.168.4.1) luon hoat dong
 *   - Ho tro cau hinh WiFi router tu App qua API /api/set-wifi va luu vao Flash
 *   - Ho tro xoa sach WiFi ve mac dinh qua API /api/reset-wifi hoac giu nut BOOT 3s
 *   - Ho tro dieu khien qua REST API cho Web Dashboard & MIT App Inventor (B1/T1/B2/T2)
 * ==============================================================================
 */

#include <ESP32Servo.h>
#include <ESPmDNS.h>
#include <LiquidCrystal_I2C.h>
#include <Preferences.h>
#include <WiFi.h>
#include <Wire.h>

// ==================== KHAI BAO NGUYEN MAU HAM (PROTOTYPES) ====================
void updateLcd(String line1, String line2);
void showDefaultLcd();
void openInGate();
void closeInGate();
void openOutGate();
void closeOutGate();
void checkClient();
void drainRemainingHeaders(WiFiClient &client);
void sendJsonResponse(WiFiClient &client, const String &json);
void resetWifiVeMacDinh();

// ==================== 1. KHAI BAO CHAN THIET BI ====================
// Cong Vao (IN)
const int PIN_SENSOR_IN = 2; // Cam bien hong ngoai IR Cong Vao (chan D2)
const int PIN_SERVO_IN = 18; // Dong co Servo Barie Cong Vao (chan D18)

// Cong Ra (OUT)
const int PIN_SENSOR_OUT = 4; // Cam bien hong ngoai IR Cong Ra (chan D4)
const int PIN_SERVO_OUT = 19; // Dong co Servo Barie Cong Ra (chan D19)

// Nut nhan vat ly tren board ESP32 (Nut BOOT dung de Factory Reset Wi-Fi)
const int PIN_BUTTON_BOOT = 0;

// Man hinh LCD 1602 I2C (Chan SDA = D21, SCL = D22 tren ESP32)
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ==================== 2. CAU HINH WIFI & FLASH STORAGE ====================
Preferences preferences;

// WiFi router mac dinh (fallback khi chua cau hinh qua App)
String wifiSsid     = ".....";
String wifiPassword = "nhatnam222";

// Thong tin Access Point rieng de App de dang ket noi truc tiep
const char *apSsid     = "BaiDoXe_ESP32";
const char *apPassword = "123456789"; // Mat khau WiFi AP: 123456789 (IP: 192.168.4.1)

WiFiServer server(80);

// ==================== 3. KHAI BAO SERVO & THONG SO ====================
Servo inGateServo;
Servo outGateServo;

// Cau hinh goc quay khi Servo dung doc:
// - Binh thuong DONG: Thanh barie nam ngang chan duong (90 do)
// - Khi co xe MO: Thanh barie dung thang cho xe vao (0 do)
const int GOC_DONG = 90;                // Goc dong barie (nam ngang chan xe)
const int GOC_MO = 0;                   // Goc mo barie (dung dung cho xe qua)
const unsigned long THOI_GIAN_MO = 3000; // Tu dong dong sau 3 giay (3000ms)

// Quan ly so luong xe & Trang thai bai
int maxCapacity = 10;    // Suc chua toi da (App & Web co the chinh sua)
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
    if (WiFi.status() == WL_CONNECTED) {
      lcd.print("IP: ");
      lcd.print(WiFi.localIP().toString());
    } else {
      lcd.print("AP: 192.168.4.1");
    }
  } else {
    int available = maxCapacity - currentCarCount;
    // Dong 1: XE: 0/10 CON: 10
    lcd.setCursor(0, 0);
    lcd.print("XE:");
    lcd.print(currentCarCount);
    lcd.print("/");
    lcd.print(maxCapacity);
    lcd.print(" CON:");
    lcd.print(available);

    // Dong 2: Hien thi dia chi IP de de dang ket noi tren App
    lcd.setCursor(0, 1);
    if (WiFi.status() == WL_CONNECTED) {
      lcd.print("IP: ");
      lcd.print(WiFi.localIP().toString());
    } else {
      lcd.print("AP: 192.168.4.1");
    }
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

// ==================== 5.1. HAM XOA TOAN BO WIFI VE MAC DINH (FACTORY RESET) ====================
void resetWifiVeMacDinh() {
  Serial.println("\n[RESET WIFI] Dang tien hanh xoa sach WiFi trong Flash...");
  updateLcd("DANG XOA WIFI...", "XIN DANG CHO...");

  preferences.begin("parking_cfg", false);
  preferences.clear();
  wifiSsid = "";
  wifiPassword = "";

  WiFi.disconnect(true, false);
  delay(500);

  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  WiFi.softAP(apSsid, apPassword);

  updateLcd("DA XOA HET WIFI!", "AP: 192.168.4.1");
  Serial.println("[RESET WIFI] -> Hoan tat! ESP32 da tro ve che do Access Point mac dinh (BaiDoXe_ESP32 - 192.168.4.1).");
  delay(2500);
  showDefaultLcd();
}

// ==================== 6. SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("\n========================================================");
  Serial.println("  HE THONG DEM XE 2 CONG ESP32 (VAO: D2/D18, RA: D4/D19)");
  Serial.println("  TICH HOP MAN HINH LCD 1602 I2C (SDA: D21, SCL: D22)");
  Serial.println("  TICH HOP NUT BOOT (GPIO 0) DE RESET WIFI VE MAC DINH");
  Serial.println("========================================================");

  // 1. Khoi dong man hinh LCD 1602 qua I2C (SDA: GPIO 21, SCL: GPIO 22)
  Wire.begin(21, 22);
  Wire.setClock(100000);
  lcd.init();
  lcd.backlight();
  updateLcd("BAI DO XE SMART", "KHOI DONG...");

  // 2. KHOI DONG ACCESS POINT (BaiDoXe_ESP32 - 192.168.4.1)
  WiFi.persistent(false);
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  bool apOk = WiFi.softAP(apSsid, apPassword);
  Serial.printf("\n[AP MODE] Phat Access Point '%s': %s\n", apSsid, apOk ? "THANH CONG" : "THAT BAI");
  Serial.println("  [Pass AP]   -> 123456789");
  Serial.println("  [IP AP]     -> http://192.168.4.1");

  // Khoi dong Web Server & mDNS ngay de phuc vu ket noi AP tuc thi
  server.begin();
  MDNS.begin("baidoxe");

  // 3. Doc cau hinh WiFi da luu tu Flash
  preferences.begin("parking_cfg", false);
  String savedSsid = preferences.getString("ssid", "");
  String savedPass = preferences.getString("pass", "");
  if (savedSsid.length() > 0) {
    wifiSsid = savedSsid;
    wifiPassword = savedPass;
    Serial.println("[CONFIG] Da doc WiFi tu Flash: " + wifiSsid);
  }

  // 4. Cau hinh chan cam bien hong ngoai va nut BOOT
  pinMode(PIN_SENSOR_IN, INPUT_PULLUP);
  pinMode(PIN_SENSOR_OUT, INPUT_PULLUP);
  pinMode(PIN_BUTTON_BOOT, INPUT_PULLUP);

  // 5. Cau hinh PWM cho 2 Servo tren ESP32
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  inGateServo.setPeriodHertz(50);
  outGateServo.setPeriodHertz(50);

  inGateServo.attach(PIN_SERVO_IN, 500, 2400);
  outGateServo.attach(PIN_SERVO_OUT, 500, 2400);

  // Dong ca 2 Barie ban dau (90 do)
  inGateServo.write(GOC_DONG);
  outGateServo.write(GOC_DONG);

  // 6. Thu ket noi WiFi router neu da co SSID hop le
  if (wifiSsid.length() > 0 && wifiSsid != ".....") {
    updateLcd("DANG NOI ROUTER", wifiSsid);
    Serial.print("[WIFI] Dang ket noi toi: ");
    Serial.println(wifiSsid);
    WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 14) {
      delay(500);
      Serial.print(".");
      attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\n[WIFI] -> KET NOI THANH CONG! IP Router: " + WiFi.localIP().toString());
      updateLcd("WIFI KET NOI OK!", WiFi.localIP().toString());
      delay(2000);
    } else {
      Serial.println("\n[!] Khong the ket noi router. Duy tri che do AP.");
      updateLcd("AP: BaiDoXe_ESP32", "IP: 192.168.4.1");
      delay(1500);
    }
  } else {
    Serial.println("[WIFI] Chua co WiFi router. Ket noi vao 'BaiDoXe_ESP32' de cau hinh.");
    updateLcd("AP: BaiDoXe_ESP32", "IP: 192.168.4.1");
    delay(1500);
  }

  showDefaultLcd();
  Serial.printf(
      "[HE THONG] San sang! Suc chua: %d xe | So xe hien tai: %d xe\n\n",
      maxCapacity, currentCarCount);
}

// ==================== 7. LOOP ====================
void loop() {
  // 1. Lang nghe va xu ly yeu cau dieu khien tu App / Web
  checkClient();

  // 1.1. Kiem tra nhan giu nut BOOT (GPIO 0) tren board ESP32 trong 3 giay de Reset WiFi
  if (digitalRead(PIN_BUTTON_BOOT) == LOW) {
    unsigned long pressStart = millis();
    while (digitalRead(PIN_BUTTON_BOOT) == LOW) {
      delay(50);
      if (millis() - pressStart >= 3000) {
        Serial.println("\n[BOOT BUTTON] Da nhan giu nut BOOT du 3s -> Kich hoat Factory Reset!");
        resetWifiVeMacDinh();
        while (digitalRead(PIN_BUTTON_BOOT) == LOW) { delay(100); }
        break;
      }
    }
  }

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
// Ham doc sach toan bo header con lai cua request de tranh loi TCP RST socket
void drainRemainingHeaders(WiFiClient &client) {
  unsigned long start = millis();
  while (client.connected() && (millis() - start < 400)) {
    if (client.available()) {
      String line = client.readStringUntil('\n');
      if (line == "\r" || line.length() == 0) {
        break; // Da het toan bo header
      }
    } else {
      delay(1);
    }
  }
}

// Ham phan hoi JSON chuan REST API, day du Content-Length va CORS
void sendJsonResponse(WiFiClient &client, const String &json) {
  drainRemainingHeaders(client);
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json; charset=utf-8");
  client.println("Access-Control-Allow-Origin: *");
  client.println("Access-Control-Allow-Methods: GET, POST, OPTIONS");
  client.println("Access-Control-Allow-Headers: Content-Type");
  client.print("Content-Length: ");
  client.println(json.length());
  client.println("Connection: close");
  client.println();
  client.print(json);
  client.flush();
  delay(10);
  client.stop();
}

void checkClient() {
  WiFiClient client = server.available();
  if (!client)
    return;

  // Tang timeout cho doi data len 1000ms de phong mang SoftAP ban dau bi lag
  unsigned long timeout = millis();
  while (!client.available() && (millis() - timeout < 1000)) {
    delay(2);
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
    drainRemainingHeaders(client);
    client.println("HTTP/1.1 204 No Content");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    client.println("Access-Control-Allow-Headers: Content-Type");
    client.println("Content-Length: 0");
    client.println("Connection: close");
    client.println();
    client.flush();
    delay(5);
    client.stop();
    return;
  }

  // 2. API Trang thai thoi gian thuc cho Web & App: GET /api/status
  if (request.indexOf("/api/status") != -1) {
    bool isFull = (currentCarCount >= maxCapacity);
    int available = max(0, maxCapacity - currentCarCount);
    bool inDetected = (digitalRead(PIN_SENSOR_IN) == LOW);
    bool outDetected = (digitalRead(PIN_SENSOR_OUT) == LOW);

    String json = "{";
    json += "\"deviceName\":\"ESP32 Bai Do Xe\",";
    json += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
    json += "\"apIp\":\"" + WiFi.softAPIP().toString() + "\",";
    json += "\"connectedSsid\":\"" + WiFi.SSID() + "\",";
    json += "\"currentCount\":" + String(currentCarCount) + ",";
    json += "\"maxCapacity\":" + String(maxCapacity) + ",";
    json += "\"available\":" + String(available) + ",";
    json += "\"isFull\":" + String(isFull ? "true" : "false") + ",";
    json += "\"inGateOpen\":" + String(isInGateOpen ? "true" : "false") + ",";
    json += "\"outGateOpen\":" + String(isOutGateOpen ? "true" : "false") + ",";
    json += "\"sensorIn\":" + String(inDetected ? "true" : "false") + ",";
    json += "\"sensorOut\":" + String(outDetected ? "true" : "false") + ",";
    json += "\"gates\":{";
    json += "\"in\":" + String(isInGateOpen ? "true" : "false") + ",";
    json += "\"out\":" + String(isOutGateOpen ? "true" : "false");
    json += "},";
    json += "\"sensors\":{";
    json += "\"inDetected\":" + String(inDetected ? "true" : "false") + ",";
    json += "\"outDetected\":" + String(outDetected ? "true" : "false");
    json += "}}";

    sendJsonResponse(client, json);
    return;
  }

  // 2.1. API Quet cac mang WiFi xung quanh cho App: GET /api/scan-wifi
  if (request.indexOf("/api/scan-wifi") != -1) {
    Serial.println("[WIFI SCAN] Dang quet cac mang WiFi xung quanh...");
    int n = WiFi.scanNetworks();
    String json = "[";
    for (int i = 0; i < n; ++i) {
      if (i > 0) json += ",";
      json += "{";
      json += "\"ssid\":\"" + WiFi.SSID(i) + "\",";
      json += "\"rssi\":" + String(WiFi.RSSI(i)) + ",";
      json += "\"open\":" + String(WiFi.encryptionType(i) == WIFI_AUTH_OPEN ? "true" : "false");
      json += "}";
    }
    json += "]";
    Serial.printf("[WIFI SCAN] Tim thay %d mang WiFi xung quanh\n", n);

    sendJsonResponse(client, json);
    return;
  }

  // 2.2. API Cau hinh WiFi truc tiep tu App: /api/set-wifi?ssid=NAME&pass=PASS
  if (request.indexOf("/api/set-wifi") != -1) {
    String newSsid = "";
    String newPass = "";
    int idxSsid = request.indexOf("ssid=");
    int idxPass = request.indexOf("pass=");
    if (idxSsid != -1) {
      int endSsid = request.indexOf('&', idxSsid);
      if (endSsid == -1) endSsid = request.indexOf(' ', idxSsid);
      newSsid = request.substring(idxSsid + 5, endSsid);
    }
    if (idxPass != -1) {
      int endPass = request.indexOf('&', idxPass);
      if (endPass == -1) endPass = request.indexOf(' ', idxPass);
      newPass = request.substring(idxPass + 5, endPass);
    }

    newSsid.replace("%20", " ");
    newPass.replace("%20", " ");

    Serial.println("[CONFIG] Nhan cau hinh WiFi moi tu App: " + newSsid);
    if (newSsid.length() > 0) {
      preferences.putString("ssid", newSsid);
      preferences.putString("pass", newPass);
      wifiSsid = newSsid;
      wifiPassword = newPass;

      updateLcd("DANG NOI WIFI...", newSsid.substring(0, 16));
      sendJsonResponse(client, "{\"success\":true,\"message\":\"Connecting to " + newSsid + "\"}");

      delay(500);
      WiFi.disconnect(false, false);
      WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());

      int waitSec = 0;
      while (WiFi.status() != WL_CONNECTED && waitSec < 20) {
        delay(500);
        waitSec++;
      }

      if (WiFi.status() == WL_CONNECTED) {
        MDNS.begin("baidoxe");
        Serial.println("[CONFIG] Da ket noi WiFi moi! IP: " + WiFi.localIP().toString());
        updateLcd("WIFI MOI OK!", WiFi.localIP().toString());
      } else {
        Serial.println("[CONFIG] Ket noi WiFi moi that bai!");
        updateLcd("KET NOI THAT BAI", "AP: 192.168.4.1");
      }
      delay(2500);
      showDefaultLcd();
      return;
    }
  }

  // 2.3. API Reset WiFi ve mac dinh (Xoa sach WiFi da luu trong Flash): /api/reset-wifi
  if (request.indexOf("/api/reset-wifi") != -1) {
    Serial.println("[CONFIG] Nhan lenh /api/reset-wifi: Xoa toan bo WiFi!");
    sendJsonResponse(client, "{\"success\":true,\"message\":\"Da xoa sach WiFi. ESP32 tro ve che do AP mac dinh.\"}");
    delay(200);
    resetWifiVeMacDinh();
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

    sendJsonResponse(client, "{\"success\":true}");
    return;
  }

  // 3.1. API Mo phong / Dieu khien Xe Vao (+1) tu App & Web: /api/simulate-enter, /api/car-in
  if (request.indexOf("/api/simulate-enter") != -1 || request.indexOf("/api/car-in") != -1 || request.indexOf("/api/enter") != -1) {
    if (currentCarCount < maxCapacity) {
      currentCarCount++;
      Serial.printf("[APP/WEB] Xe vao (+1)! So xe hien tai: %d/%d xe\n", currentCarCount, maxCapacity);
      openInGate();
      sendJsonResponse(client, "{\"success\":true,\"action\":\"enter\",\"currentCount\":" + String(currentCarCount) + ",\"maxCapacity\":" + String(maxCapacity) + ",\"inGateOpen\":true}");
    } else {
      Serial.println("[APP/WEB] Tu choi xe vao! Bai xe da day.");
      closeInGate();
      updateLcd("! BAI DA DAY !", "TU CHOI CHO VAO");
      sendJsonResponse(client, "{\"success\":false,\"error\":\"Bai xe da day!\",\"currentCount\":" + String(currentCarCount) + ",\"maxCapacity\":" + String(maxCapacity) + ",\"inGateOpen\":false}");
    }
    return;
  }

  // 3.2. API Mo phong / Dieu khien Xe Ra (-1) tu App & Web: /api/simulate-leave, /api/car-out
  if (request.indexOf("/api/simulate-leave") != -1 || request.indexOf("/api/car-out") != -1 || request.indexOf("/api/leave") != -1) {
    if (currentCarCount > 0) {
      currentCarCount--;
      Serial.printf("[APP/WEB] Xe ra (-1)! So xe con lai: %d/%d xe\n", currentCarCount, maxCapacity);
      openOutGate();
      sendJsonResponse(client, "{\"success\":true,\"action\":\"leave\",\"currentCount\":" + String(currentCarCount) + ",\"maxCapacity\":" + String(maxCapacity) + ",\"outGateOpen\":true}");
    } else {
      Serial.println("[APP/WEB] Tu choi xe ra! Bai khong co xe.");
      closeOutGate();
      updateLcd("BAI KHONG CO XE!", "TU CHOI MO CONG");
      sendJsonResponse(client, "{\"success\":false,\"error\":\"Bai khong co xe!\",\"currentCount\":" + String(currentCarCount) + ",\"maxCapacity\":" + String(maxCapacity) + ",\"outGateOpen\":false}");
    }
    return;
  }

  // 3.3. API Dieu chinh so luong xe tu App & Web: /api/set-count?count=X
  if (request.indexOf("/api/set-count") != -1) {
    int idx = request.indexOf("count=");
    if (idx != -1) {
      int val = request.substring(idx + 6).toInt();
      if (val >= 0 && val <= maxCapacity) {
        currentCarCount = val;
        Serial.printf("[APP/WEB] Da dieu chinh so luong xe thanh: %d/%d xe\n", currentCarCount, maxCapacity);
        showDefaultLcd();
      }
    }
    sendJsonResponse(client, "{\"success\":true,\"currentCount\":" + String(currentCarCount) + ",\"maxCapacity\":" + String(maxCapacity) + "}");
    return;
  }

  // 4. API Cai dat suc chua toi da tu Web & App: /api/set-limit?limit=X
  if (request.indexOf("/api/set-limit") != -1) {
    int idx = request.indexOf("limit=");
    if (idx != -1) {
      int val = request.substring(idx + 6).toInt();
      if (val > 0) {
        maxCapacity = val;
        Serial.printf("[WEB] Da doi suc chua toi da thanh: %d xe\n", maxCapacity);
        showDefaultLcd();
      }
    }
    sendJsonResponse(client, "{\"success\":true,\"maxCapacity\":" + String(maxCapacity) + "}");
    return;
  }

  // 5. API Reset so xe ve 0: /api/reset hoac /api/reset-count
  if (request.indexOf("/api/reset-count") != -1 || request.indexOf("/api/reset") != -1) {
    currentCarCount = 0;
    Serial.println("[APP/WEB] Da reset so luong xe ve 0");
    closeInGate();
    closeOutGate();
    showDefaultLcd();
    sendJsonResponse(client, "{\"success\":true,\"currentCount\":0,\"maxCapacity\":" + String(maxCapacity) + "}");
    return;
  }

  // 6. TUONG THICH VOI MIT APP INVENTOR CU:
  // Xu ly cac lenh rut gon: /B1, /T1, /B2, /T2
  if (request.indexOf("/B1") != -1) {
    Serial.println("[MIT APP] Nhan lenh /B1: MO CONG VAO");
    if (currentCarCount < maxCapacity) {
      openInGate();
    } else {
      updateLcd("! BAI DA DAY !", "KHOA CONG VAO");
    }
  } else if (request.indexOf("/T1") != -1) {
    Serial.println("[MIT APP] Nhan lenh /T1: DONG CONG VAO");
    closeInGate();
  } else if (request.indexOf("/B2") != -1) {
    Serial.println("[MIT APP] Nhan lenh /B2: MO CONG RA");
    if (currentCarCount > 0) {
      openOutGate();
    } else {
      updateLcd("BAI KHONG CO XE!", "KHOA CONG RA");
    }
  } else if (request.indexOf("/T2") != -1) {
    Serial.println("[MIT APP] Nhan lenh /T2: DONG CONG RA");
    closeOutGate();
  }

  // Mac dinh tra ve trang HTML don gian neu truy cap bang trinh duyet
  drainRemainingHeaders(client);
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html; charset=utf-8");
  client.println("Connection: close");
  client.println();
  client.println("<!DOCTYPE html><html><head><meta charset='UTF-8'>");
  client.println("<title>ESP32 Bai Do Xe</title></head><body>");
  client.println("<h2>HE THONG BAI DO XE SMART ESP32</h2>");
  client.printf("<p>So xe: <b>%d / %d</b> | Con trong: <b>%d</b></p>",
                currentCarCount, maxCapacity, max(0, maxCapacity - currentCarCount));
  client.printf("<p>IP Router: <b>%s</b> | AP: <b>%s</b> (Pass: 123456789)</p>",
                WiFi.localIP().toString().c_str(), WiFi.softAPIP().toString().c_str());
  client.println("<hr><p>Su dung App Smart Parking de ket noi va dieu khien.</p>");
  client.println("</body></html>");
  client.flush();
  delay(10);
  client.stop();
}
