import 'package:flutter/material.dart';

class BottomBar extends StatelessWidget {
  final int tabCount;
  final bool isIncognito;
  final VoidCallback onTabSwitch;
  final VoidCallback onMenu;

  const BottomBar({
    super.key,
    required this.tabCount,
    required this.isIncognito,
    required this.onTabSwitch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 后退
          _BarIcon(icon: Icons.arrow_back_ios_new, onTap: () {}, theme: theme),

          // 标签切换
          GestureDetector(
            onTap: onTabSwitch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.crop_square, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 3),
                Text(
                  '$tabCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // 菜单
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.menu, size: 18, color: theme.colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;

  const _BarIcon({required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: theme.colorScheme.onSurfaceVariant,
      onPressed: onTap,
      splashRadius: 18,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}
