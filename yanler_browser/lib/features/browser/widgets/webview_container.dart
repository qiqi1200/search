import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/nav_bus.dart';
import '../../../providers/settings_provider.dart';
import '../../adblock/adblock_engine.dart';
import '../../adblock/popup_block_script.dart';
import '../../reading/reading_mode_service.dart';

class WebViewContainer extends StatefulWidget {
  final String tabId;
  final String initialUrl;

  /// 是否为当前活动标签页。非活动容器不注册 NavBus、不向地址栏上报导航状态，
  /// 由 BrowserScreen 用 IndexedStack 保活所有标签页 WebView（切标签零重建）。
  final bool isActive;
  final Function(String) onUrlChanged;
  final Function(String) onTitleChanged;
  final Function(bool) onLoadingChanged;

  /// 加载进度回调（0.0-1.0），用于地址栏进度条
  final Function(double)? onProgressChanged;
  final Function(InAppWebViewController)? onControllerReady;
  final Function(bool canGoBack, bool canGoForward)? onNavigationStateChanged;

  /// 弹窗/新窗口请求（合法且带手势时回调，由 BrowserScreen 开新标签）
  final void Function(String url)? onOpenInNewTab;

  const WebViewContainer({
    super.key,
    required this.tabId,
    required this.initialUrl,
    this.isActive = false,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onLoadingChanged,
    this.onControllerReady,
    this.onNavigationStateChanged,
    this.onProgressChanged,
    this.onOpenInNewTab,
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
    // 仅活动标签注册 NavBus；后台标签由 didUpdateWidget 在激活时补注册
    if (widget.isActive) {
      NavBus.register(this);
    }
  }

  @override
  void didUpdateWidget(WebViewContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // 后台标签被激活：补注册 + 上报其真实导航状态（历史栈已由 IndexedStack 保活）
      NavBus.register(this);
      refreshNavigationState();
    } else if (!widget.isActive && oldWidget.isActive) {
      // 活动标签转后台：注销，NavBus 不再指向它
      NavBus.unregister(this);
    }
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
    // 延迟刷新：WebView 内部历史栈更新有微小延迟
    await Future.delayed(const Duration(milliseconds: 80));
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
    await Future.delayed(const Duration(milliseconds: 80));
    await refreshNavigationState();
  }

  /// 刷新前进/后退可用状态（async 安全）
  ///
  /// 仅活动标签才上报，避免后台标签的加载事件覆盖活动标签的按钮状态。
  @override
  Future<void> refreshNavigationState() async {
    final c = _controller;
    if (c == null) return;
    try {
      final canBack = await c.canGoBack();
      final canFwd = await c.canGoForward();
      if (mounted && widget.isActive) {
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

  /// 浏览器状态回调统一经此转发：若在 build 帧内触发（快速切标签、WebView 回调
  /// 时序不可控），defer 到帧后执行，避免「markNeedsBuild during build」崩溃。
  void _safeBrowserNotify(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fn();
      });
    } else {
      fn();
    }
  }

  /// 弹窗/新窗口请求处理：广告/空/无手势 → 丢弃；合法且带手势 → 应用内开新标签。
  ///
  /// 广告判定复用 AdblockEngine 的精确域名规则（内存铁律：不放宽泛子串）。
  void _handlePopupWindow(String url, bool hasGesture) {
    // 空/纯脚本弹窗无实际内容可开，无论开关都忽略
    final useless = url.isEmpty ||
        url == 'about:blank' ||
        url.startsWith('javascript:') ||
        url.startsWith('data:text/html');

    final settings = context.read<SettingsProvider>();
    if (!settings.popupBlockEnabled) {
      // 关闭屏蔽时也走应用内新标签（不开原生弹窗，避免界面混乱）
      if (!useless) _openInApp(url);
      return;
    }
    if (useless) return;
    // host 命中广告规则 → 直接关闭
    final adblock = context.read<AdblockEngine>();
    if (adblock.shouldBlock(url, null)) return;
    // 无用户手势的 window.open 极可能是自动弹窗 → 关闭
    if (!hasGesture) return;
    // 合法且带手势 → 应用内开新标签
    _openInApp(url);
  }

  void _openInApp(String url) {
    final cb = widget.onOpenInNewTab;
    if (cb != null) {
      cb(url);
      return;
    }
    final c = _controller;
    if (c != null) {
      try {
        c.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      } catch (_) {}
    }
  }

  /// 自定义 scheme（非 http/https）→ 拦截 WebView 加载，改由系统外部应用处理。
  ///
  /// 修复 `net::ERR_UNKNOWN_URL_SCHEME` 错误页：默认 WebView 对
  /// `baiduboxapp://`、`alipays://`、`weixin://`、`tel:`、`mailto:` 等
  /// 未知协议会渲染红色错误页。这里统一拦下并交给 url_launcher 走系统
  /// Intent 调起第三方 App；未安装对应应用时轻量 Toast 提示，绝不落入错误页。
  void _handleExternalScheme(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
        .then((ok) {
      if (!ok && mounted) _toast('未安装对应应用');
    }).catchError((Object e) {
      if (mounted) _toast('未安装对应应用');
    });
  }

  void _toast(String msg) {
    _safeBrowserNotify(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
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
    // settings 用 watch：JS开关等变更时需重建 WebView
    final settings = context.watch<SettingsProvider>();
    // adblock 用 read：shouldInterceptRequest 回调内直接调用实例方法，
    // 无需因 blockedCount 变化而重建整个 WebView（消除卡顿）
    final adblock = context.read<AdblockEngine>();

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
        // 弹窗广告屏蔽：接管 window.open，由 onCreateWindow 决定去向
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        if (widget.isActive) {
          NavBus.register(this);
        }
        widget.onControllerReady?.call(controller);
        // 补载：控制器就绪前收到的用户意图 URL（新标签页首跳等场景兜底）
        final pending = _pendingUrl;
        if (pending != null && pending != _lastRequestedUrl) {
          _doLoad(controller, pending);
        }
        refreshNavigationState();
      },
      // 自定义协议拦截：http/https 在 WebView 内正常加载；其余协议
      //（baiduboxapp://、alipays://、weixin://、tel:、mailto: 等）一律
      // 拦下并转系统外部应用，避免渲染 ERR_UNKNOWN_URL_SCHEME 错误页。
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';
        if (url.isEmpty) return NavigationActionPolicy.ALLOW;
        final scheme = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
        if (scheme == 'http' ||
            scheme == 'https' ||
            scheme == 'about' ||
            scheme == 'data' ||
            scheme == 'javascript' ||
            scheme == 'blob' ||
            scheme == 'file') {
          return NavigationActionPolicy.ALLOW;
        }
        _handleExternalScheme(url);
        return NavigationActionPolicy.CANCEL;
      },
      shouldInterceptRequest: (controller, request) async {
        // 主框架请求绝不拦截：广告过滤只作用于子资源，
        // 避免命中规则时返回空响应导致整页白屏（搜索页空白问题）。
        if (request.isForMainFrame == true) {
          return null;
        }
        final url = request.url.toString();
        // 传入 Accept 头：图片请求（image/*）走「域名黑名单」判定，
        // 跳过路径关键词规则，避免误杀正文/缩略图（凤凰、百度）
        final headers = request.headers ?? {};
        final accept =
            headers['Accept'] ?? headers['accept'] ?? headers['ACCEPT'] ?? '';
        if (adblock.shouldBlock(url, null, acceptHeader: accept)) {
          // 返回空响应拦截广告
          return WebResourceResponse(
            contentType: 'text/plain',
            data: Uint8List.fromList([]),
          );
        }
        return null;
      },
      // 弹窗窗口拦截：window.open / target=_blank 一律接管，去向由我们决定
      onCreateWindow: (controller, action) async {
        final url = action.request.url?.toString() ?? '';
        final hasGesture = action.hasGesture ?? false;
        _handlePopupWindow(url, hasGesture);
        return true; // 始终吞掉原生弹窗
      },
      onLoadStart: (controller, url) {
        if (!mounted) return;
        final urlStr = url?.toString() ?? '';
        if (urlStr.isNotEmpty) {
          _lastRequestedUrl = urlStr;
          _pendingUrl = null;
        }
        _safeBrowserNotify(() {
          widget.onLoadingChanged(true);
          widget.onProgressChanged?.call(0.05);
          if (urlStr.isNotEmpty) widget.onUrlChanged(urlStr);
        });
        // 导航开始时立即刷新前进/后退状态
        refreshNavigationState();
      },
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        _safeBrowserNotify(() => widget.onProgressChanged?.call(progress / 100.0));
      },
      onLoadStop: (controller, url) async {
        if (!mounted) return;
        final urlStr = url?.toString() ?? '';
        if (urlStr.isNotEmpty) {
          _lastRequestedUrl = urlStr;
          _pendingUrl = null;
        }
        _safeBrowserNotify(() {
          widget.onLoadingChanged(false);
          widget.onProgressChanged?.call(1.0);
          if (urlStr.isNotEmpty) widget.onUrlChanged(urlStr);
        });
        // 更新前进/后退状态（立即 + 延迟双保险）
        refreshNavigationState();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) refreshNavigationState();
        });

        // 弹窗广告屏蔽：全局注入（受设置开关控制；与阅读模式脚本幂等共存）
        if (settings.popupBlockEnabled) {
          try {
            await controller.evaluateJavascript(
                source: PopupBlockScript.cleanScript);
          } catch (_) {}
        }

        // 洁净浏览模式：阅读页自动注入清理脚本
        if (settings.readingModeEnabled && ReadingModeService.isReadingPage(urlStr)) {
          try {
            await controller.evaluateJavascript(
                source: ReadingModeService.cleanScript);
          } catch (_) {}
        }

        // 漫画无缝续读：检测下一章 + 滚动到底自动跳转
        if (settings.comicAutoNext && ReadingModeService.isComicPage(urlStr)) {
          try {
            await controller.evaluateJavascript(
                source: ReadingModeService.comicContinuationScript);
          } catch (_) {}
        }
      },
      // 历史栈变化时（含前进/后退/链接跳转）实时刷新导航状态
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (mounted) refreshNavigationState();
      },
      onTitleChanged: (controller, title) {
        if (!mounted) return;
        final t = title;
        if (t != null) {
          _safeBrowserNotify(() => widget.onTitleChanged(t));
        }
      },
      onReceivedError: (controller, request, error) {
        if (!mounted) return;
        _safeBrowserNotify(() {
          widget.onLoadingChanged(false);
          widget.onProgressChanged?.call(1.0);
        });
        refreshNavigationState();
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        if (!mounted) return;
        _safeBrowserNotify(() {
          widget.onLoadingChanged(false);
          widget.onProgressChanged?.call(1.0);
        });
        refreshNavigationState();
      },
    );
  }
}
