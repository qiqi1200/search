import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'browser_tools.dart';

/// Agent 授权模式
enum AgentAuthorizationMode {
  /// 严格：每个工具调用都弹确认框
  strict,

  /// 智能（默认）：仅破坏性操作（删除/清空/改设置/关标签）确认，其余自动执行
  smart,

  /// 全自动：不弹确认框（最大权限，风险自担）
  auto,
}

/// Agent 执行步骤（供 UI 展示状态）
class AgentStep {
  final String phase; // thinking | tool | done | error
  final String toolName;
  final String detail;

  const AgentStep({required this.phase, this.toolName = '', this.detail = ''});
}

/// 手机内置 Agent 引擎 — 工具循环（OpenClaw/Hermes 架构的 Dart 实现）
///
/// 循环：模型选工具 → 授权 → 执行浏览器工具 → 结果回传 → 直到任务完成。
/// 能力面 = BrowserTools（全部浏览器内部操作），无系统工具，天然隔离。
/// 用户控制权：authorize 回调弹确认框；cancel() 随时中止，优先级最高。
class AgentEngine {
  final String apiUrl;
  final String apiKey;
  final String model;
  final BrowserTools tools;
  final List<Map<String, String>> history; // 会话历史（user/assistant）
  final AgentAuthorizationMode authMode;

  /// UI 授权回调：返回 true 允许执行；null 时按 authMode 兜底（auto 允许，其余拒绝）
  Future<bool> Function(String description)? authorize;

  /// 步骤状态回调（UI 显示 thinking / 工具执行中）
  void Function(AgentStep step)? onStep;

  http.Client? _client;
  bool _cancelled = false;
  static const int _maxRounds = 8;

  AgentEngine({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
    required this.tools,
    required this.history,
    this.authMode = AgentAuthorizationMode.smart,
    this.authorize,
    this.onStep,
  });

  /// 破坏性操作（smart 模式下需要用户确认）
  static const Set<String> _destructive = {
    'bookmarks_remove',
    'history_clear',
    'settings_set',
    'adblock_toggle',
    'browser_close_tab',
  };

  void cancel() {
    _cancelled = true;
    _client?.close();
    _client = null;
  }

  /// 运行一次完整工具循环，返回最终回复文本
  Future<String> run(String userMessage) async {
    _cancelled = false;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt()},
      ...history
          .where((m) =>
              (m['role'] == 'user' || m['role'] == 'assistant') &&
              (m['content'] ?? '').isNotEmpty)
          .map((m) => {'role': m['role'], 'content': m['content']}),
      {'role': 'user', 'content': userMessage},
    ];
    final toolSchemas = tools.tools.map(_toOpenAiTool).toList();

    for (var round = 0; round < _maxRounds; round++) {
      if (_cancelled) return '已停止生成';

      onStep?.call(const AgentStep(phase: 'thinking'));
      final client = http.Client();
      _client = client;

      late http.Response response;
      try {
        response = await client
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': model,
                'messages': messages,
                'tools': toolSchemas,
                'temperature': 0.5,
                'max_tokens': 2000,
              }),
            )
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        final stopped = _cancelled || e.toString().contains('closed');
        if (stopped) return '已停止生成';
        if (e.toString().contains('TimeoutException')) {
          return '请求超时（$apiUrl）。请检查 API 地址是否填对、模型是否支持工具调用，或切换网络后重试。';
        }
        return '网络错误（$apiUrl）：$e';
      } finally {
        if (_cancelled) client.close();
        _client = null;
      }

      if (response.statusCode != 200) {
        final body = response.body.length > 300
            ? '${response.body.substring(0, 300)}…'
            : response.body;
        return 'API 请求失败（$apiUrl）：${response.statusCode}\n$body';
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return '响应解析失败';
      }

      final choices = data['choices'] as List? ?? [];
      final msg = choices.isEmpty
          ? null
          : choices.first['message'] as Map<String, dynamic>?;
      if (msg == null) return '响应为空';

      final content = msg['content'] as String? ?? '';
      final toolCalls = (msg['tool_calls'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // 没有工具调用 → 任务完成
      if (toolCalls.isEmpty) {
        onStep?.call(const AgentStep(phase: 'done'));
        return content.isEmpty ? '（AI 未返回内容）' : content;
      }

      // 有工具调用 → 执行并回传结果
      final assistantMsg = {
        'role': 'assistant',
        'content': content,
        'tool_calls': toolCalls.map((tc) {
          final fn = tc['function'] as Map<String, dynamic>? ?? {};
          return {
            'id': tc['id'] ?? 'call_${round}_${toolCalls.indexOf(tc)}',
            'type': 'function',
            'function': {
              'name': fn['name'] ?? '',
              'arguments': fn['arguments'] ?? '{}',
            },
          };
        }).toList(),
      };
      messages.add(assistantMsg);

      for (final tc in toolCalls) {
        if (_cancelled) return '已停止生成';
        final fn = tc['function'] as Map<String, dynamic>? ?? {};
        // 模型可能返回非法工具名（旧版缓存会话等），清洗后再分发
        final name = _sanitizeToolName(fn['name'] as String? ?? '');
        Map<String, Object?> args;
        try {
          args = (jsonDecode(fn['arguments'] as String? ?? '{}')
                  as Map<String, dynamic>? ??
              {});
        } catch (_) {
          args = {};
        }

        // 授权检查（用户最高控制权）
        final desc = _describe(name, args);
        var allowed = true;
        final needAuth = authMode == AgentAuthorizationMode.strict ||
            (authMode == AgentAuthorizationMode.smart && _destructive.contains(name));
        if (needAuth) {
          if (authorize != null) {
            allowed = await authorize!(desc);
          } else {
            allowed = authMode == AgentAuthorizationMode.auto;
          }
        }
        if (!allowed) {
          messages.add({
            'role': 'tool',
            'tool_call_id': tc['id'] ?? '',
            'content': '用户拒绝了该操作：$desc',
          });
          continue;
        }

        onStep?.call(AgentStep(phase: 'tool', toolName: name, detail: desc));
        final result = await tools.call(name, args);
        if (_cancelled) return '已停止生成';

        messages.add({
          'role': 'tool',
          'tool_call_id': tc['id'] ?? '',
          'content': result.isError ? 'ERROR: ${result.text}' : result.text,
        });
      }
    }

    onStep?.call(const AgentStep(phase: 'done'));
    return '任务步骤过多已自动结束。如果还没完成，请告诉我继续。';
  }

  /// 工具名清洗：DeepSeek 等 OpenAI 兼容端点要求 function.name 只含
  /// `[a-zA-Z0-9_-]`（点号/中文/空格/斜杠都会触发
  /// 「Invalid 'tools[].function.name'」400）。统一替换为 `_`，
  /// 保证发给 API 的工具名永远合法。
  static String _sanitizeToolName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  /// OpenAI 兼容工具 schema
  Map<String, Object> _toOpenAiTool(MCPTool tool) => {
        'type': 'function',
        'function': {
          'name': _sanitizeToolName(tool.name),
          'description': tool.description,
          'parameters': tool.inputSchema,
        },
      };

  String _describe(String name, Map<String, Object?> args) {
    final argText = args.entries
        .map((e) => '${e.key}=${e.value}')
        .join('，');
    return '$name${argText.isEmpty ? '' : '（$argText）'}';
  }

  String _systemPrompt() => '''
你是 Yanler 浏览器内置的 AI 代理助手，可以操控浏览器完成任务。

【能力边界】你只能操作浏览器内部：
- 标签页：打开/关闭/切换/导航/前进后退/刷新
- 搜索：用浏览器默认搜索引擎搜索
- 页面：读取正文、截图、点击元素（CSS 选择器）、输入文字、滚动
- 书签 / 历史 / 浏览器设置（搜索引擎、主题、壁纸、广告过滤）

【最高原则】用户拥有最高控制权：
- 修改类操作（删除书签、清空历史、改设置、关闭标签）会弹出确认框交给用户批准；
- 用户随时可以停止你，停止指令优先于一切；
- 不要执行用户没有要求的事情。

【任务策略】
- 需要操作浏览器时调用工具；每一步基于工具返回的真实结果继续，不要猜测页面内容；
- 多步任务（如"搜索并打开第一个结果"）：搜索 → 读取结果页 → 点击目标，逐步完成；
- 点击/输入优先用稳定的 CSS 选择器；找不到元素时先读取页面文本再调整；
- 任务完成后用一句话总结成果，不要继续调用工具。
''';
}
