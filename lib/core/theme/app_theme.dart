import 'package:flutter/material.dart';

class AppTheme {
  // 主色调 — 淡紫蓝
  static const Color _primaryLight = Color(0xFF5B7FFF);
  static const Color _primaryDark = Color(0xFF7B9FFF);

  // 浅色模式
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _primaryLight,
      secondary: const Color(0xFF8B9DC9),
      surface: const Color(0xFFF8F6F3),
      surfaceContainerLow: const Color(0xFFF0EDE9),
      surfaceContainer: const Color(0xFFE8E4DF),
      surfaceContainerHigh: const Color(0xFFDDD9D3),
      onSurface: const Color(0xFF1A1A1E),
      onSurfaceVariant: const Color(0xFF6B6B73),
      outline: const Color(0xFFD0CCC6),
      outlineVariant: const Color(0xFFE0DCD6),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F6F3),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: const Color(0xFFF0EDE9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD0CCC6), width: 0.5),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Color(0x335B7FFF),
      selectionHandleColor: Color(0xFF5B7FFF),
    ),
  );

  // 深色模式
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: _primaryDark,
      secondary: const Color(0xFFA0B3E0),
      surface: const Color(0xFF1A1A1E),
      surfaceContainerLow: const Color(0xFF222226),
      surfaceContainer: const Color(0xFF2A2A2E),
      surfaceContainerHigh: const Color(0xFF323236),
      onSurface: const Color(0xFFE8E6E3),
      onSurfaceVariant: const Color(0xFF9E9EA6),
      outline: const Color(0xFF3A3A3E),
      outlineVariant: const Color(0xFF2E2E32),
    ),
    scaffoldBackgroundColor: const Color(0xFF1A1A1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF222226),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF3A3A3E), width: 0.5),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Color(0x337B9FFF),
      selectionHandleColor: Color(0xFF7B9FFF),
    ),
  );
}
