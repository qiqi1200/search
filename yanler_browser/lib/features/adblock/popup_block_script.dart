/// 通用弹窗广告屏蔽脚本 — 注入到所有页面（受设置开关 popupBlockEnabled 控制）
///
/// 基于 ReadingModeService.cleanScript 抽取的精简通用版：
/// - 移除 fixed/absolute 高 z-index 的遮罩层与浮窗广告
/// - 移除常见广告 class/id（带正文豁免，不误杀正文）
/// - MutationObserver 持续清理动态插入的弹窗
/// - 恢复被弹窗锁定的滚动
/// - 顶部幂等守卫 `__yanlerPopupBlocked`：同一页面只执行一次，
///   与洁净浏览模式脚本共存时不会重复挂载。
///
/// 阈值比洁净模式保守（遮罩 >40% 视口 / 小浮窗 180~260px 且 z>99999），
/// 减少对普通网站正规弹窗（登录层等）的误杀。
class PopupBlockScript {
  static String get cleanScript => '''
(function() {
  if (window.__yanlerPopupBlocked) return 'already';
  window.__yanlerPopupBlocked = true;
  'use strict';

  // 1. 移除 fixed/absolute 定位的高层遮罩广告（仅保留「覆盖视口 40%+ 的遮罩」判定，
  //    不做按固定尺寸/小浮窗判定——避免误伤正文 fixed 小元素与正常图片）
  var removeFloating = function() {
    var all = document.querySelectorAll('*');
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      // 正文内元素豁免
      if (el.closest('article') || el.closest('.content') || el.closest('.chapter-content')) continue;
      var style = window.getComputedStyle(el);
      var pos = style.position;
      var zIndex = parseInt(style.zIndex) || 0;
      if ((pos === 'fixed' || pos === 'absolute') && zIndex > 999) {
        var rect = el.getBoundingClientRect();
        var area = rect.width * rect.height;
        var viewArea = window.innerWidth * window.innerHeight;
        // 覆盖面积超过视口 40% → 遮罩广告
        if (area > viewArea * 0.4) { el.remove(); }
      }
    }
  };

  // 2. 移除精确类名广告弹层（白名单，不用 [class*="x"] / [id*="x"] 属性包含
  //    选择器——那会误命中 loading/header/sidebar 等正常元素，隐藏正文图片）
  var adSelectors = [
    '.popup', '.modal', '.overlay', '.mask', '.float-ad', '.floating',
    '.sidebar-ad', '.download-app', '.app-download', '.open-app',
    '.guide-download', '.read-more-mask',
    '.layui-layer', '.layer-mask', '.weui-mask', '.weui-dialog',
  ];
  adSelectors.forEach(function(sel) {
    try {
      Array.prototype.forEach.call(document.querySelectorAll(sel), function(el) {
        if (el.closest('article') || el.closest('.content') || el.closest('.chapter-content')) return;
        el.remove();
      });
    } catch(e) {}
  });

  // 3. 恢复被弹窗锁定的滚动
  document.body.style.overflow = 'auto';
  document.documentElement.style.overflow = 'auto';
  document.body.style.position = '';
  document.body.style.top = '';

  removeFloating();

  // 4. MutationObserver 持续清理动态插入的弹窗
  if (window.MutationObserver) {
    var observer = new MutationObserver(function(mutations) {
      var needClean = false;
      mutations.forEach(function(m) {
        m.addedNodes.forEach(function(node) {
          if (node.nodeType === 1) {
            var st = window.getComputedStyle(node);
            if (st.position === 'fixed' && (parseInt(st.zIndex) || 0) > 999) {
              needClean = true;
            }
          }
        });
      });
      if (needClean) removeFloating();
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  return 'popup_block_done';
})();
''';
}
