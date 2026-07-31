import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../../providers/browser_provider.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/search_engines.dart';
import '../../settings/settings_screen.dart';
import '../../adblock/adblock_engine.dart';
import '../../ai/ai_chat_screen.dart';
import '../../bookmarks/bookmark_service.dart';
import '../../bookmarks/bookmarks_screen.dart';
import '../../history/history_service.dart';
import '../../history/history_screen.dart';
import '../../updater/update_service.dart';
import '../widgets/address_bar.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/tab_switcher.dart';
import '../widgets/new_tab_page.dart';
import '../widgets/webview_container.dart';
import '../../../core/widgets/liquid_glass.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;
  bool _canGoForward = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final browser = context.read<BrowserProvider>();
      if (browser.tabCount == 0) {
        browser.addTab();
      }
      // 启动静默检查更新（仅一次；失败静默，校园网下不打扰）
      _scheduleUpdateCheck();
    });
  }

  static bool _updateChecked = false;

  void _scheduleUpdateCheck() {
    if (_updateChecked) return;
    _updateChecked = true;
    Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;
      final result = await UpdateService.checkForUpdates();
      if (!mounted || result.info == null) return;
      UpdateService.showUpdateDialog(context, result.info!);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUrlSubmitted(String url) {
    final browser = context.read<BrowserProvider>();
    final settings = context.read<SettingsProvider>();

    String finalUrl = url.trim();
    // 检测是否为搜索词
    if (!finalUrl.startsWith('http://') &&
        !finalUrl.startsWith('https://') &&
        !finalUrl.contains('.')) {
      final engine = SearchEngines.byName(settings.searchEngine);
      finalUrl = '${engine.url}${Uri.encodeComponent(finalUrl)}';
    } else if (!finalUrl.startsWith('http://') &&
        !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    if (browser.activeTabIndex >= 0) {
      browser.updateTabUrl(browser.activeTabIndex, finalUrl);
    }

    // 已有 WebView 时直接驱动加载（新标签页场景由 initialUrlRequest 负责），
    // 避免依赖 didUpdateWidget 自动重载造成重定向循环。
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(finalUrl)),
    );
  }

  /// 刷新/停止 — 加载中停止，否则刷新
  void _onRefreshPressed() {
    final controller = _webViewController;
    if (controller == null) return;
    final activeTab = context.read<BrowserProvider>().activeTab;
    if (activeTab?.isLoading == true) {
      controller.stopLoading();
    } else {
      controller.reload();
    }
  }

  /// 后退：调用 WebView 原生方法，并刷新按钮可用状态
  Future<void> _goBack() async {
    final c = _webViewController;
    if (c == null) return;
    await c.goBack();
    await _refreshNavStateAfterAction();
  }

  /// 前进：调用 WebView 原生方法，并刷新按钮可用状态
  Future<void> _goForward() async {
    final c = _webViewController;
    if (c == null) return;
    await c.goForward();
    await _refreshNavStateAfterAction();
  }

  /// 前进/后退后稍候刷新按钮可用状态（等待 WebView 历史栈更新）
  Future<void> _refreshNavStateAfterAction() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    final c = _webViewController;
    if (c == null) return;
    try {
      final canBack = await c.canGoBack();
      final canFwd = await c.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = canBack;
          _canGoForward = canFwd;
        });
      }
    } catch (_) {
      // WebView 尚未就绪时忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrowserProvider, SettingsProvider>(
      builder: (context, browser, settings, _) {
        final isOnNewTab = browser.activeTab?.url.isEmpty ?? true;
        final adblock = context.watch<AdblockEngine>();
        final ai = context.watch<AIProvider>();

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // 地址栏
                if (!isOnNewTab)
                  AddressBar(
                    url: browser.activeTab?.url ?? '',
                    isLoading: browser.activeTab?.isLoading ?? false,
                    progress: _progress,
                    onRefresh: _onRefreshPressed,
                    onSubmitted: _onUrlSubmitted,
                  ),

                // 页面内容
                Expanded(
                  child: isOnNewTab
                      ? const NewTabPage()
                      : WebViewContainer(
                          key: ValueKey(browser.activeTab?.id),
                          tabId: browser.activeTab?.id ?? '',
                          initialUrl: browser.activeTab?.url ?? '',
                          onUrlChanged: (url) {
                            final activeIndex = browser.activeTabIndex;
                            if (activeIndex >= 0) {
                              browser.updateTabUrl(activeIndex, url);
                            }
                          },
                          onTitleChanged: (title) {
                            final activeIndex = browser.activeTabIndex;
                            if (activeIndex >= 0) {
                              browser.updateTabTitle(activeIndex, title);
                              // 记录历史（Firefox/Chrome 同款行为）
                              final url = browser.activeTab?.url;
                              if (url != null && url.isNotEmpty) {
                                context
                                    .read<HistoryService>()
                                    .add(title, url);
                              }
                            }
                          },
                          onLoadingChanged: (loading) {
                            final activeIndex = browser.activeTabIndex;
                            if (activeIndex >= 0) {
                              browser.setTabLoading(activeIndex, loading);
                            }
                          },
                          onProgressChanged: (progress) {
                            if (mounted) {
                              setState(() => _progress = progress);
                            }
                          },
                          onControllerReady: (controller) {
                            _webViewController = controller;
                          },
                          onNavigationStateChanged: (canBack, canFwd) {
                            if (mounted) {
                              setState(() {
                                _canGoBack = canBack;
                                _canGoForward = canFwd;
                              });
                            }
                          },
                        ),
                ),

                // 底部栏
                BottomBar(
                  tabCount: browser.tabCount,
                  isIncognito: browser.isIncognitoMode,
                  canGoBack: _canGoBack,
                  canGoForward: _canGoForward,
                  adBlockCount: adblock.blockedCount,
                  aiActive: ai.agentMode,
                  onBack: () => _goBack(),
                  onForward: () => _goForward(),
                  onHome: () => _goHome(browser),
                  onAI: () => _openAIChat(context),
                  onTabSwitch: () => _showTabSwitcher(context),
                  onMenu: () => _showMenu(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTabSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TabSwitcherSheet(),
    );
  }

  void _goHome(BrowserProvider browser) {
    // 回到新标签页
    final activeIndex = browser.activeTabIndex;
    if (activeIndex >= 0) {
      browser.updateTabUrl(activeIndex, '');
    }
    setState(() {
      _canGoBack = false;
      _canGoForward = false;
      _webViewController = null;
    });
  }

  void _showMenu(BuildContext context) {
    final adblock = context.read<AdblockEngine>();
    final browser = context.read<BrowserProvider>();
    final currentUrl = browser.activeTab?.url ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomMenuSheet(
        adBlockCount: adblock.blockedCount,
        canBookmark: currentUrl.isNotEmpty,
        isDarkModeActive: context.read<SettingsProvider>().isDarkMode,
        isIncognitoActive: browser.isIncognitoMode,
        isAIActive: context.read<AIProvider>().agentMode,
        onToggleTheme: () {
          context.read<SettingsProvider>().toggleTheme();
          Navigator.pop(context);
        },
        onOpenSettings: () {
          Navigator.pop(context);
          _openSettings(context);
        },
        onToggleIncognito: () {
          context.read<BrowserProvider>().toggleIncognito();
          Navigator.pop(context);
        },
        onToggleAI: () {
          Navigator.pop(context);
          _openAIChat(context);
        },
        onOpenBookmarks: () {
          Navigator.pop(context);
          _openBookmarks(context);
        },
        onOpenHistory: () {
          Navigator.pop(context);
          _openHistory(context);
        },
        onAddBookmark: () {
          final title = browser.activeTab?.title ?? '未命名';
          context.read<BookmarkService>().add(title, currentUrl);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已收藏到书签'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _openBookmarks(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookmarksScreen()),
    ).then((url) {
      if (url is String && url.isNotEmpty && context.mounted) {
        context.read<BrowserProvider>().addTab(url: url);
      }
    });
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    ).then((url) {
      if (url is String && url.isNotEmpty && context.mounted) {
        context.read<BrowserProvider>().addTab(url: url);
      }
    });
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    ).then((url) {
      if (url is String && url.isNotEmpty && context.mounted) {
        context.read<BrowserProvider>().addTab(url: url);
      }
    });
  }

  /// 打开 AI 聊天窗口（无论是否已配置，未配置时聊天页内引导）
  void _openAIChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIChatScreen()),
    );
  }
}

// 底部菜单面板（三点菜单）— 液态玻璃
class _BottomMenuSheet extends StatelessWidget {
  final int adBlockCount;
  final bool canBookmark;
  final bool isDarkModeActive;
  final bool isIncognitoActive;
  final bool isAIActive;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleIncognito;
  final VoidCallback onToggleAI;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenHistory;
  final VoidCallback onAddBookmark;

  const _BottomMenuSheet({
    required this.adBlockCount,
    required this.canBookmark,
    required this.isDarkModeActive,
    required this.isIncognitoActive,
    required this.isAIActive,
    required this.onToggleTheme,
    required this.onOpenSettings,
    required this.onToggleIncognito,
    required this.onToggleAI,
    required this.onOpenBookmarks,
    required this.onOpenHistory,
    required this.onAddBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return LiquidGlass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      blur: 30,
      opacity: isDark ? 0.42 : 0.38,
      borderWidth: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示条
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // 广告拦截统计条
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '广告拦截',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '已拦截 $adBlockCount 个',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 功能宫格：深色 / 设置 / 无痕 / AI / 书签 / 历史 / 收藏此页
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 12,
                children: [
                  _MenuButton(
                    icon: isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    label: isDark ? '浅色' : '深色',
                    active: isDarkModeActive,
                    onTap: onToggleTheme,
                  ),
                  _MenuButton(
                    icon: Icons.settings_rounded,
                    label: '设置',
                    active: false,
                    onTap: onOpenSettings,
                  ),
                  _MenuButton(
                    icon: Icons.privacy_tip_outlined,
                    label: '无痕',
                    active: isIncognitoActive,
                    onTap: onToggleIncognito,
                  ),
                  _MenuButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI',
                    active: isAIActive,
                    onTap: onToggleAI,
                  ),
                  _MenuButton(
                    icon: Icons.bookmark_border_rounded,
                    label: '书签',
                    active: false,
                    onTap: onOpenBookmarks,
                  ),
                  _MenuButton(
                    icon: Icons.history_rounded,
                    label: '历史',
                    active: false,
                    onTap: onOpenHistory,
                  ),
                  if (canBookmark)
                    _MenuButton(
                      icon: Icons.bookmark_add_outlined,
                      label: '收藏此页',
                      active: false,
                      onTap: onAddBookmark,
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
                    )
                  : null,
              color: active
                  ? null
                  : theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? theme.colorScheme.primary.withValues(alpha: 0.85)
                    : theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CFF).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 24,
              color: active ? Colors.white : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: active ? theme.colorScheme.primary : null,
              fontWeight: active ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}
