import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_panel_controller.dart';
import '../../providers/ai_provider.dart';
import 'ai_assistant_view.dart';
import 'ai_config_sheet.dart';

/// AI 聊天全屏页 — 由共享组件组装（保留原有全屏外观）。
///
/// 底部工具栏 AI 按钮在网页内默认打开半屏面板、首页默认全屏面板；
/// 「全屏形态」即面板 maxChildSize=1.0，由 [AiPanelSheet] 承载。
/// 本页保留作为「全屏形态」的独立载体，与面板共用
/// [AiAssistantView] / [AiAssistantHeader]，状态同存 [AIProvider]，切换形态对话不丢失。
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AiAssistantHeader(
              onBack: () => Navigator.pop(context),
              isFullscreen: true,
              onToggleFullscreen: () {
                // 切到半屏 → 打开根部浮层面板（本页实际不经路由使用）
                context.read<AiPanelController>().open(AiPanelMode.half);
              },
              onHistory: () => showAiHistorySheet(context, ai),
              onConfig: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AIConfigSheet(),
              ),
              agentMode: ai.agentMode,
              onToggleAgent: () => ai.toggleAgentMode(),
            ),
            const SizedBox(height: 4),
            const Expanded(
              child: AiAssistantView(autoFocus: true),
            ),
          ],
        ),
      ),
    );
  }
}
