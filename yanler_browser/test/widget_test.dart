import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanler_browser/core/theme/app_theme.dart';
import 'package:yanler_browser/providers/browser_provider.dart';
import 'package:yanler_browser/providers/settings_provider.dart';
import 'package:yanler_browser/providers/ai_provider.dart';
import 'package:yanler_browser/providers/quick_links_provider.dart';
import 'package:yanler_browser/features/adblock/adblock_engine.dart';
import 'package:yanler_browser/features/bookmarks/bookmark_service.dart';
import 'package:yanler_browser/features/history/history_service.dart';
import 'package:yanler_browser/features/browser/screens/browser_screen.dart';

void main() {
  testWidgets('App loads with provider tree', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final adblockEngine = AdblockEngine();
    final bookmarkService = BookmarkService();
    final historyService = HistoryService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BrowserProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AIProvider()),
          ChangeNotifierProvider(create: (_) => QuickLinksProvider()),
          ChangeNotifierProvider.value(value: adblockEngine),
          ChangeNotifierProvider.value(value: bookmarkService),
          ChangeNotifierProvider.value(value: historyService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const BrowserScreen(),
        ),
      ),
    );
    await tester.pump();

    // 新标签页应显示品牌字标
    expect(find.byType(BrowserScreen), findsOneWidget);

    // 触发并消化启动时的静默更新检查定时器，避免 pending timer 断言
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
  });
}
