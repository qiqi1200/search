import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/yanler_motion.dart';
import '../../../core/widgets/site_avatar.dart';
import '../../../core/widgets/yanler_surface.dart';
import '../../../providers/browser_provider.dart';

class TabSwitcherSheet extends StatelessWidget {
  const TabSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.55;

    // 实色标签切换面板
    return YanlerSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      elevated: false,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Consumer<BrowserProvider>(
          builder: (context, browser, _) {
            return Column(
              children: [
                // 头部
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      // 拖拽指示条
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '标签页 (${browser.tabCount})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('新建'),
                                onPressed: () {
                                  browser.addTab();
                                  Navigator.pop(context);
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  browser.clearAllTabs();
                                  browser.addTab();
                                  Navigator.pop(context);
                                },
                                child: const Text('全部关闭'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 标签列表
                Expanded(
                  child: browser.tabs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tab_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '暂无标签页',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.74,
                              ),
                          itemCount: browser.tabs.length,
                          itemBuilder: (context, index) {
                            final tab = browser.tabs[index];
                            final isActive = index == browser.activeTabIndex;
                            // 交错入场 + 按压反馈
                            return StaggerItem(
                              index: index,
                              child: Pressable(
                                child: _TabCard(
                                  tab: tab,
                                  isActive: isActive,
                                  onTap: () {
                                    browser.switchTab(index);
                                    Navigator.pop(context);
                                  },
                                  onClose: () {
                                    browser.closeTab(index);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  final dynamic tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabCard({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: isActive ? 1.0 : 0.985,
        curve: Curves.easeOutCubic,
        child: YanlerSurface(
          borderRadius: BorderRadius.circular(18),
          elevated: false,
          // 选中 = 品牌色描边
          tint: isActive ? theme.colorScheme.primary : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图区域 — 字母头像
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF16171B)
                        : const Color(0xFFE9E5E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SiteAvatar(
                      title: tab.title ?? '新标签页',
                      url: tab.url ?? '',
                      size: 42,
                    ),
                  ),
                ),
              ),
              // 标题和关闭
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tab.title ?? '新标签页',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 15),
                        padding: EdgeInsets.zero,
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: onClose,
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceContainerHigh
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
