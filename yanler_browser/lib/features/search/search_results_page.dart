import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../providers/ai_provider.dart';
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

  // AI 检索
  bool _aiLoading = false;
  Map<String, dynamic>? _aiAnswer;

  @override
  void initState() {
    super.initState();
    _search();
  }

  /// 调用 AI 对聚合结果去重/排序/总结（未配置 AI 时按钮不显示）
  Future<void> _runAIRetrieval() async {
    if (_aiLoading || _results.isEmpty) return;
    setState(() => _aiLoading = true);
    final ai = context.read<AIProvider>();
    final raw = await ai.smartRetrieval(widget.query, _results);
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiAnswer = _tryParse(raw);
    });
  }

  /// 容错解析 LLM JSON：取首个 `{` 到末个 `}`，失败退化为纯文本 summary。
  /// LLM 输出非严格 JSON 是常态，绝不因解析失败崩溃。
  Map<String, dynamic> _tryParse(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final data = jsonDecode(raw.substring(start, end + 1));
        if (data is Map<String, dynamic>) return data;
      } catch (_) {}
    }
    return {'summary': raw.trim(), 'results': const []};
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
                      ? _ErrorView(
                          error: _error!,
                          query: widget.query,
                          onRetry: _search,
                          onFallback: () {
                            // 回退到 Bing WebView 直跳
                            final bingUrl =
                                'https://www.bing.com/search?q=${Uri.encodeComponent(widget.query)}';
                            Navigator.pop(context, bingUrl);
                          },
                        )
                      : _results.isEmpty
                          ? _EmptyView(isDark: isDark)
                          : _ResultsList(
                              results: _results,
                              isDark: isDark,
                              onTapResult: (item) {
                                // 返回 URL 给 browser_screen 处理导航
                                Navigator.pop(context, item.url);
                              },
                              aiConfigured:
                                  context.read<AIProvider>().isConfigured,
                              aiLoading: _aiLoading,
                              aiAnswer: _aiAnswer,
                              onAIRetrieve: _runAIRetrieval,
                              onOpenUrl: (url) {
                                if (url.isNotEmpty) Navigator.pop(context, url);
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
            '正在聚合多个引擎…',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bing · 百度 · 搜狗 · 360 · 神马 · 国际引擎',
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
  final String query;
  final VoidCallback onRetry;
  final VoidCallback onFallback;
  const _ErrorView({
    required this.error,
    required this.query,
    required this.onRetry,
    required this.onFallback,
  });

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onFallback,
                child: const Text('用 Bing 搜索'),
              ),
            ],
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

  // AI 检索
  final bool aiConfigured;
  final bool aiLoading;
  final Map<String, dynamic>? aiAnswer;
  final VoidCallback onAIRetrieve;
  final ValueChanged<String> onOpenUrl;

  const _ResultsList({
    required this.results,
    required this.isDark,
    required this.onTapResult,
    required this.aiConfigured,
    required this.aiLoading,
    required this.aiAnswer,
    required this.onAIRetrieve,
    required this.onOpenUrl,
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
      itemCount: results.length + 2, // +2: AI 卡片 + 来源统计条
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _AICard(
            configured: aiConfigured,
            loading: aiLoading,
            answer: aiAnswer,
            onRetrieve: onAIRetrieve,
            onOpenUrl: onOpenUrl,
          );
        }
        if (index == 1) {
          // 来源统计条
          return _EngineSummaryBar(
            counts: engineCounts,
            total: results.length,
            isDark: isDark,
          );
        }
        final item = results[index - 2];
        return _ResultCard(
          item: item,
          isDark: isDark,
          onTap: () => onTapResult(item),
        );
      },
    );
  }
}

/// AI 检索卡片：未配置 AI → 不占位；未检索 → 显示按钮；检索中 → loading；
/// 完成后 → 摘要 + 精简结果行（点击直接用 AI 选的 URL 导航）
class _AICard extends StatelessWidget {
  final bool configured;
  final bool loading;
  final Map<String, dynamic>? answer;
  final VoidCallback onRetrieve;
  final ValueChanged<String> onOpenUrl;

  const _AICard({
    required this.configured,
    required this.loading,
    required this.answer,
    required this.onRetrieve,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!configured) return const SizedBox.shrink();

    if (loading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'AI 正在去重与总结…',
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final data = answer;
    if (data == null) {
      // 未检索：入口按钮
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: onRetrieve,
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: const Text('AI 检索 · 去重与总结'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: const TextStyle(fontSize: 12.5),
          ),
        ),
      );
    }

    final summary = (data['summary'] as String? ?? '').trim();
    final aiResults = (data['results'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x335B7FFF), Color(0x338B5CFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'AI 检索',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
          if (aiResults.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final r in aiResults)
              _AIResultRow(
                title: r['title']?.toString() ?? '',
                url: r['url']?.toString() ?? '',
                why: r['why']?.toString() ?? '',
                onTap: () => onOpenUrl(r['url']?.toString() ?? ''),
              ),
          ],
        ],
      ),
    );
  }
}

/// AI 检索卡片内的精简结果行
class _AIResultRow extends StatelessWidget {
  final String title;
  final String url;
  final String why;
  final VoidCallback onTap;

  const _AIResultRow({
    required this.title,
    required this.url,
    required this.why,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (title.isEmpty && why.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (why.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                why,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
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
    'Google': Color(0xFF4285F4),
    '百度': Color(0xFF2932E1),
    'DuckDuckGo': Color(0xFFDE5833),
    'Brave': Color(0xFFFB542B),
    '360': Color(0xFF7DAA2A),
    '搜狗': Color(0xFFFB6045),
    '神马': Color(0xFF00B39D),
    'SearXNG': Color(0xFF4C8BF5),
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
