import 'dart:async';
import 'dart:math';
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
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  ChinesePoem _currentPoem = PoemDatabase.randomPoem;
  Timer? _poemTimer;
  int _charIndex = 0;
  String _displayedPoem = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
    _startPoemCycle();
  }

  void _startPoemCycle() {
    _poemTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _switchToRandomPoem();
    });
  }

  void _switchToRandomPoem() {
    ChinesePoem newPoem;
    do {
      newPoem = PoemDatabase.randomPoem;
    } while (newPoem.content == _currentPoem.content);

    setState(() {
      _currentPoem = newPoem;
      _charIndex = 0;
      _displayedPoem = '';
    });

    _animController.reset();
    _animController.forward();

    // 打字机逐字效果
    _typePoem();
  }

  void _typePoem() {
    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_charIndex < _currentPoem.content.length) {
        setState(() {
          _charIndex++;
          _displayedPoem = _currentPoem.content.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _poemTimer?.cancel();
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
              const SizedBox(height: 60),

              // Yanler 艺术字体 Logo
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: child,
                    ),
                  );
                },
                child: _YanlerLogo(isDark: isDark),
              ),

              const SizedBox(height: 12),

              // Slogan
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: max(0, _fadeAnim.value - 0.3) / 0.7,
                    child: child,
                  );
                },
                child: Text(
                  '纯净搜索，无扰浏览',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 4,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // 搜索框
              _SearchInput(onSubmit: _onSearch),

              const SizedBox(height: 48),

              // 诗词区域
              GestureDetector(
                onTap: _switchToRandomPoem,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: max(0, _fadeAnim.value - 0.5) / 0.5,
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      // 诗句
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 400),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Text(
                            _displayedPoem + (_charIndex < _currentPoem.content.length ? '▊' : ''),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: theme.colorScheme.onSurface,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 出处
                      if (_charIndex >= _currentPoem.content.length)
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: AnimationController(
                              vsync: this,
                              duration: const Duration(milliseconds: 500),
                            )..forward(),
                            curve: Curves.easeIn,
                          ),
                          child: Text(
                            '—— ${_currentPoem.author} 《${_currentPoem.title}》',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  void _onSearch(String query) {
    // Navigate to search directly
    final searchService = SearchService();
    searchService.openSearch(context, query);
  }
}

// Yanler 艺术字体 Logo + 图标
class _YanlerLogo extends StatelessWidget {
  final bool isDark;

  const _YanlerLogo({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图标
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/fonts/yanler_icon.png',
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        // 文字 Logo
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark
                  ? const Color(0xFF7B9FFF)
                  : const Color(0xFF5B7FFF),
              isDark
                  ? const Color(0xFFA07BFF)
                  : const Color(0xFF8B5CFF),
              isDark
                  ? const Color(0xFFFF7B9F)
                  : const Color(0xFFFF5C7B),
            ],
          ).createShader(bounds),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Y',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -2,
                    color: Colors.white,
                    fontFamily: 'serif',
                  ),
                ),
                TextSpan(
                  text: 'anler',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 6,
                    color: Colors.white,
                    fontFamily: 'serif',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      constraints: const BoxConstraints(maxWidth: 500),
      height: 52,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2E).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
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
          const SizedBox(width: 20),
          Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '搜索或输入网址...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  widget.onSubmit(value.trim());
                }
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
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
