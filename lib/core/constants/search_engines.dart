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
    SearchEngine(
      name: 'Yanler Search',
      url: 'http://localhost:8080/search?q=',
      iconUrl: 'https://www.google.com/favicon.ico',
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
      name: 'Bing',
      url: 'https://www.bing.com/search?q=',
      iconUrl: 'https://www.bing.com/favicon.ico',
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
}
