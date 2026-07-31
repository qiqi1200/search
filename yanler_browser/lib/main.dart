import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/browser/screens/browser_screen.dart';
import 'providers/browser_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/quick_links_provider.dart';
import 'features/adblock/adblock_engine.dart';
import 'features/bookmarks/bookmark_service.dart';
import 'features/history/history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化服务
  final adblockEngine = AdblockEngine();
  await adblockEngine.initialize();

  final bookmarkService = BookmarkService();
  await bookmarkService.initialize();

  final historyService = HistoryService();
  await historyService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BrowserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => QuickLinksProvider()..initialize()),
        ChangeNotifierProvider.value(value: adblockEngine),
        ChangeNotifierProvider.value(value: bookmarkService),
        ChangeNotifierProvider.value(value: historyService),
      ],
      child: const YanlerApp(),
    ),
  );
}

class YanlerApp extends StatelessWidget {
  const YanlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'Yanler',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          locale: const Locale('zh', 'CN'),
          home: const BrowserScreen(),
        );
      },
    );
  }
}
