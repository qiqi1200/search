import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/liquid_glass.dart';
import 'instant_answer.dart';

/// 本地即时答案页 — 计算 / 时间 / 农历 / 诗词。
///
/// 零网络零 AI：答案全部本地生成，底部提供「用 Bing 搜索」兜底
///（点击后以 Bing URL 返回，由 browser_screen 驱动 WebView 加载）。
class InstantAnswerPage extends StatelessWidget {
  final String query;
  final InstantAnswer answer;

  const InstantAnswerPage({
    super.key,
    required this.query,
    required this.answer,
  });

  static String bingUrlFor(String query) =>
      'https://cn.bing.com/search?q=${Uri.encodeComponent(query)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (icon, color) = switch (answer.kind) {
      InstantAnswerKind.calculator => (Icons.calculate_rounded, const Color(0xFF5B7FFF)),
      InstantAnswerKind.time => (Icons.schedule_rounded, const Color(0xFF00A3E0)),
      InstantAnswerKind.lunar => (Icons.nightlight_round, const Color(0xFF8B5CFF)),
      InstantAnswerKind.poem => (Icons.auto_stories_rounded, const Color(0xFFFF8E53)),
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：返回 + 查询 + Yanler 标签
            LiquidGlass(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
              blur: 24,
              opacity: isDark ? 0.32 : 0.34,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          query,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Yanler',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            // 答案卡片
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.12),
                          color.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: color.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 18, color: color),
                            const SizedBox(width: 8),
                            Text(
                              answer.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            const Spacer(),
                            // 复制
                            InkWell(
                              onTap: () {
                                if (answer.copyText.isNotEmpty) {
                                  Clipboard.setData(
                                    ClipboardData(text: answer.copyText),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已复制'),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SelectableText(
                          answer.content,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.75,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                            fontFamily: answer.kind == InstantAnswerKind.poem
                                ? 'SourceHanSerifSC'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Bing 兜底
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: const Color(0xFF5B7FFF),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, bingUrlFor(query)),
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: Text('用 Bing 搜索「$query」'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
