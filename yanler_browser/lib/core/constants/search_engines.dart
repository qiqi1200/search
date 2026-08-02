class SearchEngine {
  final String name;
  final String url;
  final String iconUrl;

  const SearchEngine({
    required this.name,
    required this.url,
    required this.iconUrl,
  });
}

class SearchEngines {
  static const List<SearchEngine> engines = [
    // Yanler Search = 本地即时答案（计算/时间/农历/诗词）+ Bing 兜底。
    // 零网络零 AI 免 VPN；通用词由 browser_screen 直接打开 cn.bing.com。
    SearchEngine(
      name: 'Yanler Search',
      url: 'https://cn.bing.com/search?q=',
      iconUrl: 'https://www.bing.com/favicon.ico',
    ),
    SearchEngine(
      name: '百度',
      url: 'https://www.baidu.com/s?wd=',
      iconUrl: 'https://www.baidu.com/favicon.ico',
    ),
    SearchEngine(
      name: 'Bing',
      url: 'https://www.bing.com/search?q=',
      iconUrl: 'https://www.bing.com/favicon.ico',
    ),
    SearchEngine(
      name: 'DuckDuckGo',
      url: 'https://duckduckgo.com/?q=',
      iconUrl: 'https://duckduckgo.com/favicon.ico',
    ),
    SearchEngine(
      name: 'Google',
      url: 'https://www.google.com/search?q=',
      iconUrl: 'https://www.google.com/favicon.ico',
    ),
    SearchEngine(
      name: 'Brave',
      url: 'https://search.brave.com/search?q=',
      iconUrl: 'https://search.brave.com/favicon.ico',
    ),
    SearchEngine(
      name: 'SearXNG',
      url: 'https://searx.be/search?q=',
      iconUrl: 'https://searx.be/favicon.ico',
    ),
  ];

  static SearchEngine byName(String name) {
    return engines.firstWhere(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => engines[0],
    );
  }

  /// 关联搜索建议接口（输入联想）。
  /// 优先 Bing Autosuggest（JSON，国内可用），失败回退百度 JSONP。
  static String suggestionUrl(String query) =>
      'https://api.bing.com/osjson.aspx?query=${Uri.encodeComponent(query)}';

  static String baiduSuggestionUrl(String query) =>
      'https://suggestion.baidu.com/su?wd=${Uri.encodeComponent(query)}&p=3&cb=yanlerSug';
}
