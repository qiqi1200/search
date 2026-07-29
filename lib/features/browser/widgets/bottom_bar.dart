import 'package:flutter/material.dart';

class BottomBar extends StatelessWidget {
  final int tabCount;
  final bool isIncognito;
  final VoidCallback onNewTab;
  final VoidCallback onTabSwitch;
  final VoidCallback onMenu;
  final bool isOnNewTab;

  const BottomBar({
    super.key,
    required this.tabCount,
    required this.isIncognito,
    required this.onNewTab,
    required this.onTabSwitch,
    required this.onMenu,
    required this.isOnNewTab,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 后退
          _BottomIcon(
            icon: Icons.arrow_back_ios_new,
            onTap: () {},
            theme: theme,
          ),
          // 前进
          _BottomIcon(
            icon: Icons.arrow_forward_ios,
            onTap: () {},
            theme: theme,
          ),
          // 标签切换（显示标签数量）
          GestureDetector(
            onTap: onTabSwitch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.crop_square,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$tabCount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 多功能按钮（菜单入口）
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.menu,
                size: 20,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          // 主页
          _BottomIcon(
            icon: Icons.home_outlined,
            onTap: () {},
            theme: theme,
          ),
          // 新标签
          _BottomIcon(
            icon: Icons.add,
            onTap: onNewTab,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _BottomIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;

  const _BottomIcon({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: theme.colorScheme.onSurfaceVariant,
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}
