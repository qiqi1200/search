import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
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

class WebViewContainerState extends State<WebViewContainer> {
  InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
  }


  /// 刷新前进/后退可用状态（async 安全）
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

  @override
  void dispose() {
    _controller = null;
    super.dispose();
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
        widget.onControllerReady?.call(controller);
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
        if (url != null && url.toString().isNotEmpty) {
          widget.onUrlChanged(url.toString());
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
        if (url != null) {
          widget.onUrlChanged(url.toString());
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
