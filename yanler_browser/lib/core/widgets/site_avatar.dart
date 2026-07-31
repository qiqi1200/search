import 'package:flutter/material.dart';

/// 站点字母头像 — 取域名首字母 + 品牌渐变色块（无网络依赖）
class SiteAvatar extends StatelessWidget {
  final String title;
  final String url;
  final double size;

  const SiteAvatar({
    super.key,
    required this.title,
    required this.url,
    this.size = 42,
  });

  static const List<List<Color>> _palette = [
    [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
    [Color(0xFF00B8A9), Color(0xFF00A3E0)],
    [Color(0xFFFF8E53), Color(0xFFFF5C7B)],
    [Color(0xFF7B61FF), Color(0xFFB05CFF)],
    [Color(0xFF2E9EFF), Color(0xFF00C6A7)],
    [Color(0xFFF95C7B), Color(0xFFF7A35C)],
  ];

  List<Color> get _colors {
    final key = url.isNotEmpty ? url : title;
    final hash = key.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0xFFFF);
    return _palette[hash % _palette.length];
  }

  String get _letter {
    if (url.isNotEmpty) {
      final host = Uri.tryParse(url)?.host ?? '';
      if (host.isNotEmpty) return host[0].toUpperCase();
    }
    if (title.isNotEmpty) return title.characters.first.toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _colors,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Text(
          _letter,
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }
}
