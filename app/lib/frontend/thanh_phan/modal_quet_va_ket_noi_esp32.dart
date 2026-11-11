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

  // Trạng thái kiểm tra kết nối AP (192.168.4.1)
  bool _isCheckingAp = false;
  ThietBiEsp32TimThay? _apThietBi;
  String? _loiKiemTraAp;

  // Trạng thái quét WiFi từ ESP32
  bool _isScanningWifi = false;
  List<MangWifiQuetDuoc> _danhSachWifi = [];
  bool _isSendingWifi = false;
  bool _hienMatKhau = false;
  String _thongBaoKetQuaWifi = '';

  // Trạng thái quét mạng LAN
  bool _isScanningLan = false;
  List<ThietBiEsp32TimThay> _danhSachLan = [];
  bool _moNhapThuCong = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ipThuCongController.text = esp.state.espIp;

    // Tự động kiểm tra kết nối AP khi mở
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kiemTraKetNoiAp();
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

  /// 1. Kiểm tra kết nối tới Access Point ESP32 (192.168.4.1)
  Future<void> _kiemTraKetNoiAp() async {
    if (_isCheckingAp) return;
    setState(() {
      _isCheckingAp = true;
      _loiKiemTraAp = null;
    });

    try {
      final res = await esp.kiemTraKetNoiAp();
      if (mounted) {
        setState(() {
          _isCheckingAp = false;
          _apThietBi = res;
          if (res == null) {
            _loiKiemTraAp =
                'Chưa nhận được phản hồi từ 192.168.4.1. Hãy kiểm tra xem điện thoại đã kết nối vào Wi-Fi "BaiDoXe_ESP32" (Mật khẩu: 123456789) chưa.';
          } else {
            _loiKiemTraAp = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAp = false;
          _loiKiemTraAp = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  /// 2. Quét các mạng Wi-Fi xung quanh từ ESP32
  Future<void> _quetDanhSachWifi() async {
    if (_isScanningWifi) return;
    setState(() {
      _isScanningWifi = true;
      _danhSachWifi.clear();
      _thongBaoKetQuaWifi = '';
    });

    // Ưu tiên quét qua AP 192.168.4.1 hoặc IP hiện tại
    final targetIp = _apThietBi?.ip ?? '192.168.4.1';
    final list = await esp.quetDanhSachWifi(targetIp, 80);

    if (mounted) {
      setState(() {
        _danhSachWifi = list;
        _isScanningWifi = false;
      });
    }
  }

  /// 3. Gửi SSID và Mật khẩu WiFi xuống ESP32
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

    final targetIp = _apThietBi?.ip ?? '192.168.4.1';

    setState(() {
      _isSendingWifi = true;
      _thongBaoKetQuaWifi = '';
    });

    final success = await esp.cauHinhWifiChoEsp32(
      espIp: targetIp,
      port: 80,
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
              '🎉 Đã gửi cấu hình Wi-Fi "$ssid" xuống ESP32 thành công!\n\n'
              '👉 HƯỚNG DẪN TIẾP THEO:\n'
              '1. ESP32 đang kết nối vào Wi-Fi nhà bạn.\n'
              '2. Nhìn màn hình LCD 1602 của ESP32 để xem địa chỉ IP mới (Ví dụ: IP: 192.168.1.xxx).\n'
              '3. Kết nối điện thoại trở lại Wi-Fi nhà bạn.\n'
              '4. Chuyển sang Tab "Quét mạng LAN & Nhập IP" để kết nối điều khiển!';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gửi cấu hình thất bại! Hãy chắc chắn điện thoại đang kết nối Wi-Fi "BaiDoXe_ESP32" (Mật khẩu: 123456789).',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: MauSac.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 4. Sử dụng ngay chế độ Access Point trực tiếp (192.168.4.1)
  Future<void> _dungCheDoApTrucTiep() async {
    await esp.capNhatKetNoi(
      ip: '192.168.4.1',
      port: 80,
      isDemoMode: false,
    );
    widget.onConnected();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 Đã kết nối trực tiếp với ESP32 qua Access Point (192.168.4.1)!',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
          backgroundColor: MauSac.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 5. Bắt đầu quét tìm ESP32 trong mạng LAN
  Future<void> _quetTimLan() async {
    if (_isScanningLan) return;
    setState(() {
      _isScanningLan = true;
      _danhSachLan.clear();
    });

    try {
      final ipBoSung = _ipThuCongController.text.trim();
      final ketQua = await esp.quetTimThietBiEsp32(
        ipBoSung: ipBoSung.isNotEmpty ? ipBoSung : null,
      );

      if (mounted) {
        setState(() {
          _danhSachLan = ketQua;
          _isScanningLan = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanningLan = false;
        });
      }
    }
  }

  /// 6. Kết nối tới thiết bị cụ thể
  Future<void> _ketNoiThietBi(ThietBiEsp32TimThay tb) async {
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
                        'Cài đặt Wi-Fi cho ESP32 hoặc kết nối mạng LAN',
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
              labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(
                  icon: Icon(Icons.wifi_rounded, size: 18),
                  text: 'Cài đặt Wi-Fi (AP)',
                ),
                Tab(
                  icon: Icon(Icons.router_rounded, size: 18),
                  text: 'Quét LAN / Nhập IP',
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
                _buildTabCaiDatWifiAp(),
                _buildTabQuetLan(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: CÀI ĐẶT WIFI CHO ESP32 QUA ACCESS POINT (192.168.4.1)
  // ===========================================================================
  Widget _buildTabCaiDatWifiAp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hướng dẫn các bước kết nối Wi-Fi ban đầu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MauSac.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MauSac.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings_input_antenna_rounded, color: MauSac.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bước 1: Kết nối Wi-Fi của ESP32 trên điện thoại',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: MauSac.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildHuongDanStep('1', 'Cấp nguồn cho mạch ESP32 (LED nguồn đỏ sáng).'),
                _buildHuongDanStep('2', 'Vào Cài đặt Wi-Fi trên điện thoại, chọn mạng:'),
                Container(
                  margin: const EdgeInsets.only(left: 26, top: 4, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MauSac.borderSubtle),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_lock_rounded, size: 16, color: MauSac.primary),
                          const SizedBox(width: 6),
                          Text(
                            'BaiDoXe_ESP32',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13, color: MauSac.onSurface),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MauSac.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Pass: 123456789',
                          style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold, color: MauSac.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHuongDanStep('3', 'Nếu điện thoại báo "Mạng không có Internet", hãy chọn "Duy trì kết nối" (hoặc tạm tắt 4G).'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Nút kiểm tra kết nối AP (192.168.4.1)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MauSac.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MauSac.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    if (_isCheckingAp)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: MauSac.primary),
                      )
                    else if (_apThietBi != null)
                      const Icon(Icons.check_circle_rounded, color: MauSac.success, size: 24)
                    else
                      const Icon(Icons.help_outline_rounded, color: MauSac.outline, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _apThietBi != null
                                ? 'ĐÃ KẾT NỐI VỚI ESP32 (192.168.4.1)'
                                : 'Trạng thái kết nối AP',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: _apThietBi != null ? MauSac.success : MauSac.onSurface,
                            ),
                          ),
                          Text(
                            _apThietBi != null
                                ? 'Độ trễ: ${_apThietBi!.pingMs} ms | Sẵn sàng cấu hình Wi-Fi'
                                : (_loiKiemTraAp ?? 'Nhấn nút bên cạnh để kiểm tra kết nối'),
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: _loiKiemTraAp != null ? MauSac.error : MauSac.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isCheckingAp ? null : _kiemTraKetNoiAp,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text('Kiểm tra', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MauSac.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                if (_apThietBi != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _dungCheDoApTrucTiep,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Dùng chế độ Trực tiếp này (Không cần Wi-Fi nhà)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MauSac.primary,
                        side: const BorderSide(color: MauSac.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Form cài đặt Wi-Fi nhà bạn cho ESP32
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'CÀI ĐẶT WI-FI CHO ESP32',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: MauSac.outline,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isScanningWifi ? null : _quetDanhSachWifi,
                icon: _isScanningWifi
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: MauSac.primary),
                      )
                    : const Icon(Icons.wifi_find_rounded, size: 16),
                label: Text(
                  _isScanningWifi ? 'Đang dò sóng...' : 'Quét sóng Wi-Fi',
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Danh sách Wi-Fi quét được (nếu có)
          if (_danhSachWifi.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              margin: const EdgeInsets.only(bottom: 14),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    leading: Icon(
                      wifi.signalBars >= 3 ? Icons.wifi_rounded : Icons.wifi_2_bar_rounded,
                      color: isSelected ? MauSac.primary : MauSac.onSurfaceVariant,
                      size: 20,
                    ),
                    title: Text(
                      wifi.ssid,
                      style: GoogleFonts.manrope(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                        color: isSelected ? MauSac.primary : MauSac.onSurface,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!wifi.isOpen)
                          const Icon(Icons.lock_rounded, size: 14, color: MauSac.outline),
                        const SizedBox(width: 8),
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
          ],

          // Form nhập SSID & Pass
          TextField(
            controller: _ssidController,
            decoration: InputDecoration(
              labelText: 'Tên mạng Wi-Fi nhà bạn (SSID)',
              hintText: 'Nhập tên Wi-Fi hoặc chọn ở danh sách trên',
              prefixIcon: const Icon(Icons.wifi, color: MauSac.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _passController,
            obscureText: !_hienMatKhau,
            decoration: InputDecoration(
              labelText: 'Mật khẩu Wi-Fi',
              hintText: 'Nhập mật khẩu Wi-Fi nhà bạn',
              prefixIcon: const Icon(Icons.lock_outline, color: MauSac.primary),
              suffixIcon: IconButton(
                icon: Icon(_hienMatKhau ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _hienMatKhau = !_hienMatKhau),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            '💡 Mẹo: ESP32 hỗ trợ mạng Wi-Fi 2.4GHz. Mật khẩu sẽ được lưu vào bộ nhớ Flash vĩnh viễn, tự động kết nối mỗi khi cắm điện.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: MauSac.outline, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 18),

          // Nút gửi cấu hình Wi-Fi xuống ESP32
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
                _isSendingWifi ? 'Đang gửi cấu hình xuống ESP32...' : 'Gửi Wi-Fi xuống ESP32',
                style: GoogleFonts.manrope(fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MauSac.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Thông báo kết quả sau khi gửi
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
                        'ĐÃ GỬI CẤU HÌNH THÀNH CÔNG',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          color: MauSac.success,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _thongBaoKetQuaWifi,
                    style: GoogleFonts.manrope(fontSize: 12.5, height: 1.5, color: MauSac.onSurface),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Chuyển sang Tab Quét mạng LAN & Nhập IP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MauSac.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(color: MauSac.borderSubtle),
          const SizedBox(height: 14),

          // Khôi phục mặc định (Xóa sạch Wi-Fi)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MauSac.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MauSac.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: MauSac.error, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Khôi phục cài đặt gốc Wi-Fi',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: MauSac.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Xóa toàn bộ Wi-Fi router đã lưu trên ESP32 và quay về chế độ Access Point mặc định (BaiDoXe_ESP32 - 192.168.4.1). Bạn cũng có thể nhấn giữ nút BOOT trên mạch 3 giây.',
                  style: GoogleFonts.manrope(fontSize: 11.5, color: MauSac.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _xacNhanResetWifiMacDinh,
                    icon: const Icon(Icons.delete_sweep_rounded, color: MauSac.error, size: 17),
                    label: Text(
                      'Khôi phục mặc định (Xóa Wi-Fi đã lưu)',
                      style: GoogleFonts.manrope(
                        color: MauSac.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: MauSac.error.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Xác nhận và thực hiện xóa toàn bộ cấu hình Wi-Fi trên ESP32
  Future<void> _xacNhanResetWifiMacDinh() async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: MauSac.error, size: 26),
            const SizedBox(width: 10),
            Text('Xác nhận xóa Wi-Fi?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Hành động này sẽ xóa vĩnh viễn cấu hình Wi-Fi đã lưu trên bộ nhớ Flash của ESP32.\n\n'
          '👉 ESP32 sẽ ngắt kết nối với mọi mạng router và quay về chế độ phát Access Point mặc định (BaiDoXe_ESP32 - IP: 192.168.4.1).',
          style: GoogleFonts.manrope(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Hủy', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MauSac.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Xác nhận xóa', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (xacNhan == true) {
      final success = await esp.resetWifiVeMacDinh();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 Đã khôi phục mặc định! ESP32 đã quay về Access Point (BaiDoXe_ESP32 - 192.168.4.1).',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
              backgroundColor: MauSac.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _kiemTraKetNoiAp();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Không thể gửi lệnh tới ESP32. Hãy kiểm tra điện thoại đã kết nối vào ESP32, hoặc bạn có thể NHẤN GIỮ NÚT BOOT trên mạch 3 giây để xóa trực tiếp.',
                style: GoogleFonts.manrope(),
              ),
              backgroundColor: MauSac.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ===========================================================================
  // TAB 2: QUÉT MẠNG LAN & NHẬP IP HIỂN THỊ TRÊN MÀN HÌNH LCD
  // ===========================================================================
  Widget _buildTabQuetLan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner hướng dẫn xem LCD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MauSac.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MauSac.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MauSac.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tv_rounded, color: MauSac.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xem địa chỉ IP trên LCD 1602',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dòng 2 của màn hình LCD trên mô hình bãi xe sẽ hiển thị IP (Ví dụ: IP: 192.168.1.150). Nhập IP đó vào bên dưới:',
                        style: GoogleFonts.manrope(fontSize: 12, color: MauSac.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Form nhập IP thủ công
          Text(
            'KẾT NỐI NHANH BẰNG ĐỊA CHỈ IP',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: MauSac.outline,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipThuCongController,
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ IP ESP32',
                    hintText: 'Ví dụ: 192.168.1.150 hoặc 192.168.4.1',
                    prefixIcon: const Icon(Icons.lan_rounded, color: MauSac.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final ip = _ipThuCongController.text.trim();
                    if (ip.isNotEmpty) {
                      _ketNoiThietBi(
                        ThietBiEsp32TimThay(
                          ten: 'ESP32 Bãi Đỗ Xe',
                          ip: ip,
                          port: 80,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Kết nối'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MauSac.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Tự động quét tìm trong mạng LAN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'HOẶC DÒ TÌM TRONG MẠNG LAN',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: MauSac.outline,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isScanningLan ? null : _quetTimLan,
                icon: _isScanningLan
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.radar_rounded, size: 16),
                label: Text(
                  _isScanningLan ? 'Đang dò...' : 'Quét mạng LAN',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MauSac.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Danh sách thiết bị tìm thấy
          if (_danhSachLan.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _danhSachLan.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final tb = _danhSachLan[index];
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
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MauSac.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.memory_rounded, color: MauSac.success, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tb.ten,
                              style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            Text(
                              'http://${tb.ip}:${tb.port} (⚡ ${tb.pingMs} ms)',
                              style: GoogleFonts.manrope(fontSize: 12, color: MauSac.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _ketNoiThietBi(tb),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MauSac.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Chọn'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else if (!_isScanningLan) ...[
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MauSac.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Nhấn nút "Quét mạng LAN" ở trên để tự động dò tìm các mạch ESP32 trong mạng Wi-Fi của bạn.',
                style: GoogleFonts.manrope(fontSize: 12.5, color: MauSac.onSurfaceVariant),
                textAlign: TextAlign.center,
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
              color: MauSac.primary,
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
}
