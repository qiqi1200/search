import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/search_engines.dart';

/// 关联搜索 — 输入联想建议服务
///
/// 优先走 Bing Autosuggest（返回纯 JSON，国内可用）；
/// 失败时回退百度联想接口（JSONP，国内最稳）。
class SearchSuggestions {
  static const _timeout = Duration(seconds: 5);

  static Future<List<String>> fetch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    // 1) Bing Autosuggest: ["query", ["sug1", ...], ...]
    try {
      final resp = await http
          .get(
            Uri.parse(SearchEngines.suggestionUrl(q)),
            headers: {'User-Agent': 'Mozilla/5.0 (Yanler Browser)'},
          )
          .timeout(_timeout);
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.length >= 2 && decoded[1] is List) {
          final sugs = (decoded[1] as List)
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toList();
          if (sugs.isNotEmpty) return sugs;
        }
      }
    } catch (_) {
      // 忽略，走百度回退
    }

    // 2) 百度 JSONP: yanlerSug({q:"...", p:false, s:["a","b",...]});
    try {
      final resp = await http
          .get(
            Uri.parse(SearchEngines.baiduSuggestionUrl(q)),
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final match = RegExp(r'yanlerSug\((.*)\)').firstMatch(resp.body);
        if (match != null) {
          final data = jsonDecode(match.group(1)!);
          final sugs = (data['s'] as List? ?? [])
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toList();
          if (sugs.isNotEmpty) return sugs;
        }
      }
    } catch (_) {
      // 完全失败：静默返回空列表
    }

    return const [];
  }
}
