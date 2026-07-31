import 'package:flutter/material.dart';
import '../../core/widgets/liquid_glass.dart';
import 'aggregated_search_service.dart';

/// Yanler 聚合搜索结果页 — 多引擎结果统一展示
///
/// 在 WebView 中展示，点击结果项直接加载。
/// 引擎来源标签：Bing / 百度 / 搜狗 / DuckDuckGo
class SearchResultsPage extends StatefulWidget {
  final String query;

  const SearchResultsPage({super.key, required this.query});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<SearchResultItem> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await AggregatedSearchService.search(widget.query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索栏
            _SearchHeader(
              query: widget.query,
              isDark: isDark,
              onBack: () => Navigator.pop(context),
              onReSearch: (q) {
                Navigator.pop(context, q);
              },
            ),

            // 结果列表
            Expanded(
              child: _loading
                  ? _LoadingView(isDark: isDark)
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: _search)
                      : _results.isEmpty
                          ? _EmptyView(isDark: isDark)
                          : _ResultsList(
                              results: _results,
                              isDark: isDark,
                              onTapResult: (item) {
                                // 返回 URL 给 browser_screen 处理导航
                                Navigator.pop(context, item.url);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部搜索栏
class _SearchHeader extends StatelessWidget {
  final String query;
  final bool isDark;
  final VoidCallback onBack;
  final ValueChanged<String> onReSearch;

  const _SearchHeader({
    required this.query,
    required this.isDark,
    required this.onBack,
    required this.onReSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LiquidGlass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      blur: 24,
      opacity: isDark ? 0.32 : 0.34,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Row(
          children: [
            // 返回
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                padding: EdgeInsets.zero,
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 4),

            // 搜索框
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        query,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Yanler 标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Yanler',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// 加载中
class _LoadingView extends StatelessWidget {
  final bool isDark;
  const _LoadingView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在聚合搜索…',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bing · 百度 · 搜狗 · DuckDuckGo',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空结果
class _EmptyView extends StatelessWidget {
  final bool isDark;
  const _EmptyView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('未找到相关结果', style: TextStyle(
            fontSize: 14, color: theme.colorScheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}

/// 错误视图
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 40,
              color: theme.colorScheme.error.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text('搜索失败', style: TextStyle(
            fontSize: 14, color: theme.colorScheme.onSurface,
          )),
          const SizedBox(height: 4),
          Text(error, style: TextStyle(
            fontSize: 11, color: theme.colorScheme.onSurfaceVariant,
          ), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 结果列表
class _ResultsList extends StatelessWidget {
  final List<SearchResultItem> results;
  final bool isDark;
  final ValueChanged<SearchResultItem> onTapResult;

  const _ResultsList({
    required this.results,
    required this.isDark,
    required this.onTapResult,
  });

  @override
  Widget build(BuildContext context) {
    // 统计引擎来源
    final engineCounts = <String, int>{};
    for (final r in results) {
      engineCounts[r.engine] = (engineCounts[r.engine] ?? 0) + 1;
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      itemCount: results.length + 1, // +1 for header
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        if (index == 0) {
          // 来源统计条
          return _EngineSummaryBar(
            counts: engineCounts,
            total: results.length,
            isDark: isDark,
          );
        }
        final item = results[index - 1];
        return _ResultCard(
          item: item,
          isDark: isDark,
          onTap: () => onTapResult(item),
        );
      },
    );
  }
}

/// 引擎来源统计条
class _EngineSummaryBar extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  final bool isDark;

  const _EngineSummaryBar({
    required this.counts,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = counts.entries.map((e) => '${e.key} ${e.value}').join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.view_agenda_rounded, size: 14,
              color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '聚合 $total 条结果 — $tags',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索结果卡片
class _ResultCard extends StatelessWidget {
  final SearchResultItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _ResultCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 来源 + URL
            Row(
              children: [
                _EngineTag(engine: item.engine, isDark: isDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _displayUrl(item.url),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 标题
            Text(
              item.title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // 摘要
            if (item.snippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.snippet,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url.length > 40 ? '${url.substring(0, 40)}…' : url;
    }
  }
}

/// 引擎标签
class _EngineTag extends StatelessWidget {
  final String engine;
  final bool isDark;

  const _EngineTag({required this.engine, required this.isDark});

  static const _engineColors = {
    'Bing': Color(0xFF00809D),
    '百度': Color(0xFF2932E1),
    '搜狗': Color(0xFFFB6045),
    'DuckDuckGo': Color(0xFFDE5833),
  };

  @override
  Widget build(BuildContext context) {
    final color = _engineColors[engine] ?? const Color(0xFF666666);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        engine,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
