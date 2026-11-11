import 'package:flutter/material.dart';
import '../chu_de/mau_sac.dart';

/// Khung xương tải trang (Skeleton loader) cho giao diện Tổng quan
class TrangTongQuanSkeleton extends StatefulWidget {
  const TrangTongQuanSkeleton({super.key});

  @override
  State<TrangTongQuanSkeleton> createState() => _TrangTongQuanSkeletonState();
}

class _TrangTongQuanSkeletonState extends State<TrangTongQuanSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBox({required double width, required double height, double radius = 12}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: MauSac.surfaceContainerHigh.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MauSac.background,
      appBar: AppBar(
        backgroundColor: MauSac.surface,
        title: _buildBox(width: 160, height: 20),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBox(width: 220, height: 26),
            const SizedBox(height: 16),
            // Hero card
            _buildBox(width: double.infinity, height: 180, radius: 20),
            const SizedBox(height: 20),
            // 3 Stats cards
            Row(
              children: [
                Expanded(child: _buildBox(width: double.infinity, height: 100, radius: 16)),
                const SizedBox(width: 12),
                Expanded(child: _buildBox(width: double.infinity, height: 100, radius: 16)),
                const SizedBox(width: 12),
                Expanded(child: _buildBox(width: double.infinity, height: 100, radius: 16)),
              ],
            ),
            const SizedBox(height: 24),
            // Gate control boxes
            _buildBox(width: double.infinity, height: 140, radius: 16),
            const SizedBox(height: 16),
            _buildBox(width: double.infinity, height: 140, radius: 16),
          ],
        ),
      ),
    );
  }
}
