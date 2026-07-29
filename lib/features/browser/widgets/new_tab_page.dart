import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/poem_database.dart';
import '../../search/search_service.dart';

class NewTabPage extends StatefulWidget {
  const NewTabPage({super.key});

  @override
  State<NewTabPage> createState() => _NewTabPageState();
}

class _NewTabPageState extends State<NewTabPage>
    with SingleTickerProviderStateMixin {
  // 动画
  late AnimationController _fadeOutCtrl;
  late AnimationController _fadeInCtrl;
  late Animation<double> _fadeOutAnim;
  late Animation<double> _fadeInAnim;

  // 打字机
  ChinesePoem _currentPoem = PoemDatabase.randomPoem;
  int _charIndex = 0;
  String _displayedPoem = '';

  // 状态: true=显示Yanler, false=显示诗词
  bool _showLogo = true;
  Timer? _cycleTimer;
  Timer? _typeTimer;

  @override
  void initState() {
    super.initState();
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeOutAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeOut),
    );
    _fadeInAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInCtrl, curve: Curves.easeIn),
    );

    // 入场显示 Logo
    _fadeInCtrl.forward();

    // 启动循环: 显示Logo 4.5秒 → 切诗词 → 显示诗词 6秒 → 切回Logo
    _startCycle();
  }

  void _startCycle() {
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      // 由 _onTimerTick 统一调度
    });
    _scheduleNext();
  }

  int _phase = 0; // 0=显示logo, 1=显示诗词
  void _scheduleNext() {
    if (_phase == 0) {
      // 显示 Logo 4.5 秒后切到诗词
      _cycleTimer?.cancel();
      _cycleTimer = Timer(const Duration(milliseconds: 4500), () {
        _switchToPoem();
        _phase = 1;
        _scheduleNext();
      });
    } else {
      // 显示诗词 6 秒后切回 Logo
      _cycleTimer?.cancel();
      _cycleTimer = Timer(const Duration(milliseconds: 6000), () {
        _switchToLogo();
        _phase = 0;
        _scheduleNext();
      });
    }
  }

  void _switchToPoem() {
    // 选择新诗词
    ChinesePoem newPoem;
    do {
      newPoem = PoemDatabase.randomPoem;
    } while (newPoem.content == _currentPoem.content);
    _currentPoem = newPoem;
    _charIndex = 0;
    _displayedPoem = '';

    // 淡出 Logo
    _fadeOutCtrl.reset();
    _fadeOutCtrl.forward().then((_) {
      setState(() => _showLogo = false);
      _fadeInCtrl.reset();
      _fadeInCtrl.forward();
      // 打字机逐字输出
      _typeTimer?.cancel();
      _typeTimer = Timer.periodic(const Duration(milliseconds: 55), (t) {
        if (_charIndex < _currentPoem.content.length) {
          setState(() {
            _charIndex++;
            _displayedPoem = _currentPoem.content.substring(0, _charIndex);
          });
        } else {
          t.cancel();
        }
      });
    });
  }

  void _switchToLogo() {
    // 淡出诗词
    _fadeOutCtrl.reset();
    _fadeOutCtrl.forward().then((_) {
      _typeTimer?.cancel();
      setState(() {
        _showLogo = true;
        _displayedPoem = '';
        _charIndex = 0;
      });
      _fadeInCtrl.reset();
      _fadeInCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeOutCtrl.dispose();
    _fadeInCtrl.dispose();
    _cycleTimer?.cancel();
    _typeTimer?.cancel();
    super.dispose();
  }

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
              const SizedBox(height: 80),

              // Yanler 图标（始终显示）
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/fonts/yanler_icon.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 16),

              // 交替区域：Yanler 文字 ↔ 诗词
              SizedBox(
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Yanler Logo
                    AnimatedBuilder(
                      animation: _showLogo ? _fadeInAnim : _fadeOutAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _showLogo
                              ? _fadeInAnim.value
                              : _fadeOutAnim.value,
                          child: child,
                        );
                      },
                      child: _YanlerText(isDark: isDark),
                    ),
                    // 诗词
                    AnimatedBuilder(
                      animation: _showLogo ? _fadeOutAnim : _fadeInAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _showLogo
                              ? _fadeOutAnim.value
                              : _fadeInAnim.value,
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _displayedPoem +
                                (_charIndex < _currentPoem.content.length
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
                          if (_charIndex >= _currentPoem.content.length)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '—— ${_currentPoem.author}',
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
        text: TextSpan(
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
