import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backend/models/models.dart';
import 'backend/services/esp32_service.dart';
import 'frontend/chu_de/mau_sac.dart';
import 'frontend/man_hinh/cai_dat.dart';
import 'frontend/man_hinh/lich_su.dart';
import 'frontend/man_hinh/so_do_bai_xe.dart';
import 'frontend/man_hinh/thong_bao.dart';
import 'frontend/man_hinh/tong_quan.dart';
import 'frontend/thanh_phan/modal_hanh_dong_nhanh.dart';
import 'frontend/thanh_phan/skeleton_loading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo dịch vụ ESP32 và tải cấu hình đã lưu
  await Esp32Service.instance.khoiTao();

  runApp(const SmartParkingApp());
}

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bãi đổ xe',
      debugShowCheckedModeBanner: false,
      theme: MauSac.lightTheme,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ManHinhChinh(),
    );
  }
}

class ManHinhChinh extends StatefulWidget {
  const ManHinhChinh({super.key});

  @override
  State<ManHinhChinh> createState() => _ManHinhChinhState();
}

class _ManHinhChinhState extends State<ManHinhChinh> {
  int _chiMucHienTai = 0;
  bool _truotSangTrai = true;
  bool _isLoading = false;

  final NguoiDung _nguoiDung = NguoiDung.macDinh();
  final Esp32Service _espService = Esp32Service.instance;

  @override
  void initState() {
    super.initState();
    _espService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _espService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _lamMoiDuLieu() async {
    setState(() => _isLoading = true);
    await _espService.dongBoDuLieu();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _moThongBao() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManHinhThongBao(
          onUpdated: () => setState(() {}),
        ),
      ),
    );
    setState(() {});
  }

  void _moModalHanhDongNhanh() {
    ModalHanhDongNhanh.show(context, () => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final cacManHinh = [
      ManHinhTongQuan(
        state: _espService.state,
        onRefresh: _lamMoiDuLieu,
        moThongBao: _moThongBao,
        coThongBaoChuaDoc: _espService.coThongBaoChuaDoc,
        xemTatCaODo: () {
          setState(() {
            _truotSangTrai = true;
            _chiMucHienTai = 1;
          });
        },
      ),
      ManHinhSoDoBaiXe(
        danhSachODo: _espService.state.slots,
        onRefresh: _lamMoiDuLieu,
      ),
      ManHinhLichSu(
        danhSachLichSu: _espService.danhSachLichSu,
        onRefresh: _lamMoiDuLieu,
      ),
      ManHinhCaiDat(
        nguoiDung: _nguoiDung,
        onUpdated: () => setState(() {}),
      ),
    ];

    Widget bodyContent;
    if (_isLoading) {
      bodyContent = const TrangTongQuanSkeleton();
    } else {
      bodyContent = AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming =
              (child.key as ValueKey<int>).value == _chiMucHienTai;

          final slideDirection = _truotSangTrai ? 1.0 : -1.0;
          final offsetBegin = isIncoming
              ? Offset(slideDirection, 0.0)
              : Offset(-slideDirection, 0.0);

          final slideAnimation = Tween<Offset>(
            begin: offsetBegin,
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
        child: Container(
          key: ValueKey<int>(_chiMucHienTai),
          child: cacManHinh[_chiMucHienTai],
        ),
      );
    }

    return Scaffold(
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: MauSac.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        onPressed: _moModalHanhDongNhanh,
        child: const Icon(Icons.flash_on, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: MauSac.surfaceContainerHighest,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.grid_view_outlined, Icons.grid_view),
            _buildNavItem(1, Icons.local_parking_outlined, Icons.local_parking),
            const SizedBox(width: 48), // Khoảng trống cho FAB docked
            _buildNavItem(2, Icons.history_outlined, Icons.history),
            _buildNavItem(3, Icons.settings_outlined, Icons.settings),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon) {
    final isSelected = _chiMucHienTai == index;
    return GestureDetector(
      onTap: () {
        if (_chiMucHienTai != index) {
          setState(() {
            _truotSangTrai = index > _chiMucHienTai;
            _chiMucHienTai = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? solidIcon : outlineIcon,
              color: isSelected ? MauSac.primary : MauSac.onSurfaceVariant,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
