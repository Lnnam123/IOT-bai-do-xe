import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';
import 'modal_cai_dat_suc_chua.dart';

/// Modal thao tác khẩn cấp / hành động nhanh từ Floating Action Button
class ModalHanhDongNhanh extends StatelessWidget {
  final VoidCallback onUpdated;

  const ModalHanhDongNhanh({super.key, required this.onUpdated});

  static Future<void> show(BuildContext context, VoidCallback onUpdated) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ModalHanhDongNhanh(onUpdated: onUpdated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esp = Esp32Service.instance;
    final isFull = esp.state.isFull;

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 28),
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
            'Thao tác nhanh Bãi đỗ xe ESP32',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: MauSac.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Điều khiển trực tiếp phần cứng và trạng thái bãi xe',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: MauSac.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Action 1: Nhận xe vào (+1)
          _buildActionItem(
            context: context,
            icon: Icons.login,
            iconColor: MauSac.primary,
            title: 'Mô phỏng xe vào bãi (+1)',
            subtitle: isFull
                ? 'Bãi đã đầy (${esp.state.currentCount}/${esp.state.maxCapacity}) - Bị khóa'
                : 'Mở barie lối vào (D18), đếm +1 và tự đóng sau 3s',
            enabled: !isFull,
            onTap: () async {
              Navigator.of(context).pop();
              final success = await esp.xeVaoBai();
              onUpdated();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Đã mở barie và nhận xe vào bãi!'
                          : 'Bãi xe đã đầy! Không thể cho xe vào.',
                      style: GoogleFonts.manrope(),
                    ),
                    backgroundColor: success ? MauSac.success : MauSac.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),

          // Action 2: Mở barie vào thủ công
          _buildActionItem(
            context: context,
            icon: Icons.meeting_room,
            iconColor: MauSac.success,
            title: 'Mở Barie Cổng Vào (90°)',
            subtitle: isFull ? 'Bãi đầy - Không thể mở Barie vào!' : 'Nâng thanh chắn GPIO 18 lên 90 độ',
            enabled: !isFull,
            onTap: () async {
              Navigator.of(context).pop();
              await esp.dieuKhienCong('in', 'open');
              onUpdated();
            },
          ),
          const SizedBox(height: 10),

          // Action 3: Mở barie ra thủ công
          _buildActionItem(
            context: context,
            icon: Icons.no_meeting_room,
            iconColor: MauSac.secondary,
            title: 'Mở Barie Cổng Ra (90°)',
            subtitle: 'Nâng thanh chắn GPIO 19 lên 90 độ cho xe xuất bãi',
            onTap: () async {
              Navigator.of(context).pop();
              await esp.dieuKhienCong('out', 'open');
              onUpdated();
            },
          ),
          const SizedBox(height: 10),

          // Action 4: Cài đặt sức chứa
          _buildActionItem(
            context: context,
            icon: Icons.tune,
            iconColor: MauSac.warning,
            title: 'Cài đặt sức chứa tối đa & số xe',
            subtitle: 'Điều chỉnh giới hạn Max Capacity và đếm xe',
            onTap: () {
              Navigator.of(context).pop();
              ModalCaiDatSucChua.show(
                context,
                currentCapacity: esp.state.maxCapacity,
                currentCount: esp.state.currentCount,
                onUpdated: onUpdated,
              );
            },
          ),
          const SizedBox(height: 10),

          // Action 5: Reset Counter
          _buildActionItem(
            context: context,
            icon: Icons.restart_alt,
            iconColor: MauSac.error,
            title: 'Đặt lại bộ đếm xe về 0 (Reset)',
            subtitle: 'Xóa toàn bộ số lượng xe trong bãi và đóng cổng',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Xác nhận Đặt lại bộ đếm?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                  content: Text(
                    'Toàn bộ số lượng xe hiện tại sẽ đặt về 0 và toàn bộ ô đỗ sẽ chuyển về trạng thái Trống.',
                    style: GoogleFonts.manrope(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text('Hủy bỏ', style: GoogleFonts.manrope()),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MauSac.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text('Đặt lại 0', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (context.mounted) Navigator.of(context).pop();
                await esp.datLaiBoDem();
                onUpdated();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? MauSac.surfaceContainerLow : MauSac.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MauSac.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: enabled ? iconColor.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: enabled ? iconColor : Colors.grey, size: 22),
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
                      fontWeight: FontWeight.bold,
                      color: enabled ? MauSac.onSurface : MauSac.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: enabled ? MauSac.onSurfaceVariant : MauSac.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: enabled ? MauSac.outlineVariant : Colors.transparent),
          ],
        ),
      ),
    );
  }
}
