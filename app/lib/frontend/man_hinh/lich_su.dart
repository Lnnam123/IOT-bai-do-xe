import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../backend/models/models.dart';
import '../chu_de/mau_sac.dart';

/// Màn hình 3: Lịch sử xe ra vào bãi
class ManHinhLichSu extends StatefulWidget {
  static const String tenTrang = 'Lịch sử ra vào';

  final List<LichSuXeRaVao> danhSachLichSu;
  final VoidCallback onRefresh;

  const ManHinhLichSu({
    super.key,
    required this.danhSachLichSu,
    required this.onRefresh,
  });

  @override
  State<ManHinhLichSu> createState() => _ManHinhLichSuState();
}

class _ManHinhLichSuState extends State<ManHinhLichSu> {
  String _tuKhoa = '';

  int get tongLuotVao => widget.danhSachLichSu.where((l) => l.suKien == 'VÀO').length;
  int get tongLuotRa => widget.danhSachLichSu.where((l) => l.suKien == 'RA').length;
  int get tongLuot => widget.danhSachLichSu.length;

  List<LichSuXeRaVao> get _danhSachLoc {
    if (_tuKhoa.isEmpty) return widget.danhSachLichSu;
    final q = _tuKhoa.toLowerCase();
    return widget.danhSachLichSu.where((l) {
      return l.loaiXe.toLowerCase().contains(q) ||
          l.suKien.toLowerCase().contains(q) ||
          (l.viTriO?.toLowerCase().contains(q) ?? false) ||
          (l.ghiChu?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MauSac.background,
      appBar: AppBar(
        backgroundColor: MauSac.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          ManHinhLichSu.tenTrang,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: MauSac.onSurface,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Operations Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MauSac.surface,
                  borderRadius: BorderRadius.circular(20),
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
                    Text(
                      'TỔNG LƯỢT XE RA VÀO BÃI',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: MauSac.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$tongLuot lượt',
                      style: GoogleFonts.manrope(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: MauSac.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: MauSac.borderSubtle),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            title: 'Tổng lượt vào',
                            val: '$tongLuotVao lượt',
                            icon: Icons.arrow_downward,
                            color: MauSac.success,
                          ),
                        ),
                        Container(width: 1, height: 36, color: MauSac.borderSubtle),
                        Expanded(
                          child: _buildMiniStat(
                            title: 'Tổng lượt ra',
                            val: '$tongLuotRa lượt',
                            icon: Icons.arrow_upward,
                            color: MauSac.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Search bar
              TextField(
                onChanged: (val) => setState(() => _tuKhoa = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Tìm theo vị trí ô đỗ hoặc sự kiện...',
                  hintStyle: GoogleFonts.manrope(fontSize: 14, color: MauSac.outline),
                  prefixIcon: const Icon(Icons.search, color: MauSac.primary, size: 22),
                  filled: true,
                  fillColor: MauSac.surface,
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
              const SizedBox(height: 18),

              Text(
                'Chi tiết các lượt xe (${_danhSachLoc.length})',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: MauSac.onSurface,
                ),
              ),
              const SizedBox(height: 10),

              if (_danhSachLoc.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.history, size: 48, color: MauSac.outlineVariant),
                        const SizedBox(height: 10),
                        Text(
                          'Chưa có dữ liệu lịch sử xe ra vào',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: MauSac.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _danhSachLoc.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = _danhSachLoc[idx];
                    final isVao = item.suKien == 'VÀO';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MauSac.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MauSac.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isVao
                                  ? MauSac.success.withValues(alpha: 0.12)
                                  : MauSac.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isVao ? Icons.login : Icons.logout,
                              color: isVao ? MauSac.success : MauSac.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${item.loaiXe} - ${item.viTriO ?? "Bãi xe"}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: MauSac.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isVao
                                            ? MauSac.success.withValues(alpha: 0.1)
                                            : MauSac.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.suKien,
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isVao ? MauSac.success : MauSac.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.formattedTime,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: MauSac.onSurfaceVariant,
                                  ),
                                ),
                                if (item.ghiChu != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.ghiChu!,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      color: MauSac.outline,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required String title,
    required String val,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              val,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: MauSac.onSurface,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: MauSac.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
