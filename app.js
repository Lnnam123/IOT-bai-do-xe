/**
 * Smart Parking IoT - Frontend Application Logic
 * Đếm xe tự động (+1 vào, -1 ra) qua 2 cảm biến IR & Khóa Barie khi bãi đầy
 */

// Application State
const state = {
  espIp: "192.168.1.150",
  isConnected: false,
  isDemoMode: true,
  pollInterval: null,
  maxCapacity: 4,      // Sức chứa tối đa (người dùng có thể set trên web)
  currentCount: 2,     // Số xe hiện có trong bãi
  totalRevenue: 30000,
  totalEntriesToday: 2,
  selectedSlot: null,
  gates: {
    in: false,  // false: closed (0°), true: open (90°)
    out: false
  },
  slots: [
    { id: "A1", label: "A-01", zone: "A", pin: "GPIO 13", occupied: true, plate: "30E-456.78", entryTime: new Date(Date.now() - 35 * 60 * 1000) },
    { id: "A2", label: "A-02", zone: "A", pin: "GPIO 14", occupied: false, plate: null, entryTime: null },
    { id: "B1", label: "B-01", zone: "B", pin: "GPIO 26", occupied: true, plate: "29A-888.88", entryTime: new Date(Date.now() - 75 * 60 * 1000) },
    { id: "B2", label: "B-02", zone: "B", pin: "GPIO 27", occupied: false, plate: null, entryTime: null }
  ]
};

// Realistic Vietnamese License Plate Generator
const samplePlates = [
  "29A-888.88", "30E-456.78", "51G-123.45", "43A-999.99",
  "14B-234.56", "36A-777.66", "72A-345.67", "60B-889.12",
  "29K-112.34", "30F-987.65", "50E-654.32", "15A-333.22"
];

// Pricing calculation logic (VND)
function calculateParkingFee(entryDate) {
  if (!entryDate) return 0;
  const now = new Date();
  const diffMs = Math.max(0, now - new Date(entryDate));
  const diffMinutes = Math.floor(diffMs / (1000 * 60));

  if (diffMinutes <= 30) {
    return 10000; // Giá mở cửa 30p
  }
  const additionalHours = Math.ceil((diffMinutes - 30) / 60);
  return 10000 + (additionalHours * 15000);
}

function formatDuration(entryDate) {
  if (!entryDate) return "--";
  const now = new Date();
  const diffMs = Math.max(0, now - new Date(entryDate));
  const totalSeconds = Math.floor(diffMs / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}p ${seconds}s`;
  }
  return `${minutes}p ${seconds}s`;
}

function formatCurrency(amount) {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount);
}

function getTimeString(date = new Date()) {
  return date.toLocaleTimeString('vi-VN', { hour12: false });
}

// DOM References
const elClock = document.getElementById("digitalClock");
const elConnectionBadge = document.getElementById("connectionBadge");
const elConnectionText = document.getElementById("connectionText");

const elStatMaxCapacity = document.getElementById("statMaxCapacity");
const elStatAvailableSlots = document.getElementById("statAvailableSlots");
const elStatAvailablePercent = document.getElementById("statAvailablePercent");
const elStatOccupiedSlots = document.getElementById("statOccupiedSlots");
const elStatOccupiedPercent = document.getElementById("statOccupiedPercent");
const elStatRevenue = document.getElementById("statRevenue");
const elStatTotalEntries = document.getElementById("statTotalEntries");

const elInputMaxCapacity = document.getElementById("inputMaxCapacity");
const elBtnUpdateCapacity = document.getElementById("btnUpdateCapacity");
const elCapacityProgressText = document.getElementById("capacityProgressText");
const elCapacityProgressFill = document.getElementById("capacityProgressFill");
const elFullParkingAlert = document.getElementById("fullParkingAlert");

const elZoneAGrid = document.getElementById("zoneAGrid");
const elZoneBGrid = document.getElementById("zoneBGrid");

const elInBarrier = document.getElementById("inBarrier");
const elInBarrierText = document.getElementById("inBarrierText");
const elOutBarrier = document.getElementById("outBarrier");
const elOutBarrierText = document.getElementById("outBarrierText");

const elEspIpInput = document.getElementById("espIpInput");
const elBtnConnectEsp = document.getElementById("btnConnectEsp");
const elDemoModeToggle = document.getElementById("demoModeToggle");
const elDemoActions = document.getElementById("demoActions");
const elBtnSimulateEnter = document.getElementById("btnSimulateEnter");
const elBtnSimulateLeave = document.getElementById("btnSimulateLeave");
const elBtnResetSlots = document.getElementById("btnResetSlots");
const elActivityLogList = document.getElementById("activityLogList");
const elBtnClearLog = document.getElementById("btnClearLog");

// Modal Elements
const elModal = document.getElementById("slotDetailModal");
const elModalCloseBtn = document.getElementById("modalCloseBtn");
const elModalDismissBtn = document.getElementById("modalDismissBtn");
const elModalSlotTitle = document.getElementById("modalSlotTitle");
const elModalSlotStatus = document.getElementById("modalSlotStatus");
const elModalSensorVal = document.getElementById("modalSensorVal");
const elModalPlateNumber = document.getElementById("modalPlateNumber");
const elModalCheckinTime = document.getElementById("modalCheckinTime");
const elModalDuration = document.getElementById("modalDuration");
const elModalFee = document.getElementById("modalFee");
const elModalCheckOutBtn = document.getElementById("modalCheckOutBtn");

// Initialize Clock
setInterval(() => {
  const now = new Date();
  elClock.textContent = now.toLocaleTimeString('vi-VN') + " " + now.toLocaleDateString('vi-VN');
  updateSlotTimers();
}, 1000);

// Add Activity Log Entry
function addLog(message, type = 'info') {
  const time = getTimeString();
  const logItem = document.createElement("div");
  logItem.className = `log-item ${type}`;
  logItem.innerHTML = `
    <span class="log-time">[${time}]</span>
    <span class="log-content">${message}</span>
  `;
  elActivityLogList.prepend(logItem);

  if (elActivityLogList.children.length > 50) {
    elActivityLogList.removeChild(elActivityLogList.lastChild);
  }
}

// Render Parking Grid
function renderSlots() {
  elZoneAGrid.innerHTML = "";
  elZoneBGrid.innerHTML = "";

  state.slots.forEach(slot => {
    const slotCard = document.createElement("div");
    slotCard.className = `parking-slot ${slot.occupied ? 'occupied' : 'available'}`;
    slotCard.id = `slot-card-${slot.id}`;
    slotCard.onclick = () => openSlotDetail(slot);

    let bodyContent = `
      <div class="empty-placeholder">
        <span>VỊ TRÍ TRỐNG</span>
      </div>
    `;

    let footerContent = `
      <span class="slot-plate" style="color: #64748b;">Trống</span>
      <span class="slot-timer">Sẵn sàng</span>
    `;

    if (slot.occupied) {
      bodyContent = `
        <div class="car-graphic">
          <div class="car-windshield"></div>
          <div class="car-roof"></div>
          <div class="car-rear-window"></div>
          <div class="car-lights top"></div>
          <div class="car-lights bottom"></div>
        </div>
      `;

      footerContent = `
        <span class="slot-plate">${slot.plate || "29A-XXXXX"}</span>
        <span class="slot-timer slot-timer-text" data-slot-id="${slot.id}">${formatDuration(slot.entryTime)}</span>
      `;
    }

    slotCard.innerHTML = `
      <div class="slot-header">
        <span class="slot-name">${slot.label}</span>
        <span class="slot-sensor-badge">${slot.pin}</span>
      </div>
      <div class="slot-body">
        ${bodyContent}
      </div>
      <div class="slot-footer">
        ${footerContent}
      </div>
    `;

    if (slot.zone === "A") {
      elZoneAGrid.appendChild(slotCard);
    } else {
      elZoneBGrid.appendChild(slotCard);
    }
  });

  updateStatistics();
}

// Realtime Timer Updater
function updateSlotTimers() {
  document.querySelectorAll(".slot-timer-text").forEach(el => {
    const slotId = el.getAttribute("data-slot-id");
    const slot = state.slots.find(s => s.id === slotId);
    if (slot && slot.occupied) {
      el.textContent = formatDuration(slot.entryTime);
    }
  });

  if (state.selectedSlot && state.selectedSlot.occupied) {
    elModalDuration.textContent = formatDuration(state.selectedSlot.entryTime);
    elModalFee.textContent = formatCurrency(calculateParkingFee(state.selectedSlot.entryTime));
  }
}

// Update KPI Stats Cards & Capacity Progress Bar
function updateStatistics() {
  const max = state.maxCapacity;
  const count = state.currentCount;
  const available = Math.max(0, max - count);
  const isFull = (count >= max);

  elStatMaxCapacity.textContent = max;
  elStatAvailableSlots.textContent = available;
  elStatOccupiedSlots.textContent = count;

  const fillPct = Math.min(100, Math.round((count / max) * 100));

  if (isFull) {
    elStatAvailablePercent.textContent = "BÃI ĐÃ ĐẦY!";
    elStatAvailablePercent.className = "stat-desc text-danger font-bold";
    elStatOccupiedPercent.textContent = `100% (Khóa cổng vào)`;
    elStatOccupiedPercent.className = "stat-desc text-danger font-bold";

    // Show alert banner
    elFullParkingAlert.style.display = "flex";

    // Update in-barrier text
    if (!state.gates.in) {
      elInBarrierText.textContent = "🔒 ĐÃ KHÓA (BÃI ĐẦY)";
      elInBarrierText.className = "barrier-status";
    }
  } else {
    elStatAvailablePercent.textContent = `${available} chỗ sẵn sàng`;
    elStatAvailablePercent.className = "stat-desc text-success";
    elStatOccupiedPercent.textContent = `${fillPct}% lấp đầy`;
    elStatOccupiedPercent.className = "stat-desc";

    elFullParkingAlert.style.display = "none";
    if (!state.gates.in) {
      elInBarrierText.textContent = "ĐANG ĐÓNG";
      elInBarrierText.className = "barrier-status";
    }
  }

  // Update Progress Bar
  elCapacityProgressText.textContent = `${count} / ${max} xe (${fillPct}%)`;
  elCapacityProgressFill.style.width = `${fillPct}%`;
  if (fillPct >= 100) {
    elCapacityProgressFill.style.background = "#ef4444"; // Red
  } else if (fillPct >= 75) {
    elCapacityProgressFill.style.background = "#f59e0b"; // Amber
  } else {
    elCapacityProgressFill.style.background = "#10b981"; // Green
  }

  elStatRevenue.textContent = formatCurrency(state.totalRevenue);
  elStatTotalEntries.textContent = `${state.totalEntriesToday} lượt xe hôm nay`;
}

// User saves new max capacity limit from web
elBtnUpdateCapacity.onclick = () => {
  const newLimit = parseInt(elInputMaxCapacity.value, 10);
  if (isNaN(newLimit) || newLimit < 1) {
    alert("Vui lòng nhập số lượng xe hợp lệ (> 0)!");
    return;
  }
  sendSetLimitToEsp(newLimit);
};

// Send new max capacity to ESP32
async function sendSetLimitToEsp(newLimit) {
  state.maxCapacity = newLimit;
  updateStatistics();
  addLog(`Đã cài đặt giới hạn sức chứa mới: ${newLimit} xe`, 'info');

  if (state.isConnected && !state.isDemoMode) {
    const ip = elEspIpInput.value.trim();
    try {
      const res = await fetch(`http://${ip}/api/set-limit?limit=${newLimit}`, { method: 'POST' });
      if (res.ok) {
        addLog(`Đã đồng bộ giới hạn ${newLimit} xe xuống vi điều khiển ESP32`, 'info');
      }
    } catch(err) {
      console.error("Lỗi gửi set-limit tới ESP32:", err);
    }
  }
}

// Modal Handling
function openSlotDetail(slot) {
  state.selectedSlot = slot;
  elModalSlotTitle.textContent = `Chi tiết vị trí ${slot.label} (${slot.zone === "A" ? "Khu A" : "Khu B"})`;
  elModalSensorVal.textContent = `Cảm biến nối chân ${slot.pin}`;

  if (slot.occupied) {
    elModalSlotStatus.textContent = "ĐANG CÓ XE ĐỖ";
    elModalSlotStatus.className = "badge occupied";
    elModalPlateNumber.textContent = slot.plate || "29A-XXXXX";
    elModalCheckinTime.textContent = slot.entryTime ? new Date(slot.entryTime).toLocaleTimeString('vi-VN') : "--";
    elModalDuration.textContent = formatDuration(slot.entryTime);
    elModalFee.textContent = formatCurrency(calculateParkingFee(slot.entryTime));
    elModalCheckOutBtn.style.display = "inline-block";
  } else {
    elModalSlotStatus.textContent = "ĐANG TRỐNG";
    elModalSlotStatus.className = "badge available";
    elModalPlateNumber.textContent = "Chưa có xe";
    elModalCheckinTime.textContent = "--";
    elModalDuration.textContent = "0 phút";
    elModalFee.textContent = "0 VNĐ";
    elModalCheckOutBtn.style.display = "none";
  }

  elModal.classList.add("show");
}

function closeModal() {
  elModal.classList.remove("show");
  state.selectedSlot = null;
}

elModalCloseBtn.onclick = closeModal;
elModalDismissBtn.onclick = closeModal;
window.onclick = (e) => {
  if (e.target === elModal) closeModal();
};

// Check Out Car from Modal
elModalCheckOutBtn.onclick = () => {
  if (!state.selectedSlot || !state.selectedSlot.occupied) return;
  const slot = state.selectedSlot;
  const fee = calculateParkingFee(slot.entryTime);
  const plate = slot.plate;
  
  state.totalRevenue += fee;
  if (state.currentCount > 0) state.currentCount--;
  addLog(`Xe [${plate}] rời ô ${slot.label}. Thu phí: ${formatCurrency(fee)} (Còn ${state.currentCount}/${state.maxCapacity} xe)`, 'out');
  
  slot.occupied = false;
  slot.plate = null;
  slot.entryTime = null;

  renderSlots();
  closeModal();

  triggerBarrier('out', true);
  setTimeout(() => triggerBarrier('out', false), 3500);
};

// Barrier Gate Control
function triggerBarrier(gate, open) {
  if (gate === 'in') {
    if (open) {
      // KIỂM TRA SỨC CHỨA: Nếu đầy thì KHÓA, không cho mở
      if (state.currentCount >= state.maxCapacity) {
        addLog(`[TỪ CHỐI] Bãi xe đã đầy (${state.currentCount}/${state.maxCapacity})! Barie Cổng Vào bị KHÓA.`, 'out');
        alert("BÃI XE ĐÃ ĐẦY! Không thể mở cổng vào.");
        return;
      }
      state.gates.in = true;
      elInBarrier.classList.add('open');
      elInBarrierText.textContent = "ĐANG MỞ (90°)";
      elInBarrierText.className = "barrier-status open";
      addLog("Cổng vào (In Gate) đã MỞ cho xe vào", 'gate');
    } else {
      state.gates.in = false;
      elInBarrier.classList.remove('open');
      if (state.currentCount >= state.maxCapacity) {
        elInBarrierText.textContent = "🔒 ĐÃ KHÓA (BÃI ĐẦY)";
      } else {
        elInBarrierText.textContent = "ĐANG ĐÓNG (0°)";
      }
      elInBarrierText.className = "barrier-status";
      addLog("Cổng vào (In Gate) đã ĐÓNG", 'gate');
    }
  } else if (gate === 'out') {
    if (open) {
      state.gates.out = true;
      elOutBarrier.classList.add('open');
      elOutBarrierText.textContent = "ĐANG MỞ (90°)";
      elOutBarrierText.className = "barrier-status open";
      addLog("Cổng ra (Out Gate) đã MỞ cho xe ra", 'gate');
    } else {
      state.gates.out = false;
      elOutBarrier.classList.remove('open');
      elOutBarrierText.textContent = "ĐANG ĐÓNG (0°)";
      elOutBarrierText.className = "barrier-status";
      addLog("Cổng ra (Out Gate) đã ĐÓNG", 'gate');
    }
  }

  if (state.isConnected && !state.isDemoMode) {
    sendGateCommandToEsp(gate, open ? 'open' : 'close');
  }
}

// Barrier Buttons Listeners
document.getElementById("btnOpenInGate").onclick = () => triggerBarrier('in', true);
document.getElementById("btnCloseInGate").onclick = () => triggerBarrier('in', false);
document.getElementById("btnOpenOutGate").onclick = () => triggerBarrier('out', true);
document.getElementById("btnCloseOutGate").onclick = () => triggerBarrier('out', false);

// Demo Actions: CẢM BIẾN VÀO ĐẾM XE +1 & MỞ BARIE NẾU CÒN CHỖ
function simulateCarEnter() {
  // 1. Kiểm tra giới hạn bãi đỗ
  if (state.currentCount >= state.maxCapacity) {
    alert(`🚨 CẢNH BÁO: Bãi xe đã đầy (${state.currentCount}/${state.maxCapacity} xe)!\nBarie Cổng Vào từ chối mở để không cho thêm xe vào.`);
    addLog(`[CẢM BIẾN VÀO] Phát hiện xe đến cổng nhưng BÃI ĐÃ ĐẦY (${state.currentCount}/${state.maxCapacity})! Barie KHÓA CHẶT.`, 'out');
    updateStatistics();
    return;
  }

  // 2. Còn chỗ -> Đếm +1
  state.currentCount++;
  state.totalEntriesToday++;

  // Gán vào 1 ô đỗ còn trống
  const emptySlot = state.slots.find(s => !s.occupied);
  const randomPlate = samplePlates[Math.floor(Math.random() * samplePlates.length)];

  if (emptySlot) {
    emptySlot.occupied = true;
    emptySlot.plate = randomPlate;
    emptySlot.entryTime = new Date();
  }

  addLog(`[CỔNG VÀO] Xe [${randomPlate}] qua cảm biến vào. Số xe: ${state.currentCount}/${state.maxCapacity}`, 'in');

  // Mở barie vào 3 giây rồi đóng
  triggerBarrier('in', true);
  setTimeout(() => triggerBarrier('in', false), 3500);

  renderSlots();
}

// Demo Actions: CẢM BIẾN RA ĐẾM XE -1 & MỞ BARIE RA
function simulateCarLeave() {
  if (state.currentCount <= 0) {
    alert("Hiện tại bãi xe không có xe nào!");
    return;
  }

  // Giảm 1 xe
  state.currentCount--;

  // Giải phóng 1 ô đỗ đang có xe
  const occupiedSlot = state.slots.find(s => s.occupied);
  let plate = "29X-XXXXX";
  if (occupiedSlot) {
    plate = occupiedSlot.plate || "29X-XXXXX";
    const fee = calculateParkingFee(occupiedSlot.entryTime);
    state.totalRevenue += fee;
    occupiedSlot.occupied = false;
    occupiedSlot.plate = null;
    occupiedSlot.entryTime = null;
  }

  addLog(`[CỔNG RA] Xe [${plate}] qua cảm biến ra. Số xe còn lại: ${state.currentCount}/${state.maxCapacity}`, 'out');

  // Mở barie ra 3 giây rồi đóng
  triggerBarrier('out', true);
  setTimeout(() => triggerBarrier('out', false), 3500);

  renderSlots();
}

// Reset All Slots
function resetAllSlots() {
  if (!confirm("Bạn có chắc chắn muốn đặt lại bãi xe về 0 xe?")) return;
  state.currentCount = 0;
  state.slots.forEach(slot => {
    slot.occupied = false;
    slot.plate = null;
    slot.entryTime = null;
  });
  state.totalRevenue = 0;
  state.totalEntriesToday = 0;
  addLog("Đã đặt lại bộ đếm xe về 0", 'info');
  renderSlots();

  if (state.isConnected && !state.isDemoMode) {
    const ip = elEspIpInput.value.trim();
    fetch(`http://${ip}/api/reset-count`, { method: 'POST' }).catch(e => console.error(e));
  }
}

elBtnSimulateEnter.onclick = simulateCarEnter;
elBtnSimulateLeave.onclick = simulateCarLeave;
elBtnResetSlots.onclick = resetAllSlots;
elBtnClearLog.onclick = () => {
  elActivityLogList.innerHTML = "";
  addLog("Đã xóa lịch sử nhật ký", 'info');
};

// Toggle Demo Mode Switch
elDemoModeToggle.addEventListener("change", (e) => {
  state.isDemoMode = e.target.checked;
  if (state.isDemoMode) {
    elDemoActions.style.display = "flex";
    updateConnectionStatusBadge('demo', "Chế độ Giả lập (Demo Mode)");
    stopEspPolling();
  } else {
    elDemoActions.style.display = "none";
    startEspPolling();
  }
});

function updateConnectionStatusBadge(status, text) {
  elConnectionBadge.className = `status-badge ${status}`;
  elConnectionText.textContent = text;
}

// ESP32 API Communication
async function pollEsp32() {
  if (state.isDemoMode) return;
  
  const ip = elEspIpInput.value.trim();
  if (!ip) return;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 2000);

    const response = await fetch(`http://${ip}/api/status`, { signal: controller.signal });
    clearTimeout(timeoutId);

    if (response.ok) {
      const data = await response.json();
      state.isConnected = true;
      updateConnectionStatusBadge('connected', `Đã kết nối ESP32 (${ip})`);
      syncEspData(data);
    } else {
      throw new Error("HTTP error " + response.status);
    }
  } catch (err) {
    state.isConnected = false;
    updateConnectionStatusBadge('disconnected', `Mất kết nối ESP32 (${ip})`);
  }
}

// Sync data received from ESP32 JSON
function syncEspData(data) {
  if (typeof data.maxCapacity === 'number') {
    state.maxCapacity = data.maxCapacity;
    elInputMaxCapacity.value = state.maxCapacity;
  }
  if (typeof data.currentCount === 'number') {
    state.currentCount = data.currentCount;
  }
  if (data.gates) {
    if (data.gates.in) {
      elInBarrier.classList.add('open');
      elInBarrierText.textContent = "ĐANG MỞ (90°)";
      elInBarrierText.className = "barrier-status open";
    } else {
      elInBarrier.classList.remove('open');
      elInBarrierText.textContent = (state.currentCount >= state.maxCapacity) ? "🔒 ĐÃ KHÓA (BÃI ĐẦY)" : "ĐANG ĐÓNG (0°)";
      elInBarrierText.className = "barrier-status";
    }

    if (data.gates.out) {
      elOutBarrier.classList.add('open');
      elOutBarrierText.textContent = "ĐANG MỞ (90°)";
      elOutBarrierText.className = "barrier-status open";
    } else {
      elOutBarrier.classList.remove('open');
      elOutBarrierText.textContent = "ĐANG ĐÓNG (0°)";
      elOutBarrierText.className = "barrier-status";
    }
  }

  updateStatistics();
}

// Send Gate command to ESP32
async function sendGateCommandToEsp(gate, action) {
  const ip = elEspIpInput.value.trim();
  try {
    await fetch(`http://${ip}/api/gate?gate=${gate}&action=${action}`, { method: 'POST' });
  } catch (e) {
    console.error("Lỗi khi gửi lệnh servo:", e);
  }
}

function startEspPolling() {
  stopEspPolling();
  pollEsp32();
  state.pollInterval = setInterval(pollEsp32, 1800);
}

function stopEspPolling() {
  if (state.pollInterval) {
    clearInterval(state.pollInterval);
    state.pollInterval = null;
  }
}

elBtnConnectEsp.onclick = () => {
  state.isDemoMode = false;
  elDemoModeToggle.checked = false;
  elDemoActions.style.display = "none";
  updateConnectionStatusBadge('disconnected', "Đang kết nối ESP32...");
  startEspPolling();
};

// Lắng nghe sự kiện đồng bộ từ trang mô phỏng thiết bị (so_do_ket_noi.html)
window.addEventListener('storage', (e) => {
  if (e.key === 'SIMULATED_ESP32_DATA' && state.isDemoMode && e.newValue) {
    try {
      const data = JSON.parse(e.newValue);
      syncEspData(data);
    } catch(err) {
      console.error("Lỗi parse dữ liệu mô phỏng:", err);
    }
  }
});

// Initial Setup
function init() {
  elInputMaxCapacity.value = state.maxCapacity;
  renderSlots();
  updateConnectionStatusBadge('demo', "Chế độ Giả lập (Demo Mode)");
  addLog("Hệ thống khởi động: Đếm xe tự động (+1 vào, -1 ra) & Khóa barie khi bãi đầy", 'info');
  addLog(`Sức chứa tối đa ban đầu: ${state.maxCapacity} xe | Hiện có: ${state.currentCount} xe`, 'info');
}

init();
