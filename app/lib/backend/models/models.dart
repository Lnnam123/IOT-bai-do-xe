import 'package:intl/intl.dart';

/// Người dùng / Kỹ thuật viên quản trị hệ thống
class NguoiDung {
  final int id;
  final String hoTen;
  final String email;
  final String vaiTro;
  final String avatarUrl;

  const NguoiDung({
    required this.id,
    required this.hoTen,
    required this.email,
    this.vaiTro = 'Quản trị viên IoT',
    this.avatarUrl = '',
  });

  factory NguoiDung.macDinh() {
    return const NguoiDung(
      id: 1,
      hoTen: 'Lê Nhật Nam',
      email: 'lenhatnam@24ct1.edu.vn',
      vaiTro: 'Trưởng nhóm Dự án IoT',
    );
  }
}

/// Thông tin 1 Ô đỗ xe trong bãi
class ODoXe {
  final String id;
  final String label;
  final String gpioPin;
  bool isOccupied;
  String vehicleType; // 'Ô tô' hoặc 'Xe máy'
  DateTime? entryTime;

  ODoXe({
    required this.id,
    required this.label,
    required this.gpioPin,
    this.isOccupied = false,
    this.vehicleType = 'Ô tô',
    this.entryTime,
  });

  /// Định dạng thời gian đã gửi xe (Ví dụ: 1h 25p 10s)
  String get formattedDuration {
    if (!isOccupied || entryTime == null) return '--';
    final now = DateTime.now();
    final totalSeconds = now.difference(entryTime!).inSeconds;
    if (totalSeconds < 0) return '0s';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}p';
    } else if (minutes > 0) {
      return '${minutes}p ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Tạo bản sao
  ODoXe copyWith({
    String? id,
    String? label,
    String? gpioPin,
    bool? isOccupied,
    String? vehicleType,
    DateTime? entryTime,
  }) {
    return ODoXe(
      id: id ?? this.id,
      label: label ?? this.label,
      gpioPin: gpioPin ?? this.gpioPin,
      isOccupied: isOccupied ?? this.isOccupied,
      vehicleType: vehicleType ?? this.vehicleType,
      entryTime: entryTime ?? this.entryTime,
    );
  }
}

/// Trạng thái một Barie Cổng (Vào / Ra)
class GateInfo {
  final String name; // 'Cổng Vào' hoặc 'Cổng Ra'
  final String servoPin; // 'GPIO 18' hoặc 'GPIO 19'
  final String sensorPin; // 'GPIO 2' hoặc 'GPIO 4'
  bool isOpen; // true = 90 độ, false = 0 độ (đóng)
  bool sensorDetected; // Cảm biến phát hiện xe

  GateInfo({
    required this.name,
    required this.servoPin,
    required this.sensorPin,
    this.isOpen = false,
    this.sensorDetected = false,
  });
}

/// Toàn bộ trạng thái thời gian thực của Hệ thống Bãi Đỗ Xe ESP32
class HeThongBaiXeState {
  String espIp;
  int port;
  bool isOnline;
  bool isDemoMode;
  int maxCapacity;
  int currentCount;
  GateInfo inGate;
  GateInfo outGate;
  List<ODoXe> slots;
  DateTime lastUpdate;

  HeThongBaiXeState({
    this.espIp = '192.168.1.150',
    this.port = 80,
    this.isOnline = false,
    this.isDemoMode = true,
    this.maxCapacity = 10,
    this.currentCount = 0,
    required this.inGate,
    required this.outGate,
    required this.slots,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  /// Kiểm tra bãi đã đầy hay chưa
  bool get isFull => currentCount >= maxCapacity;

  /// Số chỗ còn trống
  int get availableSlots => (maxCapacity - currentCount).clamp(0, maxCapacity);

  /// Tỷ lệ lấp đầy (%)
  double get occupancyRate =>
      maxCapacity > 0 ? (currentCount / maxCapacity).clamp(0.0, 1.0) : 0.0;

  /// Tỷ lệ phần trăm dạng chuỗi
  String get occupancyPercentString =>
      '${(occupancyRate * 100).toStringAsFixed(0)}%';

  /// Khởi tạo trạng thái mặc định ban đầu
  factory HeThongBaiXeState.initial() {
    final defaultSlots = generateDefaultSlots(10);
    return HeThongBaiXeState(
      espIp: '192.168.1.150',
      port: 80,
      isOnline: false,
      isDemoMode: true,
      maxCapacity: 10,
      currentCount: 0,
      inGate: GateInfo(
        name: 'Cổng Vào (IN)',
        servoPin: 'GPIO 18',
        sensorPin: 'GPIO 2',
      ),
      outGate: GateInfo(
        name: 'Cổng Ra (OUT)',
        servoPin: 'GPIO 19',
        sensorPin: 'GPIO 4',
      ),
      slots: defaultSlots,
    );
  }

  /// Tự động sinh danh sách ô đỗ tương ứng theo sức chứa tối đa
  static List<ODoXe> generateDefaultSlots(int capacity, [List<ODoXe>? oldSlots]) {
    final samplePins = [
      'GPIO 13', 'GPIO 14', 'GPIO 26', 'GPIO 27', 'GPIO 25',
      'GPIO 32', 'GPIO 33', 'GPIO 15', 'GPIO 4', 'GPIO 16',
      'GPIO 18', 'GPIO 19', 'GPIO 21', 'GPIO 22', 'GPIO 23',
    ];

    final result = <ODoXe>[];
    for (int i = 1; i <= capacity; i++) {
      final id = 'S$i';
      final label = 'Ô-${i.toString().padLeft(2, '0')}';
      ODoXe? existing;
      if (oldSlots != null) {
        for (final s in oldSlots) {
          if (s.id == id || s.label == label) {
            existing = s;
            break;
          }
        }
      }

      result.add(
        existing ??
            ODoXe(
              id: id,
              label: label,
              gpioPin: samplePins[(i - 1) % samplePins.length],
              isOccupied: false,
            ),
      );
    }
    return result;
  }
}

/// Lịch sử lượt xe ra vào
class LichSuXeRaVao {
  final String id;
  final String loaiXe; // 'Ô tô' hoặc 'Xe máy'
  final String suKien; // 'VÀO' hoặc 'RA'
  final DateTime thoiGian;
  final String? viTriO;
  final String? ghiChu;

  LichSuXeRaVao({
    required this.id,
    this.loaiXe = 'Ô tô',
    required this.suKien,
    required this.thoiGian,
    this.viTriO,
    this.ghiChu,
  });

  String get formattedTime {
    return DateFormat('HH:mm:ss - dd/MM/yyyy').format(thoiGian);
  }
}

/// Thông báo hệ thống
class ThongBaoHeThong {
  final String id;
  final String tieuDe;
  final String noiDung;
  final DateTime thoiGian;
  final String loai; // 'INFO', 'WARNING', 'SUCCESS', 'DANGER'
  bool daDoc;

  ThongBaoHeThong({
    required this.id,
    required this.tieuDe,
    required this.noiDung,
    required this.thoiGian,
    this.loai = 'INFO',
    this.daDoc = false,
  });

  String get formattedTime {
    return DateFormat('HH:mm - dd/MM').format(thoiGian);
  }
}

/// Thông tin thiết bị ESP32 quét thấy được trên mạng LAN hoặc Access Point
class ThietBiEsp32TimThay {
  final String ten;
  final String ip;
  final int port;
  final bool isApMode;
  final String? ssid;
  final int pingMs;

  const ThietBiEsp32TimThay({
    required this.ten,
    required this.ip,
    this.port = 80,
    this.isApMode = false,
    this.ssid,
    this.pingMs = 0,
  });
}

/// Thông tin mạng WiFi mà ESP32 quét được xung quanh
class MangWifiQuetDuoc {
  final String ssid;
  final int rssi; // dBm (ví dụ -50 là rất mạnh, -85 là yếu)
  final bool isOpen; // Không có mật khẩu

  const MangWifiQuetDuoc({
    required this.ssid,
    this.rssi = -70,
    this.isOpen = false,
  });

  /// Số vạch sóng (1 - 4)
  int get signalBars {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }
}

