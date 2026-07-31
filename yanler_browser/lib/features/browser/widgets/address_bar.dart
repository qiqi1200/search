import 'package:flutter/material.dart';
import '../../../core/widgets/liquid_glass.dart';

class AddressBar extends StatefulWidget {
  final String url;
  final bool isLoading;

  /// 加载进度 0.0-1.0；无加载时为 null
  final double? progress;

  /// 刷新/停止回调（由 BrowserScreen 接线到 WebView 控制器）
  final VoidCallback onRefresh;

  final Function(String) onSubmitted;

  const AddressBar({
    super.key,
    required this.url,
    required this.isLoading,
    this.progress,
    required this.onRefresh,
    required this.onSubmitted,
  });

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _isEditing = true);
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void didUpdateWidget(AddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && !_isEditing) {
      _controller.text = widget.url;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final progress = widget.progress ?? 0.0;
    final showProgress = widget.isLoading && progress > 0 && progress < 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: LiquidGlass(
        borderRadius: BorderRadius.circular(24),
        blur: 20,
        opacity: isDark ? 0.42 : 0.45,
        shadows: GlassTokens.softShadow(isDark),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 14),

                  // 安全锁 / 加载指示
                  SizedBox(
                    width: 18,
                    child: widget.isLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Icon(
                            widget.url.startsWith('https')
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            size: 14,
                            color: widget.url.startsWith('https')
                                ? const Color(0xFF34C759)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: GestureDetector(
                      onTap: () => _focusNode.requestFocus(),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: '搜索或输入网址',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 0.1,
                          color: theme.colorScheme.onSurface,
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (value) {
                          setState(() => _isEditing = false);
                          _focusNode.unfocus();
                          if (value.trim().isNotEmpty) {
                            widget.onSubmitted(value.trim());
                          }
                        },
                      ),
                    ),
                  ),

                  // 刷新 / 停止
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton(
                      icon: Icon(
                        widget.isLoading ? Icons.close_rounded : Icons.refresh_rounded,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: widget.onRefresh,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),

            // 加载进度条（Chrome 式细进度线）
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: showProgress ? 2 : 0,
              child: showProgress
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
