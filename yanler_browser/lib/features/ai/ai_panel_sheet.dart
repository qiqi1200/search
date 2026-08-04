import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_panel_controller.dart';
import '../../providers/ai_provider.dart';
import 'ai_assistant_view.dart';
import 'ai_config_sheet.dart';

/// AI 助手浮层面板 — 挂载在浏览器根部 Stack，位于 WebView / 底部栏之上。
///
/// 用 DraggableScrollableSheet 实现：
/// - 打开时从 min 0.3 起步，post-frame 以 220ms easeOutCubic 滑入到目标高度
///   （半屏 0.55 / 全屏 1.0）；纯位移、无透明度交叉淡化；
/// - min 0.3，max 1.0，snap [0.55, 1.0]；拖到 min 或点关闭 → 下滑收起；
/// - 半屏时上方网页区域保持可见且可触摸，Agent 模式下用户可实时观察网页操作；
/// - 全屏⇄半屏由 [DraggableScrollableController] 动画切换，
///   拖拽横条 / Header 在滚动体内 pin 顶部，可自由拖拽。
class AiPanelSheet extends StatefulWidget {
  const AiPanelSheet({super.key});

  @override
  State<AiPanelSheet> createState() => _AiPanelSheetState();
}

class _AiPanelSheetState extends State<AiPanelSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  /// 面板形态切换 / 滑入动画时长与曲线 — 纯位移、无透明度交叉淡化
  static const Duration _animateMs = Duration(milliseconds: 220);
  static const Curve _animateCurve = Curves.easeOutCubic;

  /// 程序化动画进行中 — 期间拖拽同步停止，避免动画与用户手势互相覆盖
  bool _animating = false;

  /// 抑制模式监听 — 拖拽同步时置位，防止同步又触发 animateTo 形成循环
  bool _suppressModeListener = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
    context.read<AiPanelController>().addListener(_onModeChanged);
    // 首帧对齐（打开时 initialChildSize 已按模式设置，这里仅兜底）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onModeChanged();
    });
  }

  @override
  void dispose() {
    context.read<AiPanelController>().removeListener(_onModeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  /// 拖拽/动画过程中尺寸变化 → 同步模式（供图标、状态栏避让、入口判断）
  void _onSheetSizeChanged() {
    if (_animating || !_sheetController.isAttached) return;
    final panel = context.read<AiPanelController>();
    if (panel.mode == AiPanelMode.hidden) return;
    // 拖拽下拉到最小高度 → 收起（纯位移下滑，无交叉淡化）
    if (_sheetController.size <= 0.31) {
      panel.hide();
      return;
    }
    final target = _sheetController.size >= 0.85
        ? AiPanelMode.full
        : AiPanelMode.half;
    if (target == panel.mode) return;
    _suppressModeListener = true;
    panel.setMode(target);
    _suppressModeListener = false;
  }

  /// 模式变化（入口切换 / Header 按钮 / 打开）→ 驱动尺寸动画
  void _onModeChanged() {
    if (_suppressModeListener || _animating || !mounted) return;
    final panel = context.read<AiPanelController>();
    if (panel.mode == AiPanelMode.hidden) return;
    final target = panel.mode == AiPanelMode.full ? 1.0 : 0.55;
    if (!_sheetController.isAttached) return;
    if ((target - _sheetController.size).abs() <= 0.03) return;
    _animating = true;
    _sheetController
        .animateTo(
          target,
          duration: _animateMs,
          curve: _animateCurve,
        )
        .whenComplete(() => _animating = false);
  }

  /// 全屏⇄半屏切换按钮
  void _toggleFullscreen() {
    if (!_sheetController.isAttached) return;
    final target =
        _sheetController.size >= 0.85 ? AiPanelMode.half : AiPanelMode.full;
    // 直接驱动尺寸动画，并把模式对齐（供外部消费）
    _animating = true;
    _sheetController
        .animateTo(
          target == AiPanelMode.full ? 1.0 : 0.55,
          duration: _animateMs,
          curve: _animateCurve,
        )
        .whenComplete(() => _animating = false);
    context.read<AiPanelController>().setMode(target);
  }

  /// 收起：先 220ms 下滑到最小高度（纯位移），再真正隐藏，避免「弹一下消失」。
  void _close() {
    if (!_sheetController.isAttached) {
      context.read<AiPanelController>().hide();
      return;
    }
    _animating = true;
    _sheetController
        .animateTo(
          0.3,
          duration: _animateMs,
          curve: _animateCurve,
        )
        .whenComplete(() {
      _animating = false;
      if (mounted) context.read<AiPanelController>().hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<AiPanelController>();
    final isFullscreen = panel.mode == AiPanelMode.full;
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    // 头部 sliver 高度 = 拖拽条(8+4+10) + Header(48) + 全屏时状态栏避让
    final headerExtent = 70.0 + (isFullscreen ? topPad : 0.0);

    return DraggableScrollableSheet(
      controller: _sheetController,
      // 首帧从 min 高度起步，post-frame 由 _onModeChanged 动画滑入到目标高度，
      // 实现「底部抽屉从下方快速滑入」；之后半屏/全屏切换也走同一控制器动画。
      initialChildSize: 0.3,
      minChildSize: 0.3,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.55, 1.0],
      builder: (context, sheetScrollController) {
        return DraggableScrollableActuator(
          child: Container(
            clipBehavior: Clip.antiAlias,
            // 沿用 AI 页深色/浅色底，~97% 不透明度；不用 BackdropFilter（安卓平台视图下不稳）
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: AiAssistantView(
              scrollController: sheetScrollController,
              autoFocus: isFullscreen,
              headerExtent: headerExtent,
              headerSliver: Column(
                children: [
                  if (isFullscreen) SizedBox(height: topPad),
                  const SizedBox(height: 8),
                  // 拖拽横条 — 与现有菜单面板一致
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AiAssistantHeader(
                    onBack: _close,
                    isFullscreen: isFullscreen,
                    onToggleFullscreen: _toggleFullscreen,
                    onHistory: () =>
                        showAiHistorySheet(context, context.read<AIProvider>()),
                    onConfig: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const AIConfigSheet(),
                    ),
                    agentMode: context.watch<AIProvider>().agentMode,
                    onToggleAgent: () =>
                        context.read<AIProvider>().toggleAgentMode(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
