import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/services/esp32_service.dart';
import '../chu_de/mau_sac.dart';

/// Màn hình Thông báo hệ thống bãi xe (Chuẩn phong cách Cointap)
class ManHinhThongBao extends StatefulWidget {
  final VoidCallback onUpdated;

  const ManHinhThongBao({super.key, required this.onUpdated});

  @override
  State<ManHinhThongBao> createState() => _ManHinhThongBaoState();
}

class _ManHinhThongBaoState extends State<ManHinhThongBao> {
  final esp = Esp32Service.instance;

  @override
  void initState() {
    super.initState();
    esp.danhDauTatCaDaDoc();
  }

  @override
  Widget build(BuildContext context) {
    final list = esp.danhSachThongBao;

    return Scaffold(
      backgroundColor: MauSac.background,
      appBar: AppBar(
        backgroundColor: MauSac.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Thông báo hệ thống',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: MauSac.onSurface,
          ),
        ),
        actions: [
          if (list.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: MauSac.onSurfaceVariant),
              tooltip: 'Xóa toàn bộ',
              onPressed: () {
                setState(() {
                  esp.xoaTatCaThongBao();
                });
                widget.onUpdated();
              },
            ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none_outlined, size: 56, color: MauSac.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Không có thông báo mới',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MauSac.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final tb = list[idx];
                Color badgeColor;
                IconData badgeIcon;

                switch (tb.loai) {
                  case 'DANGER':
                    badgeColor = MauSac.error;
                    badgeIcon = Icons.warning_rounded;
                    break;
                  case 'WARNING':
                    badgeColor = MauSac.warning;
                    badgeIcon = Icons.error_outline_rounded;
                    break;
                  case 'SUCCESS':
                    badgeColor = MauSac.success;
                    badgeIcon = Icons.check_circle_outline_rounded;
                    break;
                  case 'INFO':
                  default:
                    badgeColor = MauSac.primary;
                    badgeIcon = Icons.info_outline_rounded;
                    break;
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MauSac.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MauSac.borderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(badgeIcon, color: badgeColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    tb.tieuDe,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: MauSac.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  tb.formattedTime,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: MauSac.outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tb.noiDung,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: MauSac.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
