import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Dịch vụ quản lý kết nối, giao tiếp REST API với ESP32 và Server Node.js Gateway
class Esp32Service extends ChangeNotifier {
  static final Esp32Service instance = Esp32Service._internal();
  Esp32Service._internal();

  HeThongBaiXeState state = HeThongBaiXeState.initial();

  Timer? _pollingTimer;
  bool _isSyncing = false;

  final List<LichSuXeRaVao> danhSachLichSu = [];
  final List<ThongBaoHeThong> danhSachThongBao = [];

  bool get coThongBaoChuaDoc => danhSachThongBao.any((t) => !t.daDoc);

  /// Khởi tạo dịch vụ, nạp cấu hình lưu trữ
  Future<void> khoiTao() async {
    final prefs = await SharedPreferences.getInstance();
    state.espIp = prefs.getString('esp_ip') ?? '192.168.1.150';
    state.port = prefs.getInt('esp_port') ?? 80;
    state.isDemoMode = prefs.getBool('is_demo_mode') ?? true;
    final savedCapacity = prefs.getInt('max_capacity') ?? 10;
    state.maxCapacity = savedCapacity;
    state.slots = HeThongBaiXeState.generateDefaultSlots(savedCapacity);

    // Khởi tạo một vài dữ liệu mẫu cho Demo Mode
    if (state.isDemoMode) {
      _khoiTaoDuLieuMauDemo();
    }

    // Bắt đầu vòng lặp đồng bộ thời gian thực
    batDongBoRealtime();
    notifyListeners();
  }

  void _khoiTaoDuLieuMauDemo() {
    if (danhSachLichSu.isNotEmpty) return;

    final now = DateTime.now();
    // Gán 3 xe mẫu đang đỗ
    if (state.slots.length >= 3) {
      state.slots[0].isOccupied = true;
      state.slots[0].vehicleType = 'Ô tô';
      state.slots[0].entryTime = now.subtract(const Duration(minutes: 85));

      state.slots[1].isOccupied = true;
      state.slots[1].vehicleType = 'Ô tô';
      state.slots[1].entryTime = now.subtract(const Duration(minutes: 42));

      state.slots[2].isOccupied = true;
      state.slots[2].vehicleType = 'Xe máy';
      state.slots[2].entryTime = now.subtract(const Duration(minutes: 15));

      state.currentCount = 3;
    }

    // Tạo lịch sử mẫu
    danhSachLichSu.addAll([
      LichSuXeRaVao(
        id: 'LS-01',
        suKien: 'VÀO',
        thoiGian: now.subtract(const Duration(minutes: 85)),
        viTriO: 'Ô-01',
      ),
      LichSuXeRaVao(
        id: 'LS-02',
        suKien: 'VÀO',
        thoiGian: now.subtract(const Duration(minutes: 42)),
        viTriO: 'Ô-02',
      ),
      LichSuXeRaVao(
        id: 'LS-03',
        suKien: 'VÀO',
        thoiGian: now.subtract(const Duration(minutes: 15)),
        viTriO: 'Ô-03',
      ),
      LichSuXeRaVao(
        id: 'LS-04',
        suKien: 'RA',
        thoiGian: now.subtract(const Duration(minutes: 110)),
        viTriO: 'Ô-04',
        ghiChu: 'Thời gian đỗ: 1h 45p',
      ),
    ]);

    // Tạo thông báo mẫu
    danhSachThongBao.addAll([
      ThongBaoHeThong(
        id: 'TB-01',
        tieuDe: 'Hệ thống khởi động',
        noiDung: 'Ứng dụng đã sẵn sàng kết nối ESP32 Smart Parking.',
        thoiGian: now.subtract(const Duration(minutes: 90)),
        loai: 'INFO',
      ),
      ThongBaoHeThong(
        id: 'TB-02',
        tieuDe: 'Xe vào bãi',
        noiDung: 'Xe 43A-567.89 đã vào đỗ tại Ô-01 qua Cổng Vào.',
        thoiGian: now.subtract(const Duration(minutes: 85)),
        loai: 'SUCCESS',
      ),
    ]);
  }

  /// Bắt đầu Polling tự động mỗi 1.8 giây
  void batDongBoRealtime() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      dongBoDuLieu();
    });
  }

  void tatDongBoRealtime() {
    _pollingTimer?.cancel();
  }

  /// Thực hiện một chu kỳ đồng bộ dữ liệu với thiết bị thật hoặc cập nhật Demo
  Future<void> dongBoDuLieu() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      if (state.isDemoMode) {
        // Cập nhật timestamp và thông báo cảnh báo bãi đầy
        state.lastUpdate = DateTime.now();
        _kiemTraCanhBaoBaiDay();
        notifyListeners();
        return;
      }

      // Gọi REST API của ESP32 hoặc Backend Node.js
      final url = Uri.parse('http://${state.espIp}:${state.port}/api/status');
      final response = await http.get(url).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state.isOnline = true;
        state.lastUpdate = DateTime.now();

        if (data['currentCount'] != null) {
          state.currentCount = (data['currentCount'] as num).toInt();
        }
        if (data['maxCapacity'] != null) {
          final newCap = (data['maxCapacity'] as num).toInt();
          if (newCap != state.maxCapacity) {
            state.maxCapacity = newCap;
            state.slots = HeThongBaiXeState.generateDefaultSlots(newCap, state.slots);
          }
        }
        if (data['inGateOpen'] != null) {
          state.inGate.isOpen = data['inGateOpen'] == true;
        }
        if (data['outGateOpen'] != null) {
          state.outGate.isOpen = data['outGateOpen'] == true;
        }
        if (data['sensorIn'] != null) {
          state.inGate.sensorDetected = data['sensorIn'] == true;
        }
        if (data['sensorOut'] != null) {
          state.outGate.sensorDetected = data['sensorOut'] == true;
        }

        _dongBoDanhSachODoVoiSoXe();
        _kiemTraCanhBaoBaiDay();
      } else {
        state.isOnline = false;
      }
    } catch (e) {
      state.isOnline = false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _dongBoDanhSachODoVoiSoXe() {
    // Đảm bảo số lượng ô có cờ isOccupied khớp với state.currentCount
    int currentOccupied = state.slots.where((s) => s.isOccupied).length;
    if (currentOccupied < state.currentCount) {
      // Bổ sung ô đỗ tự động
      int needToAdd = state.currentCount - currentOccupied;
      for (final slot in state.slots) {
        if (!slot.isOccupied && needToAdd > 0) {
          slot.isOccupied = true;
          slot.entryTime = DateTime.now();
          needToAdd--;
        }
      }
    } else if (currentOccupied > state.currentCount) {
      // Giảm ô đỗ tự động từ cuối
      int needToRemove = currentOccupied - state.currentCount;
      for (int i = state.slots.length - 1; i >= 0 && needToRemove > 0; i--) {
        if (state.slots[i].isOccupied) {
          state.slots[i].isOccupied = false;
          state.slots[i].entryTime = null;
          needToRemove--;
        }
      }
    }
  }

  void _kiemTraCanhBaoBaiDay() {
    if (state.isFull) {
      const title = '🚨 BÃI XE ĐÃ ĐẦY!';
      final exists = danhSachThongBao.any((t) =>
          t.tieuDe == title &&
          DateTime.now().difference(t.thoiGian).inMinutes < 5);
      if (!exists) {
        themThongBao(
          title,
          'Số lượng xe (${state.currentCount}/${state.maxCapacity}) đã đạt ngưỡng tối đa. Barie Cổng Vào tự động KHÓA!',
          'DANGER',
        );
      }
    }
  }

  /// Thêm thông báo mới
  void themThongBao(String tieuDe, String noiDung, String loai) {
    danhSachThongBao.insert(
      0,
      ThongBaoHeThong(
        id: 'TB-${DateTime.now().millisecondsSinceEpoch}',
        tieuDe: tieuDe,
        noiDung: noiDung,
        thoiGian: DateTime.now(),
        loai: loai,
      ),
    );
    notifyListeners();
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  void danhDauTatCaDaDoc() {
    for (final tb in danhSachThongBao) {
      tb.daDoc = true;
    }
    notifyListeners();
  }

  /// Xóa toàn bộ thông báo
  void xoaTatCaThongBao() {
    danhSachThongBao.clear();
    notifyListeners();
  }

  /// Điều khiển Barie Cổng (in hoặc out, action: open hoặc close)
  Future<bool> dieuKhienCong(String gate, String action, {bool boQuaKiemTraSucChua = false}) async {
    final isOpen = (action == 'open');

    // Chặn mở cổng vào nếu bãi đã đầy (trừ khi đang chạy thử nghiệm kỹ thuật)
    if (!boQuaKiemTraSucChua && gate == 'in' && isOpen && state.isFull) {
      themThongBao(
        'Từ chối mở Barie Vào',
        'Không thể mở Cổng Vào vì bãi đỗ xe đã đầy (${state.currentCount}/${state.maxCapacity})!',
        'WARNING',
      );
      notifyListeners();
      return false;
    }

    if (state.isDemoMode) {
      if (gate == 'in') {
        state.inGate.isOpen = isOpen;
      } else {
        state.outGate.isOpen = isOpen;
      }
      notifyListeners();
      return true;
    }

    try {
      final url = Uri.parse(
          'http://${state.espIp}:${state.port}/api/gate?gate=$gate&action=$action');
      final resp = await http.post(url).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        if (gate == 'in') {
          state.inGate.isOpen = isOpen;
        } else {
          state.outGate.isOpen = isOpen;
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi điều khiển cổng: $e');
    }
    return false;
  }

  /// Chạy thử chu trình mở cổng rồi tự đóng sau 500ms (dành cho kiểm tra phần cứng)
  Future<void> chayThuChuTrinhCong(String gate) async {
    await dieuKhienCong(gate, 'open', boQuaKiemTraSucChua: true);
    await Future.delayed(const Duration(milliseconds: 500));
    await dieuKhienCong(gate, 'close', boQuaKiemTraSucChua: true);
  }

  /// Chạy thử nghiệm tự động toàn bộ phần cứng (Servo Vào, Servo Ra, Đồng bộ)
  Future<String> chayThuToanBoPhanCung() async {
    // 1. Chạy thử Servo Cổng Vào
    await dieuKhienCong('in', 'open', boQuaKiemTraSucChua: true);
    await Future.delayed(const Duration(milliseconds: 500));
    await dieuKhienCong('in', 'close', boQuaKiemTraSucChua: true);
    await Future.delayed(const Duration(milliseconds: 400));

    // 2. Chạy thử Servo Cổng Ra
    await dieuKhienCong('out', 'open', boQuaKiemTraSucChua: true);
    await Future.delayed(const Duration(milliseconds: 500));
    await dieuKhienCong('out', 'close', boQuaKiemTraSucChua: true);
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Đồng bộ lại dữ liệu
    await dongBoDuLieu();
    return 'Đã hoàn thành chạy thử Servo Cổng Vào và Cổng Ra!';
  }

  /// Cài đặt sức chứa tối đa
  Future<bool> caiDatSucChua(int limit) async {
    if (limit < 1) return false;

    state.maxCapacity = limit;
    state.slots = HeThongBaiXeState.generateDefaultSlots(limit, state.slots);
    _dongBoDanhSachODoVoiSoXe();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_capacity', limit);

    themThongBao(
      'Cập nhật sức chứa',
      'Đã điều chỉnh sức chứa tối đa của bãi xe thành: $limit xe.',
      'INFO',
    );

    if (!state.isDemoMode) {
      try {
        final url = Uri.parse(
            'http://${state.espIp}:${state.port}/api/set-limit?limit=$limit');
        await http.post(url).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Lỗi cập nhật sức chứa lên ESP32: $e');
      }
    }

    notifyListeners();
    return true;
  }

  /// Điều chỉnh số xe thực tế
  Future<bool> dieuChinhSoXe(int count) async {
    if (count < 0 || count > state.maxCapacity) return false;

    state.currentCount = count;
    _dongBoDanhSachODoVoiSoXe();

    themThongBao(
      'Hiệu chỉnh số xe',
      'Đã cân chỉnh số lượng xe trong bãi thành: $count xe.',
      'INFO',
    );

    if (!state.isDemoMode) {
      try {
        final url = Uri.parse(
            'http://${state.espIp}:${state.port}/api/set-count?count=$count');
        await http.post(url).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Lỗi hiệu chỉnh số xe lên ESP32: $e');
      }
    }

    notifyListeners();
    return true;
  }

  /// Đặt lại bộ đếm xe về 0
  Future<void> datLaiBoDem() async {
    state.currentCount = 0;
    state.inGate.isOpen = false;
    state.outGate.isOpen = false;
    for (final s in state.slots) {
      s.isOccupied = false;
      s.entryTime = null;
    }

    themThongBao(
      'Đặt lại bộ đếm',
      'Đã xóa sạch bộ đếm xe về 0 và đóng toàn bộ barie.',
      'WARNING',
    );

    if (!state.isDemoMode) {
      try {
        final url = Uri.parse('http://${state.espIp}:${state.port}/api/reset-count');
        await http.post(url).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Lỗi reset bộ đếm lên ESP32: $e');
      }
    }

    notifyListeners();
  }

  /// Giả lập hoặc xử lý xe vào bãi (+1)
  Future<bool> xeVaoBai({String loaiXe = 'Ô tô', String? maO}) async {
    if (state.isFull) {
      themThongBao(
        'Từ chối xe vào',
        'Bãi đỗ xe đã đầy (${state.currentCount}/${state.maxCapacity})! Barie vào bị khóa.',
        'DANGER',
      );
      notifyListeners();
      return false;
    }

    // Tìm ô còn trống
    ODoXe? targetSlot;
    if (maO != null) {
      for (final s in state.slots) {
        if (s.id == maO && !s.isOccupied) {
          targetSlot = s;
          break;
        }
      }
    }
    if (targetSlot == null) {
      for (final s in state.slots) {
        if (!s.isOccupied) {
          targetSlot = s;
          break;
        }
      }
    }

    if (targetSlot != null) {
      targetSlot.isOccupied = true;
      targetSlot.vehicleType = loaiXe;
      targetSlot.entryTime = DateTime.now();
    }

    state.currentCount++;
    state.inGate.isOpen = true;

    // Lưu vào lịch sử
    danhSachLichSu.insert(
      0,
      LichSuXeRaVao(
        id: 'LS-${DateTime.now().millisecondsSinceEpoch}',
        loaiXe: loaiXe,
        suKien: 'VÀO',
        thoiGian: DateTime.now(),
        viTriO: targetSlot?.label ?? 'Khu A',
      ),
    );

    themThongBao(
      'Xe vào bãi (+1)',
      'Xe ($loaiXe) đã vào ${targetSlot?.label ?? ""}. Barie vào tự mở.',
      'SUCCESS',
    );

    // Tự động đóng barie sau 3 giây
    Timer(const Duration(milliseconds: 3000), () {
      state.inGate.isOpen = false;
      notifyListeners();
    });

    if (!state.isDemoMode) {
      try {
        final url = Uri.parse('http://${state.espIp}:${state.port}/api/simulate-enter');
        await http.post(url).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Lỗi gửi lệnh xe vào tới ESP32: $e');
      }
    }

    notifyListeners();
    return true;
  }

  /// Giả lập hoặc xử lý xe ra bãi (-1)
  Future<bool> xeRaBai(String oDoId) async {
    ODoXe? slot;
    for (final s in state.slots) {
      if (s.id == oDoId) {
        slot = s;
        break;
      }
    }

    if (slot == null || !slot.isOccupied) {
      return false;
    }

    final durationStr = slot.formattedDuration;

    slot.isOccupied = false;
    slot.entryTime = null;

    if (state.currentCount > 0) {
      state.currentCount--;
    }
    state.outGate.isOpen = true;

    // Lưu vào lịch sử
    danhSachLichSu.insert(
      0,
      LichSuXeRaVao(
        id: 'LS-${DateTime.now().millisecondsSinceEpoch}',
        loaiXe: slot.vehicleType,
        suKien: 'RA',
        thoiGian: DateTime.now(),
        viTriO: slot.label,
        ghiChu: 'Thời gian đỗ: $durationStr',
      ),
    );

    themThongBao(
      'Xe ra bãi (-1)',
      'Xe đã xuất bãi từ ${slot.label}. Thời gian đỗ: $durationStr.',
      'INFO',
    );

    // Tự động đóng barie sau 3 giây
    Timer(const Duration(milliseconds: 3000), () {
      state.outGate.isOpen = false;
      notifyListeners();
    });

    if (!state.isDemoMode) {
      try {
        final url = Uri.parse('http://${state.espIp}:${state.port}/api/simulate-leave');
        await http.post(url).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Lỗi gửi lệnh xe ra tới ESP32: $e');
      }
    }

    notifyListeners();
    return true;
  }

  /// Cập nhật địa chỉ IP và chế độ hoạt động
  Future<void> capNhatKetNoi({
    required String ip,
    required int port,
    required bool isDemoMode,
  }) async {
    state.espIp = ip;
    state.port = port;
    state.isDemoMode = isDemoMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp_ip', ip);
    await prefs.setInt('esp_port', port);
    await prefs.setBool('is_demo_mode', isDemoMode);

    notifyListeners();
    await dongBoDuLieu();
  }

  /// Quét tìm các thiết bị ESP32 trong mạng WiFi hoặc Access Point
  Future<List<ThietBiEsp32TimThay>> quetTimThietBiEsp32({String? ipBoSung}) async {
    final ketQua = <ThietBiEsp32TimThay>[];
    final Set<String> daKiemTra = {};

    // 1. Danh sách địa chỉ IP ưu tiên hàng đầu để thăm dò
    final danhSachUngVien = <String>[];
    if (ipBoSung != null && ipBoSung.trim().isNotEmpty) {
      danhSachUngVien.add(ipBoSung.trim());
    }

    danhSachUngVien.addAll([
      '192.168.4.1',     // Địa chỉ mặc định khi phát Access Point (BaiDoXe_ESP32)
      'baidoxe.local',   // Tên miền mDNS nội bộ
      state.espIp,       // Địa chỉ IP hiện tại đã lưu
      '10.42.77.139',    // Địa chỉ IP ESP32 trong cấu hình trước đó
      '192.168.1.139',
      '192.168.1.150',
      '192.168.1.100',
      '192.168.0.100',
      '192.168.0.150',
      '192.168.2.100',
      '192.168.2.150',
    ]);

    // Tạo thêm các IP trong cùng dải mạng subnet của IP hiện tại
    final parts = state.espIp.split('.');
    if (parts.length == 4) {
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      final commonHostIds = [1, 2, 4, 10, 15, 20, 50, 77, 100, 101, 105, 110, 139, 150, 200];
      for (final h in commonHostIds) {
        final candidate = '$prefix.$h';
        if (!danhSachUngVien.contains(candidate)) {
          danhSachUngVien.add(candidate);
        }
      }
    }

    // Quét song song (Parallel probe) để tốc độ siêu nhanh (~1.5 giây)
    final futures = danhSachUngVien.map((ip) async {
      if (ip.isEmpty || daKiemTra.contains(ip)) return null;
      daKiemTra.add(ip);

      final sw = Stopwatch()..start();
      try {
        final url = Uri.parse('http://$ip:80/api/status');
        final response = await http.get(url).timeout(const Duration(milliseconds: 1600));
        sw.stop();

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && (data.containsKey('currentCount') || data.containsKey('gates') || data.containsKey('deviceName'))) {
            final name = data['deviceName']?.toString() ?? 'ESP32 Bãi Đỗ Xe';
            final apIp = data['apIp']?.toString() ?? '';
            final connectedSsid = data['connectedSsid']?.toString();
            return ThietBiEsp32TimThay(
              ten: name,
              ip: ip,
              port: 80,
              isApMode: (ip == '192.168.4.1' || apIp == ip),
              ssid: connectedSsid,
              pingMs: sw.elapsedMilliseconds,
            );
          }
        }
      } catch (_) {
        // Bỏ qua lỗi timeout hoặc không phản hồi
      }
      return null;
    });

    final results = await Future.wait(futures);
    for (final r in results) {
      if (r != null) {
        ketQua.add(r);
      }
    }

    return ketQua;
  }

  /// Yêu cầu ESP32 quét danh sách các mạng WiFi có sẵn xung quanh
  Future<List<MangWifiQuetDuoc>> quetDanhSachWifi(String ip, int port) async {
    final danhSach = <MangWifiQuetDuoc>[];
    try {
      final url = Uri.parse('http://$ip:$port/api/scan-wifi');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          for (final item in data) {
            if (item is Map) {
              final ssid = item['ssid']?.toString() ?? '';
              if (ssid.isNotEmpty) {
                danhSach.add(
                  MangWifiQuetDuoc(
                    ssid: ssid,
                    rssi: (item['rssi'] as num?)?.toInt() ?? -70,
                    isOpen: item['open'] == true,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi quét WiFi từ ESP32: $e');
    }

    // Sắp xếp theo cường độ sóng mạnh nhất lên đầu
    danhSach.sort((a, b) => b.rssi.compareTo(a.rssi));
    return danhSach;
  }

  /// Gửi thông tin WiFi (SSID và Mật khẩu) từ App xuống cho ESP32 kết nối
  Future<bool> cauHinhWifiChoEsp32({
    required String espIp,
    required int port,
    required String ssid,
    required String password,
  }) async {
    try {
      final query = 'ssid=${Uri.encodeComponent(ssid)}&pass=${Uri.encodeComponent(password)}';
      final url = Uri.parse('http://$espIp:$port/api/set-wifi?$query');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        themThongBao(
          'Đã gửi cấu hình WiFi',
          'Đang gửi WiFi "$ssid" xuống ESP32. Thiết bị sẽ kết nối lại trong vài giây.',
          'SUCCESS',
        );
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi gửi cấu hình WiFi xuống ESP32: $e');
    }
    return false;
  }

  /// Gửi lệnh tương thích MIT App Inventor (B1, T1, B2, T2)
  Future<void> guiLenhMit(String cmd) async {
    if (state.isDemoMode) {
      if (cmd == 'B1') state.inGate.isOpen = true;
      if (cmd == 'T1') state.inGate.isOpen = false;
      if (cmd == 'B2') state.outGate.isOpen = true;
      if (cmd == 'T2') state.outGate.isOpen = false;
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse('http://${state.espIp}:${state.port}/$cmd');
      await http.get(url).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Lỗi gửi lệnh MIT App Inventor: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
