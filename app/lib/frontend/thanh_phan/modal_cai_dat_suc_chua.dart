import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';

/// Modal cài đặt sức chứa tối đa và điều chỉnh số xe
class ModalCaiDatSucChua extends StatefulWidget {
  final int currentCapacity;
  final int currentCount;
  final VoidCallback onUpdated;

  const ModalCaiDatSucChua({
    super.key,
    required this.currentCapacity,
    required this.currentCount,
    required this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentCapacity,
    required int currentCount,
    required VoidCallback onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModalCaiDatSucChua(
        currentCapacity: currentCapacity,
        currentCount: currentCount,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<ModalCaiDatSucChua> createState() => _ModalCaiDatSucChuaState();
}

class _ModalCaiDatSucChuaState extends State<ModalCaiDatSucChua> {
  late TextEditingController _capacityController;
  late TextEditingController _countController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _capacityController = TextEditingController(text: widget.currentCapacity.toString());
    _countController = TextEditingController(text: widget.currentCount.toString());
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _luuSucChua() async {
    final cap = int.tryParse(_capacityController.text.trim());
    if (cap == null || cap < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sức chứa tối đa phải lớn hơn 0', style: GoogleFonts.manrope()),
          backgroundColor: MauSac.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Esp32Service.instance.caiDatSucChua(cap);
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật sức chứa thành $cap xe!', style: GoogleFonts.manrope()),
        backgroundColor: MauSac.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _luuSoXe() async {
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Số xe hiện tại phải lớn hơn hoặc bằng 0', style: GoogleFonts.manrope()),
          backgroundColor: MauSac.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Esp32Service.instance.dieuChinhSoXe(count);
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã điều chỉnh số xe thành $count xe!', style: GoogleFonts.manrope()),
        backgroundColor: MauSac.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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

          Text(
            'Cài đặt thông số bãi xe ESP32',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: MauSac.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dữ liệu sẽ được cập nhật đồng thời lên Vi điều khiển ESP32 và Web Dashboard.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: MauSac.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Setting 1: Max Capacity
          Text(
            'Sức chứa tối đa (Max Capacity)',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MauSac.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.warehouse, color: MauSac.primary),
                    suffixText: 'xe',
                    filled: true,
                    fillColor: MauSac.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MauSac.borderSubtle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MauSac.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _luuSucChua,
                child: Text('Lưu', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Setting 2: Adjust current car count
          Text(
            'Điều chỉnh số xe thực tế (Set Count)',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MauSac.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.directions_car, color: MauSac.secondary),
                    suffixText: 'xe',
                    filled: true,
                    fillColor: MauSac.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MauSac.borderSubtle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MauSac.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _luuSoXe,
                child: Text('Lưu', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick preset buttons
          Text(
            'Cài đặt nhanh sức chứa:',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: MauSac.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [3, 4, 5, 10, 20].map((presetVal) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text('$presetVal xe'),
                  backgroundColor: MauSac.surfaceContainer,
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MauSac.primary,
                  ),
                  onPressed: () {
                    _capacityController.text = presetVal.toString();
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
