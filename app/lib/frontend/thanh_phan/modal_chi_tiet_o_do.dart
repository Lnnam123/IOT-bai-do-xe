import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../backend/models/models.dart';
import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';

/// Modal chi tiết và quản lý Ô đỗ xe (Check-in / Check-out / Tính cước phí)
class ModalChiTietODo extends StatefulWidget {
  final ODoXe slot;
  final VoidCallback onUpdated;

  const ModalChiTietODo({
    super.key,
    required this.slot,
    required this.onUpdated,
  });

  static Future<void> show(BuildContext context, ODoXe slot, VoidCallback onUpdated) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModalChiTietODo(slot: slot, onUpdated: onUpdated),
    );
  }

  @override
  State<ModalChiTietODo> createState() => _ModalChiTietODoState();
}

class _ModalChiTietODoState extends State<ModalChiTietODo> {
  String _loaiXe = 'Ô tô';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.slot.isOccupied) {
      _loaiXe = widget.slot.vehicleType;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _xuLyNhanXe() async {
    setState(() => _isLoading = true);
    final success = await Esp32Service.instance.xeVaoBai(
      loaiXe: _loaiXe,
      maO: widget.slot.id,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onUpdated();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhận xe vào ${widget.slot.label} thành công!', style: GoogleFonts.manrope()),
          backgroundColor: MauSac.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể nhận xe: Bãi đỗ đã đầy!', style: GoogleFonts.manrope()),
          backgroundColor: MauSac.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _xuLyTraXe() async {
    final duration = widget.slot.formattedDuration;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xác nhận xe rời bãi',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vị trí ô đỗ: ${widget.slot.label}', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Thời gian đỗ: $duration', style: GoogleFonts.manrope()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Hủy bỏ', style: GoogleFonts.manrope()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MauSac.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Xác nhận & Mở Barie', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    await Esp32Service.instance.xeRaBai(widget.slot.id);
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cho xe rời ${widget.slot.label}, mở Cổng Ra thành công!', style: GoogleFonts.manrope()),
        backgroundColor: MauSac.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isOccupied = widget.slot.isOccupied;

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: 24 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: MauSac.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MauSac.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? MauSac.error.withValues(alpha: 0.12)
                          : MauSac.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isOccupied ? Icons.directions_car : Icons.local_parking,
                      color: isOccupied ? MauSac.error : MauSac.success,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết ${widget.slot.label}',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: MauSac.onSurface,
                        ),
                      ),
                      Text(
                        'Cảm biến kết nối: ${widget.slot.gpioPin}',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: MauSac.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? MauSac.error.withValues(alpha: 0.12)
                      : MauSac.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOccupied ? 'Đang đỗ' : 'Còn trống',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOccupied ? MauSac.error : MauSac.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: MauSac.borderSubtle),
          const SizedBox(height: 16),

          if (isOccupied) ...[
            // Information when slot is occupied
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MauSac.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MauSac.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Trạng thái', 'Có xe đang đỗ', isBold: true),
                  const SizedBox(height: 10),
                  _buildInfoRow('Loại phương tiện', widget.slot.vehicleType),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    'Thời gian vào',
                    widget.slot.entryTime != null
                        ? DateFormat('HH:mm:ss - dd/MM/yyyy').format(widget.slot.entryTime!)
                        : '--',
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Thời gian đã đỗ', widget.slot.formattedDuration, highlight: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Button check-out
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MauSac.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _xuLyTraXe,
                icon: const Icon(Icons.exit_to_app),
                label: Text(
                  'Xác nhận xe rời ô',
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            // Form to check in when slot is empty
            Text(
              'Chọn loại phương tiện vào ô:',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: MauSac.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildVehicleTypeButton('Ô tô', Icons.directions_car),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildVehicleTypeButton('Xe máy', Icons.two_wheeler),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MauSac.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _xuLyNhanXe,
                icon: const Icon(Icons.login),
                label: Text(
                  'Xác nhận nhận xe vào đỗ',
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool highlight = false, bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: isLarge ? 15 : 13.5,
            color: MauSac.onSurfaceVariant,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: isLarge ? 18 : 14,
            fontWeight: isBold || highlight || isLarge ? FontWeight.bold : FontWeight.w500,
            color: highlight || isLarge ? MauSac.primary : MauSac.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeButton(String title, IconData icon) {
    final isSelected = _loaiXe == title;
    return InkWell(
      onTap: () => setState(() => _loaiXe = title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? MauSac.primary.withValues(alpha: 0.12) : MauSac.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MauSac.primary : MauSac.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? MauSac.primary : MauSac.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? MauSac.primary : MauSac.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
