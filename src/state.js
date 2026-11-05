/**
 * Smart Parking IoT - Global State & Dynamic Slot Generator
 */

/**
 * Sinh danh sách ô đỗ tự động theo sức chứa tối đa.
 * Gộp thành một khu vực duy nhất, cứ 5 ô thì tự động xuống hàng tiếp theo.
 */
export function createDefaultSlots(maxCapacity, existingSlots = []) {
  const samplePins = [
    "GPIO 13", "GPIO 14", "GPIO 26", "GPIO 27", "GPIO 25",
    "GPIO 32", "GPIO 33", "GPIO 15", "GPIO 4", "GPIO 16",
    "GPIO 18", "GPIO 19", "GPIO 21", "GPIO 22", "GPIO 23",
    "GPIO 5", "GPIO 17", "GPIO 12", "GPIO 34", "GPIO 35"
  ];

  const newSlots = [];

  for (let i = 1; i <= maxCapacity; i++) {
    const id = `S${i}`;
    const label = `Ô-${String(i).padStart(2, '0')}`;
    const existing = existingSlots.find(s => s.id === id || s.label === label);
    newSlots.push({
      id,
      label,
      pin: samplePins[(i - 1) % samplePins.length],
      occupied: existing ? existing.occupied : false,
      entryTime: existing ? existing.entryTime : null
    });
  }

  return newSlots;
}

// Global Application State (Khởi tạo mặc định 10 ô đỗ)
export const state = {
  espIp: "192.168.1.150",
  isConnected: false,
  isDemoMode: true,
  pollInterval: null,
  maxCapacity: 10,     // Mặc định 10 ô đỗ
  currentCount: 2,     // 2 xe khởi tạo đang đỗ
  selectedSlot: null,
  gates: {
    in: false,  // false: closed (0°), true: open (90°)
    out: false
  },
  slots: createDefaultSlots(10, [
    { id: "S1", label: "Ô-01", pin: "GPIO 13", occupied: true, entryTime: new Date(Date.now() - 35 * 60 * 1000) },
    { id: "S2", label: "Ô-02", pin: "GPIO 14", occupied: true, entryTime: new Date(Date.now() - 75 * 60 * 1000) }
  ])
};

/**
 * Cập nhật sức chứa tối đa và tự động tái tạo danh sách ô đỗ
 */
export function setCapacity(newLimit) {
  state.maxCapacity = newLimit;
  state.slots = createDefaultSlots(newLimit, state.slots);

  // Đảm bảo số xe đang đỗ không vượt quá số ô
  const occupiedSlots = state.slots.filter(s => s.occupied);
  if (occupiedSlots.length > newLimit) {
    let removed = 0;
    const toRemove = occupiedSlots.length - newLimit;
    for (let i = state.slots.length - 1; i >= 0 && removed < toRemove; i--) {
      if (state.slots[i].occupied) {
        state.slots[i].occupied = false;
        state.slots[i].entryTime = null;
        removed++;
      }
    }
  }
  state.currentCount = state.slots.filter(s => s.occupied).length;
}

// Pricing calculation logic (VND)
export function calculateParkingFee(entryDate) {
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

export function formatDuration(entryDate) {
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

export function formatCurrency(amount) {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount);
}

export function getTimeString(date = new Date()) {
  return date.toLocaleTimeString('vi-VN', { hour12: false });
}
