import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/search_engines.dart';
import '../../providers/settings_provider.dart';
import '../../providers/browser_provider.dart';

class SearchService {
  /// 直接打开搜索
  void openSearch(BuildContext context, String query) {
    final settings = context.read<SettingsProvider>();
    final browser = context.read<BrowserProvider>();
    final engine = SearchEngines.byName(settings.searchEngine);
    final searchUrl = '${engine.url}${Uri.encodeComponent(query)}';

    if (browser.activeTabIndex >= 0) {
      browser.updateTabUrl(browser.activeTabIndex, searchUrl);
    }
  }

  /// 判断输入是搜索词还是URL
  static String normalizeInput(String input, String searchEngineName) {
    final trimmed = input.trim();

    if (trimmed.isEmpty) return '';

    // 已经是 URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // 包含 . 可能是域名（如 google.com）
    if (trimmed.contains('.') && !trimmed.contains(' ')) {
      return 'https://$trimmed';
    }

    // 否则当作搜索
    final engine = SearchEngines.byName(searchEngineName);
    return '${engine.url}${Uri.encodeComponent(trimmed)}';
  }
}
