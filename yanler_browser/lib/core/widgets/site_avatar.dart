import 'package:flutter/material.dart';

/// 站点字母头像 — 取域名首字母 + 纸面风格（2026-08 改版）
///
/// 去掉彩色渐变，收敛为：纸面底 + 1px 边框 + 墨色字母。
/// 深浅模式自适应，不发白。
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
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          _letter,
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }
}
