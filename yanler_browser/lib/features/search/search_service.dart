import '../../core/constants/search_engines.dart';

/// 搜索输入规范化 — 判断输入是网址还是关键词，归一为可加载的完整 URL。
///
/// 所有导航入口（地址栏 / 首页搜索 / 联想点击 / AI 操作）共用此逻辑，
/// 保证「关键词 → 搜索引擎 URL」「域名 → https:// 前缀」行为完全一致。
class SearchService {
  SearchService._();

  /// 判断输入是搜索词还是 URL
  static String normalizeInput(String input, String searchEngineName) {
    final trimmed = input.trim();

    if (trimmed.isEmpty) return '';

    // 已经是 URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // 包含 . 可能是域名（如 google.com、example.com.cn）
    if (trimmed.contains('.') && !trimmed.contains(' ')) {
      return 'https://$trimmed';
    }

    // 否则当作搜索
    final engine = SearchEngines.byName(searchEngineName);
    return '${engine.url}${Uri.encodeComponent(trimmed)}';
  }
}
