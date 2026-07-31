import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// LiquidGlass — 液态玻璃表面组件
///
/// 复刻 AndroidLiquidGlass (Kyant0/backdrop, iOS 26 Liquid Glass 风格) 的视觉语言，
/// 用 Flutter 原生能力实现：
///   1. BackdropFilter 背景模糊（BlurView 式）
///   2. 半透明底色 + 亮度微调
///   3. 确定性噪点纹理（模拟液体的折射颗粒感）
///   4. 顶部镜面高光（玻璃边缘反光）
///   5. 渐变发丝描边（Stillmind 风格渐变边框）
///   6. 环境光分层投影
///
/// 注意：在 WebView 之上（平台视图）BackdropFilter 无法模糊平台内容，
/// 此时自动退化为「半透明 + 噪点 + 高光 + 描边」，视觉效果依然成立。
class LiquidGlass extends StatelessWidget {
  final Widget child;

  /// 圆角
  final BorderRadius? borderRadius;

  /// 背景模糊强度（sigma）
  final double blur;

  /// 底色不透明度
  final double opacity;

  /// 是否绘制顶部镜面高光
  final bool specular;

  /// 是否绘制噪点纹理
  final bool noise;

  /// 是否绘制渐变发丝描边
  final bool border;

  /// 描边宽度
  final double borderWidth;

  /// 额外阴影
  final List<BoxShadow>? shadows;

  /// 自定义底色（默认取主题 surface）
  final Color? tint;

  /// 是否启用环境光投影（默认开）
  final bool elevation;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur = 20,
    this.opacity = 0.55,
    this.specular = true,
    this.noise = true,
    this.border = true,
    this.borderWidth = 1,
    this.shadows,
    this.tint,
    this.elevation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(16);

    final Color baseTint = tint ?? theme.colorScheme.surface;
    final Color fill = isDark
        ? Color.lerp(baseTint, Colors.white, 0.04)!
        : Color.lerp(baseTint, Colors.white, 0.5)!;

    final Widget surface = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 1. 背景模糊
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(color: Colors.transparent),
            ),
          ),
          // 2. 半透明底色
          Positioned.fill(
            child: Container(
              color: fill.withValues(alpha: opacity),
            ),
          ),
          // 3. 噪点纹理（折射颗粒感）
          if (noise)
            Positioned.fill(
              child: CustomPaint(
                painter: _NoisePainter(
                  seed: 260607,
                  density: isDark ? 0.06 : 0.045,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.035),
                  pointSize: 1.1,
                ),
              ),
            ),
          // 4. 顶部镜面高光
          if (specular)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, 0.35),
                    colors: [
                      isDark
                          ? Colors.white.withValues(alpha: 0.09)
                          : Colors.white.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          // 5. 渐变发丝描边 + 边缘暗化
          if (border)
            Positioned.fill(
              child: CustomPaint(
                painter: _GlassBorderPainter(
                  radius: radius,
                  width: borderWidth,
                  isDark: isDark,
                  accent: theme.colorScheme.primary,
                ),
              ),
            ),
          // 6. 内容层（决定组件尺寸）
          child,
        ],
      ),
    );

    // 环境光投影画在裁剪层之外
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

/// 确定性噪点 — 同一 seed 永远画同一张纹理，不闪屏
class _NoisePainter extends CustomPainter {
  final int seed;
  final double density;
  final Color color;
  final double pointSize;

  _NoisePainter({
    required this.seed,
    required this.density,
    required this.color,
    required this.pointSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final paint = Paint()..color = color;
    const cell = 4.0; // 网格粒度，保证分布均匀
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        if (rnd.nextDouble() < density) {
          final jitterX = rnd.nextDouble() * cell;
          final jitterY = rnd.nextDouble() * cell;
          final r = pointSize * (0.6 + rnd.nextDouble() * 0.8);
          canvas.drawCircle(
            Offset(x + jitterX, y + jitterY),
            r,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.density != density ||
      oldDelegate.color != color;
}

/// 渐变发丝描边 — 玻璃边缘反光（上亮下暗 + 一点品牌色）
class _GlassBorderPainter extends CustomPainter {
  final BorderRadius radius;
  final double width;
  final bool isDark;
  final Color accent;

  _GlassBorderPainter({
    required this.radius,
    required this.width,
    required this.isDark,
    required this.accent,
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
      ..strokeWidth = width;

    // 渐变：顶部亮（高光反射），两侧过渡，底部带一丝品牌色
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.06),
              accent.withValues(alpha: 0.10),
            ]
          : [
              Colors.white.withValues(alpha: 0.95),
              Colors.black.withValues(alpha: 0.10),
              accent.withValues(alpha: 0.12),
            ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(strokeRect);

    paint.shader = gradient;
    canvas.drawRRect(strokeRRect, paint);
  }

  @override
  bool shouldRepaint(_GlassBorderPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.radius != radius ||
      oldDelegate.width != width ||
      oldDelegate.accent != accent;
}

/// 便捷：浅色/深色主题下统一的玻璃卡片外观参数
class GlassTokens {
  GlassTokens._();

  static List<BoxShadow> softShadow(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
}
