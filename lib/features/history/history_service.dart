import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String id;
  final String title;
  final String url;
  final DateTime visitedAt;
  final int visitCount;

  HistoryEntry({
    required this.id,
    required this.title,
    required this.url,
    DateTime? visitedAt,
    this.visitCount = 1,
  }) : visitedAt = visitedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'visitedAt': visitedAt.toIso8601String(),
    'visitCount': visitCount,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'],
    title: json['title'],
    url: json['url'],
    visitedAt: DateTime.parse(json['visitedAt']),
    visitCount: json['visitCount'] ?? 1,
  );
}

class HistoryService extends ChangeNotifier {
  List<HistoryEntry> _history = [];

  List<HistoryEntry> get history => List.unmodifiable(_history);
  int get count => _history.length;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('history') ?? [];
    _history = data
        .map((e) => HistoryEntry.fromJson(jsonDecode(e)))
        .toList();
    notifyListeners();
  }

  Future<void> add(String title, String url) async {
    // 检查是否已存在
    final existing = _history.indexWhere((h) => h.url == url);
    if (existing >= 0) {
      _history[existing] = HistoryEntry(
        id: _history[existing].id,
        title: title,
        url: url,
        visitedAt: DateTime.now(),
        visitCount: _history[existing].visitCount + 1,
      );
      _history.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    } else {
      _history.insert(
        0,
        HistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          url: url,
        ),
      );
    }

    // 限制历史记录数量（最近500条）
    if (_history.length > 500) {
      _history = _history.sublist(0, 500);
    }

    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _history.clear();
    await _save();
    notifyListeners();
  }

  Future<void> clearForTimeRange(DateTime start, DateTime end) async {
    _history.removeWhere(
      (h) => h.visitedAt.isAfter(start) && h.visitedAt.isBefore(end),
    );
    await _save();
    notifyListeners();
  }

  List<HistoryEntry> search(String query) {
    final q = query.toLowerCase();
    return _history
        .where((h) =>
            h.title.toLowerCase().contains(q) ||
            h.url.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      _history.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }
}
