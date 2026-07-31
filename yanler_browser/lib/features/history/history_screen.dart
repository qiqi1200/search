import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/site_avatar.dart';
import '../history/history_service.dart';

/// 历史记录页 — 支持搜索，点击返回所选 URL
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final history = context.watch<HistoryService>();

    final entries = _query.isEmpty ? history.history : history.search(_query);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('历史记录'),
        centerTitle: true,
        actions: [
          if (history.count > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: '清空历史',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _confirmClear(context, history),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          if (history.count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: LiquidGlass(
                borderRadius: BorderRadius.circular(18),
                blur: 20,
                opacity: isDark ? 0.32 : 0.36,
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: '搜索历史',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) => setState(() => _query = v.trim()),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          color: theme.colorScheme.onSurfaceVariant,
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceContainerHigh
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
          // 列表
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? '暂无历史记录' : '没有匹配的结果',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      return _HistoryCard(
                        title: e.title,
                        url: e.url,
                        visitedAt: e.visitedAt,
                        onTap: () => Navigator.pop(context, e.url),
                        onDelete: () => history.remove(e.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, HistoryService history) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定删除全部历史记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              history.clear();
              Navigator.pop(dialogContext);
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title;
  final String url;
  final DateTime visitedAt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.title,
    required this.url,
    required this.visitedAt,
    required this.onTap,
    required this.onDelete,
  });

  String _relativeTime(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(visitedAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return DateFormat('M月d日').format(visitedAt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return LiquidGlass(
      borderRadius: BorderRadius.circular(16),
      blur: 18,
      opacity: isDark ? 0.3 : 0.36,
      borderWidth: 0.9,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: SiteAvatar(title: title, url: url, size: 36),
        title: Text(
          title.isEmpty ? url : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _relativeTime(context),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              padding: EdgeInsets.zero,
              color: theme.colorScheme.onSurfaceVariant,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
