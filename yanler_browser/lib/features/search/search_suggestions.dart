import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/search_engines.dart';

/// 关联搜索 — 输入联想建议服务
///
/// 修复「联想加载缓慢」：Bing Autosuggest（JSON）与百度联想（JSONP）
/// **并行发起**，先拿到非空结果者立即返回，不再串行等待 + 5s 超时兜底。
class SearchSuggestions {
  static const _timeout = Duration(seconds: 3);

  static Future<List<String>> fetch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final completer = Completer<List<String>>();
    final done = <Future<List<String>>>[_fetchBing(q), _fetchBaidu(q)];
    var settled = 0;

    for (final f in done) {
      unawaited(f.then((list) {
        settled++;
        if (list.isNotEmpty && !completer.isCompleted) {
          completer.complete(list);
        } else if (settled == done.length && !completer.isCompleted) {
          // 两个接口都返回空：静默返回空列表
          completer.complete(const []);
        }
      }).catchError((_) {
        settled++;
        if (settled == done.length && !completer.isCompleted) {
          completer.complete(const []);
        }
      }));
    }

    return completer.future;
  }

  /// Bing Autosuggest: ["query", ["sug1", ...], ...]
  static Future<List<String>> _fetchBing(String q) async {
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
      // 忽略，走并行兜底
    }
    return const [];
  }

  /// 百度 JSONP: yanlerSug({q:"...", p:false, s:["a","b",...]});
  static Future<List<String>> _fetchBaidu(String q) async {
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
      // 忽略
    }
    return const [];
  }
}
