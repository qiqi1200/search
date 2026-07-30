import 'package:flutter/material.dart';

/// 底部导航栏 — 标准浏览器布局，AI 居中
///
/// 布局: ◀ ▶ [spacer] ✦ AI [spacer] ■ ≡
/// AI 按钮在绝对 C 位，视觉突出
class BottomBar extends StatelessWidget {
  final int tabCount;
  final bool isIncognito;
  final bool canGoBack;
  final bool canGoForward;
  final int adBlockCount;
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

    return Container(
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom > 0 ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFFAFAF8),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          // 后退
          _NavButton(
            icon: Icons.arrow_back_ios_new,
            enabled: canGoBack,
            onTap: canGoBack ? onBack : null,
            theme: theme,
          ),

          // 前进
          _NavButton(
            icon: Icons.arrow_forward_ios,
            enabled: canGoForward,
            onTap: canGoForward ? onForward : null,
            theme: theme,
          ),

          // 弹性空间将 AI 推向中心
          const Spacer(),

          // AI — 绝对 C 位，视觉焦点
          _AICenterButton(
            onTap: onAI,
            isDark: isDark,
            theme: theme,
          ),

          // 弹性空间将右侧内容推向右边
          const Spacer(),

          // 标签页按钮
          _TabCountButton(
            count: tabCount,
            onTap: onTabSwitch,
            theme: theme,
          ),

          // 菜单
          _NavButton(
            icon: Icons.more_horiz,
            enabled: true,
            onTap: onMenu,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮（后退 / 前进 / 菜单）
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
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
        onPressed: onTap,
        splashRadius: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

/// AI 中心按钮 — 渐变圆形，视觉焦点，绝对 C 位
class _AICenterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final ThemeData theme;

  const _AICenterButton({
    required this.onTap,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CFF).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 22,
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
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        onPressed: onTap,
        splashRadius: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
