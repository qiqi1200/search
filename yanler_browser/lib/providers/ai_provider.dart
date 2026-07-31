import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  // 会话
  List<ChatSession> _sessions = [];
  String? _activeSessionId;
  http.Client? _currentClient; // 当前请求句柄，用于中止

  String get apiKey => _apiKey;
  String get apiUrl => _apiUrl;
  String get model => _model;
  bool get agentMode => _agentMode;
  bool get isProcessing => _isProcessing;
  bool get isConfigured => _apiKey.isNotEmpty;

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
    _currentClient?.close();
    _currentClient = null;
    if (_isProcessing) {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 向 AI 发送消息（支持代理模式；可被 stopGenerating 中止）
  Future<String> sendMessage(String message) async {
    if (!isConfigured) {
      return '请先在 AI 助手界面配置 API Key';
    }

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

    _isProcessing = true;
    notifyListeners();

    final systemPrompt = _agentMode
        ? _buildAgentSystemPrompt()
        : '你是一个友好的 AI 助手，帮助用户解答问题。请用中文回复。';

    final client = http.Client();
    _currentClient = client;

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
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // 若已被中止（client 被 close），丢弃结果
        if (_currentClient != client) {
          return '已停止生成';
        }

        session.messages.add({'role': 'assistant', 'content': content});
        session.updatedAt = DateTime.now();

        // 限制历史长度
        if (session.messages.length > 20) {
          session.messages.removeRange(0, session.messages.length - 20);
        }

        _isProcessing = false;
        _currentClient = null;
        _persistSessions();
        notifyListeners();
        return content;
      } else {
        _isProcessing = false;
        _currentClient = null;
        notifyListeners();
        return 'API 请求失败：${response.statusCode} ${response.body}';
      }
    } catch (e) {
      _isProcessing = false;
      _currentClient = null;
      notifyListeners();
      if (e.toString().contains('Client is already closed') ||
          e.toString().contains('Connection closed')) {
        return '已停止生成';
      }
      return '网络错误：$e';
    }
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
你是 Yanler 浏览器的内置 AI 代理助手。

【最高原则】用户拥有最高控制权：
- 你的所有浏览器操作都必须以命令形式输出，由前端弹出确认框交给用户批准；
- 用户随时可以停止你的任务，用户的终止指令优先于一切；
- 未经用户明确要求，不得执行任何修改类操作（删除、关闭、清空等）。

你的能力包括：
1. 搜索：帮用户搜索网页内容
2. 书签管理：添加、删除、查看书签
3. 历史记录：查看和清除浏览历史
4. 标签管理：打开新标签、切换标签、关闭标签
5. 设置管理：更改搜索引擎、主题、隐私设置等
6. 广告过滤：开关广告过滤功能

请用中文回复，风格简洁友好。
执行浏览器操作时，请输出以下可执行命令格式（每行一个）：
- [SEARCH: 查询内容]
- [OPEN_URL: https://...]
- [NEW_TAB: url]
- [CLOSE_TAB: tab_id]
- [BOOKMARK_ADD: 标题, url]
- [BOOKMARK_LIST]
- [BOOKMARK_DELETE: 书签id]
- [HISTORY_CLEAR]
- [SETTING: 设置项, 值]
- [ADBLOCK_TOGGLE]
- [THEME_TOGGLE]
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

  void clearApiConfig() {
    clearApiKey();
  }
}
