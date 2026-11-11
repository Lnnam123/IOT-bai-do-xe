import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/models/models.dart';
import '../chu_de/mau_sac.dart';
import '../thanh_phan/modal_chi_tiet_o_do.dart';

/// Màn hình 2: Sơ đồ chi tiết và quản lý các ô đỗ xe trong bãi
class ManHinhSoDoBaiXe extends StatefulWidget {
  static const String tenTrang = 'Sơ đồ Bãi xe';

  final List<ODoXe> danhSachODo;
  final VoidCallback onRefresh;

  const ManHinhSoDoBaiXe({
    super.key,
    required this.danhSachODo,
    required this.onRefresh,
  });

  @override
  State<ManHinhSoDoBaiXe> createState() => _ManHinhSoDoBaiXeState();
}

class _ManHinhSoDoBaiXeState extends State<ManHinhSoDoBaiXe> {
  String _boLoc = 'ALL'; // 'ALL', 'AVAILABLE', 'OCCUPIED'
  String _tuKhoaTimKiem = '';

  List<ODoXe> get _danhSachLoc {
    return widget.danhSachODo.where((slot) {
      if (_boLoc == 'AVAILABLE' && slot.isOccupied) return false;
      if (_boLoc == 'OCCUPIED' && !slot.isOccupied) return false;

      if (_tuKhoaTimKiem.isNotEmpty) {
        final query = _tuKhoaTimKiem.toLowerCase();
        final matchLabel = slot.label.toLowerCase().contains(query);
        final matchPin = slot.gpioPin.toLowerCase().contains(query);
        return matchLabel || matchPin;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final soChoTrong = widget.danhSachODo.where((s) => !s.isOccupied).length;
    final soChoDaDo = widget.danhSachODo.where((s) => s.isOccupied).length;

    return Scaffold(
      backgroundColor: MauSac.background,
      appBar: AppBar(
        backgroundColor: MauSac.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          ManHinhSoDoBaiXe.tenTrang,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: MauSac.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips & Search Bar
          Container(
            color: MauSac.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Search box
                TextField(
                  onChanged: (val) => setState(() => _tuKhoaTimKiem = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên ô đỗ...',
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: MauSac.outline),
                    prefixIcon: const Icon(Icons.search, color: MauSac.primary, size: 22),
                    filled: true,
                    fillColor: MauSac.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MauSac.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MauSac.borderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter pills
                Row(
                  children: [
                    _buildFilterChip('Tất cả (${widget.danhSachODo.length})', 'ALL'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Còn trống ($soChoTrong)', 'AVAILABLE', color: MauSac.success),
                    const SizedBox(width: 8),
                    _buildFilterChip('Đang đỗ ($soChoDaDo)', 'OCCUPIED', color: MauSac.error),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: MauSac.borderSubtle),

          // Slots Grid List
          Expanded(
            child: _danhSachLoc.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 54, color: MauSac.outlineVariant),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy ô đỗ phù hợp',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MauSac.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => widget.onRefresh(),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: _danhSachLoc.length,
                      itemBuilder: (context, idx) {
                        final slot = _danhSachLoc[idx];
                        return _buildSlotCard(slot);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String code, {Color? color}) {
    final isSelected = _boLoc == code;
    return InkWell(
      onTap: () => setState(() => _boLoc = code),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? MauSac.primary)
              : MauSac.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? MauSac.primary)
                : MauSac.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : MauSac.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(ODoXe slot) {
    final isOccupied = slot.isOccupied;

    return InkWell(
      onTap: () => ModalChiTietODo.show(context, slot, widget.onRefresh),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MauSac.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOccupied ? MauSac.error.withValues(alpha: 0.5) : MauSac.borderSubtle,
            width: isOccupied ? 1.5 : 1,
          ),
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
            // Top Row: Slot ID + Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  slot.label,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MauSac.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? MauSac.error.withValues(alpha: 0.12)
                        : MauSac.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOccupied ? 'Có xe' : 'Trống',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOccupied ? MauSac.error : MauSac.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Icon + GPIO Pin
            Row(
              children: [
                Icon(
                  isOccupied ? Icons.directions_car : Icons.local_parking,
                  size: 28,
                  color: isOccupied ? MauSac.error : MauSac.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot.gpioPin,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: MauSac.outline,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Status when occupied or empty
            if (isOccupied) ...[
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 16, color: MauSac.error),
                  const SizedBox(width: 4),
                  Text(
                    'CÓ XE ĐỖ',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: MauSac.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Thời gian: ${slot.formattedDuration}',
                style: GoogleFonts.manrope(fontSize: 11, color: MauSac.onSurfaceVariant),
              ),
            ] else ...[
              Text(
                'Sẵn sàng nhận xe',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: MauSac.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nhấn để Check-in',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: MauSac.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
