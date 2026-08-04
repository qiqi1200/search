import 'package:flutter/foundation.dart';

/// AI 面板形态
enum AiPanelMode {
  /// 隐藏（未挂载，面板从根部 Stack 移除）
  hidden,

  /// 半屏（约 55% 高度，上方保留网页区域供观察 Agent 操作）
  half,

  /// 全屏（maxChildSize 1.0）
  full,
}

/// AI 助手浮层面板的全局状态。
///
/// 面板挂载在浏览器根部 Stack（位于 WebView / 底部栏之上），
/// 由 [BrowserScreen] 读取本状态决定是否挂载与初始尺寸；
/// [AiPanelSheet] 监听本状态驱动 DraggableScrollableSheet 的尺寸动画，
/// 保证切换标签/页面时面板不重建、对话状态不丢失。
class AiPanelController extends ChangeNotifier {
  AiPanelMode _mode = AiPanelMode.hidden;

  AiPanelMode get mode => _mode;
  bool get isVisible => _mode != AiPanelMode.hidden;
  bool get isFullscreen => _mode == AiPanelMode.full;

  void setMode(AiPanelMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// 打开面板（默认模式由调用方按入口规则决定）
  void open(AiPanelMode mode) => setMode(mode);

  /// 关闭面板
  void hide() => setMode(AiPanelMode.hidden);
}
