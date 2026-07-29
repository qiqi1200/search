import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AIProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String _apiKey = '';
  String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  String _model = 'gpt-3.5-turbo';
  bool _agentMode = false;
  bool _isProcessing = false;
  List<Map<String, String>> _messages = [];

  String get apiKey => _apiKey;
  String get apiUrl => _apiUrl;
  String get model => _model;
  bool get agentMode => _agentMode;
  bool get isProcessing => _isProcessing;
  bool get isConfigured => _apiKey.isNotEmpty;

  AIProvider() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    _apiKey = await _secureStorage.read(key: 'ai_api_key') ?? '';
    _apiUrl = await _secureStorage.read(key: 'ai_api_url') ??
        'https://api.openai.com/v1/chat/completions';
    _model = await _secureStorage.read(key: 'ai_model') ?? 'gpt-3.5-turbo';
    _agentMode =
        (await SharedPreferences.getInstance()).getBool('ai_agent_mode') ?? false;
    notifyListeners();
  }

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

  /// 向 AI 发送消息（支持代理模式）
  Future<String> sendMessage(String message) async {
    if (!isConfigured) {
      return '请先在设置中配置 API Key';
    }

    _isProcessing = true;
    notifyListeners();

    final systemPrompt = _agentMode
        ? _buildAgentSystemPrompt()
        : '你是一个友好的 AI 助手，帮助用户解答问题。请用中文回复。';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            ..._messages,
            {'role': 'user', 'content': message},
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        _messages.add({'role': 'user', 'content': message});
        _messages.add({'role': 'assistant', 'content': content});

        // 限制历史长度
        if (_messages.length > 20) {
          _messages = _messages.sublist(_messages.length - 20);
        }

        _isProcessing = false;
        notifyListeners();
        return content;
      } else {
        _isProcessing = false;
        notifyListeners();
        return 'API 请求失败：${response.statusCode} ${response.body}';
      }
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      return '网络错误：$e';
    }
  }

  /// 构建 AI 代理的系统提示 — 赋予 AI 管理浏览器的权限
  String _buildAgentSystemPrompt() {
    return '''
你是 Yanler 浏览器的内置 AI 代理助手。你拥有管理浏览器的全部权限。

你的能力包括：
1. 搜索：你可以帮用户搜索网页内容
2. 书签管理：添加、删除、查看书签
3. 历史记录：查看和清除浏览历史
4. 标签管理：打开新标签、切换标签、关闭标签
5. 设置管理：更改搜索引擎、主题、隐私设置等
6. 广告过滤：开关广告过滤功能
7. 浏览器配置：修改所有浏览器设置

请用中文回复，风格简洁友好。
当用户请求执行浏览器操作时，请给出明确的指令格式，以便前端解析执行。

可执行命令格式：
- [SEARCH: 查询内容]
- [OPEN_URL: https://...]
- [BOOKMARK_ADD: 标题, url]
- [BOOKMARK_LIST]
- [BOOKMARK_DELETE: 书签id]
- [HISTORY_CLEAR]
- [SETTING: 设置项, 值]
- [ADBLOCK_TOGGLE]
- [NEW_TAB: url]
- [CLOSE_TAB: tab_id]
- [THEME_TOGGLE]
''';
  }

  /// 执行浏览器操作（由 UI 层解析执行）
  String? extractCommand(String response) {
    final regex = RegExp(r'\[(\w+):?\s*(.*?)\]');
    final match = regex.firstMatch(response);
    return match?.group(0);
  }

  void clearHistory() {
    _messages.clear();
    notifyListeners();
  }
}
