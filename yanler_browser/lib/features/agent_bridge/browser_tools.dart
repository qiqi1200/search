import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/utils/nav_bus.dart';
import '../../providers/browser_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/search_engines.dart';
import '../../features/bookmarks/bookmark_service.dart';
import '../../features/history/history_service.dart';

/// 浏览器 MCP 工具描述
class MCPTool {
  final String name;
  final String description;
  final Map<String, Object> inputSchema;

  const MCPTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  Map<String, Object> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// 单个工具调用的结果
class ToolResult {
  final bool isError;
  final String text;

  const ToolResult.success(this.text) : isError = false;
  const ToolResult.error(this.text) : isError = true;

  List<Map<String, Object>> toContent() => [
        {'type': 'text', 'text': text},
      ];
}

/// 浏览器工具执行器 — 全部能力收敛在浏览器内部
///
/// 安全模型：Agent 只拿到这组工具（标签/搜索/书签/历史/设置/页面读取），
/// 没有 shell / 文件 / 系统网络工具，职能天然锁死在浏览器内。
class BrowserTools {
  final BrowserProvider browser;
  final SettingsProvider settings;
  final BookmarkService bookmarks;
  final HistoryService history;

  BrowserTools({
    required this.browser,
    required this.settings,
    required this.bookmarks,
    required this.history,
  });

  /// 当前活动标签页的 WebView 控制器（来自 NavBus，页面级操作用）
  BrowserController? get webViewController => NavBus.active;

  static const List<MCPTool> _definitions = [
    MCPTool(
      name: 'browser.list_tabs',
      description: '列出所有标签页（id/标题/URL/是否激活）',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'browser.open_tab',
      description: '在新标签页打开网址',
      inputSchema: {
        'type': 'object',
        'properties': {'url': {'type': 'string', 'description': '完整网址，如 https://example.com'}},
        'required': ['url'],
      },
    ),
    MCPTool(
      name: 'browser.close_tab',
      description: '关闭指定标签页（tabId 为列表中的索引）',
      inputSchema: {
        'type': 'object',
        'properties': {'tabId': {'type': 'integer'}},
        'required': ['tabId'],
      },
    ),
    MCPTool(
      name: 'browser.switch_tab',
      description: '切换到指定标签页',
      inputSchema: {
        'type': 'object',
        'properties': {'tabId': {'type': 'integer'}},
        'required': ['tabId'],
      },
    ),
    MCPTool(
      name: 'browser.search',
      description: '使用当前默认搜索引擎搜索关键词',
      inputSchema: {
        'type': 'object',
        'properties': {'query': {'type': 'string'}},
        'required': ['query'],
      },
    ),
    MCPTool(
      name: 'browser.navigate',
      description: '在当前标签页导航到指定网址',
      inputSchema: {
        'type': 'object',
        'properties': {'url': {'type': 'string'}},
        'required': ['url'],
      },
    ),
    MCPTool(
      name: 'browser.back',
      description: '当前标签页后退',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'browser.forward',
      description: '当前标签页前进',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'browser.reload',
      description: '刷新当前标签页',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'browser.get_active_tab',
      description: '获取当前激活标签页的 URL 和标题',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'browser.get_page_text',
      description: '读取当前页面正文文本（AI 阅读理解网页内容用）',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'browser.click',
      description: '点击页面元素（CSS 选择器，如 button[type=submit]、a[href*=news]）',
      inputSchema: {
        'type': 'object',
        'properties': {'selector': {'type': 'string', 'description': 'CSS 选择器'}},
        'required': ['selector'],
      },
    ),
    MCPTool(
      name: 'browser.type',
      description: '向页面输入框输入文字（CSS 选择器定位输入框）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'selector': {'type': 'string', 'description': 'CSS 选择器，如 input[name=q]'},
          'text': {'type': 'string', 'description': '要输入的文字'},
        },
        'required': ['selector', 'text'],
      },
    ),
    MCPTool(
      name: 'browser.scroll',
      description: '滚动当前页面（up/down/top/bottom）',
      inputSchema: {
        'type': 'object',
        'properties': {'direction': {'type': 'string', 'enum': ['up', 'down', 'top', 'bottom']}},
        'required': ['direction'],
      },
    ),
    MCPTool(
      name: 'browser.get_page_screenshot',
      description: '截取当前页面（返回 base64 PNG，AI 看图用）',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'bookmarks.list',
      description: '列出全部书签',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'bookmarks.add',
      description: '添加书签',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'url': {'type': 'string'},
        },
        'required': ['title', 'url'],
      },
    ),
    MCPTool(
      name: 'bookmarks.remove',
      description: '按 id 删除书签',
      inputSchema: {
        'type': 'object',
        'properties': {'id': {'type': 'string'}},
        'required': ['id'],
      },
    ),
    MCPTool(
      name: 'history.list',
      description: '列出历史记录（可带关键词过滤）',
      inputSchema: {
        'type': 'object',
        'properties': {'query': {'type': 'string'}},
        'required': [],
      },
    ),
    MCPTool(
      name: 'history.clear',
      description: '清空全部历史记录',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'settings.get',
      description: '读取浏览器设置（searchEngine/theme/adblock/wallpaper/homepage）',
      inputSchema: {
        'type': 'object',
        'properties': {'key': {'type': 'string'}},
        'required': ['key'],
      },
    ),
    MCPTool(
      name: 'settings.set',
      description: '修改浏览器设置（searchEngine/theme/adblock/wallpaper/homepage）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'key': {'type': 'string'},
          'value': {'type': 'string'},
        },
        'required': ['key', 'value'],
      },
    ),
    MCPTool(
      name: 'adblock.status',
      description: '查询广告过滤状态',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
    MCPTool(
      name: 'adblock.toggle',
      description: '切换广告过滤开关',
      inputSchema: {'type': 'object', 'properties': {}, 'required': []},
    ),
  ];

  List<MCPTool> get tools => _definitions;

  /// 执行工具调用。name 为工具名，args 为参数（JSON）。
  Future<ToolResult> call(String name, Map<String, Object?> args) async {
    try {
      switch (name) {
        case 'browser.list_tabs':
          return ToolResult.success(jsonEncode(browser.tabs.asMap().entries.map((e) => {
                'tabId': e.key,
                'title': e.value.title,
                'url': e.value.url,
                'active': e.key == browser.activeTabIndex,
                'loading': e.value.isLoading,
              }).toList()));
        case 'browser.open_tab':
          final url = _str(args, 'url');
          if (url.isEmpty) return const ToolResult.error('缺少 url 参数');
          browser.addTab(url: _normalizeUrl(url));
          return ToolResult.success('已在新标签页打开 $url');
        case 'browser.close_tab':
          final id = args['tabId'];
          if (id is! num) return const ToolResult.error('缺少 tabId 参数');
          browser.closeTab(id.toInt());
          return ToolResult.success('已关闭标签页 ${id.toInt()}');
        case 'browser.switch_tab':
          final id = args['tabId'];
          if (id is! num) return const ToolResult.error('缺少 tabId 参数');
          browser.switchTab(id.toInt());
          return ToolResult.success('已切换到标签页 ${id.toInt()}');
        case 'browser.search':
          final q = _str(args, 'query');
          if (q.isEmpty) return const ToolResult.error('缺少 query 参数');
          final engine = SearchEngines.byName(settings.searchEngine);
          browser.updateTabUrl(browser.activeTabIndex, '${engine.url}${Uri.encodeComponent(q)}');
          return ToolResult.success('已搜索：$q（引擎：${engine.name}）');
        case 'browser.navigate':
          final url = _str(args, 'url');
          if (url.isEmpty) return const ToolResult.error('缺少 url 参数');
          browser.updateTabUrl(browser.activeTabIndex, _normalizeUrl(url));
          return ToolResult.success('正在导航到 $url');
        case 'browser.back':
          await _controllerCall('goBack');
          return const ToolResult.success('已后退');
        case 'browser.forward':
          await _controllerCall('goForward');
          return const ToolResult.success('已前进');
        case 'browser.reload':
          await _controllerCall('reload');
          return const ToolResult.success('已刷新');
        case 'browser.get_active_tab':
          final tab = browser.activeTab;
          return ToolResult.success(jsonEncode({
            'title': tab?.title ?? '',
            'url': tab?.url ?? '',
            'loading': tab?.isLoading ?? false,
          }));
        case 'browser.get_page_text':
          return await _evalJs('(function(){return document.body ? document.body.innerText.slice(0, 20000) : ""})()');
        case 'browser.click':
          final sel = _str(args, 'selector');
          if (sel.isEmpty) return const ToolResult.error('缺少 selector 参数');
          return await _evalJs(
              '(function(){var el=document.querySelector(${_jsQuote(sel)});'
              'if(!el) return "NOT_FOUND: $sel"; el.click(); return "CLICKED: $sel";})()');
        case 'browser.type':
          final sel = _str(args, 'selector');
          final text = _str(args, 'text');
          if (sel.isEmpty) return const ToolResult.error('缺少 selector 参数');
          return await _evalJs(
              '(function(){var el=document.querySelector(${_jsQuote(sel)});'
              'if(!el) return "NOT_FOUND: $sel"; el.focus(); el.value=${_jsQuote(text)};'
              'el.dispatchEvent(new Event("input",{bubbles:true}));'
              'el.dispatchEvent(new Event("change",{bubbles:true})); return "TYPED";})()');
        case 'browser.scroll':
          final dir = _str(args, 'direction');
          return await _evalJs(
              '(function(){var d=${_jsQuote(dir)};'
              'if(d==="top")window.scrollTo(0,0);'
              'else if(d==="bottom")window.scrollTo(0,document.body?document.body.scrollHeight:0);'
              'else window.scrollBy(0, d==="up"?-window.innerHeight*0.8:window.innerHeight*0.8);'
              'return "SCROLLED:"+d;})()');
        case 'browser.get_page_screenshot':
          final shot = await _takeScreenshot();
          return ToolResult.success(shot);
        case 'bookmarks.list':
          return ToolResult.success(jsonEncode(bookmarks.bookmarks
              .map((b) => {'id': b.id, 'title': b.title, 'url': b.url})
              .toList()));
        case 'bookmarks.add':
          final title = _str(args, 'title');
          final url = _str(args, 'url');
          if (url.isEmpty) return const ToolResult.error('缺少 url 参数');
          await bookmarks.add(title.isEmpty ? url : title, _normalizeUrl(url));
          return const ToolResult.success('书签已添加');
        case 'bookmarks.remove':
          final id = _str(args, 'id');
          if (id.isEmpty) return const ToolResult.error('缺少 id 参数');
          await bookmarks.remove(id);
          return const ToolResult.success('书签已删除');
        case 'history.list':
          final q = _str(args, 'query');
          final items = q.isEmpty ? history.history : history.search(q);
          return ToolResult.success(jsonEncode(items
              .take(100)
              .map((h) => {'title': h.title, 'url': h.url, 'visitedAt': h.visitedAt.toIso8601String()})
              .toList()));
        case 'history.clear':
          await history.clear();
          return const ToolResult.success('历史已清空');
        case 'settings.get':
          return ToolResult.success(jsonEncode({'value': _getSetting(_str(args, 'key'))}));
        case 'settings.set':
          await _setSetting(_str(args, 'key'), _str(args, 'value'));
          return const ToolResult.success('设置已更新');
        case 'adblock.status':
          return ToolResult.success(jsonEncode({'enabled': settings.adblockEnabled}));
        case 'adblock.toggle':
          settings.setAdblockEnabled(!settings.adblockEnabled);
          return ToolResult.success('广告过滤已${settings.adblockEnabled ? '开启' : '关闭'}');
        default:
          return ToolResult.error('未知工具：$name');
      }
    } catch (e, st) {
      debugPrint('MCP tool $name error: $e\n$st');
      return ToolResult.error('执行失败：$e');
    }
  }

  // ==================== 内部辅助 ====================

  String _str(Map<String, Object?> args, String key) =>
      (args[key] as String? ?? '').trim();

  String _normalizeUrl(String input) {
    if (input.startsWith('http://') || input.startsWith('https://')) return input;
    if (input.contains('.') && !input.contains(' ')) return 'https://$input';
    final engine = SearchEngines.byName(settings.searchEngine);
    return '${engine.url}${Uri.encodeComponent(input)}';
  }

  String _getSetting(String key) {
    switch (key) {
      case 'searchEngine':
        return settings.searchEngine;
      case 'theme':
        return settings.isDarkMode ? 'dark' : 'light';
      case 'adblock':
        return settings.adblockEnabled ? 'true' : 'false';
      case 'wallpaper':
        return settings.wallpaperId;
      case 'homepage':
        return settings.homepage;
      default:
        return '未知设置项：$key（可用：searchEngine/theme/adblock/wallpaper/homepage）';
    }
  }

  Future<void> _setSetting(String key, String value) async {
    switch (key) {
      case 'searchEngine':
        await settings.setSearchEngine(value);
      case 'theme':
        await settings.setThemeMode(value.contains('dark') ? ThemeMode.dark : ThemeMode.light);
      case 'adblock':
        await settings.setAdblockEnabled(value == 'true' || value == '1');
      case 'wallpaper':
        await settings.setWallpaper(value);
      case 'homepage':
        await settings.setHomepage(value);
    }
  }

  /// 调用 WebView 控制器方法（导航类）
  Future<void> _controllerCall(String method) async {
    final c = NavBus.active;
    if (c == null) throw StateError('WebView 未就绪（当前可能在新标签页）');
    switch (method) {
      case 'goBack':
        await c.goBack();
      case 'goForward':
        await c.goForward();
      case 'reload':
        await c.reload();
    }
  }

  Future<ToolResult> _evalJs(String script) async {
    final c = NavBus.active;
    if (c == null) return const ToolResult.error('WebView 未就绪（当前可能在新标签页）');
    try {
      final result = await c.evaluateJavascript(script);
      return ToolResult.success(result ?? '');
    } catch (e) {
      return ToolResult.error('读取页面失败：$e');
    }
  }

  Future<String> _takeScreenshot() async {
    final c = NavBus.active;
    if (c == null) throw StateError('WebView 未就绪');
    final shot = await c.takeScreenshot();
    if (shot == null) throw StateError('截图失败');
    return base64Encode(shot);
  }

  /// 转义为安全的 JS 字符串字面量
  static String _jsQuote(String s) {
    final escaped = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
    return '"$escaped"';
  }
}
