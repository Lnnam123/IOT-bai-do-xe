/**
 * Smart Parking IoT - Main Application Bootstrap (Vite + ES Modules)
 */
import './style.css';
import { state, setCapacity } from './state.js';
import {
  dom,
  addLog,
  updateConnectionStatusBadge,
  renderSlots,
  updateStatistics,
  updateSlotTimers,
  closeModal,
  setBarrierUi
} from './ui.js';
import {
  fetchEspStatus,
  sendCapacityLimit,
  sendCarCount,
  sendGateCommand,
  sendResetCount
} from './api.js';

// Khởi tạo đồng hồ thời gian thực
setInterval(() => {
  const now = new Date();
  if (dom.clock) {
    dom.clock.textContent = now.toLocaleTimeString('vi-VN') + " " + now.toLocaleDateString('vi-VN');
  }
  updateSlotTimers();
}, 1000);

// Xử lý điều khiển Barie
export function triggerBarrier(gate, open) {
  if (gate === 'in') {
    if (open) {
      // KIỂM TRA SỨC CHỨA: Nếu đầy thì KHÓA, không cho mở
      if (state.currentCount >= state.maxCapacity) {
        addLog(`[TỪ CHỐI] Bãi xe đã đầy (${state.currentCount}/${state.maxCapacity})! Barie Cổng Vào bị KHÓA.`, 'out');
        alert("BÃI XE ĐÃ ĐẦY! Không thể mở cổng vào.");
        return;
      }
      setBarrierUi('in', true);
      addLog("Cổng vào (In Gate) đã MỞ cho xe vào", 'gate');
    } else {
      setBarrierUi('in', false);
      addLog("Cổng vào (In Gate) đã ĐÓNG", 'gate');
    }
  } else if (gate === 'out') {
    if (open) {
      if (state.currentCount <= 0) {
        addLog(`[TỪ CHỐI] Bãi xe đang không có xe nào (0 xe)! Không thể mở Barie Cổng Ra.`, 'out');
        alert("🚨 BÃI XE KHÔNG CÓ XE!\nHiện tại bãi đang trống (0 xe), không thể mở cổng ra.");
        return;
      }
      setBarrierUi('out', true);
      addLog("Cổng ra (Out Gate) đã MỞ cho xe ra", 'gate');
    } else {
      setBarrierUi('out', false);
      addLog("Cổng ra (Out Gate) đã ĐÓNG", 'gate');
    }
  }

  if (state.isConnected && !state.isDemoMode) {
    const ip = dom.espIpInput?.value.trim() || state.espIp;
    sendGateCommand(ip, gate, open ? 'open' : 'close');
  }
}

// Giả lập xe vào (+1)
export function simulateCarEnter() {
  if (state.currentCount >= state.maxCapacity) {
    alert(`🚨 CẢNH BÁO: Bãi xe đã đầy (${state.currentCount}/${state.maxCapacity} xe)!\nBarie Cổng Vào từ chối mở để không cho thêm xe vào.`);
    addLog(`[CẢM BIẾN VÀO] Phát hiện xe đến cổng nhưng BÃI ĐÃ ĐẦY (${state.currentCount}/${state.maxCapacity})! Barie KHÓA CHẶT.`, 'out');
    updateStatistics();
    return;
  }

  state.currentCount++;
  state.totalEntriesToday++;

  const emptySlot = state.slots.find(s => !s.occupied);

  if (emptySlot) {
    emptySlot.occupied = true;
    emptySlot.entryTime = new Date();
  }

  addLog(`[CỔNG VÀO] Xe qua cảm biến vào. Số xe: ${state.currentCount}/${state.maxCapacity}`, 'in');

  triggerBarrier('in', true);
  setTimeout(() => triggerBarrier('in', false), 500);

  renderSlots();
}

// Giả lập xe ra (-1)
export function simulateCarLeave() {
  if (state.currentCount <= 0) {
    alert("Hiện tại bãi xe không có xe nào!");
    return;
  }

  state.currentCount--;

  const occupiedSlot = state.slots.find(s => s.occupied);
  if (occupiedSlot) {
    occupiedSlot.occupied = false;
    occupiedSlot.entryTime = null;
  }

  addLog(`[CỔNG RA] Xe qua cảm biến ra. Số xe còn lại: ${state.currentCount}/${state.maxCapacity}`, 'out');

  triggerBarrier('out', true);
  setTimeout(() => triggerBarrier('out', false), 500);

  renderSlots();
}

// Đặt lại bãi xe
export function resetAllSlots() {
  if (!confirm("Bạn có chắc chắn muốn đặt lại bãi xe về 0 xe?")) return;
  state.currentCount = 0;
  state.slots.forEach(slot => {
    slot.occupied = false;
    slot.entryTime = null;
  });
  addLog("Đã đặt lại bộ đếm xe về 0", 'info');
  renderSlots();

  if (state.isConnected && !state.isDemoMode) {
    const ip = dom.espIpInput?.value.trim() || state.espIp;
    sendResetCount(ip);
  }
}

// Cập nhật dữ liệu nhận từ ESP32
function syncEspData(data) {
  if (typeof data.maxCapacity === 'number') {
    if (state.maxCapacity !== data.maxCapacity) {
      setCapacity(data.maxCapacity);
      renderSlots();
    }
    if (dom.inputMaxCapacity) dom.inputMaxCapacity.value = state.maxCapacity;
  }

  if (typeof data.currentCount === 'number') {
    const newCount = Math.max(0, Math.min(state.maxCapacity, data.currentCount));
    const currentOccupied = state.slots.filter(s => s.occupied).length;

    if (newCount !== currentOccupied || state.currentCount !== newCount) {
      if (newCount > currentOccupied) {
        // Có xe mới vào -> Cập nhật ô đỗ đầu tiên còn trống thành CÓ XE (viền đỏ + icon xe)
        let toAdd = newCount - currentOccupied;
        for (let slot of state.slots) {
          if (!slot.occupied && toAdd > 0) {
            slot.occupied = true;
            slot.entryTime = new Date();
            toAdd--;
            addLog(`[ESP32] Xe vào bãi -> Đỗ tại ${slot.label}`, 'in');
          }
        }
      } else if (newCount < currentOccupied) {
        // Có xe ra -> Giải phóng ô đỗ
        let toRemove = currentOccupied - newCount;
        for (let i = state.slots.length - 1; i >= 0 && toRemove > 0; i--) {
          if (state.slots[i].occupied) {
            state.slots[i].occupied = false;
            state.slots[i].entryTime = null;
            toRemove--;
            addLog(`[ESP32] Xe ra khỏi bãi -> Giải phóng ${state.slots[i].label}`, 'out');
          }
        }
      }

      state.currentCount = newCount;
      renderSlots();
    }
  }

  if (data.gates) {
    setBarrierUi('in', !!data.gates.in);
    setBarrierUi('out', !!data.gates.out);
  }

  if (dom.inputCurrentCount && document.activeElement !== dom.inputCurrentCount) {
    dom.inputCurrentCount.value = state.currentCount;
  }

  updateStatistics();
}

// Quét định kỳ trạng thái ESP32
async function pollEsp32() {
  if (state.isDemoMode) return;

  const ip = dom.espIpInput?.value.trim() || state.espIp;
  if (!ip) return;

  try {
    const data = await fetchEspStatus(ip, 2000);
    state.isConnected = true;
    updateConnectionStatusBadge('connected', `Đã kết nối ESP32 (${ip})`);
    syncEspData(data);
  } catch {
    state.isConnected = false;
    updateConnectionStatusBadge('disconnected', `Mất kết nối ESP32 (${ip})`);
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

// Gán các sự kiện giao diện
function setupEventListeners() {
  // Nút lưu sức chứa
  if (dom.btnUpdateCapacity) {
    dom.btnUpdateCapacity.onclick = async () => {
      const newLimit = parseInt(dom.inputMaxCapacity?.value, 10);
      if (isNaN(newLimit) || newLimit < 1) {
        alert("Vui lòng nhập số lượng xe hợp lệ (> 0)!");
        return;
      }
      setCapacity(newLimit);
      renderSlots();
      updateStatistics();
      addLog(`Đã cài đặt giới hạn sức chứa mới: ${newLimit} ô đỗ`, 'info');

      if (state.isConnected && !state.isDemoMode) {
        const ip = dom.espIpInput?.value.trim() || state.espIp;
        const ok = await sendCapacityLimit(ip, newLimit);
        if (ok) {
          addLog(`Đã đồng bộ giới hạn ${newLimit} xe xuống vi điều khiển ESP32`, 'info');
        }
      }
    };
  }

  // Nút điều chỉnh số lượng xe hiện tại trong bãi
  if (dom.btnUpdateCurrentCount) {
    dom.btnUpdateCurrentCount.onclick = async () => {
      const newCount = parseInt(dom.inputCurrentCount?.value, 10);
      if (isNaN(newCount) || newCount < 0) {
        alert("Vui lòng nhập số lượng xe hợp lệ (>= 0)!");
        return;
      }
      if (newCount > state.maxCapacity) {
        alert(`Số xe (${newCount}) không được vượt quá sức chứa tối đa (${state.maxCapacity} xe)!`);
        return;
      }

      state.currentCount = newCount;
      // Cập nhật trạng thái các ô đỗ
      state.slots.forEach((slot, index) => {
        if (index < newCount) {
          if (!slot.occupied) {
            slot.occupied = true;
            slot.entryTime = new Date();
          }
        } else {
          slot.occupied = false;
          slot.entryTime = null;
        }
      });

      renderSlots();
      updateStatistics();
      addLog(`[CẤU HÌNH] Đã điều chỉnh số xe trong bãi: ${newCount} xe`, 'info');

      if (state.isConnected && !state.isDemoMode) {
        const ip = dom.espIpInput?.value.trim() || state.espIp;
        const ok = await sendCarCount(ip, newCount);
        if (ok) {
          addLog(`Đã đồng bộ số xe (${newCount} xe) xuống vi điều khiển ESP32`, 'info');
        } else {
          addLog(`Không thể gửi số xe tới ESP32, vui lòng kiểm tra kết nối`, 'warning');
        }
      }
    };
  }

  // Tự động cập nhật tức thì khi nhập số lượng ô đỗ
  dom.inputMaxCapacity?.addEventListener('input', (e) => {
    const newLimit = parseInt(e.target.value, 10);
    if (!isNaN(newLimit) && newLimit > 0) {
      setCapacity(newLimit);
      renderSlots();
      updateStatistics();
    }
  });

  // Điều khiển cổng vào / ra
  dom.btnOpenInGate?.addEventListener('click', () => triggerBarrier('in', true));
  dom.btnCloseInGate?.addEventListener('click', () => triggerBarrier('in', false));
  dom.btnOpenOutGate?.addEventListener('click', () => triggerBarrier('out', true));
  dom.btnCloseOutGate?.addEventListener('click', () => triggerBarrier('out', false));

  // Giả lập Demo
  dom.btnSimulateEnter?.addEventListener('click', simulateCarEnter);
  dom.btnSimulateLeave?.addEventListener('click', simulateCarLeave);
  dom.btnResetSlots?.addEventListener('click', resetAllSlots);
  dom.btnClearLog?.addEventListener('click', () => {
    if (dom.activityLogList) dom.activityLogList.innerHTML = "";
    addLog("Đã xóa lịch sử nhật ký", 'info');
  });

  // Chuyển đổi chế độ Demo
  dom.demoModeToggle?.addEventListener('change', (e) => {
    state.isDemoMode = e.target.checked;
    if (state.isDemoMode) {
      if (dom.demoActions) dom.demoActions.style.display = "flex";
      updateConnectionStatusBadge('demo', "Chế độ Giả lập (Demo Mode)");
      stopEspPolling();
    } else {
      if (dom.demoActions) dom.demoActions.style.display = "none";
      startEspPolling();
    }
  });

  // Nút kết nối ESP32
  dom.btnConnectEsp?.addEventListener('click', () => {
    state.isDemoMode = false;
    if (dom.demoModeToggle) dom.demoModeToggle.checked = false;
    if (dom.demoActions) dom.demoActions.style.display = "none";
    updateConnectionStatusBadge('disconnected', "Đang kết nối ESP32...");
    startEspPolling();
  });

  // Modal
  dom.modalCloseBtn?.addEventListener('click', closeModal);
  dom.modalDismissBtn?.addEventListener('click', closeModal);
  window.addEventListener('click', (e) => {
    if (e.target === dom.modal) closeModal();
  });

  // Cho xe rời ô đỗ từ Modal
  dom.modalCheckOutBtn?.addEventListener('click', () => {
    if (!state.selectedSlot || !state.selectedSlot.occupied) return;
    const slot = state.selectedSlot;

    if (state.currentCount > 0) state.currentCount--;
    addLog(`Xe rời ô ${slot.label} (Còn lại ${state.currentCount}/${state.maxCapacity} xe trong bãi)`, 'out');

    slot.occupied = false;
    slot.entryTime = null;

    renderSlots();
    closeModal();

    triggerBarrier('out', true);
    setTimeout(() => triggerBarrier('out', false), 3500);
  });

  // Đồng bộ qua localStorage từ trang mô phỏng sa bàn (so_do_ket_noi.html)
  window.addEventListener('storage', (e) => {
    if (e.key === 'SIMULATED_ESP32_DATA' && state.isDemoMode && e.newValue) {
      try {
        const data = JSON.parse(e.newValue);
        syncEspData(data);
      } catch (err) {
        console.error("Lỗi parse dữ liệu mô phỏng:", err);
      }
    }
  });
}

// Khởi chạy ứng dụng
function init() {
  if (dom.inputMaxCapacity) dom.inputMaxCapacity.value = state.maxCapacity;
  renderSlots();
  updateConnectionStatusBadge('demo', "Chế độ Giả lập (Demo Mode)");
  addLog("Hệ thống khởi động: Đếm xe tự động (+1 vào, -1 ra) & Khóa barie khi bãi đầy", 'info');
  addLog(`Sức chứa tối đa ban đầu: ${state.maxCapacity} xe | Hiện có: ${state.currentCount} xe`, 'info');
  setupEventListeners();
}

// Khi DOM sẵn sàng
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
