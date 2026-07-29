import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../adblock/adblock_engine.dart';

class WebViewContainer extends StatefulWidget {
  final String tabId;
  final String initialUrl;
  final Function(String) onUrlChanged;
  final Function(String) onTitleChanged;
  final Function(bool) onLoadingChanged;

  const WebViewContainer({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onLoadingChanged,
  });

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Theme.of(context).colorScheme.primary,
      ),
      onRefresh: () {
        _webViewController?.reload();
      },
    );
  }

  @override
  void dispose() {
    _pullToRefreshController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final adblockEngine = context.watch<AdblockEngine>();

    if (widget.initialUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: settings.javascriptEnabled,
        useWideViewPort: true,
        supportZoom: true,
        allowFileAccess: true,
        useOnLoadResource: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        cacheEnabled: !settings.doNotTrack,
        disableDefaultErrorPage: false,
        preferredContentMode: UserPreferredContentMode.RECOMMENDED,
        transparency: true,
        allowBackgroundAudioPlaying: true,
        // 隐私设置：禁止第三方 Cookie
        thirdPartyCookiesEnabled: !settings.blockThirdPartyCookies,
        // DNT 头
        applicationNameForUserAgent: settings.doNotTrack
            ? 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36'
            : null,
      ),
      pullToRefreshController: _pullToRefreshController,
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStart: (controller, url) {
        widget.onLoadingChanged(true);
        if (url != null) {
          widget.onUrlChanged(url.toString());
        }
      },
      onLoadStop: (controller, url) {
        widget.onLoadingChanged(false);
        _pullToRefreshController?.endRefreshing();
        if (url != null) {
          widget.onUrlChanged(url.toString());
        }
        // 获取页面标题
        controller.getTitle().then((title) {
          if (title != null && mounted) {
            widget.onTitleChanged(title);
          }
        });
      },
      onTitleChanged: (controller, title) {
        if (title != null) {
          widget.onTitleChanged(title);
        }
      },
      onUrlChanged: (controller, url) {
        if (url != null) {
          widget.onUrlChanged(url.toString());
        }
      },
      onProgressChanged: (controller, progress) {
        // 进度条更新（可选）
      },
      // ========== 广告过滤核心 ==========
      shouldInterceptRequest: (controller, request) async {
        if (!settings.adblockEnabled) return null;

        final url = request.url.toString();
        final resourceType = request.resourceType;

        // 检查是否匹配广告规则
        if (adblockEngine.shouldBlock(url, resourceType)) {
          // 返回空响应阻断广告
          return ShouldInterceptRequestAction(
            contentType: 'text/plain',
            content: ''.codeUnits,
          );
        }
        return null;
      },
      // ========== DNT 头 ==========
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        if (settings.doNotTrack) {
          // 已经在 userAgent 层做了
        }
        return NavigationActionPolicy.ALLOW;
      },
    );
  }
}
