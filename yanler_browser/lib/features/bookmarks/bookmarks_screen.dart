import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/yanler_motion.dart';
import '../../core/widgets/site_avatar.dart';
import '../../core/widgets/yanler_surface.dart';
import '../bookmarks/bookmark_service.dart';

/// 书签管理页 — 点击返回所选 URL，由 BrowserScreen 打开
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarks = context.watch<BookmarkService>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('书签'),
        centerTitle: true,
        actions: [
          if (bookmarks.count > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: '清空书签',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _confirmClear(context, bookmarks),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: bookmarks.count == 0
          ? _EmptyState(theme: theme)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: bookmarks.count,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final b = bookmarks.bookmarks[index];
                // 交错入场 + 按压反馈
                return StaggerItem(
                  index: index,
                  child: Pressable(
                    child: _BookmarkCard(
                      title: b.title,
                      url: b.url,
                      onTap: () => Navigator.pop(context, b.url),
                      onDelete: () => bookmarks.remove(b.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context, BookmarkService bookmarks) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空书签'),
        content: const Text('确定删除全部书签吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              bookmarks.clear();
              Navigator.pop(dialogContext);
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final String title;
  final String url;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkCard({
    required this.title,
    required this.url,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 实色书签卡片
    return YanlerSurface(
      borderRadius: BorderRadius.circular(18),
      elevated: false,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: SiteAvatar(title: title, url: url, size: 40),
        title: Text(
          title.isEmpty ? url : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded, size: 17),
          color: theme.colorScheme.onSurfaceVariant,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHigh
                .withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;

  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 52,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            '还没有书签',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '在浏览网页时从菜单收藏即可',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
