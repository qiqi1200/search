import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../features/agent_bridge/agent_engine.dart';
import '../features/agent_bridge/browser_tools.dart';
import '../features/search/aggregated_search_service.dart';

/// 聊天会话 — 支持持久化保存/恢复
class ChatSession {
  final String id;
  String title;
  final List<Map<String, String>> messages;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    String? title,
    List<Map<String, String>>? messages,
    DateTime? updatedAt,
  })  : title = title ?? '新对话',
        messages = messages ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'],
        title: json['title'] ?? '新对话',
        messages: (json['messages'] as List? ?? [])
            .map((m) => Map<String, String>.from(m as Map))
            .toList(),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      );
}

class AIProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String _apiKey = '';
  String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  String _model = 'gpt-3.5-turbo';
  bool _agentMode = false;
  bool _isProcessing = false;
  AgentAuthorizationMode _authMode = AgentAuthorizationMode.smart;

  // 会话
  List<ChatSession> _sessions = [];
  String? _activeSessionId;
  http.Client? _currentClient; // 当前请求句柄，用于中止

  // Agent 引擎（工具循环）
  AgentEngine? _activeEngine;
  AgentStep? _currentStep;

  /// 输入草稿 — 跨形态（半屏/全屏）、跨关闭重开面板持久保留
  final TextEditingController inputController = TextEditingController();

  /// 当前网页上下文（上下文头部/快捷操作用）：{title, host, url, favicon}。
  /// 由 BrowserScreen 在面板打开 / 页面加载完成 / 切换标签时刷新。
  Map<String, String> _pageContext = const {};
  Map<String, String> get pageContext => Map.unmodifiable(_pageContext);

  void setPageContext(Map<String, String> ctx) {
    _pageContext = ctx;
    notifyListeners();
  }

  /// 待用户批准的 Agent 命令（面板内执行，用户拥有最高控制权）
  List<String> _pendingCommands = [];
  List<String> get pendingCommands => List.unmodifiable(_pendingCommands);
  void setPendingCommands(List<String> cmds) {
    _pendingCommands = cmds;
    notifyListeners();
  }

  /// Agent 操作日志（最新在前），面板内以消息流形式同步展示 AI 正在执行的步骤
  final List<String> _agentLog = [];
  List<String> get agentLog => List.unmodifiable(_agentLog);

  static const Map<String, String> _toolLabels = {
    'browser_navigate': '打开网页',
    'browser_search': '搜索',
    'browser_click': '点击',
    'browser_type': '输入文字',
    'browser_scroll': '滚动页面',
    'browser_back': '返回上一页',
    'browser_forward': '前进',
    'browser_reload': '刷新页面',
    'browser_open_tab': '打开新标签',
    'browser_close_tab': '关闭标签',
    'browser_switch_tab': '切换标签',
    'browser_get_page_text': '读取页面文字',
    'browser_get_page_screenshot': '页面截图',
    'browser_get_active_tab': '读取活动标签',
    'bookmarks_add': '收藏书签',
    'bookmarks_remove': '删除书签',
    'bookmarks_list': '查看书签',
    'history_clear': '清空历史',
    'settings_set': '修改设置',
    'adblock_toggle': '切换广告拦截',
  };

  /// 浏览器工具集（由聊天页注入）
  BrowserTools? browserTools;

  /// 授权确认回调（由聊天页注入弹窗）
  Future<bool> Function(String description)? authorizeRequest;

  String get apiKey => _apiKey;
  String get apiUrl => _apiUrl;
  String get model => _model;
  bool get agentMode => _agentMode;
  bool get isProcessing => _isProcessing;
  bool get isConfigured => _apiKey.isNotEmpty;
  AgentAuthorizationMode get authMode => _authMode;
  AgentStep? get currentStep => _currentStep;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get activeSession {
    if (_sessions.isEmpty) return null;
    return _sessions.firstWhere(
      (s) => s.id == _activeSessionId,
      orElse: () => _sessions.first,
    );
  }

  List<Map<String, String>> get messages => activeSession?.messages ?? [];

  AIProvider() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    _apiKey = await _secureStorage.read(key: 'ai_api_key') ?? '';
    _apiUrl = await _secureStorage.read(key: 'ai_api_url') ??
        'https://api.openai.com/v1/chat/completions';
    _model = await _secureStorage.read(key: 'ai_model') ?? 'gpt-3.5-turbo';
    final prefs = await SharedPreferences.getInstance();
    _agentMode = prefs.getBool('ai_agent_mode') ?? false;
    _authMode = AgentAuthorizationMode.values.firstWhere(
      (m) => m.name == prefs.getString('ai_auth_mode'),
      orElse: () => AgentAuthorizationMode.smart,
    );
    _loadSessions(prefs);
    notifyListeners();
  }

  // ==================== 配置 ====================

  Future<void> configure({
    required String apiKey,
    String apiUrl = 'https://api.openai.com/v1/chat/completions',
    String model = 'gpt-3.5-turbo',
  }) async {
    _apiKey = apiKey;
    _apiUrl = apiUrl;
    _model = model;

    await _secureStorage.write(key: 'ai_api_key', value: apiKey);
    await _secureStorage.write(key: 'ai_api_url', value: apiUrl);
    await _secureStorage.write(key: 'ai_model', value: model);

    notifyListeners();
  }

  void toggleAgentMode() {
    _agentMode = !_agentMode;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('ai_agent_mode', _agentMode),
    );
    notifyListeners();
  }

  /// 设置授权模式（strict/smart/auto），持久化
  Future<void> setAuthMode(AgentAuthorizationMode mode) async {
    _authMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_auth_mode', mode.name);
    notifyListeners();
  }

  void clearApiKey() {
    _apiKey = '';
    _secureStorage.delete(key: 'ai_api_key');
    notifyListeners();
  }

  // ==================== 会话管理 ====================

  void _loadSessions(SharedPreferences prefs) {
    final data = prefs.getStringList('ai_chat_sessions') ?? [];
    _sessions = data
        .map((e) => ChatSession.fromJson(jsonDecode(e)))
        .toList();
    if (_sessions.isNotEmpty) {
      _activeSessionId = _sessions.first.id;
    }
  }

  Future<void> _persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ai_chat_sessions',
      _sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  /// 新建会话并激活
  void newChat() {
    final session = ChatSession(id: DateTime.now().millisecondsSinceEpoch.toString());
    _sessions.insert(0, session);
    _activeSessionId = session.id;
    _persistSessions();
    notifyListeners();
  }

  /// 打开历史会话
  void openSession(String id) {
    if (_sessions.any((s) => s.id == id)) {
      _activeSessionId = id;
      notifyListeners();
    }
  }

  /// 删除历史会话
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    if (_activeSessionId == id) {
      _activeSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
    }
    await _persistSessions();
    notifyListeners();
  }

  /// 清空当前会话消息（保留会话）
  void clearHistory() {
    final session = activeSession;
    if (session != null) {
      session.messages.clear();
      session.updatedAt = DateTime.now();
      _persistSessions();
      notifyListeners();
    }
  }

  // ==================== 发送消息 ====================

  /// 用户可随时终止当前生成，终止指令优先级最高
  void stopGenerating() {
    _activeEngine?.cancel();
    _activeEngine = null;
    _currentClient?.close();
    _currentClient = null;
    if (_isProcessing) {
      _isProcessing = false;
      _currentStep = null;
      notifyListeners();
    }
  }

  // ==================== Agent 操作日志 ====================

  String _formatStep(AgentStep step) {
    if (step.phase == 'thinking') return '思考中…';
    if (step.phase == 'error') return '出错了：${step.detail}';
    if (step.phase == 'done') return '任务完成';
    final label = _toolLabels[step.toolName] ??
        step.toolName.replaceAll('_', ' ');
    return '执行：$label';
  }

  void _appendAgentLog(AgentStep step) {
    final text = _formatStep(step);
    // 连续同一步骤去重，避免「思考中…」反复刷屏
    if (_agentLog.isNotEmpty && _agentLog.first == text) return;
    _agentLog.insert(0, text);
    if (_agentLog.length > 12) {
      _agentLog.removeRange(12, _agentLog.length);
    }
  }

  void clearAgentLog() {
    if (_agentLog.isEmpty) return;
    _agentLog.clear();
    notifyListeners();
  }

  /// 向 AI 发送消息（支持代理模式；可被 stopGenerating 中止）
  ///
  /// 无论成功、失败、未配置还是被中止，都会把「用户消息 + AI 回复」
  /// 追加到当前会话中，保证聊天界面始终有完整反馈。
  Future<String> sendMessage(String message) async {
    // 终止指令优先级最高：处理中再次发送视为「停止并重发」
    if (_isProcessing) {
      stopGenerating();
    }

    var session = activeSession ?? _newSession();
    // 首条用户消息作为会话标题
    if (session.messages.isEmpty && session.title == '新对话') {
      session.title = message.length > 20
          ? '${message.substring(0, 20)}…'
          : message;
    }
    session.messages.add({'role': 'user', 'content': message});
    session.updatedAt = DateTime.now();
    _persistSessions();
    notifyListeners();

    if (!isConfigured) {
      const tip = '请先在 AI 助手界面右上角「API 配置」中填写 API Key。';
      _appendAssistant(tip);
      return tip;
    }

    _isProcessing = true;
    notifyListeners();

    // Agent 模式 + 浏览器工具已注入 → 走原生工具循环（function calling）
    if (agentMode && browserTools != null) {
      return _runAgentLoop(session, message);
    }

    return _requestCompletion(session);
  }

  /// 首页快捷操作（总结/翻译）专用：始终走普通补全，不受 Agent 模式影响。
  ///
  /// 与 [sendMessage] 相同流程（追加用户消息 + 补全 + 展示回复），
  /// 但不进入 Agent 工具循环——总结/翻译应一次给出结果。
  Future<String> sendPageTask(String message) async {
    if (_isProcessing) stopGenerating();

    var session = activeSession ?? _newSession();
    // 首条用户消息作为会话标题
    if (session.messages.isEmpty && session.title == '新对话') {
      session.title = message.length > 20
          ? '${message.substring(0, 20)}…'
          : message;
    }
    session.messages.add({'role': 'user', 'content': message});
    session.updatedAt = DateTime.now();
    _persistSessions();
    notifyListeners();

    if (!isConfigured) {
      const tip = '请先在 AI 助手界面右上角「API 配置」中填写 API Key。';
      _appendAssistant(tip);
      return tip;
    }

    _isProcessing = true;
    notifyListeners();
    return _requestCompletion(session);
  }

  /// Agent 工具循环入口（可被 stopGenerating 中止）
  Future<String> _runAgentLoop(ChatSession session, String userMessage) async {
    clearAgentLog();
    final engine = AgentEngine(
      apiUrl: _apiUrl,
      apiKey: _apiKey,
      model: _model,
      tools: browserTools!,
      history: session.messages,
      authMode: _authMode,
      authorize: authorizeRequest,
      onStep: (step) {
        _currentStep = step;
        _appendAgentLog(step);
        notifyListeners();
      },
    );
    _activeEngine = engine;

    try {
      final reply = await engine.run(userMessage);
      if (reply == '已停止生成') {
        _appendAssistant('已停止生成');
        return reply;
      }
      _isProcessing = false;
      _appendAssistant(reply);
      return reply;
    } catch (e) {
      // 引擎内部未捕获异常（如授权回调抛错）不得静默——必须反馈给用户，
      // 否则表现为「消息发出但 AI 无任何响应」。
      _isProcessing = false;
      final err = 'Agent 执行出错：$e';
      _appendAssistant(err);
      return err;
    } finally {
      _isProcessing = false;
      _activeEngine = null;
      _currentStep = null;
      notifyListeners();
    }
  }

  /// Agent 网页操控结果回注：
  /// 将 PAGE_INFO / CLICK / TYPE / SCROLL 的真实执行结果注入会话，
  /// 让 AI 基于真实页面继续「搜索→定位→执行」全链路任务。
  Future<String> continueWithToolResult(String result) async {
    if (_isProcessing) {
      stopGenerating();
    }

    final session = activeSession ?? _newSession();
    session.messages.add({
      'role': 'user',
      'content':
          '[网页/操作结果]\n$result\n\n请根据以上真实结果继续你的任务。'
              '如需点击、输入、滚动、搜索或打开网页，请以命令格式输出（每行一个）。'
              '若任务已全部完成，请用一句话总结成果即可。',
    });
    session.updatedAt = DateTime.now();
    _persistSessions();
    notifyListeners();

    if (!isConfigured) return '未配置 AI 服务';

    _isProcessing = true;
    notifyListeners();

    return _requestCompletion(session);
  }

  /// 发起一次 LLM 补全请求（sendMessage / continueWithToolResult 共用）
  Future<String> _requestCompletion(ChatSession session) async {
    final systemPrompt = _agentMode
        ? _buildAgentSystemPrompt()
        : '你是一个友好的 AI 助手，帮助用户解答问题。请用中文回复。';

    final client = http.Client();
    _currentClient = client;

    // 超时缩短到 30s：长时间「思考中」无响应的主因是端点不可达，
    // 快速失败并给出可诊断的提示比干等 60 秒更友好。
    const timeout = Duration(seconds: 30);

    try {
      final response = await client
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                ...session.messages,
              ],
              'temperature': 0.7,
              'max_tokens': 2000,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // 若已被中止（client 被 close），丢弃结果
        if (_currentClient != client) {
          return '已停止生成';
        }

        _isProcessing = false;
        _currentClient = null;
        _appendAssistant(content);
        return content;
      } else {
        _isProcessing = false;
        _currentClient = null;
        final body = response.body.length > 300
            ? '${response.body.substring(0, 300)}…'
            : response.body;
        final err = 'API 请求失败（$_apiUrl）：${response.statusCode}\n$body';
        _appendAssistant(err);
        return err;
      }
    } catch (e) {
      _isProcessing = false;
      _currentClient = null;
      if (e.toString().contains('Client is already closed') ||
          e.toString().contains('Connection closed')) {
        return '已停止生成';
      }
      if (e.toString().contains('TimeoutException')) {
        final err = '请求超时（$_apiUrl）。请检查 API 地址是否填对、模型名是否有效、'
            '或切换可访问的网络（如校园网/代理）。';
        _appendAssistant(err);
        return err;
      }
      final err = '网络错误（$_apiUrl）：$e';
      _appendAssistant(err);
      return err;
    }
  }

  /// 追加一条 AI 回复（若与最后一条相同则跳过，避免重复显示）
  void _appendAssistant(String content) {
    final session = activeSession;
    if (session == null) return;
    if (session.messages.isNotEmpty &&
        session.messages.last['role'] == 'assistant' &&
        session.messages.last['content'] == content) {
      return;
    }
    session.messages.add({'role': 'assistant', 'content': content});
    session.updatedAt = DateTime.now();
    // 限制历史长度
    if (session.messages.length > 20) {
      session.messages.removeRange(0, session.messages.length - 20);
    }
    _persistSessions();
    notifyListeners();
  }

  ChatSession _newSession() {
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _sessions.insert(0, session);
    _activeSessionId = session.id;
    return session;
  }

  /// 构建 AI 代理的系统提示 — 用户拥有最高控制权
  String _buildAgentSystemPrompt() {
    return '''
你是 Yanler 浏览器的内置 AI 代理助手，可以操控浏览器完成「搜索→定位目标→执行操作」的全链路任务。

【最高原则】用户拥有最高控制权：
- 你的所有浏览器操作都必须以命令形式输出，由前端弹出确认框交给用户批准；
- 用户随时可以停止你的任务，用户的终止指令优先于一切；
- 未经用户明确要求，不得执行任何修改类操作（删除、关闭、清空等）。

【网页操控能力】
你可以读取当前网页、点击元素、输入文字、滚动页面：
1. 需要了解当前页面时，输出 [PAGE_INFO]，执行结果会作为真实页面信息回传给你；
2. 定位并点击元素时，输出 [CLICK: 元素文本或CSS选择器]，例如 [CLICK: 搜索];
   （优先使用页面回传的链接文本/按钮文字，更精确）
3. 向输入框填字时，输出 [TYPE: 输入框占位符或选择器, 要输入的文字]；
4. 滚动页面时，输出 [SCROLL: down|up|top|bottom]；
5. 高级操作可输出 [JS: 任意JavaScript表达式]，结果为 JSON。

【任务执行策略】
- 分步执行：一次只输出下一步需要的 1~2 个命令；
- 搜索类任务流程：先 [SEARCH: 关键词] 打开结果页 → 再 [PAGE_INFO] 读取结果 →
  根据结果 [CLICK: 目标链接] 或继续调整；
- 每步执行结果都会回传给你，请基于真实结果继续，不要凭空猜测页面内容；
- 任务完成后用一句话总结成果，不要继续输出命令。

【其他能力】
- 书签管理：[BOOKMARK_ADD: 标题, url]、[BOOKMARK_LIST]、[BOOKMARK_DELETE: 书签id]
- 历史记录：[HISTORY_CLEAR]
- 标签管理：[NEW_TAB: url]、[OPEN_URL: url]、[CLOSE_TAB: tab_id]
- 设置管理：[SETTING: 设置项, 值]、[ADBLOCK_TOGGLE]、[THEME_TOGGLE]

请用中文回复，风格简洁友好。
''';
  }

  /// 提取 AI 回复中的所有命令
  List<String> extractCommands(String response) {
    final regex = RegExp(r'\[(\w+):?\s*(.*?)\]');
    return regex
        .allMatches(response)
        .map((m) => m.group(0)!)
        .toList();
  }

  // ==================== AI 聚合检索（不污染会话历史） ====================

  /// 把多引擎聚合结果喂给 LLM 去重/排序/总结。
  /// 不写入会话历史、不触碰聊天页的 `_isProcessing`/`_currentClient`，
  /// 返回 LLM 裸文本（结果页自行解析 JSON）。
  Future<String> smartRetrieval(
    String query,
    List<SearchResultItem> items,
  ) async {
    if (!isConfigured) return '未配置 AI 服务，请在 AI 助手页面填写 API Key。';
    final prompt = _buildRetrievalPrompt(query, items);
    return _requestMessages([
      {
        'role': 'system',
        'content': '你是资深搜索聚合助手。请对用户给的多引擎结果去重、按相关度排序、'
            '提取精华，并严格输出 JSON。',
      },
      {'role': 'user', 'content': prompt},
    ]);
  }

  String _buildRetrievalPrompt(String query, List<SearchResultItem> items) {
    final sb = StringBuffer('对「$query」做聚合检索。下面是来自各引擎的原始结果'
        '（标题 | URL | 摘要）：\n');
    final top = items.take(20).toList();
    for (var i = 0; i < top.length; i++) {
      final it = top[i];
      sb.writeln('${i + 1}. [${it.engine}] ${it.title} / ${it.url} / ${it.snippet}');
    }
    sb.writeln();
    sb.writeln('请：1) 删除重复内容（同 URL 或高度相似标题只留一条）；'
        '2) 按相关度排序，保留最相关的 8 条；');
    sb.writeln('3) 每条给一句「为什么值得点」；4) 结尾用一两句总结最佳答案。');
    sb.writeln('严格只输出 JSON（不要 markdown 代码块）：');
    sb.writeln('{"summary":"…","results":[{"title":"…","url":"…","why":"…"}]}');
    return sb.toString();
  }

  /// 裸 LLM 请求（AI 检索专用）：不复用会话、不写历史。
  Future<String> _requestMessages(List<Map<String, String>> messages) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': 0.3,
              'max_tokens': 800,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String? ?? '')
            .trim();
      }
      return 'AI 请求失败（${response.statusCode}）';
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return 'AI 请求超时，请检查 API 地址或网络';
      }
      return 'AI 请求出错：$e';
    } finally {
      client.close();
    }
  }

  void clearApiConfig() {
    clearApiKey();
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }
}
