import 'package:flutter/material.dart';

/// 壁纸预设 — 新标签页背景
class Wallpaper {
  final String id;
  final String name;
  final List<Color> light;
  final List<Color> dark;

  const Wallpaper({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });

  List<Color> colorsFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

class Wallpapers {
  Wallpapers._();

  static const String defaultId = 'default';

  static const List<Wallpaper> presets = [
    Wallpaper(
      id: 'aurora',
      name: '极光',
      light: [Color(0xFFDCEBFF), Color(0xFFE8DDF7), Color(0xFFF7DCE8)],
      dark: [Color(0xFF101828), Color(0xFF1A1633), Color(0xFF2A1630)],
    ),
    Wallpaper(
      id: 'dusk',
      name: '暮色',
      light: [Color(0xFFFFE9D6), Color(0xFFFFD6D6), Color(0xFFE8D5F7)],
      dark: [Color(0xFF2A1712), Color(0xFF2E1420), Color(0xFF221433)],
    ),
    Wallpaper(
      id: 'ocean',
      name: '深海',
      light: [Color(0xFFD6F2F0), Color(0xFFD6E8F7), Color(0xFFE0DCF7)],
      dark: [Color(0xFF0E1F24), Color(0xFF10202E), Color(0xFF161B30)],
    ),
    Wallpaper(
      id: 'forest',
      name: '山野',
      light: [Color(0xFFE3F2E0), Color(0xFFE0EDE9), Color(0xFFE8E2D6)],
      dark: [Color(0xFF101D16), Color(0xFF12201C), Color(0xFF1A1C12)],
    ),
    Wallpaper(
      id: 'sakura',
      name: '樱粉',
      light: [Color(0xFFFFF0F3), Color(0xFFFDE8F0), Color(0xFFF5EBFA)],
      dark: [Color(0xFF241820), Color(0xFF2A1722), Color(0xFF231A2B)],
    ),
    Wallpaper(
      id: 'paper',
      name: '宣纸',
      light: [Color(0xFFF7F3E8), Color(0xFFF3EEE2), Color(0xFFEFEAE0)],
      dark: [Color(0xFF1D1B16), Color(0xFF22201A), Color(0xFF26231C)],
    ),
  ];

  static Wallpaper byId(String id) {
    return presets.firstWhere(
      (w) => w.id == id,
      orElse: () => presets.first,
    );
  }
}
