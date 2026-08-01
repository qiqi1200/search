import 'package:flutter/material.dart';

class AppTheme {
  // 品牌主色调 — 淡紫蓝（Yanler 渐变 Logo 的同源色）
  static const Color _primaryLight = Color(0xFF5B7FFF);
  static const Color _primaryDark = Color(0xFF7B9FFF);

  // 中文字体回退链（Outfit 只覆盖拉丁字符）
  static const List<String> _fallback = [
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

  // 浅色模式
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Outfit',
    fontFamilyFallback: _fallback,
    colorScheme: const ColorScheme.light(
      primary: _primaryLight,
      secondary: Color(0xFF8B9DC9),
      surface: Color(0xFFF7F5F2),
      surfaceContainerLow: Color(0xFFF0EDE9),
      surfaceContainer: Color(0xFFE9E5E0),
      surfaceContainerHigh: Color(0xFFDDD9D3),
      onSurface: Color(0xFF191A1E),
      onSurfaceVariant: Color(0xFF5F6068),
      outline: Color(0xFFD2CEC8),
      outlineVariant: Color(0xFFE2DED8),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F5F2),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Color(0xFF191A1E),
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
      selectionColor: Color(0x335B7FFF),
      selectionHandleColor: Color(0xFF5B7FFF),
    ),
    splashFactory: InkRipple.splashFactory,
    // 按压缩留高光用品牌色微染——原来 transparent 导致所有可点项（设置行等）无按压反馈
    highlightColor: const Color(0x145B7FFF),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2DED8),
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
      backgroundColor: const Color(0xFFFCFAF7),
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
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  // 深色模式
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Outfit',
    fontFamilyFallback: _fallback,
    colorScheme: const ColorScheme.dark(
      primary: _primaryDark,
      secondary: Color(0xFFA0B3E0),
      surface: Color(0xFF191A1E),
      surfaceContainerLow: Color(0xFF212226),
      surfaceContainer: Color(0xFF28292E),
      surfaceContainerHigh: Color(0xFF303136),
      onSurface: Color(0xFFE9E7E3),
      onSurfaceVariant: Color(0xFF9B9CA4),
      outline: Color(0xFF3B3C42),
      outlineVariant: Color(0xFF2E2F34),
    ),
    scaffoldBackgroundColor: const Color(0xFF191A1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Color(0xFFE9E7E3),
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
      selectionColor: Color(0x337B9FFF),
      selectionHandleColor: Color(0xFF7B9FFF),
    ),
    splashFactory: InkRipple.splashFactory,
    highlightColor: const Color(0x167B9FFF),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2E2F34),
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
      backgroundColor: const Color(0xFF232328),
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
      backgroundColor: const Color(0xFFE9E7E3),
      contentTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF191A1E)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
