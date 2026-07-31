import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../providers/ai_provider.dart';
import '../../providers/browser_provider.dart';
import '../../providers/settings_provider.dart';
import '../agent_bridge/agent_engine.dart';
import '../agent_bridge/browser_tools.dart';
import '../bookmarks/bookmark_service.dart';
import '../history/history_service.dart';
import 'ai_config_sheet.dart';
import 'agent_commands.dart';

/// AI 聊天界面 — 会话历史持久化、可中止生成、Agent 命令经用户确认后执行
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  // AI 回复中的待执行命令（等待用户批准）
  List<String> _pendingCommands = [];

  @override
  void initState() {
    super.initState();
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
      ai.authorizeRequest = (desc) => _confirmCommand('允许 AI 执行此操作？\n\n$desc');
      // 自动聚焦输入框并唤起键盘
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final ai = context.read<AIProvider>();
    _inputController.clear();
    _pendingCommands = [];
    _scrollToBottom();

    final reply = await ai.sendMessage(text);
    if (!mounted) return;

    // 工具循环模式：模型直接 function calling（授权已在循环内弹框），无需命令面板；
    // 非工具循环模式：保留文本命令解析作为兼容
    if (ai.agentMode && ai.browserTools != null) return;

    // 解析 Agent 命令，等待用户批准
    final commands = ai.extractCommands(reply);
    setState(() => _pendingCommands = commands);
    _scrollToBottom();
  }

  // ==================== Agent 命令执行（用户拥有最高控制权） ====================

  /// 每个命令执行前弹确认框
  Future<bool> _confirmCommand(String desc) async {
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

  /// 执行 Agent 命令（与首页搜索框直达模式共用同一套执行器）
  Future<void> _executeCommand(String cmd) async {
    await executeAgentCommand(
      context,
      cmd,
      confirm: _confirmCommand,
      toast: _toast,
    );
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

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF8B5CFF)),
            const SizedBox(width: 8),
            const Text('AI 助手'),
            if (ai.agentMode)
              GestureDetector(
                onTap: () => ai.toggleAgentMode(),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Agent',
                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          // 历史会话
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 20),
            tooltip: '聊天历史',
            onPressed: () => _showHistorySheet(context, ai),
          ),
          // 配置
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'API 配置',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const AIConfigSheet(),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 未配置提示条
          if (!ai.isConfigured)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.5)),
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
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const AIConfigSheet(),
                    ),
                    child: const Text('去配置', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: ai.messages.isEmpty
                ? _EmptyChat(agentMode: ai.agentMode)
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    itemCount: ai.messages.length,
                    itemBuilder: (context, index) {
                      final msg = ai.messages[ai.messages.length - 1 - index];
                      return _ChatBubble(
                        text: msg['content'] ?? '',
                        isUser: msg['role'] == 'user',
                      );
                    },
                  ),
          ),

          // Agent 执行状态条（工具循环进行中）
          if (ai.isProcessing && ai.currentStep != null)
            _AgentStatusBar(step: ai.currentStep!, isDark: isDark),

          // 待执行命令面板（Agent 操作需用户批准）
          if (_pendingCommands.isNotEmpty)
            Container(
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
                          'AI 请求执行 ${_pendingCommands.length} 项操作，是否批准？',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._pendingCommands.take(3).map(
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
                        onPressed: () => setState(() => _pendingCommands = []),
                        child: const Text('忽略'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5B7FFF),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        onPressed: () async {
                          final cmds = List.of(_pendingCommands);
                          setState(() => _pendingCommands = []);
                          final msgCountBefore = ai.messages.length;
                          for (final c in cmds) {
                            await _executeCommand(c);
                          }
                          // 网页操控命令会回传真实结果让 AI 继续决策；
                          // 仅在 AI 产出了新回复时提取下一轮命令，等待用户再次批准。
                          if (mounted && ai.messages.length > msgCountBefore) {
                            final latest = ai.messages.last['content'] ?? '';
                            final newCmds = ai.extractCommands(latest);
                            setState(() => _pendingCommands = newCmds);
                          }
                          _scrollToBottom();
                        },
                        child: const Text('批准执行'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 输入区
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: LiquidGlass(
                      borderRadius: BorderRadius.circular(24),
                      blur: 22,
                      opacity: isDark ? 0.3 : 0.36,
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: ai.agentMode ? '输入指令，AI 可帮你操作浏览器' : '输入问题…',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => ai.isProcessing ? ai.stopGenerating() : _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 发送 / 停止（停止指令优先级最高）
                  GestureDetector(
                    onTap: () => ai.isProcessing ? ai.stopGenerating() : _send(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: ai.isProcessing
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
                              ),
                        color: ai.isProcessing ? const Color(0xFFE5484D) : null,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: (ai.isProcessing ? const Color(0xFFE5484D) : const Color(0xFF8B5CFF))
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
          ),
        ],
      ),
    );
  }

  void _showHistorySheet(BuildContext context, AIProvider ai) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LiquidGlass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 28,
        opacity: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.45,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                  child: Row(
                    children: [
                      Text(
                        '聊天历史',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
                            return LiquidGlass(
                              borderRadius: BorderRadius.circular(14),
                              blur: 12,
                              opacity: isActive ? 0.6 : 0.4,
                              tint: isActive ? Theme.of(context).colorScheme.primary : null,
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  '${s.messages.length ~/ 2} 轮对话',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
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
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

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
              colors: [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
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

class _EmptyChat extends StatelessWidget {
  final bool agentMode;

  const _EmptyChat({required this.agentMode});

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
                colors: [Color(0xFF5B7FFF), Color(0xFF8B5CFF), Color(0xFFFF5C7B)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CFF).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 28, color: Colors.white),
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
              style: TextStyle(fontSize: 12.5, height: 1.6, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Agent 工具循环状态条（思考中 / 正在执行工具）
class _AgentStatusBar extends StatelessWidget {
  final AgentStep step;
  final bool isDark;

  const _AgentStatusBar({required this.step, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final thinking = step.phase == 'thinking';
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (thinking)
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(Icons.bolt_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              thinking
                  ? 'AI 正在思考…'
                  : '正在执行：${step.toolName}',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
