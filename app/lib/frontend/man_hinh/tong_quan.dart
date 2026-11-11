import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/models/models.dart';
import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';
import '../thanh_phan/modal_cai_dat_suc_chua.dart';
import '../thanh_phan/modal_chi_tiet_o_do.dart';
import '../thanh_phan/modal_quet_va_ket_noi_esp32.dart';

/// Màn hình 1: Tổng quan giám sát bãi đỗ xe ESP32 (Chuẩn layout CoinTap)
class ManHinhTongQuan extends StatelessWidget {
  static const String tenTrang = 'Tổng quan Bãi xe';

  final HeThongBaiXeState state;
  final VoidCallback onRefresh;
  final VoidCallback moThongBao;
  final bool coThongBaoChuaDoc;
  final VoidCallback xemTatCaODo;

  const ManHinhTongQuan({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.moThongBao,
    required this.coThongBaoChuaDoc,
    required this.xemTatCaODo,
  });

  @override
  Widget build(BuildContext context) {
    final esp = Esp32Service.instance;
    final isFull = state.isFull;

    return Scaffold(
      backgroundColor: MauSac.background,
      appBar: AppBar(
        backgroundColor: MauSac.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: MauSac.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_parking, color: MauSac.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'BÃI ĐỖ XE ESP32',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: MauSac.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          // Connection badge (Bấm để quét và cấu hình ESP32)
          InkWell(
            onTap: () {
              ModalQuetVaKetNoiEsp32.show(
                context,
                onConnected: onRefresh,
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: state.isOnline
                    ? MauSac.success.withValues(alpha: 0.12)
                    : (state.isDemoMode
                        ? MauSac.warning.withValues(alpha: 0.12)
                        : MauSac.error.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: state.isOnline
                          ? MauSac.success
                          : (state.isDemoMode ? MauSac.warning : MauSac.error),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.isOnline
                        ? 'Online'
                        : (state.isDemoMode ? 'Demo' : 'Offline'),
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: state.isOnline
                          ? MauSac.success
                          : (state.isDemoMode ? MauSac.warning : MauSac.error),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.wifi_find_rounded,
                    size: 14,
                    color: state.isOnline
                        ? MauSac.success
                        : (state.isDemoMode ? MauSac.warning : MauSac.error),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: MauSac.onSurface),
                if (coThongBaoChuaDoc)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: MauSac.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: moThongBao,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner nhắc nhở quét & kết nối ESP32 khi chưa Online
              if (!state.isOnline) ...[
                InkWell(
                  onTap: () {
                    ModalQuetVaKetNoiEsp32.show(
                      context,
                      onConnected: onRefresh,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: MauSac.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MauSac.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MauSac.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isDemoMode
                                    ? 'Đang ở chế độ Mô phỏng (Demo)'
                                    : 'Chưa kết nối ESP32 phần cứng',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: MauSac.primary,
                                ),
                              ),
                              Text(
                                'Bấm vào đây để quét tìm & cài đặt WiFi cho ESP32',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  color: MauSac.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: MauSac.primary, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Banner cảnh báo bãi xe đầy
              if (isFull) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MauSac.error,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: MauSac.error.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚨 BÃI XE ĐÃ ĐẦY (100%)',
                              style: GoogleFonts.manrope(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Barie Cổng Vào tự động KHÓA! Từ chối nhận thêm xe.',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // HERO CARD: Trạng thái Bãi xe (Cointap Blue Gradient Card)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [MauSac.primary, Color(0xFF003EA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MauSac.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SỐ XE TRONG BÃI / SỨC CHỨA',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.white70,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            ModalCaiDatSucChua.show(
                              context,
                              currentCapacity: state.maxCapacity,
                              currentCount: state.currentCount,
                              onUpdated: onRefresh,
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.settings, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Cài đặt',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${state.currentCount}',
                          style: GoogleFonts.manrope(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ' / ${state.maxCapacity} xe',
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isFull
                                ? MauSac.error
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isFull ? 'HẾT CHỖ' : 'CÒN CHỖ',
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: state.occupancyRate,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFull ? MauSac.error : (state.occupancyRate > 0.8 ? MauSac.warning : MauSac.success),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Badges row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Còn trống: ${state.availableSlots} chỗ',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Đã đỗ: ${state.occupancyPercentString}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2 Quick Simulation Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: MauSac.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: isFull ? null : () async {
                              await esp.xeVaoBai();
                              onRefresh();
                            },
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: Text(
                              'Xe Vào (+1)',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: state.currentCount <= 0 ? null : () async {
                              // Tìm ô đỗ đầu tiên có xe để xuất bãi
                              ODoXe? occupiedSlot;
                              for (final s in state.slots) {
                                if (s.isOccupied) {
                                  occupiedSlot = s;
                                  break;
                                }
                              }
                              if (occupiedSlot != null) {
                                await esp.xeRaBai(occupiedSlot.id);
                                onRefresh();
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: Text(
                              'Xe Ra (-1)',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // STATS GRID: 3 Card phong cách CoinTap
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.warehouse,
                      iconColor: MauSac.secondary,
                      title: 'Sức chứa Max',
                      value: '${state.maxCapacity}',
                      subtext: 'Giới hạn',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle_outline,
                      iconColor: MauSac.success,
                      title: 'Còn trống',
                      value: '${state.availableSlots}',
                      subtext: 'Chỗ vào',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.directions_car,
                      iconColor: isFull ? MauSac.error : MauSac.primary,
                      title: 'Đang đỗ',
                      value: '${state.currentCount}',
                      subtext: 'Trong bãi',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // MINI PARKING GRID (Sơ đồ nhanh các ô đỗ)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sơ đồ Ô đỗ trực quan (${state.slots.length} ô)',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MauSac.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: xemTatCaODo,
                    child: Text(
                      'Xem chi tiết',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        color: MauSac.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Grid 5 ô mỗi hàng
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: state.slots.length,
                itemBuilder: (context, idx) {
                  final slot = state.slots[idx];
                  return InkWell(
                    onTap: () {
                      ModalChiTietODo.show(context, slot, onRefresh);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: slot.isOccupied
                            ? MauSac.error.withValues(alpha: 0.12)
                            : MauSac.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: slot.isOccupied ? MauSac.error : MauSac.success,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            slot.isOccupied ? Icons.directions_car : Icons.local_parking,
                            color: slot.isOccupied ? MauSac.error : MauSac.success,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slot.label,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: MauSac.onSurface,
                            ),
                          ),
                          Text(
                            slot.isOccupied ? 'Đỗ' : 'Trống',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: slot.isOccupied ? MauSac.error : MauSac.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: MauSac.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MauSac.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: MauSac.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: MauSac.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
