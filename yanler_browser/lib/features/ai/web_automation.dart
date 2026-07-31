import '../../core/utils/nav_bus.dart';

/// 网页自动化 — AI Agent 屏幕操控能力层
///
/// 通过向当前活动 WebView 注入 JS，实现：
/// - 网页元素识别（PAGE_INFO）：提取标题/链接/按钮/输入框
/// - 屏幕模拟点击（CLICK）：按选择器或文本定位并点击
/// - 输入（TYPE）：向输入框填入文本并触发 input/change
/// - 滑动（SCROLL）：上/下/顶部/底部
/// - 任意 JS（JS）：高级自定义操作
///
/// 所有操作都要求用户批准后才执行（最高控制权），见 AIChatScreen。
class WebAutomation {
  WebAutomation._();

  /// 网页元素识别：返回标题/URL/链接/按钮/输入框的 JSON
  static Future<String?> getPageInfo() => _run(_kGetPageInfo);

  /// 按选择器或文本点击元素
  static Future<String?> click(String target) =>
      _run('($_kClick)(JSON.stringify(__yanlerClick(${_quote(target)})));');

  /// 向输入框填入文本（选择器或占位符/名称定位）
  static Future<String?> type(String target, String text) =>
      _run('($_kType)(JSON.stringify(__yanlerType(${_quote(target)}, ${_quote(text)})));');

  /// 滚动：down / up / top / bottom
  static Future<String?> scroll(String direction) =>
      _run('($_kScroll)(JSON.stringify(__yanlerScroll(${_quote(direction)})));');

  /// 任意 JS，返回结果字符串
  static Future<String?> evaluate(String script) =>
      _run('($_kEval)(JSON.stringify($script));');

  static Future<String?> _run(String script) async {
    final controller = NavBus.active;
    if (controller == null) return null;
    return controller.evaluateJavascript(script);
  }

  static String _quote(String s) =>
      "'${s.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'";

  // ==================== JS 注入脚本 ====================

  /// 元素识别
  static const String _kGetPageInfo = '''
  __yanlerGetPageInfo = function() {
    var links = Array.from(document.querySelectorAll('a'))
      .map(function(a){ return { text: (a.innerText||'').trim().slice(0,60), href: a.href }; })
      .filter(function(l){ return l.text && l.href && !l.href.startsWith('javascript:'); })
      .slice(0, 30);
    var buttons = Array.from(document.querySelectorAll('button, [role="button"], input[type="submit"], input[type="button"]'))
      .map(function(b){ return (b.innerText||b.value||'').trim(); })
      .filter(Boolean).slice(0, 20);
    var inputs = Array.from(document.querySelectorAll('input[type="text"], input[type="search"], input:not([type]), textarea'))
      .map(function(i){ return { placeholder: i.placeholder||'', name: i.name||'', id: i.id||'' }; })
      .filter(function(i){ return i.placeholder || i.name || i.id; })
      .slice(0, 20);
    return JSON.stringify({
      title: document.title || '',
      url: location.href,
      links: links,
      buttons: buttons,
      inputs: inputs
    });
  };
  JSON.stringify(__yanlerGetPageInfo());
  ''';

  /// 点击
  static const String _kClick = '''
  __yanlerClick = function(target) {
    try {
      var bySel = document.querySelector(target);
      if (bySel) { bySel.click(); return { ok: true, method: 'selector', target: target }; }
      var els = Array.from(document.querySelectorAll('a,button,[role="button"],input[type="button"],input[type="submit"],span,div,li'));
      var exact = els.find(function(e){ return (e.innerText||e.value||'').trim() === target; });
      if (exact) { exact.click(); return { ok: true, method: 'text-exact', target: target }; }
      var partial = els.find(function(e){ return (e.innerText||e.value||'').indexOf(target) >= 0; });
      if (partial) { partial.click(); return { ok: true, method: 'text-contains', target: target }; }
      return { ok: false, reason: 'NOT_FOUND', target: target };
    } catch (e) { return { ok: false, reason: String(e), target: target }; }
  };
  __yanlerClick
  ''';

  /// 输入
  static const String _kType = '''
  __yanlerType = function(target, text) {
    try {
      var el = document.querySelector(target);
      if (!el) {
        var inputs = Array.from(document.querySelectorAll('input[type="text"], input[type="search"], input:not([type]), textarea'));
        el = inputs.find(function(i){
          return (i.placeholder||'') === target || (i.name||'') === target || (i.id||'') === target ||
                 (i.placeholder||'').indexOf(target) >= 0;
        });
      }
      if (!el) return { ok: false, reason: 'INPUT_NOT_FOUND', target: target };
      el.focus();
      var proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
      var setter = Object.getOwnPropertyDescriptor(proto, 'value');
      if (setter && setter.set) setter.set.call(el, text);
      else el.value = text;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return { ok: true, where: (el.placeholder||el.name||el.id||'input') };
    } catch (e) { return { ok: false, reason: String(e) }; }
  };
  __yanlerType
  ''';

  /// 滚动
  static const String _kScroll = '''
  __yanlerScroll = function(dir) {
    try {
      if (dir === 'top') window.scrollTo(0, 0);
      else if (dir === 'bottom') window.scrollTo(0, document.body.scrollHeight);
      else if (dir === 'up') window.scrollBy(0, -window.innerHeight * 0.8);
      else if (dir === 'down') window.scrollBy(0, window.innerHeight * 0.8);
      else return { ok: false, reason: 'BAD_DIRECTION', dir: dir };
      return { ok: true, dir: dir };
    } catch (e) { return { ok: false, reason: String(e) }; }
  };
  __yanlerScroll
  ''';

  /// 任意 JS 求值
  static const String _kEval = '''
  __yanlerEval = function(expr) {
    try {
      var v = eval(expr);
      if (v === undefined) return '';
      if (typeof v === 'object') { try { return JSON.stringify(v); } catch(e) { return String(v); } }
      return String(v);
    } catch (e) { return 'JS_ERROR: ' + e; }
  };
  __yanlerEval
  ''';
}
