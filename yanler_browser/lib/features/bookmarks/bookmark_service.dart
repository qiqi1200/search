import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Bookmark {
  final String id;
  final String title;
  final String url;
  final DateTime addedAt;

  Bookmark({
    required this.id,
    required this.title,
    required this.url,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    id: json['id'],
    title: json['title'],
    url: json['url'],
    addedAt: DateTime.parse(json['addedAt']),
  );
}

class BookmarkService extends ChangeNotifier {
  List<Bookmark> _bookmarks = [];

  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);
  int get count => _bookmarks.length;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('bookmarks') ?? [];
    _bookmarks = data
        .map((e) => Bookmark.fromJson(jsonDecode(e)))
        .toList();
    notifyListeners();
  }

  Future<void> add(String title, String url) async {
    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      url: url,
    );
    _bookmarks.insert(0, bookmark);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _bookmarks.removeWhere((b) => b.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _bookmarks.clear();
    await _save();
    notifyListeners();
  }

  bool isBookmarked(String url) {
    return _bookmarks.any((b) => b.url == url);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bookmarks',
      _bookmarks.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }
}
