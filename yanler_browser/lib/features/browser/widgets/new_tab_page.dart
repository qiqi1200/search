import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/poem_database.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../providers/browser_provider.dart';
import '../../../providers/quick_links_provider.dart';
import '../../search/search_service.dart';

/// 新标签页 — Yanler 品牌 Logo 与诗词交叉淡化 + 打字机动画
///
/// 视觉层：Outfit 品牌字标 / 思源宋体诗词 / 液态玻璃搜索框 / 快捷链接
class NewTabPage extends StatefulWidget {
  const NewTabPage({super.key});

  @override
  State<NewTabPage> createState() => _NewTabPageState();
}

class _NewTabPageState extends State<NewTabPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _crossFade;

  // 打字机状态（保持原逻辑不变）
  ChinesePoem _currentPoem = PoemDatabase.randomPoem;
  int _charIndex = 0;
  String _displayedPoem = '';
  bool _showingPoem = false;

  // 生命周期安全
  bool _disposed = false;

  // 定时器 — 合并为单一驱动
  Timer? _phaseTimer;
  Timer? _typewriterTimer;

  final _random = Random();

  // 可配置时长（ms）
  static const int _logoDuration = 4000;
  static const int _poemMinDuration = 6000; // 最短显示时间，含打字
  static const int _poemExtraDuration = 2000; // 打字完成后额外停留
  static const int _typewriterDelay = 350;
  static const int _typewriterInterval = 60;

  @override
  void initState() {
    super.initState();
    _crossFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 0.0,
    );
    // —— 从 Logo 阶段开始 ——
    _scheduleLogoPhase();
  }

  @override
  void dispose() {
    _disposed = true;
    _phaseTimer?.cancel();
    _typewriterTimer?.cancel();
    _crossFade.dispose();
    super.dispose();
  }

  // ===============================================================
  // 阶段调度
  // ===============================================================

  /// 调度 Logo 阶段 → 倒计时后切到诗词
  void _scheduleLogoPhase() {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: _logoDuration), () {
      if (_disposed) return;
      _switchToPoem();
    });
  }

  /// 调度诗词阶段 → 倒计时后切回 Logo
  void _schedulePoemPhase() {
    _phaseTimer?.cancel();
    // 总时长 = 最短展示 + 额外停留（如果打字很快完成）
    const totalDuration = _poemMinDuration + _poemExtraDuration;
    _phaseTimer = Timer(const Duration(milliseconds: totalDuration), () {
      if (_disposed) return;
      _switchToLogo();
    });
  }

  // ===============================================================
  // 阶段切换
  // ===============================================================

  void _switchToPoem() {
    if (_disposed) return;

    // 选一首不同的诗
    ChinesePoem next;
    do {
      next = PoemDatabase.poems[_random.nextInt(PoemDatabase.poems.length)];
    } while (next.content == _currentPoem.content && PoemDatabase.poems.length > 1);

    setState(() {
      _currentPoem = next;
      _charIndex = 0;
      _displayedPoem = '';
      _showingPoem = true;
    });

    // 交叉淡化到诗词
    _crossFade.forward();

    // 延迟后启动打字机（等待淡化过渡）
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer(
      const Duration(milliseconds: _typewriterDelay),
      _startTypewriter,
    );

    // 调度切回 Logo
    _schedulePoemPhase();
  }

  void _switchToLogo() {
    if (_disposed) return;

    // 停止打字机
    _typewriterTimer?.cancel();
    _typewriterTimer = null;

    setState(() {
      _showingPoem = false;
    });

    // 交叉淡化回 Logo
    _crossFade.reverse();

    // 调度下一轮
    _scheduleLogoPhase();
  }

  // ===============================================================
  // 打字机（逻辑保持不变）
  // ===============================================================

  void _startTypewriter() {
    if (_disposed || !_showingPoem) return;

    _typewriterTimer = Timer.periodic(
      const Duration(milliseconds: _typewriterInterval),
      _onTypewriterTick,
    );
  }

  void _onTypewriterTick(Timer t) {
    if (_disposed) {
      t.cancel();
      return;
    }

    if (!_showingPoem) {
      // 阶段已切换，停止打字
      t.cancel();
      return;
    }

    if (_charIndex < _currentPoem.content.length) {
      setState(() {
        _charIndex++;
        _displayedPoem = _currentPoem.content.substring(0, _charIndex);
      });
    } else {
      // 打字完成
      t.cancel();
    }
  }

  // ===============================================================
  // Build
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            isDark ? const Color(0xFF1D1E24) : const Color(0xFFF0EDE9),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),

                // 交替区域：Yanler 文字 ↔ 诗词（交叉淡化）
                SizedBox(
                  height: 100,
                  child: AnimatedBuilder(
                    animation: _crossFade,
                    builder: (context, child) {
                      final t = _crossFade.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Yanler Logo
                          Opacity(
                            opacity: 1.0 - t,
                            child: const _YanlerText(),
                          ),
                          // 诗词
                          Opacity(
                            opacity: t,
                            child: _PoemDisplay(
                              poem: _currentPoem,
                              displayed: _displayedPoem,
                              typing: _showingPoem &&
                                  _charIndex < _currentPoem.content.length,
                              complete: _showingPoem &&
                                  _charIndex >= _currentPoem.content.length,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 36),

                // 搜索框 — 液态玻璃
                _SearchInput(onSubmit: _onSearch),

                const SizedBox(height: 40),

                // 快捷链接 — Speed Dial
                const _QuickLinksSection(),

                const SizedBox(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSearch(String query) {
    final searchService = SearchService();
    searchService.openSearch(context, query);
  }
}

/// Yanler 文字 Logo — Outfit 字体，品牌渐变
class _YanlerText extends StatelessWidget {
  const _YanlerText();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          isDark ? const Color(0xFF7B9FFF) : const Color(0xFF5B7FFF),
          isDark ? const Color(0xFFA07BFF) : const Color(0xFF8B5CFF),
          isDark ? const Color(0xFFFF7B9F) : const Color(0xFFFF5C7B),
        ],
      ).createShader(bounds),
      child: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'Y',
              style: TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w200,
                letterSpacing: -4,
                color: Colors.white,
                fontFamily: 'Outfit',
              ),
            ),
            TextSpan(
              text: 'anler',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: Colors.white,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 诗词展示 — 思源宋体，古籍排印气质
class _PoemDisplay extends StatelessWidget {
  final ChinesePoem poem;
  final String displayed;
  final bool typing;
  final bool complete;

  const _PoemDisplay({
    required this.poem,
    required this.displayed,
    required this.typing,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayed + (typing ? '▊' : ''),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            height: 1.7,
            letterSpacing: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
            fontFamily: 'SourceHanSerifSC',
          ),
        ),
        if (complete)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '—— ${poem.author} 《${poem.title}》',
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 2,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.85),
                fontFamily: 'SourceHanSerifSC',
              ),
            ),
          ),
      ],
    );
  }
}

/// 搜索输入框 — 液态玻璃
class _SearchInput extends StatefulWidget {
  final void Function(String) onSubmit;
  const _SearchInput({required this.onSubmit});

  @override
  State<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<_SearchInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

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

    return LiquidGlass(
      borderRadius: BorderRadius.circular(26),
      blur: 22,
      opacity: isDark ? 0.45 : 0.55,
      shadows: GlassTokens.softShadow(isDark),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(
                Icons.search_rounded,
                size: 19,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: '搜索或输入网址',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.55),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) widget.onSubmit(value.trim());
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5B7FFF),
                      Color(0xFF8B5CFF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      widget.onSubmit(_controller.text.trim());
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 快捷链接区 — Speed Dial（Vivaldi / Chrome 同款）
class _QuickLinksSection extends StatelessWidget {
  const _QuickLinksSection();

  static const List<List<Color>> _palette = [
    [Color(0xFF5B7FFF), Color(0xFF8B5CFF)],
    [Color(0xFF00B8A9), Color(0xFF00A3E0)],
    [Color(0xFFFF8E53), Color(0xFFFF5C7B)],
    [Color(0xFF7B61FF), Color(0xFFB05CFF)],
    [Color(0xFF2E9EFF), Color(0xFF00C6A7)],
    [Color(0xFFF95C7B), Color(0xFFF7A35C)],
  ];

  static List<Color> _colorsFor(String url) {
    final hash = url.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0xFFFF);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quickLinks = context.watch<QuickLinksProvider>();
    final browser = context.read<BrowserProvider>();

    if (quickLinks.links.isEmpty) return const SizedBox.shrink();

    // 网格宽度随屏宽自适应：4 列
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = ((screenWidth - 64) / 4).clamp(56.0, 88.0);

    return Column(
      children: [
        Text(
          '快捷链接',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: ((screenWidth - 64 - tileWidth * 4) / 3).clamp(0.0, 24.0),
          runSpacing: 18,
          alignment: WrapAlignment.center,
          children: [
            ...quickLinks.links.map((link) {
              final colors = _colorsFor(link.url);
              return _QuickLinkTile(
                width: tileWidth,
                title: link.title,
                colors: colors,
                onTap: () {
                  if (link.url.isNotEmpty) {
                    browser.addTab(url: link.url);
                  }
                },
                onLongPress: () => _confirmRemove(context, quickLinks, link),
              );
            }),
            _AddTile(
              width: tileWidth,
              onTap: () => _showAddDialog(context, quickLinks),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmRemove(
    BuildContext context,
    QuickLinksProvider quickLinks,
    QuickLink link,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除快捷链接'),
        content: Text('确定移除「${link.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              quickLinks.remove(link.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, QuickLinksProvider quickLinks) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加快捷链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：知乎',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '网址',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              final normalized =
                  url.contains('.') ? url : 'https://$url';
              quickLinks.add(titleController.text, normalized);
              Navigator.pop(dialogContext);
            },
            child: Text('添加', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}

/// 单个快捷链接磁贴
class _QuickLinkTile extends StatelessWidget {
  final double width;
  final String title;
  final List<Color> colors;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickLinkTile({
    required this.width,
    required this.title,
    required this.colors,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 字母头像 — 渐变圆
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors[1].withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  title.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 添加磁贴
class _AddTile extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _AddTile({required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '添加',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
