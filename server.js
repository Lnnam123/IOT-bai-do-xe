/**
 * Smart Parking IoT - Node.js Express Backend Server & ESP32 Gateway
 */
import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// In-Memory Parking State (Mô phỏng bộ nhớ của hệ thống)
const parkingState = {
  maxCapacity: 10,
  currentCount: 0,
  gates: {
    in: false,  // false: 0 deg (close), true: 90 deg (open)
    out: false
  },
  lastUpdate: new Date().toISOString()
};

// Logging middleware
app.use((req, res, next) => {
  const timestamp = new Date().toLocaleTimeString('vi-VN');
  console.log(`[${timestamp}] ${req.method} ${req.url}`);
  next();
});

// ==================== REST API ENDPOINTS ====================

/**
 * GET /api/status
 * Trả về trạng thái bãi xe hiện tại
 */
app.get('/api/status', (req, res) => {
  res.json({
    status: 'success',
    maxCapacity: parkingState.maxCapacity,
    currentCount: parkingState.currentCount,
    availableSlots: Math.max(0, parkingState.maxCapacity - parkingState.currentCount),
    isFull: parkingState.currentCount >= parkingState.maxCapacity,
    gates: parkingState.gates,
    timestamp: new Date().toISOString()
  });
});

/**
 * POST /api/set-limit?limit=X
 * Cài đặt sức chứa tối đa
 */
app.post('/api/set-limit', (req, res) => {
  const limit = parseInt(req.query.limit || req.body.limit, 10);
  if (isNaN(limit) || limit < 1) {
    return res.status(400).json({ error: 'Giới hạn không hợp lệ (> 0)' });
  }

  parkingState.maxCapacity = limit;
  parkingState.lastUpdate = new Date().toISOString();
  console.log(`[CẤU HÌNH] Đã cập nhật sức chứa tối đa: ${parkingState.maxCapacity} xe`);

  res.json({
    status: 'success',
    message: `Đã cập nhật sức chứa: ${limit} xe`,
    maxCapacity: parkingState.maxCapacity,
    isFull: parkingState.currentCount >= parkingState.maxCapacity
  });
});

/**
 * POST /api/gate?gate=in|out&action=open|close
 * Điều khiển Servo cổng barie
 */
app.post('/api/gate', (req, res) => {
  const gate = req.query.gate || req.body.gate;
  const action = req.query.action || req.body.action;

  if (gate !== 'in' && gate !== 'out') {
    return res.status(400).json({ error: 'Tham số gate phải là in hoặc out' });
  }

  const isOpen = (action === 'open');

  // Kiểm tra nếu mở cổng vào mà bãi đã đầy -> TỪ CHỐI
  if (gate === 'in' && isOpen && parkingState.currentCount >= parkingState.maxCapacity) {
    console.log(`[TỪ CHỐI] Bãi xe đã đầy (${parkingState.currentCount}/${parkingState.maxCapacity})! Barie vào bị KHÓA.`);
    return res.status(403).json({
      error: 'BÃI XE ĐÃ ĐẦY! Không thể mở cổng vào.',
      currentCount: parkingState.currentCount,
      maxCapacity: parkingState.maxCapacity
    });
  }

  parkingState.gates[gate] = isOpen;
  console.log(`[BARIE] Cổng ${gate.toUpperCase()}: ${isOpen ? 'MỞ (90°)' : 'ĐÓNG (0°)'}`);

  res.json({
    status: 'success',
    gate: gate,
    action: action,
    gates: parkingState.gates
  });
});

/**
 * POST /api/set-count?count=X
 * Điều chỉnh số xe hiện có trong bãi
 */
app.post('/api/set-count', (req, res) => {
  const count = parseInt(req.query.count || req.body.count, 10);
  if (isNaN(count) || count < 0) {
    return res.status(400).json({ error: 'Số xe không hợp lệ (>= 0)' });
  }

  parkingState.currentCount = count;
  parkingState.lastUpdate = new Date().toISOString();
  console.log(`[CẤU HÌNH] Đã điều chỉnh số xe trong bãi: ${parkingState.currentCount} xe`);

  res.json({
    status: 'success',
    message: `Đã cập nhật số xe: ${count} xe`,
    currentCount: parkingState.currentCount,
    isFull: parkingState.currentCount >= parkingState.maxCapacity
  });
});

/**
 * POST /api/reset-count
 * Đặt lại bộ đếm xe về 0
 */
app.post('/api/reset-count', (req, res) => {
  parkingState.currentCount = 0;
  parkingState.gates.in = false;
  parkingState.gates.out = false;
  parkingState.lastUpdate = new Date().toISOString();
  console.log(`[RESET] Đã đặt lại số xe trong bãi về 0`);

  res.json({
    status: 'success',
    message: 'Đã đặt lại số xe về 0',
    currentCount: 0
  });
});

/**
 * POST /api/simulate-enter
 * Giả lập xe vào qua cảm biến IR (+1)
 */
app.post('/api/simulate-enter', (req, res) => {
  if (parkingState.currentCount >= parkingState.maxCapacity) {
    return res.status(403).json({
      error: 'Bãi đã đầy!',
      currentCount: parkingState.currentCount,
      maxCapacity: parkingState.maxCapacity
    });
  }

  parkingState.currentCount++;
  parkingState.gates.in = true;

  // Tự động đóng barie sau 3.5s
  setTimeout(() => {
    parkingState.gates.in = false;
  }, 3500);

  res.json({
    status: 'success',
    message: 'Xe đã vào bãi',
    currentCount: parkingState.currentCount,
    maxCapacity: parkingState.maxCapacity
  });
});

/**
 * POST /api/simulate-leave
 * Giả lập xe ra qua cảm biến IR (-1)
 */
app.post('/api/simulate-leave', (req, res) => {
  if (parkingState.currentCount <= 0) {
    return res.status(400).json({ error: 'Bãi xe hiện đang trống' });
  }

  parkingState.currentCount--;
  parkingState.gates.out = true;

  setTimeout(() => {
    parkingState.gates.out = false;
  }, 3500);

  res.json({
    status: 'success',
    message: 'Xe đã rời bãi',
    currentCount: parkingState.currentCount,
    maxCapacity: parkingState.maxCapacity
  });
});

/**
 * ALL /api/esp32/proxy
 * Proxy trung gian để giải quyết vấn đề CORS khi trình duyệt gọi thẳng IP ESP32
 */
app.all('/api/esp32/proxy', async (req, res) => {
  const targetUrl = req.query.target;
  if (!targetUrl) {
    return res.status(400).json({ error: 'Thiếu query param target' });
  }

  try {
    const fetchOptions = {
      method: req.method,
      headers: { 'Content-Type': 'application/json' }
    };
    if (req.method !== 'GET' && req.method !== 'HEAD' && req.body) {
      fetchOptions.body = JSON.stringify(req.body);
    }

    const response = await fetch(targetUrl, fetchOptions);
    const contentType = response.headers.get('content-type') || '';

    if (contentType.includes('application/json')) {
      const data = await response.json();
      return res.status(response.status).json(data);
    } else {
      const text = await response.text();
      return res.status(response.status).send(text);
    }
  } catch (err) {
    console.error(`[PROXY ERROR] Không thể kết nối tới ${targetUrl}:`, err.message);
    res.status(502).json({ error: `Không thể kết nối tới thiết bị ESP32: ${err.message}` });
  }
});

// ==================== STATIC FILE SERVING ====================

const distPath = path.join(__dirname, 'dist');
if (fs.existsSync(distPath)) {
  console.log(`[INFO] Phục vụ giao diện tĩnh từ thư mục build: ${distPath}`);
  app.use(express.static(distPath));

  app.get('/so_do_ket_noi.html', (req, res) => {
    res.sendFile(path.join(distPath, 'so_do_ket_noi.html'));
  });

  app.get('*', (req, res) => {
    res.sendFile(path.join(distPath, 'index.html'));
  });
} else {
  // Khi chưa build dist, phục vụ trực tiếp thư mục gốc (hoặc nhắc người dùng chạy npm run dev)
  app.use(express.static(__dirname));
  app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
  });
}

// Khởi động server
app.listen(PORT, () => {
  console.log('==========================================================');
  console.log(' SMART PARKING IOT - NODE.JS & VITE BACKEND SERVER');
  console.log(` 🚀 Máy chủ Node.js đang chạy tại: http://localhost:${PORT}`);
  console.log('    - GET  /api/status');
  console.log('    - POST /api/set-limit?limit=X');
  console.log('    - POST /api/gate?gate=in|out&action=open|close');
  console.log('    - POST /api/reset-count');
  console.log('    - ALL  /api/esp32/proxy?target=http://<IP_ESP32>/api/...');
  console.log('==========================================================');
});
