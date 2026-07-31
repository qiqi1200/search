import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _searchEngine = 'Yanler Search';
  bool _adblockEnabled = true;
  bool _doNotTrack = true;
  bool _blockThirdPartyCookies = true;
  bool _javascriptEnabled = true;
  String _homepage = '';
  double _fontSize = 1.0;
  String _wallpaperId = 'default';
  String _customWallpaperPath = '';

  ThemeMode get themeMode => _themeMode;
  String get searchEngine => _searchEngine;
  bool get adblockEnabled => _adblockEnabled;
  bool get doNotTrack => _doNotTrack;
  bool get blockThirdPartyCookies => _blockThirdPartyCookies;
  bool get javascriptEnabled => _javascriptEnabled;
  String get homepage => _homepage;
  double get fontSize => _fontSize;
  String get wallpaperId => _wallpaperId;
  String get customWallpaperPath => _customWallpaperPath;
  bool get hasCustomWallpaper => _customWallpaperPath.isNotEmpty;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode =
        prefs.getBool('darkMode') == true ? ThemeMode.dark : ThemeMode.light;
    _searchEngine = prefs.getString('searchEngine') ?? 'Yanler Search';
    _adblockEnabled = prefs.getBool('adblockEnabled') ?? true;
    _doNotTrack = prefs.getBool('doNotTrack') ?? true;
    _blockThirdPartyCookies =
        prefs.getBool('blockThirdPartyCookies') ?? true;
    _javascriptEnabled = prefs.getBool('javascriptEnabled') ?? true;
    _homepage = prefs.getString('homepage') ?? '';
    _fontSize = prefs.getDouble('fontSize') ?? 1.0;
    _wallpaperId = prefs.getString('wallpaperId') ?? 'default';
    _customWallpaperPath = prefs.getString('customWallpaperPath') ?? '';
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setSearchEngine(String engine) async {
    _searchEngine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('searchEngine', engine);
    notifyListeners();
  }

  Future<void> setHomepage(String homepage) async {
    _homepage = homepage.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('homepage', _homepage);
    notifyListeners();
  }

  Future<void> setWallpaper(String id) async {
    _wallpaperId = id;
    _customWallpaperPath = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallpaperId', id);
    await prefs.setString('customWallpaperPath', '');
    notifyListeners();
  }

  /// 设置自定义壁纸（本地图片路径）
  Future<void> setCustomWallpaper(String path) async {
    _wallpaperId = 'custom';
    _customWallpaperPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallpaperId', 'custom');
    await prefs.setString('customWallpaperPath', path);
    notifyListeners();
  }

  Future<void> setAdblockEnabled(bool value) async {
    _adblockEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adblockEnabled', value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', mode == ThemeMode.dark);
    notifyListeners();
  }
}
