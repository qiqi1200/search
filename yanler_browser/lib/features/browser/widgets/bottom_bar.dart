import 'package:flutter/material.dart';
import '../../../core/widgets/yanler_surface.dart';

/// 底部导航栏 — 标准浏览器布局，AI 居中
///
/// 布局（保持不变）: ◀ ▶ [spacer] ✦AI [spacer] ▦ ⋮
class BottomBar extends StatelessWidget {
  final int tabCount;
  final bool isIncognito;
  final bool canGoBack;
  final bool canGoForward;
  final int adBlockCount;
  final bool aiActive;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onAI;
  final VoidCallback onTabSwitch;
  final VoidCallback onMenu;

  const BottomBar({
    super.key,
    required this.tabCount,
    required this.isIncognito,
    required this.canGoBack,
    required this.canGoForward,
    required this.adBlockCount,
    required this.aiActive,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onAI,
    required this.onTabSwitch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 系统导航栏高度（三键 ~48dp / 手势 ~24-32dp），edge-to-edge 下必须避让，
    // 否则工具栏会绘制进导航栏区域，与系统返回/主页键重叠。
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // 实色底栏：顶部圆角 + 1px 顶边。
    // 背景仍延伸到屏幕底（壁纸风格 edge-to-edge），仅内容区避开系统导航栏。
    return YanlerSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      elevated: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 4,
          right: 4,
          top: 6,
          // 有导航栏：inset + 4px 视觉间距；无导航栏：8px 常规内边距
          bottom: bottomInset > 0 ? bottomInset + 4 : 8,
        ),
        child: Row(
          children: [
            // 后退：始终可点。一级页面无历史时由 BrowserScreen 兜底回新标签页
            _NavButton(
              icon: Icons.arrow_back_ios_new_rounded,
              enabled: true,
              onTap: onBack,
              theme: theme,
            ),

            // 前进
            _NavButton(
              icon: Icons.arrow_forward_ios_rounded,
              enabled: canGoForward,
              onTap: canGoForward ? onForward : null,
              theme: theme,
            ),

            const Spacer(),

            // AI — 绝对 C 位
            _AICenterButton(
              onTap: onAI,
              isDark: isDark,
              active: aiActive,
              theme: theme,
            ),

            const Spacer(),

            // 标签页按钮
            _TabCountButton(
              count: tabCount,
              onTap: onTabSwitch,
              theme: theme,
            ),

            // 菜单
            _NavButton(
              icon: Icons.more_horiz_rounded,
              enabled: true,
              onTap: onMenu,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

/// 导航按钮（后退 / 前进 / 菜单）— 带按压反馈 + 统一圆角底 + 高光效果
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final ThemeData theme;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: enabled
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }
}

/// AI 中心按钮 — 渐变圆形，Agent 模式开启时高亮描边
class _AICenterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final bool active;
  final ThemeData theme;

  const _AICenterButton({
    required this.onTap,
    required this.isDark,
    required this.active,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5B7FFF),
              Color(0xFF8B5CFF),
              Color(0xFFFF5C7B),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.25),
            width: active ? 1.8 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CFF).withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            if (active)
              BoxShadow(
                color: const Color(0xFF34C759).withValues(alpha: 0.5),
                blurRadius: 14,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 21,
              color: Colors.white,
            ),
            // AI 在线指示点
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x8034C759),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签页计数按钮
class _TabCountButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final ThemeData theme;

  const _TabCountButton({
    required this.count,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        icon: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.onSurfaceVariant,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
        onPressed: onTap,
        splashRadius: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHigh
              .withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
