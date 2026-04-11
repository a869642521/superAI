import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  static const _items = [
    (Icons.explore_outlined, Icons.explore_rounded, '发现'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '对话'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, '伙伴'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: StarpathColors.surfaceBright.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: StarpathColors.outlineVariant,
                  width: 1,
                ),
              ),
              // 用 TweenAnimationBuilder 让选中位置平滑滑动
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: selectedIndex.toDouble()),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, animatedIndex, _) {
                  return CustomPaint(
                    // 光效画在导航栏内部表面
                    painter: _NavGlowPainter(
                      animatedIndex: animatedIndex,
                      itemCount: _items.length,
                    ),
                    child: Row(
                      children: List.generate(_items.length, (i) {
                        final selected = i == selectedIndex;
                        final item = _items[i];
                        return Expanded(
                          child: _NavItem(
                            icon: item.$1,
                            selectedIcon: item.$2,
                            label: item.$3,
                            selected: selected,
                            onTap: () => navigationShell.goBranch(
                              i,
                              initialLocation: i == selectedIndex,
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 把紫色光效直接绘制在导航栏容器表面：
/// • 顶部一条细亮弧线（"发光边缘"）
/// • 顶部向下扩散的径向渐变光晕
/// • 微星点（仅在选中区域上方）
class _NavGlowPainter extends CustomPainter {
  final double animatedIndex;
  final int itemCount;

  const _NavGlowPainter({
    required this.animatedIndex,
    required this.itemCount,
  });

  // 固定星点（相对于单格宽度的偏移比 & y 比）
  static const List<(double, double, double)> _sparks = [
    (-0.28, 0.08, 1.1),
    (-0.10, 0.04, 0.8),
    (0.0, 0.10, 1.3),
    (0.12, 0.06, 0.9),
    (0.30, 0.12, 1.0),
    (-0.18, 0.20, 0.6),
    (0.20, 0.18, 0.7),
    (-0.05, 0.24, 0.5),
    (0.08, 0.28, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final itemW = size.width / itemCount;
    // 选中项中心 x（连续插值，切换时会滑动）
    final cx = itemW * (animatedIndex + 0.5);

    // ── 1. 径向光晕（从顶向下扩散，更宽更亮）
    final glowRect = Rect.fromCenter(
      center: Offset(cx, 0),
      width: itemW * 2.4,
      height: size.height * 2.2,
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -1),
        radius: 0.9,
        colors: [
          StarpathColors.accentViolet.withValues(alpha: 1.0),
          StarpathColors.accentIndigo.withValues(alpha: 0.72),
          StarpathColors.accentIndigo.withValues(alpha: 0.28),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.60, 1.0],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glowPaint);

    // ── 2. 顶边高亮弧（细线 + 加宽柔光）
    const lineHalfW = 36.0;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 1.0),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - lineHalfW, 0, lineHalfW * 2, 3));
    canvas.drawLine(
      Offset(cx - lineHalfW, 0.75),
      Offset(cx + lineHalfW, 0.75),
      linePaint,
    );

    // 柔光扩散层（更宽、更亮）
    final softLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          StarpathColors.accentViolet.withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - lineHalfW - 12, 0, lineHalfW * 2 + 24, 10));
    canvas.drawLine(
      Offset(cx - lineHalfW - 10, 1.5),
      Offset(cx + lineHalfW + 10, 1.5),
      softLine,
    );

    // ── 3. 星点微光（更亮更大）
    final sparkPaint = Paint()..isAntiAlias = true;
    for (final (nx, ny, r) in _sparks) {
      final sx = cx + nx * itemW;
      final sy = size.height * ny;
      final alpha = (0.55 + r * 0.32).clamp(0.0, 1.0);
      sparkPaint.color =
          StarpathColors.accentViolet.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), r.clamp(0.8, 2.0), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_NavGlowPainter old) =>
      old.animatedIndex != animatedIndex || old.itemCount != itemCount;
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  static const List<Shadow> _bloom = [
    Shadow(color: Color(0xFFD4AAFF), blurRadius: 6),
    Shadow(color: Color(0xFFB490FF), blurRadius: 14, offset: Offset(0, 1)),
    Shadow(color: Color(0xCC9B72FF), blurRadius: 26, offset: Offset(0, 2)),
    Shadow(color: Color(0xAA7B5CFF), blurRadius: 40, offset: Offset(0, 3)),
    Shadow(color: Color(0x775B48E8), blurRadius: 56, offset: Offset(0, 5)),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 68,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                key: ValueKey(widget.selected),
                size: 30,
                color: widget.selected
                    ? const Color(0xFFFFF8FC)
                    : StarpathColors.onSurfaceVariant.withValues(alpha: 0.50),
                shadows: widget.selected ? _bloom : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
