/**
 * Smart Parking IoT - Sơ đồ đấu nối & Chạy thử mô phỏng
 */
import './schematic.css';

let simMax = 3;
let simCount = 0;
let isGateInOpen = false;
let isGateOutOpen = false;

let elSimMaxInput, elSimCountText, elSimFullBadge, elInCard;
let elLedIn, elTextIrIn, elTextBarrierIn, elArmIn;
let elLedOut, elTextIrOut, elTextBarrierOut, elArmOut, elSerial;

export function logSerial(msg, type = '') {
  if (!elSerial) return;
  const now = new Date().toLocaleTimeString('vi-VN');
  const line = document.createElement("div");
  line.className = `serial-line ${type}`;
  line.textContent = `[${now}] ${msg}`;
  elSerial.appendChild(line);
  elSerial.scrollTop = elSerial.scrollHeight;
}

export function updateUi() {
  if (!elSimCountText) return;
  elSimCountText.textContent = `${simCount} / ${simMax}`;
  const isFull = (simCount >= simMax);

  if (isFull) {
    if (elSimFullBadge) elSimFullBadge.style.display = "inline-block";
    if (elInCard) elInCard.classList.add("locked");
    if (!isGateInOpen && elTextBarrierIn) {
      elTextBarrierIn.textContent = "🔒 ĐÃ KHÓA (BÃI ĐẦY)";
      elTextBarrierIn.style.color = "#ef4444";
    }
  } else {
    if (elSimFullBadge) elSimFullBadge.style.display = "none";
    if (elInCard) elInCard.classList.remove("locked");
    if (!isGateInOpen && elTextBarrierIn) {
      elTextBarrierIn.textContent = "ĐANG ĐÓNG (0°)";
      elTextBarrierIn.style.color = "#10b981";
    }
  }

  // Đồng bộ qua localStorage cho trang giám sát chính
  try {
    localStorage.setItem("SIMULATED_ESP32_DATA", JSON.stringify({
      currentCount: simCount,
      maxCapacity: simMax,
      isFull: isFull,
      gates: { in: isGateInOpen, out: isGateOutOpen }
    }));
  } catch {
    // Bỏ qua lỗi storage
  }
}

export function setSimCapacity() {
  if (!elSimMaxInput) return;
  const val = parseInt(elSimMaxInput.value, 10);
  if (!isNaN(val) && val > 0) {
    simMax = val;
    logSerial(`[CẤU HÌNH] Cập nhật sức chứa tối đa: ${simMax} xe`, 'warning');
    updateUi();
  }
}

export function simulateCarArriveIn() {
  // 1. Nhấp nháy LED cảm biến vào
  if (elLedIn) elLedIn.classList.add("active");
  if (elTextIrIn) elTextIrIn.textContent = "Cảm biến vào: CÓ XE ĐẾN (LOW)";

  setTimeout(() => {
    if (elLedIn) elLedIn.classList.remove("active");
    if (elTextIrIn) elTextIrIn.textContent = "Cảm biến vào: Không có xe";
  }, 1500);

  // 2. Kiểm tra sức chứa
  if (simCount >= simMax) {
    logSerial(`[CẢNH BÁO] Xe đến cổng vào nhưng BÃI ĐÃ ĐẦY (${simCount}/${simMax})! TỪ CHỐI MỞ BARIE.`, 'danger');
    alert(`🚨 BÃI ĐỖ XE ĐÃ ĐẦY (${simCount}/${simMax} xe)!\nServo Cổng Vào (GPIO 18) đã KHÓA, không cho xe vào.`);
    updateUi();
    return;
  }

  // Còn chỗ -> Đếm +1 & Mở Servo
  simCount++;
  logSerial(`[CỔNG VÀO] Xe vào -> Đếm +1 (Hiện tại: ${simCount}/${simMax}). Mở Barie vào 90 độ!`, 'success');

  isGateInOpen = true;
  if (elArmIn) elArmIn.classList.add("open");
  if (elTextBarrierIn) {
    elTextBarrierIn.textContent = "ĐANG MỞ (90°)";
    elTextBarrierIn.style.color = "#10b981";
  }
  updateUi();

  // Tự động đóng sau 3.5 giây
  setTimeout(() => {
    isGateInOpen = false;
    if (elArmIn) elArmIn.classList.remove("open");
    logSerial(`[BARIE] Cổng Vào: Đã đóng về 0 độ`);
    updateUi();
  }, 3500);
}

export function simulateCarArriveOut() {
  if (simCount <= 0) {
    alert("Bãi xe hiện đang không có xe nào!");
    return;
  }

  // Nhấp nháy LED cảm biến ra
  if (elLedOut) elLedOut.classList.add("active");
  if (elTextIrOut) elTextIrOut.textContent = "Cảm biến ra: CÓ XE RA (LOW)";

  setTimeout(() => {
    if (elLedOut) elLedOut.classList.remove("active");
    if (elTextIrOut) elTextIrOut.textContent = "Cảm biến ra: Không có xe";
  }, 1500);

  // Đếm -1 & Mở Servo ra
  simCount--;
  logSerial(`[CỔNG RA] Xe ra -> Đếm -1 (Hiện tại: ${simCount}/${simMax}). Mở Barie ra 90 độ!`, 'success');

  isGateOutOpen = true;
  if (elArmOut) elArmOut.classList.add("open");
  if (elTextBarrierOut) {
    elTextBarrierOut.textContent = "ĐANG MỞ (90°)";
    elTextBarrierOut.style.color = "#10b981";
  }
  updateUi();

  setTimeout(() => {
    isGateOutOpen = false;
    if (elArmOut) elArmOut.classList.remove("open");
    if (elTextBarrierOut) {
      elTextBarrierOut.textContent = "ĐANG ĐÓNG (0°)";
      elTextBarrierOut.style.color = "#10b981";
    }
    logSerial(`[BARIE] Cổng Ra: Đã đóng về 0 độ`);
    updateUi();
  }, 3500);
}

function initSchematic() {
  elSimMaxInput = document.getElementById("simMaxInput");
  elSimCountText = document.getElementById("simCountText");
  elSimFullBadge = document.getElementById("simFullBadge");
  elInCard = document.getElementById("simInGateCard");
  elLedIn = document.getElementById("ledIn");
  elTextIrIn = document.getElementById("textIrIn");
  elTextBarrierIn = document.getElementById("textBarrierIn");
  elArmIn = document.getElementById("armIn");

  elLedOut = document.getElementById("ledOut");
  elTextIrOut = document.getElementById("textIrOut");
  elTextBarrierOut = document.getElementById("textBarrierOut");
  elArmOut = document.getElementById("armOut");
  elSerial = document.getElementById("simSerial");

  // Gán sự kiện cho các nút
  document.getElementById("btnUpdateSimCap")?.addEventListener("click", setSimCapacity);
  document.getElementById("btnSimIn")?.addEventListener("click", simulateCarArriveIn);
  document.getElementById("btnSimOut")?.addEventListener("click", simulateCarArriveOut);

  // Expose to window if onclick in HTML is used
  window.setSimCapacity = setSimCapacity;
  window.simulateCarArriveIn = simulateCarArriveIn;
  window.simulateCarArriveOut = simulateCarArriveOut;

  updateUi();
  logSerial("Mô phỏng khởi động: Đếm xe & Khóa barie ESP32 đã sẵn sàng");
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initSchematic);
} else {
  initSchematic();
}
