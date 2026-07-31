/// 浏览器控制器接口 — 由 WebViewContainerState 实现
///
/// 只暴露浏览器需要的几个导航动作，避免跨页面直接依赖 WebView 内部实现。
abstract class BrowserController {
  /// 用户意图加载 URL（WebView 未就绪时挂起，就绪后自动补载）
  Future<void> loadUrl(String url);

  /// 后退一页（完成后自动刷新按钮可用状态）
  Future<void> goBack();

  /// 前进一页（完成后自动刷新按钮可用状态）
  Future<void> goForward();

  /// 刷新前进/后退可用状态
  Future<void> refreshNavigationState();

  /// 停止加载
  Future<void> stopLoading();

  /// 重新加载当前页
  Future<void> reload();

  /// 在网页中执行 JS（AI Agent 网页操控用），返回结果字符串
  Future<String?> evaluateJavascript(String script);
}

/// 导航总线 — 当前活动标签页 WebView 容器的全局句柄
///
/// 用于跨页面（AI 聊天、书签/历史页）驱动浏览器加载，同时保证：
/// - 始终指向「当前活动 WebView 实例」，杜绝空实例或历史实例误用；
/// - 容器销毁时自动注销，防止悬挂引用调用到已废弃的 WebView。
class NavBus {
  NavBus._();

  static BrowserController? _active;

  /// 当前活动的 WebView 控制器（无 WebView 时（如新标签页）为 null）
  static BrowserController? get active => _active;

  /// 注册当前活动容器
  static void register(BrowserController controller) => _active = controller;

  /// 注销；仅当是当前活动实例时才清空，避免误清其他容器的注册
  static void unregister(BrowserController controller) {
    if (identical(_active, controller)) {
      _active = null;
    }
  }
}
