import 'dart:async';
import 'package:http/http.dart' as http;

/// 聚合搜索结果项
class SearchResultItem {
  final String title;
  final String url;
  final String snippet;
  final String engine;
  final String favicon;

  const SearchResultItem({
    required this.title,
    required this.url,
    required this.snippet,
    required this.engine,
    this.favicon = '',
  });
}

/// Yanler 聚合搜索服务 — 并发请求多引擎，统一结果页展示
///
/// 支持引擎：Bing / 百度 / 搜狗 / DuckDuckGo
/// 去重策略：URL 标准化后取 host+path 哈希
class AggregatedSearchService {
  static const _timeout = Duration(seconds: 8);
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';

  /// 并发搜索所有引擎，返回去重排序后的统一结果
  static Future<List<SearchResultItem>> search(String query) async {
    final futures = <Future<List<SearchResultItem>>>[
      _searchBing(query),
      _searchBaidu(query),
      _searchSogou(query),
      _searchDuckDuckGo(query),
    ];

    final results = await Future.wait(futures);
    final all = results.expand((list) => list).toList();

    // 去重：按 URL host+path 归一化
    final seen = <String>{};
    final deduped = <SearchResultItem>[];
    for (final item in all) {
      final key = _normalizeUrl(item.url);
      if (key.isNotEmpty && seen.add(key)) {
        deduped.add(item);
      }
    }

    // 按引擎权重排序：Bing(3) > 百度(2) > DDG(2) > 搜狗(1)
    // 同权重保持原始顺序
    final weights = {'Bing': 3, '百度': 2, 'DuckDuckGo': 2, '搜狗': 1};
    deduped.sort((a, b) =>
        (weights[b.engine] ?? 0).compareTo(weights[a.engine] ?? 0));

    return deduped;
  }

  // ==================== Bing ====================

  static Future<List<SearchResultItem>> _searchBing(String query) async {
    try {
      final url =
          'https://www.bing.com/search?q=${Uri.encodeComponent(query)}&count=15';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_timeout);
      if (resp.statusCode != 200) return [];

      final html = resp.body;
      final results = <SearchResultItem>[];

      // 匹配 Bing 结果块：<li class="b_algo">...<h2><a href="URL">TITLE</a></h2>...<p class="b_lineclamp...">SNIPPET</p>
      final blockRegex = RegExp(
        r'<li class="b_algo">(.*?)</li>',
        dotAll: true,
      );
      final linkRegex = RegExp(
        r'<h2><a[^>]*href="([^"]*)"[^>]*>(.*?)</a></h2>',
        dotAll: true,
      );
      final snippetRegex = RegExp(
        r'<p[^>]*>(.*?)</p>',
        dotAll: true,
      );

      for (final block in blockRegex.allMatches(html)) {
        final blockHtml = block.group(1) ?? '';
        final linkMatch = linkRegex.firstMatch(blockHtml);
        if (linkMatch == null) continue;

        final rawUrl = linkMatch.group(1) ?? '';
        final title = _stripHtml(linkMatch.group(2) ?? '');
        final snippetMatch = snippetRegex.firstMatch(blockHtml);
        final snippet = _stripHtml(snippetMatch?.group(1) ?? '');

        // Bing 有时返回重定向 URL，提取真实 URL
        final finalUrl = _extractRealUrl(rawUrl);
        if (finalUrl.isEmpty || finalUrl.contains('bing.com')) continue;

        results.add(SearchResultItem(
          title: title,
          url: finalUrl,
          snippet: snippet,
          engine: 'Bing',
          favicon: 'https://www.bing.com/favicon.ico',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ==================== 百度 ====================

  static Future<List<SearchResultItem>> _searchBaidu(String query) async {
    try {
      final url =
          'https://www.baidu.com/s?wd=${Uri.encodeComponent(query)}&rn=15';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_timeout);
      if (resp.statusCode != 200) return [];

      final html = resp.body;
      final results = <SearchResultItem>[];

      // 百度结果块：<div class="result c-container" ... id="数字">...<h3 class="t"><a href="URL">TITLE</a></h3>
      final blockRegex = RegExp(
        r'<div[^>]*class="[^"]*result c-container[^"]*"[^>]*>(.*?)(?=<div[^>]*class="[^"]*result c-container|<div[^>]*id="page")',
        dotAll: true,
      );
      final linkRegex = RegExp(
        r'<h3[^>]*class="[^"]*t[^"]*"[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      final snippetRegex = RegExp(
        r'<span[^>]*class="content-right_[^"]*"[^>]*>(.*?)</span>',
        dotAll: true,
      );

      for (final block in blockRegex.allMatches(html)) {
        final blockHtml = block.group(1) ?? '';
        final linkMatch = linkRegex.firstMatch(blockHtml);
        if (linkMatch == null) continue;

        final rawUrl = linkMatch.group(1) ?? '';
        final title = _stripHtml(linkMatch.group(2) ?? '');
        final snippetMatch = snippetRegex.firstMatch(blockHtml);
        final snippet = _stripHtml(snippetMatch?.group(1) ?? '');

        // 百度链接通常是跳转链接，直接使用
        if (rawUrl.isEmpty) continue;

        results.add(SearchResultItem(
          title: title,
          url: rawUrl.startsWith('http') ? rawUrl : 'https://www.baidu.com$rawUrl',
          snippet: snippet,
          engine: '百度',
          favicon: 'https://www.baidu.com/favicon.ico',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ==================== 搜狗 ====================

  static Future<List<SearchResultItem>> _searchSogou(String query) async {
    try {
      final url =
          'https://www.sogou.com/web?query=${Uri.encodeComponent(query)}';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_timeout);
      if (resp.statusCode != 200) return [];

      final html = resp.body;
      final results = <SearchResultItem>[];

      final blockRegex = RegExp(
        r'<div[^>]*class="[^"]*vrwrap[^"]*"[^>]*>(.*?)(?=<div[^>]*class="[^"]*vrwrap|<div[^>]*id="pagebar")',
        dotAll: true,
      );
      final linkRegex = RegExp(
        r'<h3[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      final snippetRegex = RegExp(
        r'<p[^>]*class="[^"]*str_info[^"]*"[^>]*>(.*?)</p>',
        dotAll: true,
      );

      for (final block in blockRegex.allMatches(html)) {
        final blockHtml = block.group(1) ?? '';
        final linkMatch = linkRegex.firstMatch(blockHtml);
        if (linkMatch == null) continue;

        final rawUrl = linkMatch.group(1) ?? '';
        final title = _stripHtml(linkMatch.group(2) ?? '');
        final snippetMatch = snippetRegex.firstMatch(blockHtml);
        final snippet = _stripHtml(snippetMatch?.group(1) ?? '');

        if (rawUrl.isEmpty) continue;

        results.add(SearchResultItem(
          title: title,
          url: rawUrl.startsWith('http') ? rawUrl : 'https://www.sogou.com$rawUrl',
          snippet: snippet,
          engine: '搜狗',
          favicon: 'https://www.sogou.com/favicon.ico',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ==================== DuckDuckGo ====================

  static Future<List<SearchResultItem>> _searchDuckDuckGo(String query) async {
    try {
      final url =
          'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_timeout);
      if (resp.statusCode != 200) return [];

      final html = resp.body;
      final results = <SearchResultItem>[];

      final blockRegex = RegExp(
        r'<div[^>]*class="[^"]*result[^"]*"[^>]*>(.*?)(?=<div[^>]*class="[^"]*result[^"]*"|<div[^>]*class="[^"]*nav-link)',
        dotAll: true,
      );
      final linkRegex = RegExp(
        r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      final snippetRegex = RegExp(
        r'<a[^>]*class="[^"]*result__snippet[^"]*"[^>]*>(.*?)</a>',
        dotAll: true,
      );

      for (final block in blockRegex.allMatches(html)) {
        final blockHtml = block.group(1) ?? '';
        final linkMatch = linkRegex.firstMatch(blockHtml);
        if (linkMatch == null) continue;

        var rawUrl = linkMatch.group(1) ?? '';
        final title = _stripHtml(linkMatch.group(2) ?? '');
        final snippetMatch = snippetRegex.firstMatch(blockHtml);
        final snippet = _stripHtml(snippetMatch?.group(1) ?? '');

        // DDG 返回重定向 URL，提取真实 URL
        if (rawUrl.contains('uddg=')) {
          rawUrl = Uri.decodeComponent(
              rawUrl.split('uddg=').last.split('&').first);
        }
        if (rawUrl.isEmpty || rawUrl.contains('duckduckgo.com')) continue;

        results.add(SearchResultItem(
          title: title,
          url: rawUrl,
          snippet: snippet,
          engine: 'DuckDuckGo',
          favicon: 'https://duckduckgo.com/favicon.ico',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ==================== 工具方法 ====================

  /// 去除 HTML 标签
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#\d+;'), '')
        .trim();
  }

  /// URL 标准化（去重用）
  static String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}${uri.path}'.toLowerCase().replaceAll(RegExp(r'/$'), '');
    } catch (_) {
      return '';
    }
  }

  /// 从重定向 URL 提取真实 URL
  static String _extractRealUrl(String url) {
    if (url.isEmpty) return '';
    // Bing 重定向格式
    if (url.contains('/click?') || url.contains('go.microsoft.com')) {
      final match = RegExp(r'[?&]url=([^&]+)').firstMatch(url);
      if (match != null) return Uri.decodeComponent(match.group(1) ?? '');
    }
    return url;
  }
}
