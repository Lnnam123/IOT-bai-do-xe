import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/models/models.dart';
import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';

/// Modal Quét tìm thiết bị ESP32 và Cài đặt WiFi trực tiếp trong App
class ModalQuetVaKetNoiEsp32 extends StatefulWidget {
  final VoidCallback onConnected;

  const ModalQuetVaKetNoiEsp32({
    super.key,
    required this.onConnected,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConnected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModalQuetVaKetNoiEsp32(onConnected: onConnected),
    );
  }

  @override
  State<ModalQuetVaKetNoiEsp32> createState() => _ModalQuetVaKetNoiEsp32State();
}

class _ModalQuetVaKetNoiEsp32State extends State<ModalQuetVaKetNoiEsp32>
    with SingleTickerProviderStateMixin {
  final esp = Esp32Service.instance;

  late TabController _tabController;
  final TextEditingController _ipThuCongController = TextEditingController();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isScanningEsp = false;
  bool _isScanningWifi = false;
  bool _isSendingWifi = false;
  bool _hienMatKhau = false;
  bool _moNhapThuCong = false;

  List<ThietBiEsp32TimThay> _danhSachEsp = [];
  List<MangWifiQuetDuoc> _danhSachWifi = [];
  ThietBiEsp32TimThay? _thietBiDangChon;
  String _thongBaoKetQuaWifi = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ipThuCongController.text = esp.state.espIp;

    // Tự động quét tìm thiết bị ESP32 khi mở modal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quetTimEsp32();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipThuCongController.dispose();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  /// Bắt đầu quét tìm ESP32
  Future<void> _quetTimEsp32() async {
    if (_isScanningEsp) return;
    setState(() {
      _isScanningEsp = true;
      _danhSachEsp.clear();
    });

    try {
      final ipBoSung = _ipThuCongController.text.trim();
      final ketQua = await esp.quetTimThietBiEsp32(
        ipBoSung: ipBoSung.isNotEmpty ? ipBoSung : null,
      );

      if (mounted) {
        setState(() {
          _danhSachEsp = ketQua;
          _isScanningEsp = false;
          if (_danhSachEsp.isNotEmpty) {
            _thietBiDangChon = _danhSachEsp.first;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanningEsp = false;
        });
      }
    }
  }

  /// Chọn kết nối trực tiếp với ESP32 này (sử dụng ngay)
  Future<void> _ketNoiNgay(ThietBiEsp32TimThay tb) async {
    await esp.capNhatKetNoi(
      ip: tb.ip,
      port: tb.port,
      isDemoMode: false,
    );
    widget.onConnected();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 Đã kết nối thành công với ${tb.ten} (${tb.ip})!',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
          backgroundColor: MauSac.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Chuyển sang Tab Cài đặt WiFi cho thiết bị đã chọn
  void _chuyenSangCaiDatWifi(ThietBiEsp32TimThay tb) {
    setState(() {
      _thietBiDangChon = tb;
    });
    _tabController.animateTo(1);
    _quetDanhSachWifi(tb.ip, tb.port);
  }

  /// Quét các mạng WiFi xung quanh từ thiết bị ESP32
  Future<void> _quetDanhSachWifi(String ip, int port) async {
    if (_isScanningWifi) return;
    setState(() {
      _isScanningWifi = true;
      _danhSachWifi.clear();
      _thongBaoKetQuaWifi = '';
    });

    final list = await esp.quetDanhSachWifi(ip, port);
    if (mounted) {
      setState(() {
        _danhSachWifi = list;
        _isScanningWifi = false;
      });
    }
  }

  /// Gửi SSID và Password xuống ESP32 để thiết bị kết nối vào WiFi
  Future<void> _guiCauHinhWifi() async {
    final ssid = _ssidController.text.trim();
    final pass = _passController.text.trim();

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng chọn hoặc nhập tên mạng WiFi (SSID)', style: GoogleFonts.manrope()),
          backgroundColor: MauSac.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targetIp = _thietBiDangChon?.ip ?? _ipThuCongController.text.trim();
    final targetPort = _thietBiDangChon?.port ?? 80;

    setState(() {
      _isSendingWifi = true;
      _thongBaoKetQuaWifi = '';
    });

    final success = await esp.cauHinhWifiChoEsp32(
      espIp: targetIp,
      port: targetPort,
      ssid: ssid,
      password: pass,
    );

    if (mounted) {
      setState(() {
        _isSendingWifi = false;
      });

      if (success) {
        setState(() {
          _thongBaoKetQuaWifi =
              'Đã gửi cấu hình WiFi "$ssid" xuống ESP32!\nThiết bị đang kết nối router. Hãy xem địa chỉ IP mới hiển thị trên màn hình LCD 1602 của bãi xe.';
        });

        // Tự động chuyển app sang chế độ thật (tắt demo)
        await esp.capNhatKetNoi(
          ip: targetIp,
          port: targetPort,
          isDemoMode: false,
        );
        widget.onConnected();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gửi cấu hình thất bại! Hãy kiểm tra điện thoại đã kết nối WiFi "BaiDoXe_ESP32" (Mật khẩu: 123456789) chưa.',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: MauSac.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: MauSac.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: MauSac.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MauSac.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.wifi_tethering_rounded,
                    color: MauSac.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KẾT NỐI & CÀI ĐẶT ESP32',
                        style: GoogleFonts.manrope(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: MauSac.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quét tìm thiết bị & nạp WiFi trực tiếp từ App',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: MauSac.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: MauSac.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: MauSac.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: MauSac.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: MauSac.onSurfaceVariant,
              labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13.5),
              tabs: const [
                Tab(
                  icon: Icon(Icons.search_rounded, size: 18),
                  text: '1. Quét thiết bị ESP32',
                ),
                Tab(
                  icon: Icon(Icons.wifi_rounded, size: 18),
                  text: '2. Cài đặt WiFi cho ESP32',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: MauSac.borderSubtle),

          // Tab Content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabQuetEsp(),
                _buildTabCaiDatWifi(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: QUÉT TÌM THIẾT BỊ ESP32
  // ===========================================================================
  Widget _buildTabQuetEsp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner trạng thái quét
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MauSac.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MauSac.borderSubtle),
            ),
            child: Row(
              children: [
                if (_isScanningEsp)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: MauSac.primary),
                  )
                else
                  const Icon(Icons.radar_rounded, color: MauSac.primary, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isScanningEsp
                            ? 'Đang dò tìm ESP32 trên mạng...'
                            : 'Đã tìm thấy ${_danhSachEsp.length} thiết bị ESP32',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MauSac.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isScanningEsp
                            ? 'Đang kiểm tra 192.168.4.1 (Access Point) và mạng nội bộ'
                            : 'Chọn thiết bị bên dưới để kết nối hoặc cài đặt WiFi',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: MauSac.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanningEsp ? null : _quetTimEsp32,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('Quét lại', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MauSac.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Danh sách thiết bị tìm thấy
          if (_danhSachEsp.isNotEmpty) ...[
            Text(
              'DANH SÁCH THIẾT BỊ PHÁT HIỆN (${_danhSachEsp.length})',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: MauSac.outline,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _danhSachEsp.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final tb = _danhSachEsp[index];
                final isCurrent = esp.state.espIp == tb.ip;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? MauSac.primary : MauSac.borderSubtle,
                      width: isCurrent ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tb.isApMode
                                  ? MauSac.warning.withValues(alpha: 0.15)
                                  : MauSac.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.memory_rounded,
                              color: tb.isApMode ? MauSac.warning : MauSac.success,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tb.ten,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: MauSac.onSurface,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: MauSac.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '⚡ ${tb.pingMs} ms',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: MauSac.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'IP: http://${tb.ip}:${tb.port}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        color: MauSac.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (tb.isApMode)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MauSac.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Chế độ Cấu hình (AP: BaiDoXe_ESP32 - MK: 123456789)',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: MauSac.warning,
                                      ),
                                    ),
                                  )
                                else if (tb.ssid != null && tb.ssid!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MauSac.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Đang kết nối WiFi: ${tb.ssid}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: MauSac.success,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _chuyenSangCaiDatWifi(tb),
                              icon: const Icon(Icons.wifi_password_rounded, size: 16),
                              label: const Text('Cài đặt WiFi'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MauSac.primary,
                                side: const BorderSide(color: MauSac.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _ketNoiNgay(tb),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Kết nối ngay'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MauSac.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else if (!_isScanningEsp) ...[
            // Trạng thái không tìm thấy thiết bị
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MauSac.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MauSac.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: MauSac.warning, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Chưa tìm thấy ESP32 tự động?',
                        style: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: MauSac.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hãy làm theo các bước sau để kết nối lần đầu:',
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _buildHuongDanStep('1', 'Cấp nguồn cho mạch ESP32 (LED nguồn sáng đỏ).'),
                  _buildHuongDanStep('2', 'Vào Cài đặt Wi-Fi trên điện thoại của bạn.'),
                  _buildHuongDanStep('3', 'Kết nối vào mạng Wi-Fi tên: BaiDoXe_ESP32 (Mật khẩu: 123456789).'),
                  _buildHuongDanStep('4', 'Quay lại màn hình này và nhấn nút "Quét lại" ở trên.'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Tùy chọn nhập IP thủ công
          InkWell(
            onTap: () {
              setState(() {
                _moNhapThuCong = !_moNhapThuCong;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _moNhapThuCong ? Icons.expand_less : Icons.expand_more,
                    color: MauSac.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Nhập địa chỉ IP thủ công',
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: MauSac.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_moNhapThuCong) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _ipThuCongController,
              decoration: InputDecoration(
                labelText: 'Địa chỉ IP ESP32 (Ví dụ: 192.168.4.1 hoặc 192.168.1.139)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: MauSac.primary),
                  onPressed: () {
                    final ip = _ipThuCongController.text.trim();
                    if (ip.isNotEmpty) {
                      _ketNoiNgay(
                        ThietBiEsp32TimThay(
                          ten: 'ESP32 (Thủ công)',
                          ip: ip,
                          port: 80,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHuongDanStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MauSac.warning,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              number,
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(fontSize: 12.5, color: MauSac.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: CÀI ĐẶT WIFI CHO ESP32
  // ===========================================================================
  Widget _buildTabCaiDatWifi() {
    final ipHienTai = _thietBiDangChon?.ip ?? _ipThuCongController.text.trim();
    final portHienTai = _thietBiDangChon?.port ?? 80;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner thiết bị đích
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: MauSac.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MauSac.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.router_rounded, color: MauSac.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thiết bị ESP32 đang cấu hình:',
                        style: GoogleFonts.manrope(fontSize: 11, color: MauSac.onSurfaceVariant),
                      ),
                      Text(
                        'http://$ipHienTai:$portHienTai',
                        style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.bold, color: MauSac.primary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Đổi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Header Quét WiFi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MẠNG WIFI XUNG QUANH ESP32',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: MauSac.outline,
                  letterSpacing: 0.8,
                ),
              ),
              TextButton.icon(
                onPressed: _isScanningWifi ? null : () => _quetDanhSachWifi(ipHienTai, portHienTai),
                icon: _isScanningWifi
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: MauSac.primary),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  _isScanningWifi ? 'Đang quét...' : 'Quét WiFi',
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Danh sách WiFi quét được
          if (_isScanningWifi) ...[
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const CircularProgressIndicator(color: MauSac.primary),
                  const SizedBox(height: 12),
                  Text(
                    'ESP32 đang quét sóng WiFi xung quanh...',
                    style: GoogleFonts.manrope(fontSize: 13, color: MauSac.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ] else if (_danhSachWifi.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MauSac.borderSubtle),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _danhSachWifi.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: MauSac.borderSubtle),
                itemBuilder: (ctx, idx) {
                  final wifi = _danhSachWifi[idx];
                  final isSelected = _ssidController.text == wifi.ssid;

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Icon(
                      wifi.signalBars >= 3
                          ? Icons.wifi_rounded
                          : (wifi.signalBars == 2 ? Icons.wifi_2_bar_rounded : Icons.wifi_1_bar_rounded),
                      color: isSelected ? MauSac.primary : MauSac.onSurfaceVariant,
                      size: 20,
                    ),
                    title: Text(
                      wifi.ssid,
                      style: GoogleFonts.manrope(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13.5,
                        color: isSelected ? MauSac.primary : MauSac.onSurface,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!wifi.isOpen)
                          const Icon(Icons.lock_rounded, size: 14, color: MauSac.outline),
                        const SizedBox(width: 8),
                        Text(
                          '${wifi.rssi} dBm',
                          style: GoogleFonts.manrope(fontSize: 11, color: MauSac.outline),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? MauSac.primary : MauSac.outlineVariant,
                          size: 18,
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _ssidController.text = wifi.ssid;
                      });
                    },
                  );
                },
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MauSac.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: MauSac.outline, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bấm "Quét WiFi" ở góc phải để ESP32 tìm các mạng WiFi gần đó, hoặc tự nhập bên dưới.',
                      style: GoogleFonts.manrope(fontSize: 12, color: MauSac.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Form nhập WiFi
          Text(
            'THÔNG TIN KẾT NỐI WIFI',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: MauSac.outline,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _ssidController,
            decoration: InputDecoration(
              labelText: 'Tên mạng WiFi (SSID)',
              hintText: 'Nhập hoặc chọn WiFi ở danh sách trên',
              prefixIcon: const Icon(Icons.wifi, color: MauSac.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _passController,
            obscureText: !_hienMatKhau,
            decoration: InputDecoration(
              labelText: 'Mật khẩu WiFi (Password)',
              hintText: 'Nhập mật khẩu WiFi',
              prefixIcon: const Icon(Icons.lock_outline, color: MauSac.primary),
              suffixIcon: IconButton(
                icon: Icon(_hienMatKhau ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() {
                    _hienMatKhau = !_hienMatKhau;
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            '💡 Mẹo: ESP32 hỗ trợ mạng Wi-Fi băng tần 2.4GHz. Mật khẩu sẽ được lưu vào bộ nhớ Flash của chip, không bị mất khi rút nguồn.',
            style: GoogleFonts.manrope(fontSize: 12, color: MauSac.outline, fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 20),

          // Nút bấm Kết nối WiFi
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSendingWifi ? null : _guiCauHinhWifi,
              icon: _isSendingWifi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isSendingWifi ? 'Đang gửi cấu hình xuống ESP32...' : 'Kết nối WiFi cho ESP32',
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MauSac.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // Thông báo kết quả
          if (_thongBaoKetQuaWifi.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MauSac.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MauSac.success.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: MauSac.success, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Đã gửi cấu hình thành công!',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          color: MauSac.success,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _thongBaoKetQuaWifi,
                    style: GoogleFonts.manrope(fontSize: 12.5, color: MauSac.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

