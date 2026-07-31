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

  /// 首次启动的默认快捷链接
  static const List<QuickLink> _defaults = [
    QuickLink(
      id: 'default-bili',
      title: '哔哩哔哩',
      url: 'https://www.bilibili.com',
    ),
    QuickLink(
      id: 'default-zhihu',
      title: '知乎',
      url: 'https://www.zhihu.com',
    ),
    QuickLink(
      id: 'default-baidu',
      title: '百度',
      url: 'https://www.baidu.com',
    ),
    QuickLink(
      id: 'default-github',
      title: 'GitHub',
      url: 'https://github.com',
    ),
    QuickLink(
      id: 'default-blog',
      title: '博客',
      url: 'https://blog.260607.best',
    ),
    QuickLink(
      id: 'default-weibo',
      title: '微博',
      url: 'https://weibo.com',
    ),
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('quickLinks') ?? [];
    if (data.isEmpty) {
      // 首次启动：写入默认链接
      _links = List.of(_defaults);
      await _save();
    } else {
      _links = data
          .map((e) => QuickLink.fromJson(jsonDecode(e)))
          .toList();
    }
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
