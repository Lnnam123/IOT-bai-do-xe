/**
 * Smart Parking IoT - ESP32 & Node.js Backend API Service
 */

/**
 * Fetch current status from ESP32 or fallback backend proxy
 * @param {string} ip - ESP32 IP address
 * @param {number} timeoutMs - Timeout in milliseconds
 */
export async function fetchEspStatus(ip, timeoutMs = 2500) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    // 1. Thử gọi trực tiếp ESP32
    const res = await fetch(`http://${ip}/api/status`, {
      signal: controller.signal,
      mode: 'cors'
    });
    clearTimeout(timeoutId);

    if (res.ok) {
      return await res.json();
    }
    throw new Error(`HTTP ${res.status}`);
  } catch (err) {
    clearTimeout(timeoutId);

    // 2. Nếu thất bại do CORS hoặc mạng nội bộ, thử proxy qua Node.js backend
    try {
      const proxyRes = await fetch(`/api/esp32/proxy?target=${encodeURIComponent(`http://${ip}/api/status`)}`);
      if (proxyRes.ok) {
        return await proxyRes.json();
      }
    } catch {
      // Bỏ qua lỗi proxy
    }

    throw err;
  }
}

/**
 * Cập nhật giới hạn sức chứa tối đa tới ESP32
 * @param {string} ip
 * @param {number} limit
 */
export async function sendCapacityLimit(ip, limit) {
  try {
    const res = await fetch(`http://${ip}/api/set-limit?limit=${limit}`, {
      method: 'POST',
      mode: 'cors'
    });
    if (res.ok) return true;
  } catch {
    // Fallback qua proxy
    try {
      const proxyRes = await fetch(`/api/esp32/proxy?target=${encodeURIComponent(`http://${ip}/api/set-limit?limit=${limit}`)}`, {
        method: 'POST'
      });
      return proxyRes.ok;
    } catch {
      return false;
    }
  }
  return false;
}

/**
 * Điều khiển đóng/mở barie (Servo)
 * @param {string} ip
 * @param {'in'|'out'} gate
 * @param {'open'|'close'} action
 */
export async function sendGateCommand(ip, gate, action) {
  try {
    const res = await fetch(`http://${ip}/api/gate?gate=${gate}&action=${action}`, {
      method: 'POST',
      mode: 'cors'
    });
    if (res.ok) return true;
  } catch {
    try {
      const proxyRes = await fetch(`/api/esp32/proxy?target=${encodeURIComponent(`http://${ip}/api/gate?gate=${gate}&action=${action}`)}`, {
        method: 'POST'
      });
      return proxyRes.ok;
    } catch {
      return false;
    }
  }
  return false;
}

/**
 * Điều chỉnh số lượng xe hiện có trong bãi tới ESP32
 * @param {string} ip
 * @param {number} count
 */
export async function sendCarCount(ip, count) {
  try {
    const res = await fetch(`http://${ip}/api/set-count?count=${count}`, {
      method: 'POST',
      mode: 'cors'
    });
    if (res.ok) return true;
  } catch {
    try {
      const proxyRes = await fetch(`/api/esp32/proxy?target=${encodeURIComponent(`http://${ip}/api/set-count?count=${count}`)}`, {
        method: 'POST'
      });
      return proxyRes.ok;
    } catch {
      return false;
    }
  }
  return false;
}

/**
 * Đặt lại số đếm xe về 0 trên ESP32
 * @param {string} ip
 */
export async function sendResetCount(ip) {
  try {
    const res = await fetch(`http://${ip}/api/reset-count`, {
      method: 'POST',
      mode: 'cors'
    });
    if (res.ok) return true;
  } catch {
    try {
      const proxyRes = await fetch(`/api/esp32/proxy?target=${encodeURIComponent(`http://${ip}/api/reset-count`)}`, {
        method: 'POST'
      });
      return proxyRes.ok;
    } catch {
      return false;
    }
  }
  return false;
}
