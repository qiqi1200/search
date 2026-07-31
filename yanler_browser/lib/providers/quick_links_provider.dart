import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 快捷链接（Speed Dial）— 借鉴 Vivaldi / Chrome 新标签页的常用功能
class QuickLink {
  final String id;
  final String title;
  final String url;

  const QuickLink({
    required this.id,
    required this.title,
    required this.url,
  });

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'url': url};

  factory QuickLink.fromJson(Map<String, dynamic> json) => QuickLink(
        id: json['id'],
        title: json['title'],
        url: json['url'],
      );
}

class QuickLinksProvider extends ChangeNotifier {
  List<QuickLink> _links = [];

  List<QuickLink> get links => List.unmodifiable(_links);

  /// 首页默认不预置任何快捷链接（规则：仅保留用户手动添加入口与能力）
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('quickLinks') ?? [];
    // 旧版本若写入过默认链接，迁移时也不预置；只保留用户手动添加的
    _links = data
        .map((e) => QuickLink.fromJson(jsonDecode(e)))
        .where((l) => !l.id.startsWith('default-'))
        .toList();
    notifyListeners();
  }

  Future<void> add(String title, String url) async {
    final link = QuickLink(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? url : title.trim(),
      url: url.trim(),
    );
    _links.add(link);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _links.removeWhere((l) => l.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'quickLinks',
      _links.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }
}
