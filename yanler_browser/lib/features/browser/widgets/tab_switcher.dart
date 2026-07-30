import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/browser_provider.dart';

class TabSwitcherSheet extends StatelessWidget {
  const TabSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.55;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<BrowserProvider>(
        builder: (context, browser, _) {
          return Column(
            children: [
              // 头部
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
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
                          icon: const Icon(Icons.add, size: 18),
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
              ),

              // 标签列表
              Expanded(
                child: browser.tabs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tab,
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
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                        itemCount: browser.tabs.length,
                        itemBuilder: (context, index) {
                          final tab = browser.tabs[index];
                          final isActive = index == browser.activeTabIndex;
                          return _TabCard(
                            tab: tab,
                            isActive: isActive,
                            index: index,
                            onTap: () {
                              browser.switchTab(index);
                              Navigator.pop(context);
                            },
                            onClose: () {
                              browser.closeTab(index);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  final dynamic tab;
  final bool isActive;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabCard({
    required this.tab,
    required this.isActive,
    required this.index,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图区域
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A1E)
                      : const Color(0xFFE8E4DF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    tab.url.isEmpty
                        ? Icons.home_outlined
                        : Icons.language,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // 标题和关闭
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tab.title ?? '新标签页',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      padding: EdgeInsets.zero,
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: onClose,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
