import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/nav_bus.dart';
import '../../providers/ai_provider.dart';
import '../../providers/browser_provider.dart';
import '../../providers/settings_provider.dart';
import '../bookmarks/bookmark_service.dart';
import '../history/history_service.dart';
import '../search/search_service.dart';
import 'web_automation.dart';

/// 确认回调：用户批准后才执行（最高控制权）
typedef AgentConfirm = Future<bool> Function(String desc);

/// 轻提示回调
typedef AgentToast = void Function(String msg);

/// 执行一条 Agent 命令（SEARCH / OPEN_URL / CLICK / TYPE / SCROLL …）。
///
/// 命令执行后的真实结果会通过 [AIProvider.continueWithToolResult] 回传 AI，
/// 让其基于真实页面继续「搜索→定位→执行」全链路任务。
///
/// 返回 `true` 表示执行过程中注入了工具结果（AI 大概率产出了新回复，
/// 调用方应重新提取下一轮命令等待用户批准）。
///
/// 设计原则：每个操作都先弹确认框（confirm），用户拥有最高控制权。
Future<bool> executeAgentCommand(
  BuildContext context,
  String cmd, {
  required AgentConfirm confirm,
  required AgentToast toast,
}) async {
  final match = RegExp(r'\[(\w+):?\s*(.*?)\]').firstMatch(cmd);
  if (match == null) return false;
  final type = match.group(1)!.toUpperCase();
  final arg = (match.group(2) ?? '').trim();

  final ai = context.read<AIProvider>();
  final settings = context.read<SettingsProvider>();
  final browser = context.read<BrowserProvider>();
  final bookmarks = context.read<BookmarkService>();
  final history = context.read<HistoryService>();

  switch (type) {
    // ==================== 网页操控（屏幕交互） ====================
    case 'PAGE_INFO':
      if (!await confirm('读取当前网页信息')) return false;
      final info = await WebAutomation.getPageInfo();
      if (info == null || info.isEmpty || info == 'null') {
        toast('当前没有可读取的网页');
        return false;
      }
      await ai.continueWithToolResult('读取到以下网页信息：\n$info');
      return true;

    case 'CLICK':
      if (!await confirm('点击页面元素：$arg')) return false;
      final result = await WebAutomation.click(arg);
      if (result == null || result == 'null') {
        toast('当前没有可操作的网页');
        return false;
      }
      await ai.continueWithToolResult('点击结果：$result');
      return true;

    case 'TYPE':
      // 参数「输入框占位符/选择器, 要输入的文字」（仅按第一个逗号拆分）
      final sep = arg.indexOf(',');
      final target = (sep >= 0 ? arg.substring(0, sep) : arg).trim();
      final text = (sep >= 0 ? arg.substring(sep + 1) : '').trim();
      if (target.isEmpty || text.isEmpty) {
        toast('输入指令格式应为 [TYPE: 输入框, 内容]');
        return false;
      }
      if (!await confirm('在「$target」输入：$text')) return false;
      final typeResult = await WebAutomation.type(target, text);
      if (typeResult == null || typeResult == 'null') {
        toast('当前没有可操作的网页');
        return false;
      }
      await ai.continueWithToolResult('输入结果：$typeResult');
      return true;

    case 'SCROLL':
      if (!await confirm('滚动页面：$arg')) return false;
      final scrollResult = await WebAutomation.scroll(arg);
      if (scrollResult == null || scrollResult == 'null') {
        toast('当前没有可操作的网页');
        return false;
      }
      await ai.continueWithToolResult('滚动结果：$scrollResult');
      return true;

    case 'JS':
      if (!await confirm('执行自定义脚本：$arg')) return false;
      final jsResult = await WebAutomation.evaluate(arg);
      if (jsResult == null || jsResult == 'null') {
        toast('当前没有可操作的网页');
        return false;
      }
      await ai.continueWithToolResult('脚本执行结果：$jsResult');
      return true;

    // ==================== 搜索 / 打开网页 ====================
    case 'SEARCH':
      if (!await confirm('搜索：$arg')) return false;
      final searchUrl = SearchService.normalizeInput(arg, settings.searchEngine);
      if (searchUrl.isEmpty) return false;
      if (browser.activeTabIndex >= 0) {
        browser.updateTabUrl(browser.activeTabIndex, searchUrl);
      }
      final container = NavBus.active;
      if (container != null) {
        await container.loadUrl(searchUrl);
        await container.refreshNavigationState();
      }
      return false;

    case 'OPEN_URL':
    case 'NEW_TAB':
      if (!await confirm('打开网页：$arg')) return false;
      final openUrl = SearchService.normalizeInput(arg, settings.searchEngine);
      if (openUrl.isEmpty) return false;
      browser.addTab(url: openUrl);
      return false;

    // ==================== 书签 / 历史 / 设置 / 标签 ====================
    case 'BOOKMARK_ADD':
      final parts = arg.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2 && await confirm('添加书签：${parts[0]}')) {
        bookmarks.add(parts[0], parts[1]);
        toast('书签已添加');
      }
      return false;

    case 'BOOKMARK_LIST':
      if (await confirm('查看书签列表')) {
        if (context.mounted) {
          _showBookmarkList(context, bookmarks);
        }
      }
      return false;

    case 'BOOKMARK_DELETE':
      if (await confirm('删除书签：$arg')) {
        bookmarks.remove(arg);
        toast('书签已删除');
      }
      return false;

    case 'HISTORY_CLEAR':
      if (await confirm('清空全部浏览历史')) {
        history.clear();
        toast('历史已清空');
      }
      return false;

    case 'SETTING':
      final parts = arg.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2 &&
          await confirm('修改设置：${parts[0]} → ${parts[1]}')) {
        _applySetting(settings, parts[0], parts[1]);
      }
      return false;

    case 'ADBLOCK_TOGGLE':
      if (await confirm('切换广告过滤')) {
        settings.setAdblockEnabled(!settings.adblockEnabled);
        toast('广告过滤已${settings.adblockEnabled ? '开启' : '关闭'}');
      }
      return false;

    case 'THEME_TOGGLE':
      if (await confirm('切换深浅主题')) {
        settings.toggleTheme();
      }
      return false;

    case 'CLOSE_TAB':
      if (await confirm('关闭标签页：$arg')) {
        final idx = browser.tabs.indexWhere(
          (t) => t.id == arg || t.title.contains(arg),
        );
        if (idx >= 0) browser.closeTab(idx);
      }
      return false;
  }

  return false;
}

void _applySetting(SettingsProvider settings, String key, String value) {
  final k = key.toLowerCase();
  if (k.contains('engine')) {
    settings.setSearchEngine(value);
  } else if (k.contains('theme') || k.contains('dark')) {
    settings.setThemeMode(value.contains('dark') ? ThemeMode.dark : ThemeMode.light);
  } else if (k.contains('adblock')) {
    settings.setAdblockEnabled(value == 'true' || value == '1');
  }
}

void _showBookmarkList(BuildContext context, BookmarkService bookmarks) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('当前书签'),
      content: SizedBox(
        width: double.maxFinite,
        child: bookmarks.count == 0
            ? const Text('暂无书签')
            : ListView(
                shrinkWrap: true,
                children: bookmarks.bookmarks
                    .map((b) => ListTile(
                          dense: true,
                          title: Text(b.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(b.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            context.read<BrowserProvider>().addTab(url: b.url);
                          },
                        ))
                    .toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
