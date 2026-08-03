import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/liquid_glass.dart'; // GlassTokens（建议下拉阴影）仍在使用
import '../../../core/widgets/yanler_surface.dart';
import '../../search/search_suggestions.dart';

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

  // 关联搜索（输入联想）
  List<String> _suggestions = [];
  Timer? _suggestDebounce;
  bool _suggestLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
    _controller.addListener(_onTextChanged);
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
    _suggestDebounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _suggestDebounce?.cancel();
    if (!_focusNode.hasFocus) return;
    final q = _controller.text.trim();
    if (q.isEmpty) {
      if (_suggestions.isNotEmpty || _suggestLoading) {
        setState(() {
          _suggestions = [];
          _suggestLoading = false;
        });
      }
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 260), () async {
      if (!mounted) return;
      setState(() => _suggestLoading = true);
      final sugs = await SearchSuggestions.fetch(q);
      if (!mounted) return;
      // 输入已变化或已失焦则丢弃结果
      if (_controller.text.trim() != q || !_focusNode.hasFocus) return;
      setState(() {
        _suggestions = sugs;
        _suggestLoading = false;
      });
    });
  }

  void _submit(String value) {
    _suggestDebounce?.cancel();
    setState(() {
      _suggestions = [];
      _isEditing = false;
    });
    _focusNode.unfocus();
    if (value.trim().isNotEmpty) {
      widget.onSubmitted(value.trim());
    }
  }

  void _onSuggestionTap(String s) {
    _controller.text = s;
    _controller.selection = TextSelection.collapsed(offset: s.length);
    _submit(s);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final progress = widget.progress ?? 0.0;
    final showProgress = widget.isLoading && progress > 0 && progress < 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: YanlerSurface(
        borderRadius: BorderRadius.circular(24),
        // 聚焦时品牌色描边动画（AnimatedContainer 平滑过渡）
        tint: _isEditing ? theme.colorScheme.primary : null,
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
                          if (value.trim().isNotEmpty) {
                            _submit(value.trim());
                          }
                        },
                      ),
                    ),
                  ),

                  // 联想加载指示
                  if (_suggestLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                  // 刷新 / 停止
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton(
                      icon: Icon(
                        widget.isLoading
                            ? Icons.close_rounded
                            : Icons.refresh_rounded,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      color: theme.colorScheme.onSurfaceVariant,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
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

            // 关联搜索建议
            if (_suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF212226).withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    ),
                    boxShadow: GlassTokens.softShadow(isDark),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length.clamp(0, 6),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.4,
                      indent: 40,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final s = _suggestions[index];
                      return InkWell(
                        onTap: () => _onSuggestionTap(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.north_west_rounded,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
