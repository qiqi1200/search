import 'package:flutter/material.dart';

/// YanlerMotion — 统一动效规则与工具
///
/// 来自 skill 数据库 UX 指南：
///   - 微交互 150-300ms
///   - 进入 easeOut / 退出 easeIn，绝不用 linear
///   - 尊重系统「减弱动效」设置（reduce-motion 时全部直出）
class YanlerMotion {
  YanlerMotion._();

  /// 微交互时长（按压反馈等）
  static const Duration quick = Duration(milliseconds: 150);

  /// 标准时长（列表入场）
  static const Duration base = Duration(milliseconds: 250);

  /// 柔和时长（页面过渡）
  static const Duration soft = Duration(milliseconds: 300);

  /// 列表交错入场：相邻两项间隔
  static const Duration staggerInterval = Duration(milliseconds: 40);

  /// 按压回弹时长（140ms easeOut）
  static const Duration pressRelease = Duration(milliseconds: 140);

  /// iOS 自然滑动感曲线 cubic-bezier(0.22, 1, 0.36, 1)
  static const Curve spring = Cubic(0.22, 1.0, 0.36, 1.0);

  /// 进入：easeOut（用 spring）
  static const Curve enter = spring;

  /// 退出：easeIn
  static const Curve exit = Curves.easeIn;

  /// 是否尊重系统「减弱动效」
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// 页面过渡：淡入 + 轻微上移(1.5%) + 微缩放(0.985→1)
///
/// 时长由 MaterialPageRoute 提供（300ms），曲线 cubic-bezier(0.22,1,0.36,1)，
/// 退出反向 easeIn。只动 transform/opacity（GPU 合成层，不掉帧）。
class YanlerPageTransitionsBuilder extends PageTransitionsBuilder {
  const YanlerPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 尊重系统减弱动效：直出
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: YanlerMotion.enter,
      reverseCurve: YanlerMotion.exit,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// 列表交错入场 — 瀑布式浮现
///
/// 每项依次淡入 + 上移 10px，间隔 40ms（克制版，无重阴影）。
/// 用于书签 / 历史 / 标签页列表。
class StaggerItem extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggerItem({super.key, required this.index, required this.child});

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: YanlerMotion.base,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1; // 减弱动效：直出
    } else {
      Future.delayed(
        YanlerMotion.staggerInterval * widget.index,
        () {
          if (mounted) _controller.forward();
        },
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _controller, curve: YanlerMotion.enter);
    return FadeTransition(
      opacity: anim,
      child: AnimatedBuilder(
        animation: anim,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - anim.value) * 10),
          child: child,
        ),
      ),
    );
  }
}

/// 按压反馈 — 按下 scale 0.97，松开 140ms easeOut 回弹
///
/// 不做旋转/其他花哨，克制版。
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const Pressable({super.key, required this.child, this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return GestureDetector(onTap: widget.onTap, child: widget.child);
    }
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed ? YanlerMotion.quick : YanlerMotion.pressRelease,
        curve: YanlerMotion.enter,
        child: widget.child,
      ),
    );
  }
}
