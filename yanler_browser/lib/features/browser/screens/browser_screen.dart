import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/nav_bus.dart';
import '../../../providers/browser_provider.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../search/search_service.dart';
import '../../search/search_results_page.dart';
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
  bool _canGoBack = false;
  bool _canGoForward = false;
  double _progress = 0.0;
  DateTime _lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 上次渲染的活动标签索引 — 用于在切换标签时重置按钮状态，避免残留上一标签的旧状态
  int _lastActiveIndex = 0;

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

  /// 节流处理加载进度：WebView 进度回调非常高频（每秒可达数十次），
  /// 全量 setState 会导致地址栏/底部栏整棵树重建掉帧。
  /// 策略：进度变化 ≥5% 或距上次 ≥120ms 或加载完成时才刷新。
  void _onProgressChanged(double progress) {
    if (!mounted) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressAt).inMilliseconds;
    final delta = (progress - _progress).abs();
    if (delta >= 0.05 || elapsed >= 120 || progress >= 1.0) {
      _lastProgressAt = now;
      setState(() => _progress = progress);
    }
  }

  /// 统一导航入口 — 地址栏 / 首页搜索 / 联想点击 / 快捷链接 / AI 操作全部走这里。
  ///
  /// 修复「搜索提交不跳转」：任何入口都归一为
  /// 1. 更新活动标签页 URL（同步地址栏 / 路由 UI）；
  /// 2. 通过 NavBus 驱动「当前活动 WebView 实例」真正加载；
  /// 3. 若 WebView 尚未创建（新标签页首跳），由 WebViewContainer
  ///    以 initialUrl 新建并加载，pendingUrl 机制兜底。
  ///
  /// 修复「前进/后退一级页面失效」：不再手动重置导航状态，
  /// 完全由 WebView 回调 (onUpdateVisitedHistory / onLoadStop) 驱动。
  Future<void> _navigateTo(String input) async {
    final settings = context.read<SettingsProvider>();
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    // 判断输入是否为搜索词（非 URL）
    final isUrl = trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        (trimmed.contains('.') && !trimmed.contains(' '));

    // Yanler Search 引擎 + 搜索词 → 打开聚合搜索结果页
    if (!isUrl && settings.searchEngine == 'Yanler Search') {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => SearchResultsPage(query: trimmed),
        ),
      );
      // 用户点击结果项后返回 URL，继续导航
      if (result != null && result.isNotEmpty && mounted) {
        final browser = context.read<BrowserProvider>();
        if (browser.activeTabIndex >= 0) {
          browser.updateTabUrl(browser.activeTabIndex, result);
        }
        final controller = NavBus.active;
        if (controller != null) {
          await controller.loadUrl(result);
        }
      }
      return;
    }

    final url = SearchService.normalizeInput(trimmed, settings.searchEngine);
    if (url.isEmpty) return;

    final browser = context.read<BrowserProvider>();
    if (browser.activeTabIndex >= 0) {
      browser.updateTabUrl(browser.activeTabIndex, url);
    }

    // WebView 已存在时直接驱动加载；不存在时由 initialUrl 新建
    final controller = NavBus.active;
    if (controller != null) {
      await controller.loadUrl(url);
    }
  }

  /// 刷新/停止 — 加载中停止，否则刷新
  void _onRefreshPressed() {
    final container = NavBus.active;
    if (container == null) return;
    final activeTab = context.read<BrowserProvider>().activeTab;
    if (activeTab?.isLoading == true) {
      container.stopLoading();
    } else {
      container.reload();
    }
  }

  /// 后退：调用当前活动 WebView 原生 goBack，容器内部自动刷新按钮可用状态
  Future<void> _goBack() async {
    final controller = NavBus.active;
    if (controller == null) return;
    await controller.goBack();
  }

  /// 前进：调用当前活动 WebView 原生 goForward，容器内部自动刷新按钮可用状态
  Future<void> _goForward() async {
    final controller = NavBus.active;
    if (controller == null) return;
    await controller.goForward();
  }

  /// 构建单个标签页的内容（IndexedStack 子项）。
  ///
  /// - 空 URL → 新标签页；
  /// - 有 URL → WebViewContainer，仅活动标签传 isActive=true（注册 NavBus、上报导航状态）。
  /// 所有回调都绑定各自标签的 index，后台标签的回调不会覆盖活动标签的按钮/进度状态。
  Widget _buildTabBody(BuildContext context, int index, BrowserProvider browser) {
    final tab = browser.tabs[index];
    if (tab.url.isEmpty) {
      return NewTabPage(onSearch: _navigateTo);
    }
    return WebViewContainer(
      key: ValueKey(tab.id),
      tabId: tab.id,
      isActive: index == browser.activeTabIndex,
      initialUrl: tab.url,
      onUrlChanged: (url) {
        browser.updateTabUrl(index, url);
      },
      onTitleChanged: (title) {
        if (index < 0 || index >= browser.tabs.length) return;
        browser.updateTabTitle(index, title);
        // 记录历史（Firefox/Chrome 同款行为）
        final url = browser.tabs[index].url;
        if (url.isNotEmpty) {
          context.read<HistoryService>().add(title, url);
        }
      },
      onLoadingChanged: (loading) {
        browser.setTabLoading(index, loading);
      },
      onProgressChanged: (progress) {
        // 仅活动标签驱动地址栏进度条
        if (index == browser.activeTabIndex) {
          _onProgressChanged(progress);
        }
      },
      onNavigationStateChanged: (canBack, canFwd) {
        // 仅活动标签更新按钮状态（WebViewContainer 内部也已按 isActive 过滤）
        if (index == browser.activeTabIndex && mounted) {
          setState(() {
            _canGoBack = canBack;
            _canGoForward = canFwd;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrowserProvider, SettingsProvider>(
      builder: (context, browser, settings, _) {
        final isOnNewTab = browser.activeTab?.url.isEmpty ?? true;
        // 仅监听 blockedCount 变化，避免广告拦截内部状态变更导致整棵树重建
        final adblockCount = context.select<AdblockEngine, int>((e) => e.blockedCount);
        final aiActive = context.select<AIProvider, bool>((p) => p.agentMode);

        // 活动标签切换时：重置按钮/进度状态，避免残留上一标签的旧状态
        if (browser.activeTabIndex != _lastActiveIndex) {
          _lastActiveIndex = browser.activeTabIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _canGoBack = false;
                _canGoForward = false;
                _progress = 0.0;
              });
            }
          });
        }

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
                    onSubmitted: _navigateTo,
                  ),

                // 页面内容：IndexedStack 保活所有标签页的 WebView。
                // 切标签不再销毁重建（解决卡顿），WebView 历史栈完整保留（修复前后回退）。
                // 后台标签不注册 NavBus、不上报导航状态（WebViewContainer.isActive 控制）。
                Expanded(
                  child: browser.tabs.isEmpty
                      ? const SizedBox.shrink()
                      : IndexedStack(
                          index: browser.activeTabIndex
                              .clamp(0, browser.tabs.length - 1),
                          children: [
                            // KeyedSubtree 按标签 ID 复用元素：关闭中间标签时，
                            // 后续标签的 WebView 跟随移动而不是被销毁重建
                            for (var i = 0; i < browser.tabs.length; i++)
                              KeyedSubtree(
                                key: ValueKey(browser.tabs[i].id),
                                child: _buildTabBody(context, i, browser),
                              ),
                          ],
                        ),
                ),

                // 底部栏
                BottomBar(
                  tabCount: browser.tabCount,
                  isIncognito: browser.isIncognitoMode,
                  canGoBack: _canGoBack,
                  canGoForward: _canGoForward,
                  adBlockCount: adblockCount,
                  aiActive: aiActive,
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
    // 回到新标签页（WebViewContainer 随之销毁，NavBus 自动注销）
    final activeIndex = browser.activeTabIndex;
    if (activeIndex >= 0) {
      browser.updateTabUrl(activeIndex, '');
    }
    setState(() {
      _canGoBack = false;
      _canGoForward = false;
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
          // 不关闭菜单，允许用户连续操作
        },
        onOpenSettings: () {
          Navigator.pop(context);
          _openSettings(context);
        },
        onToggleIncognito: () {
          context.read<BrowserProvider>().toggleIncognito();
          // 不关闭菜单，允许用户连续操作
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
