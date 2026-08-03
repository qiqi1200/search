import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

/// LiquidGlass — 液态玻璃表面组件 (v2.1)
///
/// 设计目标：完全透明、高级感的 Apple Liquid Glass 风格
/// 核心特点：
///   1. 极低的底色不透明度 — 让背景完全透出来
///   2. 强烈的 BackdropFilter 模糊 — 玻璃核心
///   3. 柔和的顶部高光 — 仿真玻璃反射
///   4. 单色细边框（2026-08 改版：去掉渐变发丝描边，收敛为可见细边）
///   5. 无噪点、无超假纹理 — 干净纯粹
///
/// 参考：rdev/liquid-glass-react 的 Apple Liquid Glass 风格
class LiquidGlass extends StatelessWidget {
  final Widget child;

  /// 圆角
  final BorderRadius? borderRadius;

  /// 背景模糊强度（sigma）
  final double blur;

  /// 底色不透明度（建议 0.08-0.15）
  final double opacity;

  /// 是否绘制顶部镜面高光
  final bool specular;

  /// 是否绘制渐变发丝边框
  final bool border;

  /// 描边宽度
  final double borderWidth;

  /// 额外阴影
  final List<BoxShadow>? shadows;

  /// 自定义底色（默认取主题 surface）
  final Color? tint;

  /// 是否启用环境光投影
  final bool elevation;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur = 40,           // 增强模糊
    this.opacity = 0.12,      // 默认极低不透明度，更透
    this.specular = true,
    this.border = true,
    this.borderWidth = 1.0,   // 可见细边（2026-08：0.8 → 1.0）
    this.shadows,
    this.tint,
    this.elevation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(16);

    // 全局毛玻璃透明度倍率
    final glassMul = context.watch<SettingsProvider>().glassOpacity.clamp(0.0, 1.0);
    final effectiveOpacity = (opacity * glassMul).clamp(0.0, 1.0);

    // 关键：让背景完全透出来
    // 浅色模式：用纯白底色，极低不透明度
    // 深色模式：用纯黑底色，极低不透明度
    final Color fill = isDark ? Colors.black : Colors.white;

    final Widget surface = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 1. 强烈的背景模糊 — 玻璃核心效果
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(color: Colors.transparent),
            ),
          ),
          // 2. 极淡的半透明底色 — 只是轻微柔化背景
          Positioned.fill(
            child: Container(
              color: fill.withValues(alpha: effectiveOpacity),
            ),
          ),
          // 3. 顶部柔和镜面高光 — 仿真玻璃反射
          if (specular)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, 0.25),
                    colors: [
                      isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          // 4. 底部微弱暗郁 — 增加叠层深度感
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: const Alignment(0, 0.7),
                  colors: [
                    Colors.transparent,
                    isDark
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          // 5. 单色细边框
          if (border)
            Positioned.fill(
              child: CustomPaint(
                painter: _GlassBorderPainter(
                  radius: radius,
                  width: borderWidth,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
          // 6. 内容层
          child,
        ],
      ),
    );

    // 环境光投影
    if (elevation && shadows != null && shadows!.isNotEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadows,
        ),
        child: surface,
      );
    }
    return surface;
  }
}

/// 极细单色边框 — 可见细边（深浅模式不发白）
class _GlassBorderPainter extends CustomPainter {
  final BorderRadius radius;
  final double width;
  final Color color;

  _GlassBorderPainter({
    required this.radius,
    required this.width,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = width / 2;
    final strokeRect = rect.deflate(inset);
    final strokeRRect = RRect.fromRectAndRadius(
      strokeRect,
      radius.topLeft,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;

    canvas.drawRRect(strokeRRect, paint);
  }

  @override
  bool shouldRepaint(_GlassBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.width != width;
}

/// 便捷：浅色/深色主题下统一的玻璃卡片外观参数
class GlassTokens {
  GlassTokens._();

  static List<BoxShadow> softShadow(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
}
