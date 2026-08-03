import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/nav_bus.dart';
import '../../../providers/browser_provider.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../search/search_service.dart';
import '../../search/instant_answer.dart';
import '../../search/instant_answer_page.dart';
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
import '../../../core/widgets/yanler_surface.dart';

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

  /// 标签切换重置是否已调度 — 防止同一帧内连续 build 重复注册 postFrameCallback
  bool _tabResetScheduled = false;

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

    // Yanler Search：本地即时答案（计算/时间/农历/诗词），无命中则直接 Bing 兜底。
    // 完全本地、免 VPN、免 AI，聚合搜索已废弃。
    if (!isUrl && settings.searchEngine == 'Yanler Search') {
      final answer = InstantAnswerService.tryAnswer(trimmed);
      if (answer != null) {
        // 命中即时答案 → 展示答案卡片，可在页内「用 Bing 继续搜索」
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => InstantAnswerPage(query: trimmed, answer: answer),
          ),
        );
        if (result != null && result.isNotEmpty && mounted) {
          final browser = context.read<BrowserProvider>();
          // 用户在答案页停留期间可能已关闭标签，防御
          if (browser.activeTab == null) return;
          if (browser.activeTabIndex >= 0) {
            browser.updateTabUrl(browser.activeTabIndex, result);
          }
          final controller = NavBus.active;
          if (controller != null) {
            await controller.loadUrl(result);
          }
        }
      } else {
        // 通用词 → 直接打开 Bing（免 VPN 可用），不进中间页
        final bingUrl = InstantAnswerPage.bingUrlFor(trimmed);
        final browser = context.read<BrowserProvider>();
        if (browser.activeTabIndex >= 0) {
          browser.updateTabUrl(browser.activeTabIndex, bingUrl);
        }
        final controller = NavBus.active;
        if (controller != null) {
          await controller.loadUrl(bingUrl);
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

  /// 后退：有历史时走 WebView 原生 goBack；一级页面（无历史）时回到新标签页，
  /// 保证后退按钮始终可用（浏览器惯例：后退到底 = 回首页）。
  Future<void> _goBack() async {
    final controller = NavBus.active;
    if (_canGoBack && controller != null) {
      await controller.goBack();
      return;
    }
    final browser = context.read<BrowserProvider>();
    _goHome(browser);
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
      // 弹窗/新窗口（合法且带手势）→ 应用内开新标签
      onOpenInNewTab: (url) {
        if (url.isNotEmpty) {
          context.read<BrowserProvider>().addTab(url: url);
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

        // 活动标签切换时：重置按钮/进度状态，避免残留上一标签的旧状态。
        // 用一次性标志去重：同一帧内连续 build 只注册一个回调，防竞态崩溃。
        if (browser.activeTabIndex != _lastActiveIndex && !_tabResetScheduled) {
          _tabResetScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tabResetScheduled = false;
            if (mounted) {
              setState(() {
                _canGoBack = false;
                _canGoForward = false;
                _progress = 0.0;
              });
            }
            _lastActiveIndex = browser.activeTabIndex;
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // 内容层：地址栏 + 页面（新标签页壁纸 / WebView）。
              // 不再用外层 SafeArea 截断底部——壁纸容器延伸到屏幕最底端
              //（含系统导航栏下方），从根上消除「壁纸止步于底部栏顶部」的黑缝。
              Column(
                children: [
                  // 地址栏仅需顶部安全区（顶部圆角状态栏避让）
                  if (!isOnNewTab)
                    SafeArea(
                      bottom: false,
                      child: AddressBar(
                        url: browser.activeTab?.url ?? '',
                        isLoading: browser.activeTab?.isLoading ?? false,
                        progress: _progress,
                        onRefresh: _onRefreshPressed,
                        onSubmitted: _navigateTo,
                      ),
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
                ],
              ),

              // 悬浮底部栏：Overlay 叠加在壁纸/网页之上（更高 Z 层级）。
              // 底部栏顶部圆角与两侧透出的是壁纸本身，而非根布局黑底。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomBar(
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
              ),
            ],
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // 用 sheet 自身的 context watch：Provider 变化（深色/无痕/AI 开关、
      // 广告拦截计数）时弹窗内按钮高亮与计数实时刷新，而非打开瞬间的快照。
      builder: (sheetContext) {
        final settings = sheetContext.watch<SettingsProvider>();
        final browser = sheetContext.watch<BrowserProvider>();
        final ai = sheetContext.watch<AIProvider>();
        final adblock = sheetContext.watch<AdblockEngine>();
        final currentUrl = browser.activeTab?.url ?? '';

        return _BottomMenuSheet(
          adBlockCount: adblock.blockedCount,
          canBookmark: currentUrl.isNotEmpty,
          isDarkModeActive: settings.isDarkMode,
          isIncognitoActive: browser.isIncognitoMode,
          isAIActive: ai.agentMode,
          // 开关类操作不关闭菜单，允许用户连续操作；状态经 watch 实时回显
          onToggleTheme: () => settings.toggleTheme(),
          onOpenSettings: () {
            Navigator.pop(sheetContext);
            _openSettings(context);
          },
          onToggleIncognito: () => browser.toggleIncognito(),
          onToggleAI: () {
            Navigator.pop(sheetContext);
            _openAIChat(context);
          },
          onOpenBookmarks: () {
            Navigator.pop(sheetContext);
            _openBookmarks(context);
          },
          onOpenHistory: () {
            Navigator.pop(sheetContext);
            _openHistory(context);
          },
          onAddBookmark: () {
            final title = browser.activeTab?.title ?? '未命名';
            context.read<BookmarkService>().add(title, currentUrl);
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              const SnackBar(
                content: Text('已收藏到书签'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
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

    // 实色菜单面板
    return YanlerSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      elevated: false,
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

class _MenuButton extends StatefulWidget {
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
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  /// 按压态：按下缩至 0.92 + 透明度 0.8，松开 150ms easeOut 复原，
  /// 对应原生「轻触缩放 + 微震」反馈。
  ///
  /// 用 StatefulWidget 而非 StatelessWidget：状态切换（如点「深色」/「无痕」
  /// 触发父级重绘）时本 State 不重建，按压动画不被中断，丝滑收尾。
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.active;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _setPressed(true);
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
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
                  widget.icon,
                  size: 24,
                  color: active ? Colors.white : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active ? theme.colorScheme.primary : null,
                  fontWeight: active ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
