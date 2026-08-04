import 'package:flutter/material.dart';

/// 全局页面转场时长（毫秒）。改为 0 = 纯瞬时切换（无动画）。
const int kPageTransitionMs = 200;

/// 底部菜单面板收起动画时长 — 面板按钮「先收起面板，再 push 新路由」的等待时长。
const Duration kPanelCloseMs = Duration(milliseconds: 200);

/// 全局页面转场 — 干脆利落，无「双重重影」。
///
/// 规则（与 preview/index.html 的「方向转场」一致但更短更干脆）：
/// - 只对【新页面】做 SlideTransition：Offset(1,0) → Offset.zero（右向左滑入），
///   曲线 Curves.easeOutCubic；返回时反向滑出（reverseCurve easeInCubic）。
/// - 【旧页面】不做任何透明度/位移动画 —— 转场期间底层页面保持完全不透明，
///   从根上消除两屏半透明重叠的重影。
/// - 时长由 [kPageTransitionMs] 控制；改为 0 时直接瞬时切换（无动画）。
class SnappyRoute<T> extends PageRouteBuilder<T> {
  SnappyRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: kPageTransitionMs),
          reverseTransitionDuration:
              const Duration(milliseconds: kPageTransitionMs),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            if (kPageTransitionMs == 0) return child;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        );
}

/// 兜底：未显式用 [SnappyRoute] 的 MaterialPageRoute 也走同一套「只滑新页、旧页不透明」
/// 的转场，保证全站无一处残留慢速交叉淡化。时长由 MaterialPageRoute 自带（300ms），
/// 但只要新页不透出旧页透明度，就不会有重影。
class SnappyPageTransitionsBuilder extends PageTransitionsBuilder {
  const SnappyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // 只包装新页做右→左滑入；secondaryAnimation（旧页）不做任何处理，
    // 旧页保持完全不透明。
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
