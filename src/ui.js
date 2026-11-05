/**
 * Smart Parking IoT - UI Rendering & DOM Controller
 */
import { state, formatCurrency, formatDuration, getTimeString, calculateParkingFee } from './state.js';

// DOM Elements Cache
export const dom = {
  clock: document.getElementById("digitalClock"),
  connectionBadge: document.getElementById("connectionBadge"),
  connectionText: document.getElementById("connectionText"),

  statMaxCapacity: document.getElementById("statMaxCapacity"),
  statAvailableSlots: document.getElementById("statAvailableSlots"),
  statAvailablePercent: document.getElementById("statAvailablePercent"),
  statOccupiedSlots: document.getElementById("statOccupiedSlots"),
  statOccupiedPercent: document.getElementById("statOccupiedPercent"),

  inputMaxCapacity: document.getElementById("inputMaxCapacity"),
  btnUpdateCapacity: document.getElementById("btnUpdateCapacity"),
  capacityProgressText: document.getElementById("capacityProgressText"),
  capacityProgressFill: document.getElementById("capacityProgressFill"),
  fullParkingAlert: document.getElementById("fullParkingAlert"),

  slotsGrid: document.getElementById("slotsGrid"),

  inBarrier: document.getElementById("inBarrier"),
  inBarrierText: document.getElementById("inBarrierText"),
  outBarrier: document.getElementById("outBarrier"),
  outBarrierText: document.getElementById("outBarrierText"),

  espIpInput: document.getElementById("espIpInput"),
  btnConnectEsp: document.getElementById("btnConnectEsp"),
  demoModeToggle: document.getElementById("demoModeToggle"),
  demoActions: document.getElementById("demoActions"),
  btnSimulateEnter: document.getElementById("btnSimulateEnter"),
  btnSimulateLeave: document.getElementById("btnSimulateLeave"),
  btnResetSlots: document.getElementById("btnResetSlots"),
  activityLogList: document.getElementById("activityLogList"),
  btnClearLog: document.getElementById("btnClearLog"),

  btnOpenInGate: document.getElementById("btnOpenInGate"),
  btnCloseInGate: document.getElementById("btnCloseInGate"),
  btnOpenOutGate: document.getElementById("btnOpenOutGate"),
  btnCloseOutGate: document.getElementById("btnCloseOutGate"),

  // Modal
  modal: document.getElementById("slotDetailModal"),
  modalCloseBtn: document.getElementById("modalCloseBtn"),
  modalDismissBtn: document.getElementById("modalDismissBtn"),
  modalSlotTitle: document.getElementById("modalSlotTitle"),
  modalSlotStatus: document.getElementById("modalSlotStatus"),
  modalSensorVal: document.getElementById("modalSensorVal"),
  modalCheckinTime: document.getElementById("modalCheckinTime"),
  modalDuration: document.getElementById("modalDuration"),
  modalCheckOutBtn: document.getElementById("modalCheckOutBtn")
};

/**
 * Thêm một dòng ghi chú vào nhật ký xe ra vào
 */
export function addLog(message, type = 'info') {
  if (!dom.activityLogList) return;
  const time = getTimeString();
  const logItem = document.createElement("div");
  logItem.className = `log-item ${type}`;

  let iconName = 'info';
  if (type === 'in') iconName = 'login';
  else if (type === 'out') iconName = 'logout';
  else if (type === 'gate') iconName = 'fence';

  logItem.innerHTML = `
    <span class="log-icon-wrap ${type}">
      <span class="material-symbols-rounded" style="font-size:16px;">${iconName}</span>
    </span>
    <span class="log-time">[${time}]</span>
    <span class="log-content">${message}</span>
  `;
  dom.activityLogList.prepend(logItem);

  if (dom.activityLogList.children.length > 50) {
    dom.activityLogList.removeChild(dom.activityLogList.lastChild);
  }
}

/**
 * Cập nhật trạng thái badge kết nối ESP32
 */
export function updateConnectionStatusBadge(status, text) {
  if (!dom.connectionBadge || !dom.connectionText) return;
  dom.connectionBadge.className = `status-badge ${status}`;
  dom.connectionText.textContent = text;
}

/**
 * Vẽ lại danh sách toàn bộ ô đỗ xe trong bãi (5 ô / hàng)
 */
export function renderSlots() {
  const container = dom.slotsGrid || document.getElementById("slotsGrid");
  if (!container) return;
  container.innerHTML = "";

  state.slots.forEach(slot => {
    const slotCard = document.createElement("div");
    slotCard.className = `parking-slot ${slot.occupied ? 'occupied' : 'available'}`;
    slotCard.id = `slot-card-${slot.id}`;
    slotCard.onclick = () => openSlotDetail(slot);

    let bodyContent = `
      <div class="empty-placeholder">
        <span class="material-symbols-rounded" style="font-size:22px;">check_circle</span>
        <span>VỊ TRÍ TRỐNG</span>
      </div>
    `;

    let footerContent = `
      <span class="slot-status-text text-success">
        <span class="material-symbols-rounded" style="font-size:14px; margin-right:3px;">check_circle</span>
        Ô trống
      </span>
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
        <span class="slot-status-text text-danger font-bold">
          <span class="material-symbols-rounded" style="font-size:14px; margin-right:3px;">directions_car</span>
          Đang đỗ
        </span>
        <span class="slot-timer slot-timer-text" data-slot-id="${slot.id}">
          <span class="material-symbols-rounded" style="font-size:13px; margin-right:2px; vertical-align:middle;">schedule</span>
          ${formatDuration(slot.entryTime)}
        </span>
      `;
    }

    slotCard.innerHTML = `
      <div class="slot-header">
        <span class="slot-name">${slot.label}</span>
        <span class="slot-sensor-badge">
          <span class="material-symbols-rounded" style="font-size:11px; margin-right:3px;">sensors</span>
          ${slot.pin}
        </span>
      </div>
      <div class="slot-body">
        ${bodyContent}
      </div>
      <div class="slot-footer">
        ${footerContent}
      </div>
    `;

    container.appendChild(slotCard);
  });

  updateStatistics();
}

/**
 * Cập nhật các chỉ số thống kê & thanh tiến trình sức chứa
 */
export function updateStatistics() {
  const max = state.maxCapacity;
  const count = state.currentCount;
  const available = Math.max(0, max - count);
  const isFull = (count >= max);

  if (dom.statMaxCapacity) dom.statMaxCapacity.textContent = max;
  if (dom.statAvailableSlots) dom.statAvailableSlots.textContent = available;
  if (dom.statOccupiedSlots) dom.statOccupiedSlots.textContent = count;

  const fillPct = Math.min(100, Math.round((count / max) * 100));

  if (isFull) {
    if (dom.statAvailablePercent) {
      dom.statAvailablePercent.textContent = "BÃI ĐÃ ĐẦY";
      dom.statAvailablePercent.className = "stat-badge purple text-danger font-bold";
    }
    if (dom.statOccupiedPercent) {
      dom.statOccupiedPercent.textContent = `100% (Khóa cổng)`;
      dom.statOccupiedPercent.className = "stat-badge blue text-danger font-bold";
    }

    // Hiển thị banner cảnh báo
    if (dom.fullParkingAlert) dom.fullParkingAlert.style.display = "flex";

    // Khóa barie vào nếu đang đóng
    if (!state.gates.in && dom.inBarrierText) {
      dom.inBarrierText.textContent = "🔒 ĐÃ KHÓA (BÃI ĐẦY)";
      dom.inBarrierText.className = "barrier-status";
    }
  } else {
    if (dom.statAvailablePercent) {
      dom.statAvailablePercent.textContent = `${available} chỗ sẵn sàng`;
      dom.statAvailablePercent.className = "stat-badge green";
    }
    if (dom.statOccupiedPercent) {
      dom.statOccupiedPercent.textContent = `${fillPct}% lấp đầy`;
      dom.statOccupiedPercent.className = "stat-badge blue";
    }

    if (dom.fullParkingAlert) dom.fullParkingAlert.style.display = "none";
    if (!state.gates.in && dom.inBarrierText) {
      dom.inBarrierText.textContent = "ĐANG ĐÓNG (0°)";
      dom.inBarrierText.className = "barrier-status";
    }
  }

  // Cập nhật thanh tiến trình
  if (dom.capacityProgressText) dom.capacityProgressText.textContent = `${count} / ${max} xe (${fillPct}%)`;
  if (dom.capacityProgressFill) {
    dom.capacityProgressFill.style.width = `${fillPct}%`;
    if (fillPct >= 100) {
      dom.capacityProgressFill.style.background = "#ef4444"; // Đỏ
    } else if (fillPct >= 75) {
      dom.capacityProgressFill.style.background = "#f59e0b"; // Vàng
    } else {
      dom.capacityProgressFill.style.background = "#10b981"; // Xanh
    }
  }
}

/**
 * Cập nhật thời gian đã đỗ
 */
export function updateSlotTimers() {
  document.querySelectorAll(".slot-timer-text").forEach(el => {
    const slotId = el.getAttribute("data-slot-id");
    const slot = state.slots.find(s => s.id === slotId);
    if (slot && slot.occupied) {
      el.textContent = formatDuration(slot.entryTime);
    }
  });

  if (state.selectedSlot && state.selectedSlot.occupied) {
    if (dom.modalDuration) dom.modalDuration.textContent = formatDuration(state.selectedSlot.entryTime);
  }
}

/**
 * Mở modal thông tin chi tiết ô đỗ
 */
export function openSlotDetail(slot) {
  state.selectedSlot = slot;
  if (!dom.modal) return;

  dom.modalSlotTitle.textContent = `Chi tiết ô đỗ ${slot.label}`;
  dom.modalSensorVal.textContent = `Cảm biến nối chân ${slot.pin}`;

  if (slot.occupied) {
    dom.modalSlotStatus.textContent = "ĐANG CÓ XE ĐỖ";
    dom.modalSlotStatus.className = "badge occupied";
    dom.modalCheckinTime.textContent = slot.entryTime ? new Date(slot.entryTime).toLocaleTimeString('vi-VN') : "--";
    dom.modalDuration.textContent = formatDuration(slot.entryTime);
    dom.modalCheckOutBtn.style.display = "inline-block";
  } else {
    dom.modalSlotStatus.textContent = "ĐANG TRỐNG";
    dom.modalSlotStatus.className = "badge available";
    dom.modalCheckinTime.textContent = "--";
    dom.modalDuration.textContent = "0 phút";
    dom.modalCheckOutBtn.style.display = "none";
  }

  dom.modal.classList.add("show");
}

/**
 * Đóng modal
 */
export function closeModal() {
  if (dom.modal) dom.modal.classList.remove("show");
  state.selectedSlot = null;
}

/**
 * Cập nhật trạng thái hiển thị của Barie (Cổng vào / Cổng ra)
 */
export function setBarrierUi(gate, isOpen) {
  if (gate === 'in') {
    state.gates.in = isOpen;
    if (isOpen) {
      dom.inBarrier?.classList.add('open');
      if (dom.inBarrierText) {
        dom.inBarrierText.textContent = "ĐANG MỞ (90°)";
        dom.inBarrierText.className = "barrier-status open";
      }
    } else {
      dom.inBarrier?.classList.remove('open');
      if (dom.inBarrierText) {
        dom.inBarrierText.textContent = (state.currentCount >= state.maxCapacity) ? "🔒 ĐÃ KHÓA (BÃI ĐẦY)" : "ĐANG ĐÓNG (0°)";
        dom.inBarrierText.className = "barrier-status";
      }
    }
  } else if (gate === 'out') {
    state.gates.out = isOpen;
    if (isOpen) {
      dom.outBarrier?.classList.add('open');
      if (dom.outBarrierText) {
        dom.outBarrierText.textContent = "ĐANG MỞ (90°)";
        dom.outBarrierText.className = "barrier-status open";
      }
    } else {
      dom.outBarrier?.classList.remove('open');
      if (dom.outBarrierText) {
        dom.outBarrierText.textContent = "ĐANG ĐÓNG (0°)";
        dom.outBarrierText.className = "barrier-status";
      }
    }
  }
}
