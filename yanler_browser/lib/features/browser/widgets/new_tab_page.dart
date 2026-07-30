import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/utils/poem_database.dart';
import '../../search/search_service.dart';

/// 新标签页 — 显示 Yanler 品牌与诗词交叉淡化 + 打字机动画
class NewTabPage extends StatefulWidget {
  const NewTabPage({super.key});

  @override
  State<NewTabPage> createState() => _NewTabPageState();
}

class _NewTabPageState extends State<NewTabPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _crossFade;

  // 打字机状态
  ChinesePoem _currentPoem = PoemDatabase.randomPoem;
  int _charIndex = 0;
  String _displayedPoem = '';
  bool _showingPoem = false;
  bool _typewriterRunning = false;

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
    _phaseTimer = Timer(Duration(milliseconds: _logoDuration), () {
      if (_disposed) return;
      _switchToPoem();
    });
  }

  /// 调度诗词阶段 → 倒计时后切回 Logo
  void _schedulePoemPhase() {
    _phaseTimer?.cancel();
    // 总时长 = 最短展示 + 额外停留（如果打字很快完成）
    final totalDuration = _poemMinDuration + _poemExtraDuration;
    _phaseTimer = Timer(Duration(milliseconds: totalDuration), () {
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
      _typewriterRunning = false;
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
      _typewriterRunning = false;
    });

    // 交叉淡化回 Logo
    _crossFade.reverse();

    // 调度下一轮
    _scheduleLogoPhase();
  }

  // ===============================================================
  // 打字机
  // ===============================================================

  void _startTypewriter() {
    if (_disposed || !_showingPoem) return;

    _typewriterRunning = true;
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
      _typewriterRunning = false;
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
      _typewriterRunning = false;
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
            isDark
                ? const Color(0xFF1E1E24)
                : const Color(0xFFF0EDE9),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // 交替区域：Yanler 文字 ↔ 诗词（交叉淡化），无APP图标
              SizedBox(
                height: 90,
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
                          child: _YanlerText(isDark: isDark),
                        ),
                        // 诗词
                        Opacity(
                          opacity: t,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _displayedPoem +
                                    (_showingPoem &&
                                            _charIndex < _currentPoem.content.length
                                        ? '▊'
                                        : ''),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: theme.colorScheme.onSurface,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (_charIndex >= _currentPoem.content.length &&
                                  _showingPoem)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '—— ${_currentPoem.author} 《${_currentPoem.title}》',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // 搜索框
              _SearchInput(onSubmit: _onSearch),

              const SizedBox(height: 80),
            ],
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

// Yanler 文字 Logo
class _YanlerText extends StatelessWidget {
  final bool isDark;
  const _YanlerText({required this.isDark});

  @override
  Widget build(BuildContext context) {
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
                fontSize: 50,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
                color: Colors.white,
                fontFamily: 'serif',
              ),
            ),
            TextSpan(
              text: 'anler',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w300,
                letterSpacing: 6,
                color: Colors.white,
                fontFamily: 'serif',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 搜索输入框
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

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2E).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '搜索或输入网址',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              textInputAction: TextInputAction.go,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) widget.onSubmit(value.trim());
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(19),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  widget.onSubmit(_controller.text.trim());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
