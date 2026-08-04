import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/yanler_surface.dart';
import '../../providers/ai_provider.dart';
import '../../providers/browser_provider.dart';
import '../../providers/settings_provider.dart';
import '../agent_bridge/browser_tools.dart';
import '../bookmarks/bookmark_service.dart';
import '../history/history_service.dart';
import 'ai_config_sheet.dart';
import 'agent_commands.dart';
import 'web_automation.dart';

/// AI 助手顶部栏 — 半屏面板与全屏页共用（保留原有外观）。
///
/// - 左：半屏显示关闭(X)，全屏显示返回箭头；
/// - 中：星形图标 + 「AI 助手」+ Agent 徽章（可点切换 Agent 模式）；
/// - 右：历史 / 配置 / 全屏⇄半屏 切换。
class AiAssistantHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onHistory;
  final VoidCallback? onConfig;
  final bool agentMode;
  final VoidCallback? onToggleAgent;

  const AiAssistantHeader({
    super.key,
    this.onBack,
    this.isFullscreen = false,
    this.onToggleFullscreen,
    this.onHistory,
    this.onConfig,
    this.agentMode = false,
    this.onToggleAgent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: IconButton(
            icon: Icon(
              isFullscreen
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.close_rounded,
              size: 20,
            ),
            tooltip: isFullscreen ? '返回' : '关闭',
            onPressed: onBack,
          ),
        ),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFF3A5CCC),
                ),
                const SizedBox(width: 8),
                const Text('AI 助手'),
                if (agentMode)
                  GestureDetector(
                    onTap: onToggleAgent,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3A5CCC), Color(0xFF2F9E8F)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Agent',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.history_rounded, size: 20),
          tooltip: '聊天历史',
          onPressed: onHistory,
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
          tooltip: 'API 配置',
          onPressed: onConfig,
        ),
        IconButton(
          icon: Icon(
            isFullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            size: 20,
          ),
          tooltip: isFullscreen ? '切换半屏' : '切换全屏',
          onPressed: onToggleFullscreen,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// 固定高度 SliverPersistentHeader delegate — 用于让面板的
/// 拖拽条 + 顶部栏既固定在滚动体顶部、又参与 DraggableScrollableSheet 拖拽。
class AiFixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double extent;
  const AiFixedHeaderDelegate({required this.child, required this.extent});

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(AiFixedHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.extent != extent;
}

/// AI 助手共享主体 — 提示卡片 / 消息列表 / 空态 / Agent 日志 / 待批准命令 / 输入栏。
///
/// 半屏面板与全屏页共用同一组件与状态（状态在 [AIProvider]），切换形态对话不丢失。
///
/// [scrollController]：半屏面板传入 DraggableScrollableSheet 的滚动控制器，
/// 使消息列表与面板拖拽联动；全屏页不传则自建。
/// [headerSliver]：面板传入顶部拖拽条 + [AiAssistantHeader]（放滚动体内 pin 顶部）；
/// 全屏页的顶部栏由外层 AppBar 提供，不传。
/// [headerExtent]：头部 sliver 高度（含状态栏避让），与 [headerSliver] 实际高度一致。
class AiAssistantView extends StatefulWidget {
  final ScrollController? scrollController;
  final Widget? headerSliver;
  final bool autoFocus;
  final double headerExtent;

  const AiAssistantView({
    super.key,
    this.scrollController,
    this.headerSliver,
    this.autoFocus = false,
    this.headerExtent = 70,
  });

  @override
  State<AiAssistantView> createState() => _AiAssistantViewState();
}

class _AiAssistantViewState extends State<AiAssistantView> {
  late final ScrollController _scrollController;
  final FocusNode _inputFocusNode = FocusNode();

  // 消息数变化时自动吸底；首帧强制到底，之后仅靠近底部时跟随
  int _lastMessageCount = 0;
  bool _didInitialScroll = false;

  /// 首页态「已配置」说明卡是否已被用户点「知道了」收起
  bool _configuredTipDismissed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    // 注入浏览器工具集与授权确认回调（Agent 工具循环用）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ai = context.read<AIProvider>();
      ai.browserTools = BrowserTools(
        browser: context.read<BrowserProvider>(),
        settings: context.read<SettingsProvider>(),
        bookmarks: context.read<BookmarkService>(),
        history: context.read<HistoryService>(),
      );
      ai.authorizeRequest = (desc) =>
          _confirmCommand('允许 AI 执行此操作？\n\n$desc');
      if (widget.autoFocus) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final ai = context.read<AIProvider>();
    final text = ai.inputController.text.trim();
    if (text.isEmpty) return;

    ai.inputController.clear();
    ai.setPendingCommands([]);
    _scrollToBottom();

    final reply = await ai.sendMessage(text);
    if (!mounted) return;

    // 工具循环模式：模型直接 function calling（授权已在循环内弹框），无需命令面板；
    // 非工具循环模式：保留文本命令解析作为兼容
    if (ai.agentMode && ai.browserTools != null) return;

    ai.setPendingCommands(ai.extractCommands(reply));
    _scrollToBottom();
  }

  // ==================== Agent 命令执行（用户拥有最高控制权） ====================

  Future<bool> _confirmCommand(String desc) async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI 请求执行操作'),
        content: Text(desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('允许'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _executeCommand(String cmd) async {
    await executeAgentCommand(
      context,
      cmd,
      confirm: _confirmCommand,
      toast: _toast,
    );
  }

  Future<void> _executePendingCommands() async {
    final ai = context.read<AIProvider>();
    final cmds = List.of(ai.pendingCommands);
    ai.setPendingCommands([]);
    final countBefore = ai.messages.length;
    for (final c in cmds) {
      await _executeCommand(c);
    }
    // 网页操控命令会回传真实结果让 AI 继续决策，提取下一轮命令
    if (mounted && ai.messages.length > countBefore) {
      final latest = ai.messages.last['content'] ?? '';
      ai.setPendingCommands(ai.extractCommands(latest));
    }
    _scrollToBottom();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfig() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AIConfigSheet(),
    );
  }

  // ==================== 「总结 / 翻译」快捷操作 ====================

  /// 提取当前页正文 → 拼接 prompt → 调 AI（走普通补全，不受 Agent 模式影响）。
  /// AI 未配置时直接弹出配置页。
  Future<void> _runPageAction(String action) async {
    final ai = context.read<AIProvider>();
    if (!ai.isConfigured) {
      _showConfig();
      return;
    }
    final browser = context.read<BrowserProvider>();
    final tab = browser.activeTab;
    final ctx = ai.pageContext;
    final title = (ctx['title']?.isNotEmpty ?? false)
        ? ctx['title']!
        : ((tab?.title.isNotEmpty ?? false) ? tab!.title : '当前网页');
    final url = (ctx['url']?.isNotEmpty ?? false) ? ctx['url']! : tab?.url ?? '';
    final text = (await WebAutomation.getPageText())?.trim() ?? '';
    final body = text.length > 12000 ? text.substring(0, 12000) : text;
    if (body.isEmpty) {
      _toast('未能读取到当前网页内容');
      return;
    }
    final where = title + (url.isNotEmpty ? '（$url）' : '');
    final prompt = action == 'summarize'
        ? '请用简洁的中文总结以下网页（$where）的核心内容，分点列出重点，最后给一句话结论：\n\n$body'
        : '请把以下网页（$where）的内容翻译成通顺的中文，保留关键信息与专有名词：\n\n$body';
    ai.sendPageTask(prompt);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctxHost = ai.pageContext['host'] ?? '';

    // 新消息到达：首帧强制吸底，之后仅在接近底部时跟随，不打断阅读历史
    if (ai.messages.length != _lastMessageCount) {
      _lastMessageCount = ai.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final pos = _scrollController.position;
        if (!_didInitialScroll) {
          _didInitialScroll = true;
          _scrollController.jumpTo(pos.maxScrollExtent);
        } else if (pos.maxScrollExtent - pos.pixels < 120) {
          _scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 面板：拖拽条 + 顶部栏（pinned，可拖动面板）；全屏页不传
              if (widget.headerSliver != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: AiFixedHeaderDelegate(
                    child: widget.headerSliver!,
                    extent: widget.headerExtent,
                  ),
                ),

              // —— 首页态：上下文头部 + 快捷操作 + 信息卡片 ——
              if (ai.messages.isEmpty) ...[
                // 当前网页上下文头部（favicon / 标题 / 域名）
                if (ctxHost.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _AiContextHeader(meta: ai.pageContext),
                  ),
                // 快捷操作：总结 / 翻译
                if (ctxHost.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _AiQuickActions(
                      onSummarize: () => _runPageAction('summarize'),
                      onTranslate: () => _runPageAction('translate'),
                    ),
                  ),
                // 信息卡片：未配置 → 去配置；已配置 → 说明 + 知道了
                if (!ai.isConfigured)
                  SliverToBoxAdapter(child: _AiTipCard(onConfig: _showConfig))
                else if (!_configuredTipDismissed)
                  SliverToBoxAdapter(
                    child: _AiConfiguredCard(
                      onDismiss: () => setState(
                        () => _configuredTipDismissed = true,
                      ),
                    ),
                  ),
                // 空态（有网页上下文时给一句轻提示，无则展示完整空态）
                if (ctxHost.isNotEmpty)
                  const SliverToBoxAdapter(child: _AiHomeHint())
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: _AiEmptyChat(agentMode: ai.agentMode),
                    ),
                  ),
              ]
              // —— 对话态：消息列表 ——
              else ...[
                // 未配置时仍保留去配置提示条（随时可配置）
                if (!ai.isConfigured)
                  SliverToBoxAdapter(child: _AiTipCard(onConfig: _showConfig)),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final msg = ai.messages[index];
                      return _AiChatBubble(
                        text: msg['content'] ?? '',
                        isUser: msg['role'] == 'user',
                      );
                    },
                    childCount: ai.messages.length,
                  ),
                ),
              ],

              // Agent 操作日志（同步展示 AI 正在执行的步骤）
              if (ai.agentLog.isNotEmpty)
                SliverToBoxAdapter(
                  child: _AiAgentLogPanel(
                    log: ai.agentLog,
                    processing: ai.isProcessing,
                    isDark: isDark,
                  ),
                ),

              // 待批准命令面板（Agent 操作需用户批准）
              if (ai.pendingCommands.isNotEmpty)
                SliverToBoxAdapter(
                  child: _AiPendingCommandsPanel(
                    commands: ai.pendingCommands,
                    isDark: isDark,
                    onIgnore: () => ai.setPendingCommands([]),
                    onApprove: _executePendingCommands,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        ),

        // 输入区（固定底部，键盘弹出时随面板自然上移）
        _AiInputBar(
          ai: ai,
          controller: ai.inputController,
          focusNode: _inputFocusNode,
          onSend: _send,
          onStop: () => ai.stopGenerating(),
        ),
      ],
    );
  }
}

// ==================== 子组件 ====================

/// 未配置 AI 服务提示条
class _AiTipCard extends StatelessWidget {
  final VoidCallback onConfig;

  const _AiTipCard({required this.onConfig});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFE65100)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '尚未配置 AI 服务',
              style: TextStyle(fontSize: 12.5, color: Color(0xFFBF360C)),
            ),
          ),
          TextButton(
            onPressed: onConfig,
            child: const Text('去配置', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// 空态
class _AiEmptyChat extends StatelessWidget {
  final bool agentMode;

  const _AiEmptyChat({required this.agentMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A5CCC), Color(0xFF2F9E8F)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3A5CCC).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            agentMode ? 'AI Agent 模式已开启' : '你好，我是 Yanler AI 助手',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              agentMode
                  ? '你可以让我搜索、打开网页、管理书签和标签。所有浏览器操作都会先征求你的批准。'
                  : '有问题随时问我。在右上角开启 Agent 模式后，我还能帮你操作浏览器。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前网页上下文头部 — favicon + 页面标题 + 域名
class _AiContextHeader extends StatelessWidget {
  final Map<String, String> meta;

  const _AiContextHeader({required this.meta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = meta['host'] ?? '';
    final title = meta['title'] ?? '';
    var favicon = meta['favicon'] ?? '';
    if (favicon.isEmpty && host.isNotEmpty) favicon = 'https://$host/favicon.ico';
    final showFavicon = favicon.isNotEmpty && !favicon.startsWith('data:');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 36,
              height: 36,
              child: showFavicon
                  ? Image.network(
                      favicon,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _FaviconFallback(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const _FaviconFallback();
                      },
                    )
                  : const _FaviconFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? host : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (host.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// favicon 加载失败 / 缺省时的地球占位
class _FaviconFallback extends StatelessWidget {
  const _FaviconFallback();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.public_rounded,
        size: 18,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// 快捷操作：并排「总结 / 翻译」大圆角按钮
class _AiQuickActions extends StatelessWidget {
  final VoidCallback onSummarize;
  final VoidCallback onTranslate;

  const _AiQuickActions({
    required this.onSummarize,
    required this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.subject_rounded,
              label: '总结',
              onTap: onSummarize,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.translate_rounded,
              label: '翻译',
              onTap: onTranslate,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 19, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页态「已配置」说明卡 — 深色「知道了」按钮
class _AiConfiguredCard extends StatelessWidget {
  final VoidCallback onDismiss;

  const _AiConfiguredCard({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yanler AI 已就绪',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '点「总结」快速提炼当前网页，点「翻译」把网页译成中文；也可以在下方直接提问。开启 Agent 模式后，我还能帮你操作浏览器。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFFE8E6E1)
                    : const Color(0xFF2B2B31),
                foregroundColor:
                    isDark ? const Color(0xFF1A1B1E) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onDismiss,
              child: const Text('知道了', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 有网页上下文时首页态的一句轻提示
class _AiHomeHint extends StatelessWidget {
  const _AiHomeHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        '选中当前网页，随时提问。开启 Agent 模式后，我还能帮你操作浏览器。',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 消息气泡
class _AiChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _AiChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A5CCC), Color(0xFF2F9E8F)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, height: 1.5, color: Colors.white),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: SelectableText(
          text,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

/// Agent 操作日志面板 — 以消息流形式同步展示 AI 正在执行的步骤
class _AiAgentLogPanel extends StatelessWidget {
  final List<String> log;
  final bool processing;
  final bool isDark;

  const _AiAgentLogPanel({
    required this.log,
    required this.processing,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (processing)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(Icons.bolt_rounded, size: 15, color: color),
              const SizedBox(width: 8),
              Text(
                'Agent 操作',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${log.length} 步',
                style: TextStyle(
                  fontSize: 10.5,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...log.take(3).map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• $line',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 待批准命令面板
class _AiPendingCommandsPanel extends StatelessWidget {
  final List<String> commands;
  final bool isDark;
  final VoidCallback onIgnore;
  final VoidCallback onApprove;

  const _AiPendingCommandsPanel({
    required this.commands,
    required this.isDark,
    required this.onIgnore,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF212226).withValues(alpha: 0.95)
            : const Color(0xFFF0EDE9).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                size: 15,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AI 请求执行 ${commands.length} 项操作，是否批准？',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...commands.take(3).map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onIgnore,
                child: const Text('忽略'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3A5CCC),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: onApprove,
                child: const Text('批准执行'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 输入区 — 实色输入框 + 发送/停止按钮
class _AiInputBar extends StatelessWidget {
  final AIProvider ai;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _AiInputBar({
    required this.ai,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: YanlerSurface(
                borderRadius: BorderRadius.circular(24),
                elevated: false,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: ai.agentMode ? '输入指令，AI 可帮你操作浏览器' : '输入问题…',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.55),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => ai.isProcessing ? onStop() : onSend(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => ai.isProcessing ? onStop() : onSend(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: ai.isProcessing
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF3A5CCC), Color(0xFF2F9E8F)],
                        ),
                  color: ai.isProcessing ? const Color(0xFFE5484D) : null,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (ai.isProcessing ? const Color(0xFFE5484D) : const Color(0xFF3A5CCC))
                          .withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  ai.isProcessing ? Icons.stop_rounded : Icons.send_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 会话历史弹层（实色，与旧版一致）
void showAiHistorySheet(BuildContext context, AIProvider ai) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => YanlerSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      elevated: false,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                child: Row(
                  children: [
                    Text(
                      '聊天历史',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('新建会话'),
                      onPressed: () {
                        ai.newChat();
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ai.sessions.isEmpty
                    ? Center(
                        child: Text(
                          '暂无历史会话',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                        itemCount: ai.sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final s = ai.sessions[index];
                          final isActive = ai.activeSession?.id == s.id;
                          return YanlerSurface(
                            borderRadius: BorderRadius.circular(14),
                            elevated: false,
                            tint: isActive
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${s.messages.length ~/ 2} 轮对话',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                onPressed: () => ai.deleteSession(s.id),
                              ),
                              onTap: () {
                                ai.openSession(s.id);
                                Navigator.pop(sheetContext);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
