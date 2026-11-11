import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';

/// Nút trợ lý IoT thông minh nổi (Floating Draggable Widget) tương thích project_24ct_lenhatnam
class NutAiChatFloating extends StatefulWidget {
  const NutAiChatFloating({super.key});

  static double? toaDoX;
  static double? toaDoY;
  static bool daKhoiTao = false;

  @override
  State<NutAiChatFloating> createState() => _NutAiChatFloatingState();
}

class _NutAiChatFloatingState extends State<NutAiChatFloating> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    if (!NutAiChatFloating.daKhoiTao ||
        NutAiChatFloating.toaDoX == null ||
        NutAiChatFloating.toaDoY == null) {
      NutAiChatFloating.toaDoX = size.width - 66;
      NutAiChatFloating.toaDoY = size.height - padding.bottom - 150;
      NutAiChatFloating.daKhoiTao = true;
    } else {
      final minY = padding.top + 60;
      final maxY = size.height - padding.bottom - 130;
      NutAiChatFloating.toaDoX =
          NutAiChatFloating.toaDoX!.clamp(10.0, size.width - 66);
      NutAiChatFloating.toaDoY =
          NutAiChatFloating.toaDoY!.clamp(minY, maxY);
    }
  }

  void _moModalTroLy() {
    final esp = Esp32Service.instance;
    final state = esp.state;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: MauSac.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MauSac.secondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy, color: MauSac.secondary, size: 26),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trợ lý Giám sát IoT Smart Parking',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MauSac.onSurface,
                      ),
                    ),
                    Text(
                      'Chẩn đoán trạng thái phần cứng & cảm biến',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: MauSac.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MauSac.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MauSac.borderSubtle),
              ),
              child: Column(
                children: [
                  _diagRow('ESP32 Gateway:', state.isDemoMode ? 'Chế độ Demo (Mô phỏng)' : 'http://${state.espIp}:${state.port}'),
                  const SizedBox(height: 8),
                  _diagRow('Trạng thái kết nối:', state.isOnline ? '🟢 Đang Online' : (state.isDemoMode ? '🟠 Mô phỏng' : '🔴 Mất kết nối')),
                  const SizedBox(height: 8),
                  _diagRow('Barie Cổng Vào (GPIO 18):', state.inGate.isOpen ? 'MỞ (90°)' : 'ĐÓNG (0°)'),
                  const SizedBox(height: 8),
                  _diagRow('Cảm biến IR Vào (GPIO 2):', state.inGate.sensorDetected ? '🚨 Có xe' : 'Bình thường'),
                  const SizedBox(height: 8),
                  _diagRow('Barie Cổng Ra (GPIO 19):', state.outGate.isOpen ? 'MỞ (90°)' : 'ĐÓNG (0°)'),
                  const SizedBox(height: 8),
                  _diagRow('Cảm biến IR Ra (GPIO 4):', state.outGate.sensorDetected ? '🚨 Có xe' : 'Bình thường'),
                  const SizedBox(height: 8),
                  _diagRow('Khóa chống quá tải:', state.isFull ? '🚨 ĐANG KÍCH HOẠT (ĐẦY BÃI)' : 'Bình thường'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MauSac.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Đóng', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.manrope(fontSize: 13, color: MauSac.onSurfaceVariant)),
        Text(val, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: MauSac.onSurface)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!NutAiChatFloating.daKhoiTao ||
        NutAiChatFloating.toaDoX == null ||
        NutAiChatFloating.toaDoY == null) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final minY = padding.top + 60;
    final maxY = size.height - padding.bottom - 130;

    return Positioned(
      left: NutAiChatFloating.toaDoX,
      top: NutAiChatFloating.toaDoY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            NutAiChatFloating.toaDoX = (NutAiChatFloating.toaDoX! + details.delta.dx)
                .clamp(10.0, size.width - 66);
            NutAiChatFloating.toaDoY = (NutAiChatFloating.toaDoY! + details.delta.dy)
                .clamp(minY, maxY);
          });
        },
        child: Material(
          elevation: 6,
          shape: const CircleBorder(),
          color: Colors.transparent,
          child: InkWell(
            onTap: _moModalTroLy,
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MauSac.secondary, Color(0xFF4A148C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MauSac.secondary.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
