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
  });

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
        widget.onControllerReady?.call(controller);
      },
      shouldInterceptRequest: (controller, request) async {
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
      },
      onLoadStop: (controller, url) async {
        widget.onLoadingChanged(false);
        if (url != null) {
          widget.onUrlChanged(url.toString());
        }
        // 更新前进/后退状态
        final canBack = await controller.canGoBack();
        final canFwd = await controller.canGoForward();
        widget.onNavigationStateChanged?.call(canBack, canFwd);
      },
      onTitleChanged: (controller, title) {
        if (title != null) {
          widget.onTitleChanged(title);
        }
      },
      onReceivedError: (controller, request, error) {
        widget.onLoadingChanged(false);
      },
    );
  }
}
