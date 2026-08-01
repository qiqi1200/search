import 'dart:async';
import 'package:flutter/foundation.dart';
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
/// **自适应引擎集**：国内引擎（Bing/百度/搜狗/360/神马）始终参与；
/// 国际引擎（Google/DuckDuckGo/Brave/SearXNG）用**短超时探测**——能打开就并入，
/// 打不开就静默丢弃，不拖慢整体（以「能打开」为首要目的）。
///
/// 去重策略：URL 归一化（去 tracking 参数/解重定向）+ 标题相似度（bigram Jaccard）。
class AggregatedSearchService {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';

  // 国内引擎较稳定，超时可稍长；国际引擎短超时即「可达性探测」
  static const _domesticTimeout = Duration(milliseconds: 3500);
  static const _intlTimeout = Duration(milliseconds: 2500);
  /// 首胜后最多再等 3s 收尾（谁先返回用谁）
  static const _graceAfterFirst = Duration(seconds: 3);
  /// 绝对兜底上限，防止被慢源卡死
  static const _absoluteDeadline = Duration(seconds: 4);

  /// 引擎权重：排序用。国内常用引擎在前。
  static const _weights = {
    'Bing': 3, 'Google': 3,
    '百度': 2, 'DuckDuckGo': 2, 'Brave': 2, '360': 2,
    '搜狗': 1, '神马': 1, 'SearXNG': 1,
  };

  /// 并发搜索所有引擎，返回去重排序后的统一结果。
  ///
  /// **不等最慢引擎**：谁先返回用谁 + 首胜 3s 兜底 + 4s 绝对上限，
  /// 国际引擎被墙时快速失败，不阻塞国内引擎。
  /// 返回的是**快照**——兜底截止后晚到的引擎仍会往内部列表追加，
  /// 但调用方持有的列表不再受影响（修复旧版共享引用被并发修改）。
  /// 若所有引擎均失败，抛出异常以便调用方回退到 Bing WebView 直跳。
  static Future<List<SearchResultItem>> search(String query) async {
    final futures = <Future<List<SearchResultItem>>>[
      _searchBing(query),
      _searchBaidu(query),
      _searchSogou(query),
      _search360(query),
      _searchShenma(query),
      _searchGoogle(query),
      _searchDuckDuckGo(query),
      _searchBrave(query),
      _searchSearxng(query),
    ];

    final collected = <SearchResultItem>[];
    final completer = Completer<List<SearchResultItem>>();
    var settled = 0;
    DateTime? firstWinAt;

    void finish() {
      if (completer.isCompleted) return;
      completer.complete(List.of(collected)); // ★ 快照交付，防晚到引擎污染调用方
    }

    for (final f in futures) {
      unawaited(() async {
        try {
          final r = await f;
          if (r.isNotEmpty) {
            collected.addAll(r);
            if (firstWinAt == null) {
              firstWinAt = DateTime.now();
              // 已有结果 → 再等 3s 让其余引擎赶上（谁先返回用谁 + 兜底）
              Future.delayed(_graceAfterFirst, finish);
            }
          }
        } catch (_) {}
        settled++;
        if (settled == futures.length) finish();
      }());
    }

    // 绝对兜底：4 秒内即使还有引擎未返回，用当前已收集结果
    Future.delayed(_absoluteDeadline, finish);

    final result = await completer.future;

    // 所有引擎全部失败 → 抛异常，调用方回退到 Bing WebView
    if (result.isEmpty) {
      throw Exception('所有引擎暂无结果，请重试');
    }

    return _dedupeAndSort(result);
  }

  /// 解析策略：小页面（<32KB）直接在主 isolate 解析（避免每次 spawn isolate 开销），
  /// 大页面挪后台 isolate 防止正则阻塞 UI（卡顿主因）。
  static Future<List<SearchResultItem>> _parseBg(
    String html,
    List<SearchResultItem> Function(String) parser,
  ) {
    if (html.length < 32 * 1024) return Future.value(parser(html));
    return compute(parser, html);
  }

  // ==================== 国内引擎 ====================

  static Future<List<SearchResultItem>> _searchBing(String query) async {
    try {
      final url =
          'https://www.bing.com/search?q=${Uri.encodeComponent(query)}&count=15';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_domesticTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseBingHtml);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResultItem>> _searchBaidu(String query) async {
    try {
      final url = 'https://www.baidu.com/s?wd=${Uri.encodeComponent(query)}&rn=15';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_domesticTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseBaiduHtml);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResultItem>> _searchSogou(String query) async {
    try {
      final url = 'https://www.sogou.com/web?query=${Uri.encodeComponent(query)}';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_domesticTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseSogouHtml);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResultItem>> _search360(String query) async {
    try {
      final url = 'https://www.so.com/s?q=${Uri.encodeComponent(query)}&pn=1';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_domesticTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parse360Html);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResultItem>> _searchShenma(String query) async {
    try {
      final url = 'https://m.sm.cn/s?q=${Uri.encodeComponent(query)}';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_domesticTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseShenmaHtml);
    } catch (_) {
      return [];
    }
  }

  // ==================== 国际引擎（短超时探测，可达才并入） ====================

  static Future<List<SearchResultItem>> _searchGoogle(String query) async {
    try {
      final url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}&num=15';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_intlTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseGoogleHtml);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResultItem>> _searchDuckDuckGo(String query) async {
    try {
      final url = 'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_intlTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseDuckDuckGoHtml);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResultItem>> _searchBrave(String query) async {
    try {
      final url = 'https://search.brave.com/search?q=${Uri.encodeComponent(query)}';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_intlTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseBraveHtml);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResultItem>> _searchSearxng(String query) async {
    try {
      final url = 'https://searx.be/search?q=${Uri.encodeComponent(query)}';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_intlTimeout);
      if (resp.statusCode != 200) return [];
      return _parseBg(resp.body, _parseSearxngHtml);
    } catch (_) {
      return [];
    }
  }

  // ==================== HTML 解析（顶层可跨 isolate） ====================

  static List<SearchResultItem> _parseBingHtml(String html) {
    final results = <SearchResultItem>[];
    final blockRegex = RegExp(r'<li class="b_algo">(.*?)</li>', dotAll: true);
    final linkRegex = RegExp(
      r'<h2><a[^>]*href="([^"]*)"[^>]*>(.*?)</a></h2>',
      dotAll: true,
    );
    final snippetRegex = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true);
    for (final block in blockRegex.allMatches(html)) {
      final blockHtml = block.group(1) ?? '';
      final linkMatch = linkRegex.firstMatch(blockHtml);
      if (linkMatch == null) continue;
      final rawUrl = linkMatch.group(1) ?? '';
      final title = _stripHtml(linkMatch.group(2) ?? '');
      final snippetMatch = snippetRegex.firstMatch(blockHtml);
      final snippet = _stripHtml(snippetMatch?.group(1) ?? '');
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
  }

  static List<SearchResultItem> _parseBaiduHtml(String html) {
    final results = <SearchResultItem>[];
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
  }

  static List<SearchResultItem> _parseSogouHtml(String html) {
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
  }

  /// 360 搜索（so.com）：<li class="res-list"> → <h3 class="res-title"><a data-mdurl href>
  static List<SearchResultItem> _parse360Html(String html) {
    final results = <SearchResultItem>[];
    final blockRegex = RegExp(
      r'<li[^>]*class="[^"]*res-list[^"]*"[^>]*>(.*?)</li>',
      dotAll: true,
    );
    final linkRegex = RegExp(
      r'<h3[^>]*class="[^"]*res-title[^"]*"[^>]*>\s*<a[^>]*(?:data-mdurl="([^"]*)")?[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final snippetRegex = RegExp(
      r'<p[^>]*class="[^"]*res-desc[^"]*"[^>]*>(.*?)</p>',
      dotAll: true,
    );
    for (final block in blockRegex.allMatches(html)) {
      final blockHtml = block.group(1) ?? '';
      final linkMatch = linkRegex.firstMatch(blockHtml);
      if (linkMatch == null) continue;
      // 优先 data-mdurl（真实 URL），否则 href（可能为 so.com/link 跳转）
      final rawUrl =
          (linkMatch.group(1)?.isNotEmpty ?? false) ? linkMatch.group(1)! : linkMatch.group(2) ?? '';
      final title = _stripHtml(linkMatch.group(3) ?? '');
      final snippetMatch = snippetRegex.firstMatch(blockHtml);
      final snippet = _stripHtml(snippetMatch?.group(1) ?? '');
      final finalUrl = _extract360Url(rawUrl);
      if (finalUrl.isEmpty || title.isEmpty) continue;
      results.add(SearchResultItem(
        title: title,
        url: finalUrl,
        snippet: snippet,
        engine: '360',
        favicon: 'https://www.so.com/favicon.ico',
      ));
    }
    return results;
  }

  /// 神马搜索（sm.cn）：JS 渲染 + 反爬较强，尽力而为，失败返回空不影响整体。
  static List<SearchResultItem> _parseShenmaHtml(String html) {
    final results = <SearchResultItem>[];
    final blockRegex = RegExp(
      r'<div[^>]*class="[^"]*result[^"]*"[^>]*>(.*?)</div>',
      dotAll: true,
    );
    final linkRegex = RegExp(
      r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final block in blockRegex.allMatches(html)) {
      final blockHtml = block.group(1) ?? '';
      final link = linkRegex.firstMatch(blockHtml);
      if (link == null) continue;
      final url = link.group(1) ?? '';
      final title = _stripHtml(link.group(2) ?? '');
      if (url.isEmpty || title.isEmpty || url.contains('sm.cn')) continue;
      results.add(SearchResultItem(
        title: title,
        url: url,
        snippet: '',
        engine: '神马',
        favicon: 'https://www.sm.cn/favicon.ico',
      ));
    }
    return results;
  }

  /// Google：尽力而为，结果链接藏在 /url?q= 跳转里，摘要可不填。
  static List<SearchResultItem> _parseGoogleHtml(String html) {
    final results = <SearchResultItem>[];
    final linkRegex = RegExp(
      r'<a[^>]*href="/url\?q=([^"&]+)[^"]*"[^>]*>\s*<h3[^>]*>(.*?)</h3>',
      dotAll: true,
    );
    for (final m in linkRegex.allMatches(html)) {
      var rawUrl = m.group(1) ?? '';
      if (rawUrl.isEmpty) continue;
      try {
        rawUrl = Uri.decodeComponent(rawUrl);
      } catch (_) {}
      final title = _stripHtml(m.group(2) ?? '');
      if (title.isEmpty || rawUrl.isEmpty) continue;
      results.add(SearchResultItem(
        title: title,
        url: rawUrl,
        snippet: '',
        engine: 'Google',
        favicon: 'https://www.google.com/favicon.ico',
      ));
    }
    return results;
  }

  static List<SearchResultItem> _parseDuckDuckGoHtml(String html) {
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
      if (rawUrl.contains('uddg=')) {
        try {
          rawUrl = Uri.decodeComponent(rawUrl.split('uddg=').last.split('&').first);
        } catch (_) {}
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
  }

  /// Brave：snippet 块 + snippet-title 链接，尽力而为。
  static List<SearchResultItem> _parseBraveHtml(String html) {
    final results = <SearchResultItem>[];
    final blockRegex = RegExp(
      r'<div[^>]*class="[^"]*snippet[^"]*"[^>]*>(.*?)</div>',
      dotAll: true,
    );
    final linkRegex = RegExp(
      r'<a[^>]*class="[^"]*snippet-title[^"]*"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final block in blockRegex.allMatches(html)) {
      final link = linkRegex.firstMatch(block.group(1) ?? '');
      if (link == null) continue;
      final url = link.group(1) ?? '';
      final title = _stripHtml(link.group(2) ?? '');
      if (url.isEmpty || title.isEmpty) continue;
      results.add(SearchResultItem(
        title: title,
        url: url,
        snippet: '',
        engine: 'Brave',
        favicon: 'https://search.brave.com/favicon.ico',
      ));
    }
    return results;
  }

  /// SearXNG：<article class="result"> → <a href> + <p class="content">
  static List<SearchResultItem> _parseSearxngHtml(String html) {
    final results = <SearchResultItem>[];
    final blockRegex = RegExp(
      r'<article[^>]*class="[^"]*result[^"]*"[^>]*>(.*?)</article>',
      dotAll: true,
    );
    final linkRegex = RegExp(
      r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final snippetRegex = RegExp(
      r'<p[^>]*class="[^"]*content[^"]*"[^>]*>(.*?)</p>',
      dotAll: true,
    );
    for (final block in blockRegex.allMatches(html)) {
      final blockHtml = block.group(1) ?? '';
      final link = linkRegex.firstMatch(blockHtml);
      if (link == null) continue;
      final url = link.group(1) ?? '';
      final title = _stripHtml(link.group(2) ?? '');
      if (url.isEmpty || title.isEmpty || url.contains('searx.be')) continue;
      final snippet = _stripHtml(snippetRegex.firstMatch(blockHtml)?.group(1) ?? '');
      results.add(SearchResultItem(
        title: title,
        url: url,
        snippet: snippet,
        engine: 'SearXNG',
        favicon: 'https://searx.be/favicon.ico',
      ));
    }
    return results;
  }

  // ==================== 去重与排序 ====================

  /// URL 去重（归一化后）+ 标题高度相似去重 + 按引擎权重排序
  static List<SearchResultItem> _dedupeAndSort(List<SearchResultItem> items) {
    final seenUrl = <String>{};
    final seenTitles = <String>[];
    final out = <SearchResultItem>[];
    for (final item in items) {
      final u = _normalizeUrl(item.url);
      if (u.isNotEmpty && !seenUrl.add(u)) continue;
      final t = _normalizeTitle(item.title);
      if (t.isNotEmpty && seenTitles.any((s) => _titlesSimilar(s, t))) continue;
      if (t.isNotEmpty) seenTitles.add(t);
      out.add(item);
    }
    out.sort((a, b) =>
        (_weights[b.engine] ?? 0).compareTo(_weights[a.engine] ?? 0));
    return out;
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

  /// URL 标准化（去重用）：解重定向 → 去 tracking 参数 → host+path+参数名集合
  static String _normalizeUrl(String url) {
    var u = _extractRealUrl(url);
    u = _extract360Url(u);
    if (u.isEmpty) return '';
    try {
      final uri = Uri.parse(u);
      if (uri.host.isEmpty) return '';
      final clean = Map.of(uri.queryParameters)
        ..removeWhere((k, _) => const {
              'utm_source', 'utm_medium', 'utm_campaign', 'utm_term',
              'utm_content', 'spm', 'from', 'fr', 'bd_vid', 'tn',
              'ie', 'src', 'm', 'q', 'kw',
            }.contains(k.toLowerCase()));
      final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
      final path = uri.path.isEmpty ? '/' : uri.path;
      // 只比对参数名集合（值忽略），避免 tracking 值变化导致去重失效
      final params = clean.keys.map((k) => k.toLowerCase()).toList()..sort();
      return '$host$path?${params.join(',')}'.toLowerCase().replaceAll(RegExp(r'/$'), '');
    } catch (_) {
      return '';
    }
  }

  /// 标题归一化（去空格/分隔符）
  static String _normalizeTitle(String t) => t
      .toLowerCase()
      .replaceAll(RegExp(r'[\s　\-|_【】\[\]()（）·,.、，。]'), '');

  /// 标题高度相似判定：bigram Jaccard > 0.8 视为同一条
  static bool _titlesSimilar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if ((a.length - b.length).abs() > 5) return false;
    if (a == b) return true;
    Set<String> grams(String s) =>
        {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
    final ga = grams(a), gb = grams(b);
    if (ga.isEmpty || gb.isEmpty) return false;
    return ga.intersection(gb).length / ga.union(gb).length > 0.8;
  }

  /// 从重定向 URL 提取真实 URL（Bing / go.microsoft）
  static String _extractRealUrl(String url) {
    if (url.isEmpty) return '';
    if (url.contains('/click?') || url.contains('go.microsoft.com')) {
      final match = RegExp(r'[?&]url=([^&]+)').firstMatch(url);
      if (match != null) {
        try {
          return Uri.decodeComponent(match.group(1) ?? '');
        } catch (_) {
          return '';
        }
      }
    }
    return url;
  }

  /// 解 360 跳转链（so.com/link?url=...）
  static String _extract360Url(String url) {
    if (url.isEmpty) return '';
    if (url.contains('so.com/link')) {
      final match = RegExp(r'[?&]url=([^&]+)').firstMatch(url);
      if (match != null) {
        try {
          return Uri.decodeComponent(match.group(1) ?? '');
        } catch (_) {
          return '';
        }
      }
    }
    return url;
  }
}
