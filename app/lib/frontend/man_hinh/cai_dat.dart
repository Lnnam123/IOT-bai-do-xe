import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/models/models.dart';
import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';
import '../thanh_phan/modal_cai_dat_suc_chua.dart';
import '../thanh_phan/modal_quet_va_ket_noi_esp32.dart';

/// Màn hình 4: Cài đặt hệ thống, cấu hình ESP32 và Phần cứng (Chuẩn layout Cointap)
class ManHinhCaiDat extends StatefulWidget {
  static const String tenTrang = 'Cài đặt hệ thống';

  final NguoiDung nguoiDung;
  final VoidCallback onUpdated;

  const ManHinhCaiDat({
    super.key,
    required this.nguoiDung,
    required this.onUpdated,
  });

  @override
  State<ManHinhCaiDat> createState() => _ManHinhCaiDatState();
}

class _ManHinhCaiDatState extends State<ManHinhCaiDat> {
  final esp = Esp32Service.instance;

  bool _isTestingAll = false;
  bool _isTestingGateIn = false;
  bool _isTestingGateOut = false;

  void _moDialogDoiIp() {
    final ipController = TextEditingController(text: esp.state.espIp);
    final portController = TextEditingController(text: esp.state.port.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cấu hình IP ESP32 / Gateway',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'Địa chỉ IP ESP32 / Server',
                hintText: '192.168.1.150 hoặc localhost',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cổng (Port)',
                hintText: '80 hoặc 5000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Hủy', style: GoogleFonts.manrope()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MauSac.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newIp = ipController.text.trim();
              final newPort = int.tryParse(portController.text.trim()) ?? 80;
              if (newIp.isNotEmpty) {
                await esp.capNhatKetNoi(
                  ip: newIp,
                  port: newPort,
                  isDemoMode: esp.state.isDemoMode,
                );
                widget.onUpdated();
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: Text('Lưu kết nối', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _hienThongBao(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        backgroundColor: isError ? MauSac.error : MauSac.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = esp.state;

    return Scaffold(
      backgroundColor: MauSac.background,
      appBar: AppBar(
        backgroundColor: MauSac.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          ManHinhCaiDat.tenTrang,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: MauSac.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section (CoinTap Exact Layout)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MauSac.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MauSac.borderSubtle),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: MauSac.primary.withValues(alpha: 0.15),
                    child: const Icon(Icons.person, color: MauSac.primary, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nguoiDung.hoTen,
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: MauSac.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.nguoiDung.vaiTro,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: MauSac.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.nguoiDung.email,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: MauSac.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nút Quét & Cài đặt WiFi ESP32 Nổi bật
            InkWell(
              onTap: () {
                ModalQuetVaKetNoiEsp32.show(
                  context,
                  onConnected: () {
                    setState(() {});
                    widget.onUpdated();
                  },
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [MauSac.primary, Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: MauSac.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quét & Cài đặt WiFi ESP32',
                            style: GoogleFonts.manrope(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Tự động tìm thiết bị và nạp mật khẩu WiFi trực tiếp trong App',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Group 1: Kết nối ESP32
            _buildSectionTitle('Kết nối vi điều khiển ESP32'),
            _buildSettingsGroup([
              _buildSettingsItem(
                icon: Icons.radar_rounded,
                title: 'Quét tìm thiết bị ESP32',
                subtitle: 'Dò tìm ESP32 trên mạng Access Point / LAN',
                onTap: () {
                  ModalQuetVaKetNoiEsp32.show(
                    context,
                    onConnected: () {
                      setState(() {});
                      widget.onUpdated();
                    },
                  );
                },
              ),
              _buildSettingsItem(
                icon: Icons.wifi,
                title: 'Địa chỉ IP ESP32 / Server',
                subtitle: '${state.espIp}:${state.port}',
                onTap: _moDialogDoiIp,
              ),
              _buildSettingsItem(
                icon: Icons.science_outlined,
                title: 'Chế độ Giả lập (Demo Mode)',
                subtitle: state.isDemoMode
                    ? 'Đang bật mô phỏng bãi xe cục bộ'
                    : 'Đang kết nối trực tiếp ESP32',
                isToggle: true,
                toggleValue: state.isDemoMode,
                onToggle: (val) async {
                  await esp.capNhatKetNoi(
                    ip: state.espIp,
                    port: state.port,
                    isDemoMode: val,
                  );
                  setState(() {});
                  widget.onUpdated();
                },
              ),
              _buildSettingsItem(
                icon: Icons.sync,
                title: 'Kiểm tra & Đồng bộ tức thì',
                subtitle: state.isOnline ? 'ESP32 đang phản hồi tốt' : 'Nhấn để thử kết nối lại',
                trailingText: state.isOnline ? 'Online' : 'Thử lại',
                onTap: () async {
                  await esp.dongBoDuLieu();
                  setState(() {});
                  widget.onUpdated();
                  _hienThongBao(
                    state.isOnline
                        ? 'Kết nối ESP32 thành công!'
                        : 'Không thể kết nối ESP32 (Đang ở chế độ Demo)',
                    isError: !state.isOnline,
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Group 2: Cấu hình Bãi xe
            _buildSectionTitle('Thông số hoạt động bãi xe'),
            _buildSettingsGroup([
              _buildSettingsItem(
                icon: Icons.tune,
                title: 'Cài đặt sức chứa tối đa',
                subtitle: 'Hiện tại: ${state.maxCapacity} xe',
                onTap: () {
                  ModalCaiDatSucChua.show(
                    context,
                    currentCapacity: state.maxCapacity,
                    currentCount: state.currentCount,
                    onUpdated: () {
                      setState(() {});
                      widget.onUpdated();
                    },
                  );
                },
              ),
              _buildSettingsItem(
                icon: Icons.restart_alt,
                title: 'Đặt lại bộ đếm xe về 0',
                subtitle: 'Đóng toàn bộ barie và xóa số xe đỗ',
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Xác nhận đặt lại số xe về 0?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: MauSac.error, foregroundColor: Colors.white),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Đặt lại 0'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await esp.datLaiBoDem();
                    setState(() {});
                    widget.onUpdated();
                    _hienThongBao('Đã đặt lại số xe về 0 thành công!');
                  }
                },
              ),
              _buildSettingsItem(
                icon: Icons.wifi_off_rounded,
                title: 'Khôi phục mặc định Wi-Fi ESP32',
                subtitle: 'Xóa toàn bộ Wi-Fi đã lưu trên chip và về AP mặc định',
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Xác nhận xóa Wi-Fi ESP32?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                      content: Text(
                        'Hành động này sẽ xóa vĩnh viễn cấu hình Wi-Fi đã lưu trên chip ESP32. Thiết bị sẽ ngắt kết nối router và quay về chế độ phát Access Point mặc định (BaiDoXe_ESP32 - 192.168.4.1).\n\n(Bạn cũng có thể nhấn giữ nút BOOT trên mạch 3 giây).',
                        style: GoogleFonts.manrope(fontSize: 13),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: MauSac.error, foregroundColor: Colors.white),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Xác nhận xóa'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final ok = await esp.resetWifiVeMacDinh();
                    if (ok) {
                      _hienThongBao('Đã xóa cấu hình Wi-Fi trên ESP32 thành công!');
                    } else {
                      _hienThongBao('Không thể gửi lệnh tới ESP32. Bạn có thể nhấn giữ nút BOOT trên mạch 3s để xóa.', isError: true);
                    }
                  }
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Group 3: Chạy thử & Kiểm tra phần cứng ESP32
            _buildSectionTitle('Chạy thử & Kiểm tra phần cứng ESP32'),
            _buildHardwareTestSection(state),
            const SizedBox(height: 24),

            // Group 4: Thông tin đồ án
            _buildSectionTitle('Thông tin hệ thống'),
            _buildSettingsGroup([
              _buildSettingsItem(
                icon: Icons.info_outline,
                title: 'Phiên bản ứng dụng',
                trailingText: 'v1.1.0 IoT',
                showChevron: false,
              ),
              _buildSettingsItem(
                icon: Icons.school_outlined,
                title: 'Đề tài môn học',
                subtitle: 'Hệ thống Đếm Xe & Khóa Barie Tự Động ESP32',
                showChevron: false,
              ),
              _buildSettingsItem(
                icon: Icons.badge_outlined,
                title: 'Sinh viên thực hiện',
                subtitle: 'Lê Nhật Nam - Lớp 24CT1',
                showChevron: false,
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: MauSac.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: MauSac.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MauSac.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
          )
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget child = entry.value;
          if (idx != children.length - 1) {
            return Column(
              children: [
                child,
                const Divider(height: 1, indent: 68, color: MauSac.borderSubtle),
              ],
            );
          }
          return child;
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    bool showChevron = true,
    bool isToggle = false,
    bool toggleValue = false,
    ValueChanged<bool>? onToggle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isToggle ? () => onToggle?.call(!toggleValue) : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: MauSac.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: MauSac.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: MauSac.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: MauSac.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isToggle)
              Switch(
                value: toggleValue,
                onChanged: onToggle,
                activeThumbColor: MauSac.primary,
              )
            else if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: MauSac.primary,
                ),
              ),
              if (showChevron) const SizedBox(width: 4),
            ],
            if (showChevron && !isToggle)
              const Icon(Icons.chevron_right, size: 20, color: MauSac.outlineVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareTestSection(HeThongBaiXeState state) {
    return Column(
      children: [
        // Nút chạy thử toàn bộ
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isTestingAll
                ? null
                : () async {
                    setState(() => _isTestingAll = true);
                    final msg = await esp.chayThuToanBoPhanCung();
                    if (mounted) {
                      setState(() => _isTestingAll = false);
                      widget.onUpdated();
                      _hienThongBao(msg);
                    }
                  },
            icon: _isTestingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt_rounded, size: 20),
            label: Text(
              _isTestingAll
                  ? 'Đang chạy thử toàn bộ phần cứng...'
                  : 'Chạy thử toàn bộ phần cứng (Self-Test)',
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MauSac.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Card Chạy thử Cổng Vào
        _buildGateTestCard(
          title: 'Cổng Vào (IN)',
          gate: state.inGate,
          isGateIn: true,
          servoPinText: 'GPIO 18',
          sensorPinText: 'GPIO 2',
          isLoading: _isTestingGateIn,
          onRunCycle: () async {
            setState(() => _isTestingGateIn = true);
            await esp.chayThuChuTrinhCong('in');
            if (mounted) {
              setState(() => _isTestingGateIn = false);
              widget.onUpdated();
              _hienThongBao('Đã chạy thử chu trình Cổng Vào (Mở 0.5s -> Tự đóng)!');
            }
          },
          onToggleManual: (shouldOpen) async {
            await esp.dieuKhienCong('in', shouldOpen ? 'open' : 'close', boQuaKiemTraSucChua: true);
            setState(() {});
            widget.onUpdated();
          },
        ),
        const SizedBox(height: 12),

        // Card Chạy thử Cổng Ra
        _buildGateTestCard(
          title: 'Cổng Ra (OUT)',
          gate: state.outGate,
          isGateIn: false,
          servoPinText: 'GPIO 19',
          sensorPinText: 'GPIO 4',
          isLoading: _isTestingGateOut,
          onRunCycle: () async {
            setState(() => _isTestingGateOut = true);
            await esp.chayThuChuTrinhCong('out');
            if (mounted) {
              setState(() => _isTestingGateOut = false);
              widget.onUpdated();
              _hienThongBao('Đã chạy thử chu trình Cổng Ra (Mở 0.5s -> Tự đóng)!');
            }
          },
          onToggleManual: (shouldOpen) async {
            await esp.dieuKhienCong('out', shouldOpen ? 'open' : 'close', boQuaKiemTraSucChua: true);
            setState(() {});
            widget.onUpdated();
          },
        ),
        const SizedBox(height: 12),

        // Card Kiểm tra LCD 1602
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MauSac.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MauSac.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MauSac.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tv_rounded, color: MauSac.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Màn hình LCD 1602 I2C',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MauSac.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SDA: GPIO 21 • SCL: GPIO 22 (Địa chỉ 0x27)',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: MauSac.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await esp.dongBoDuLieu();
                  _hienThongBao('Đã gửi lệnh đồng bộ & làm mới hiển thị LCD 1602!');
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Làm mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MauSac.primary,
                  side: const BorderSide(color: MauSac.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGateTestCard({
    required String title,
    required GateInfo gate,
    required bool isGateIn,
    required String servoPinText,
    required String sensorPinText,
    required bool isLoading,
    required VoidCallback onRunCycle,
    required ValueChanged<bool> onToggleManual,
  }) {
    final isOpen = gate.isOpen;
    final isDetected = gate.sensorDetected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MauSac.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MauSac.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isOpen ? MauSac.success.withValues(alpha: 0.15) : MauSac.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isGateIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: isOpen ? MauSac.success : MauSac.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: MauSac.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Servo: $servoPinText • Cảm biến: $sensorPinText',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: MauSac.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen ? MauSac.success.withValues(alpha: 0.12) : MauSac.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOpen ? 'Đang MỞ (90°)' : 'Đang ĐÓNG (0°)',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOpen ? MauSac.success : MauSac.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Trạng thái cảm biến hồng ngoại IR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDetected ? MauSac.warning.withValues(alpha: 0.1) : MauSac.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sensors_rounded,
                  size: 16,
                  color: isDetected ? MauSac.warning : MauSac.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cảm biến IR ($sensorPinText): ',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: MauSac.onSurface),
                ),
                Text(
                  isDetected ? 'Phát hiện có xe chắn' : 'Thông thoáng (Không có xe)',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: isDetected ? FontWeight.bold : FontWeight.normal,
                    color: isDetected ? MauSac.warning : MauSac.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nút bấm kiểm tra
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onToggleManual(!isOpen),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isOpen ? MauSac.error : MauSac.primary,
                    side: BorderSide(color: isOpen ? MauSac.error : MauSac.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    isOpen ? 'Đóng Barie' : 'Mở Barie',
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onRunCycle,
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    isLoading ? 'Đang chạy...' : 'Chạy thử chu trình (0.5s)',
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MauSac.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
