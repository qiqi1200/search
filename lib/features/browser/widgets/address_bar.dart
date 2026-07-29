import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/browser_provider.dart';

class AddressBar extends StatefulWidget {
  final String url;
  final bool isLoading;
  final Function(String) onSubmitted;

  const AddressBar({
    super.key,
    required this.url,
    required this.isLoading,
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

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2A2A2E).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),

            // 安全锁或加载图标
            if (widget.isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                widget.url.startsWith('https')
                    ? Icons.lock
                    : Icons.lock_open,
                size: 14,
                color: widget.url.startsWith('https')
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
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
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: TextStyle(
                    fontSize: 13,
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

            // 刷新/停止按钮
            IconButton(
              icon: Icon(
                widget.isLoading ? Icons.close : Icons.refresh,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () {
                // TODO: refresh/stop
              },
            ),
          ],
        ),
      ),
    );
  }
}
