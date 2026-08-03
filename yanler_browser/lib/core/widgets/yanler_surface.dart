import 'package:flutter/material.dart';

/// YanlerSurface — 实色表面组件（替代液态玻璃）
///
/// 设计定位（Flat Design + Bento 卡片，工具类产品首选路线）：
///   1. 实色填充，无模糊、无透明度 — 卡片从背景中清晰站出来
///   2. 1px 可见边框（硬性要求）— 深浅模式都不发白
///   3. 轻阴影提升层次（可选关掉，保持列表干净）
///   4. 可选品牌 tint — 激活态用品牌色描边 + 微染底
///
/// 配色（保留品牌 #5B7FFF / #7B9FFF，微调层次）：
///   浅色：页面底 #F7F5F2 / 卡片 #FFFFFF / 边框 #E4E4E7
///   深色：页面底 #191A1E / 卡片 #232328 / 边框 #3B3C42
class YanlerSurface extends StatelessWidget {
  final Widget child;

  /// 圆角
  final BorderRadius? borderRadius;

  /// 是否显示轻阴影（列表内嵌卡片可关掉，保持扁平干净）
  final bool elevated;

  /// 品牌 tint：传入时边框与底色染品牌色（用于激活/选中态）
  final Color? tint;

  /// 可选内边距
  final EdgeInsetsGeometry? padding;

  const YanlerSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.elevated = true,
    this.tint,
    this.padding,
  });

  /// 浅色模式卡片阴影 — 克制、仅一层
  static const List<BoxShadow> _lightShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  /// 深色模式卡片阴影
  static const List<BoxShadow> _darkShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(16);

    // 实色卡片底色
    final Color baseFill = isDark ? const Color(0xFF232328) : Colors.white;
    // 默认 1px 可见边框
    final Color baseBorder =
        isDark ? const Color(0xFF3B3C42) : const Color(0xFFE4E4E7);

    final Color borderColor = tint ?? baseBorder;
    // tint 时品牌色微染底（激活态层次），不改变卡片主体色相
    final Color fill = tint == null
        ? baseFill
        : Color.alphaBlend(
            tint!.withValues(alpha: isDark ? 0.14 : 0.08),
            baseFill,
          );

    // AnimatedContainer：边框/品牌 tint 变化时平滑过渡（如地址栏聚焦描边）
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: elevated ? (isDark ? _darkShadow : _lightShadow) : null,
      ),
      padding: padding,
      child: child,
    );
  }
}
