import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/nav_bus.dart';
import '../../../providers/settings_provider.dart';
import '../../adblock/adblock_engine.dart';

class WebViewContainer extends StatefulWidget {
  final String tabId;
  final String initialUrl;
  final Function(String) onUrlChanged;
  final Function(String) onTitleChanged;
  final Function(bool) onLoadingChanged;

  /// 加载进度回调（0.0-1.0），用于地址栏进度条
  final Function(double)? onProgressChanged;
  final Function(InAppWebViewController)? onControllerReady;
  final Function(bool canGoBack, bool canGoForward)? onNavigationStateChanged;

  const WebViewContainer({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onLoadingChanged,
    this.onControllerReady,
    this.onNavigationStateChanged,
    this.onProgressChanged,
  });

  @override
  State<WebViewContainer> createState() => WebViewContainerState();
}

/// WebView 容器 State — 对外暴露导航能力（通过 NavBus / GlobalKey 使用）
///
/// 设计要点（修复前进/后退与搜索跳转失效）：
/// 1. 所有导航动作只作用于本实例的真实控制器，杜绝外部持有过期引用；
/// 2. 用户意图 URL（loadUrl 在控制器就绪前被调用）挂起为 _pendingUrl，
///    onWebViewCreated 后自动补载——覆盖「新标签页→搜索首跳」场景；
/// 3. 不在 didUpdateWidget 自动重载（避免搜索重定向循环），
///    只由显式 loadUrl / 新建 initialUrl 驱动加载。
class WebViewContainerState extends State<WebViewContainer>
    implements BrowserController {
  InAppWebViewController? _controller;

  /// 挂起的用户意图 URL（控制器就绪前调用 loadUrl 时写入）
  String? _pendingUrl;

  /// 最近一次请求加载的 URL（防重复加载同一地址）
  String? _lastRequestedUrl;

  /// 当前 WebView 控制器（供刷新/停止等操作使用）
  InAppWebViewController? get controller => _controller;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl.isNotEmpty) {
      _lastRequestedUrl = widget.initialUrl;
    }
    NavBus.register(this);
  }

  @override
  void dispose() {
    NavBus.unregister(this);
    _controller = null;
    super.dispose();
  }

  // ==================== 对外导航 API ====================

  /// 用户意图加载 URL。
  /// - 控制器已就绪：立即加载；
  /// - 未就绪（新建 WebView 尚未回调）：挂起，onWebViewCreated 后自动补载。
  @override
  Future<void> loadUrl(String url) async {
    if (url.isEmpty) return;
    final c = _controller;
    if (c == null) {
      _pendingUrl = url;
      return;
    }
    await _doLoad(c, url);
  }

  /// 后退一页，完成后刷新按钮可用状态
  @override
  Future<void> goBack() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.goBack();
    } catch (_) {
      // WebView 尚未就绪时忽略
    }
    await refreshNavigationState();
  }

  /// 前进一页，完成后刷新按钮可用状态
  @override
  Future<void> goForward() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.goForward();
    } catch (_) {
      // WebView 尚未就绪时忽略
    }
    await refreshNavigationState();
  }

  /// 刷新前进/后退可用状态（async 安全）
  @override
  Future<void> refreshNavigationState() async {
    final c = _controller;
    if (c == null) return;
    try {
      final canBack = await c.canGoBack();
      final canFwd = await c.canGoForward();
      if (mounted) {
        widget.onNavigationStateChanged?.call(canBack, canFwd);
      }
    } catch (_) {
      // WebView 尚未就绪时忽略
    }
  }

  /// 停止加载
  @override
  Future<void> stopLoading() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.stopLoading();
    } catch (_) {}
  }

  /// 重新加载当前页
  @override
  Future<void> reload() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.reload();
    } catch (_) {}
  }

  /// 执行网页 JS（AI Agent 操控 / 调试用）
  @override
  Future<String?> evaluateJavascript(String script) async {
    final c = _controller;
    if (c == null) return null;
    try {
      final result = await c.evaluateJavascript(source: script);
      if (result == null) return null;
      // evaluateJavascript 可能返回 Object；统一转字符串
      return result.toString();
    } catch (_) {
      return null;
    }
  }

  /// 截取当前网页截图（AI Agent 看图用）
  @override
  Future<Uint8List?> takeScreenshot() async {
    final c = _controller;
    if (c == null) return null;
    try {
      return await c.takeScreenshot();
    } catch (_) {
      return null;
    }
  }

  Future<void> _doLoad(InAppWebViewController c, String url) async {
    if (url.isEmpty) return;
    _pendingUrl = null;
    _lastRequestedUrl = url;
    try {
      await c.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } catch (_) {
      // 加载失败由 onReceivedError 处理，此处静默
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final adblock = context.watch<AdblockEngine>();

    if (widget.initialUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: settings.javascriptEnabled,
        useWideViewPort: true,
        supportZoom: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        preferredContentMode: UserPreferredContentMode.RECOMMENDED,
        allowBackgroundAudioPlaying: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        NavBus.register(this);
        widget.onControllerReady?.call(controller);
        // 补载：控制器就绪前收到的用户意图 URL（新标签页首跳等场景兜底）
        final pending = _pendingUrl;
        if (pending != null && pending != _lastRequestedUrl) {
          _doLoad(controller, pending);
        }
        refreshNavigationState();
      },
      shouldInterceptRequest: (controller, request) async {
        // 主框架请求绝不拦截：广告过滤只作用于子资源，
        // 避免命中规则时返回空响应导致整页白屏（搜索页空白问题）。
        if (request.isForMainFrame == true) {
          return null;
        }
        final url = request.url.toString();
        if (adblock.shouldBlock(url, null)) {
          // 返回空响应拦截广告
          return WebResourceResponse(
            contentType: 'text/plain',
            data: Uint8List.fromList([]),
          );
        }
        return null;
      },
      onLoadStart: (controller, url) {
        widget.onLoadingChanged(true);
        widget.onProgressChanged?.call(0.05);
        final urlStr = url?.toString() ?? '';
        if (urlStr.isNotEmpty) {
          _lastRequestedUrl = urlStr;
          _pendingUrl = null;
          widget.onUrlChanged(urlStr);
        }
        // 导航开始时立即刷新前进/后退状态
        refreshNavigationState();
      },
      onProgressChanged: (controller, progress) {
        widget.onProgressChanged?.call(progress / 100.0);
      },
      onLoadStop: (controller, url) async {
        widget.onLoadingChanged(false);
        widget.onProgressChanged?.call(1.0);
        final urlStr = url?.toString() ?? '';
        if (urlStr.isNotEmpty) {
          _lastRequestedUrl = urlStr;
          _pendingUrl = null;
          widget.onUrlChanged(urlStr);
        }
        // 更新前进/后退状态
        refreshNavigationState();
      },
      // 历史栈变化时（含前进/后退/链接跳转）实时刷新导航状态
      onUpdateVisitedHistory: (controller, url, isReload) {
        refreshNavigationState();
      },
      onTitleChanged: (controller, title) {
        if (title != null) {
          widget.onTitleChanged(title);
        }
      },
      onReceivedError: (controller, request, error) {
        widget.onLoadingChanged(false);
        widget.onProgressChanged?.call(1.0);
        refreshNavigationState();
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        widget.onLoadingChanged(false);
        widget.onProgressChanged?.call(1.0);
        refreshNavigationState();
      },
    );
  }
}
