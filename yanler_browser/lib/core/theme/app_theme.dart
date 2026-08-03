import 'package:flutter/material.dart';
import 'yanler_motion.dart';

class AppTheme {
  // 品牌主色调 — 黛蓝（Yanler preview 2026-08 改版：单一强调色）
  static const Color _primaryLight = Color(0xFF3A5CCC);
  static const Color _primaryDark = Color(0xFF7B93F2);

  // 中文字体回退链（Outfit 只覆盖拉丁字符）
  static const List<String> _fallback = [
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

  // 浅色模式（暖纸）
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Outfit',
    fontFamilyFallback: _fallback,
    colorScheme: const ColorScheme.light(
      primary: _primaryLight,
      secondary: Color(0xFF7E8FB8),
      surface: Color(0xFFF6F4EF),
      surfaceContainerLow: Color(0xFFECE9E2),
      surfaceContainer: Color(0xFFE5E1D9),
      surfaceContainerHigh: Color(0xFFDBD6CE),
      onSurface: Color(0xFF1A1B1E),
      onSurfaceVariant: Color(0xFF6B6C72),
      outline: Color(0xFFD5D1C9),
      outlineVariant: Color(0xFFE7E3DC),
    ),
    scaffoldBackgroundColor: const Color(0xFFF6F4EF),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Color(0xFF1A1B1E),
      ),
    ),
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0.2),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Color(0x333A5CCC),
      selectionHandleColor: Color(0xFF3A5CCC),
    ),
    splashFactory: InkRipple.splashFactory,
    // 按压缩留高光用品牌色微染——原来 transparent 导致所有可点项（设置行等）无按压反馈
    highlightColor: const Color(0x143A5CCC),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE7E3DC),
      thickness: 0.6,
      space: 1,
    ),
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFFCFBF8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2B2B31),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: YanlerPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: YanlerPageTransitionsBuilder(),
      },
    ),
  );

  // 深色模式（墨色）
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Outfit',
    fontFamilyFallback: _fallback,
    colorScheme: const ColorScheme.dark(
      primary: _primaryDark,
      secondary: Color(0xFF9AA8CE),
      surface: Color(0xFF131417),
      surfaceContainerLow: Color(0xFF191B1F),
      surfaceContainer: Color(0xFF1F2126),
      surfaceContainerHigh: Color(0xFF26282E),
      onSurface: Color(0xFFE8E6E1),
      onSurfaceVariant: Color(0xFF9C9DA5),
      outline: Color(0xFF33353B),
      outlineVariant: Color(0xFF2A2C31),
    ),
    scaffoldBackgroundColor: const Color(0xFF131417),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Color(0xFFE8E6E1),
      ),
    ),
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0.2),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Color(0x337B93F2),
      selectionHandleColor: Color(0xFF7B93F2),
    ),
    splashFactory: InkRipple.splashFactory,
    highlightColor: const Color(0x167B93F2),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A2C31),
      thickness: 0.6,
      space: 1,
    ),
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E2024),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFE8E6E1),
      contentTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1A1B1E)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: YanlerPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: YanlerPageTransitionsBuilder(),
      },
    ),
  );
}
