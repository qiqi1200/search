import 'package:flutter/material.dart';

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
        left: 12,
        right: 12,
        top: 8,
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 后退
          _NavIcon(
            icon: Icons.arrow_back_ios_new,
            onTap: canGoBack ? onBack : null,
            theme: theme,
          ),

          // 前进
          _NavIcon(
            icon: Icons.arrow_forward_ios,
            onTap: canGoForward ? onForward : null,
            theme: theme,
          ),

          // 广告拦截计数
          if (adBlockCount > 0)
            Badge(
              label: Text(
                '$adBlockCount',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              child: Icon(
                Icons.shield,
                size: 20,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            )
          else
            Icon(
              Icons.shield_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),

          // AI — C位
          _AICenterButton(onTap: onAI, theme: theme),

          // 标签页
          GestureDetector(
            onTap: onTabSwitch,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.onSurfaceVariant,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      '$tabCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 菜单
          _NavIcon(
            icon: Icons.more_horiz,
            onTap: onMenu,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

/// 普通导航图标
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ThemeData theme;

  const _NavIcon({required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      icon: Icon(icon, size: 18),
      color: enabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      onPressed: onTap,
      splashRadius: 18,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}

/// AI 中心按钮 — 渐变圆形，视觉突出
class _AICenterButton extends StatelessWidget {
  final VoidCallback onTap;
  final ThemeData theme;

  const _AICenterButton({required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
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
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CFF).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}
