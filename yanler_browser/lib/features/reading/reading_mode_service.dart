/// 洁净浏览模式 — 阅读页自动去广告/弹窗/浮层
///
/// 在页面加载完成后注入清理脚本，移除：
/// - 固定定位浮层（fixed/absolute 广告）
/// - 弹窗遮罩（overlay/modal）
/// - 悬浮客服/下载提示
/// - 正文外的推广区块
///
/// 同时提供漫画/小说站无缝续读能力：
/// - 检测「下一章」链接
/// - 滚动到底部时自动预加载
class ReadingModeService {
  /// 判断 URL 是否属于阅读类页面（小说/新闻/文章/漫画）
  static bool isReadingPage(String url) {
    const readingHosts = [
      // 小说站
      'biquge', 'biqu', '69shu', 'xbiquge', 'bqg', 'shu69',
      'dingdian', 'kanunu', 'piaotian', 'qidian', 'zongheng',
      '17k.com', 'jjwxc', 'faloo', 'ciweimao',
      // 漫画站
      'manhua', 'comic', 'mangabz', 'dmzj', 'dongman',
      'copymanga', 'mangacopy', 'baozimh', 'acg.rip',
      'mhgui', 'manhuagui', 'manhuadb', 'ykmh',
      // 新闻/文章
      'zhihu.com/p/', 'jianshu.com/p/', 'mp.weixin',
      'toutiao.com/a', 'baijiahao', 'sohu.com/a',
      '163.com/dy', 'thepaper.cn', 'caixin.com',
    ];
    final lower = url.toLowerCase();
    return readingHosts.any((h) => lower.contains(h));
  }

  /// 判断是否为漫画站
  static bool isComicPage(String url) {
    const comicHosts = [
      'manhua', 'comic', 'mangabz', 'dmzj', 'dongman',
      'copymanga', 'mangacopy', 'baozimh', 'mhgui',
      'manhuagui', 'manhuadb', 'ykmh', 'acg.rip',
    ];
    final lower = url.toLowerCase();
    return comicHosts.any((h) => lower.contains(h));
  }

  /// 洁净模式注入脚本 — 移除浮层/弹窗/遮罩
  static String get cleanScript => '''
(function() {
  'use strict';
  
  // 1. 移除 fixed/absolute 定位的浮层广告
  var removeFloating = function() {
    var all = document.querySelectorAll('*');
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      var style = window.getComputedStyle(el);
      var pos = style.position;
      var zIndex = parseInt(style.zIndex) || 0;
      // 高层级固定/绝对定位元素（排除正文工具栏）
      if ((pos === 'fixed' || pos === 'absolute') && zIndex > 999) {
        var rect = el.getBoundingClientRect();
        // 覆盖面积超过视口 30% 视为遮罩广告
        var area = rect.width * rect.height;
        var viewArea = window.innerWidth * window.innerHeight;
        if (area > viewArea * 0.3) {
          el.remove();
          continue;
        }
        // 小浮窗（客服/下载/推广）
        if (rect.width < 200 && rect.height < 200 && zIndex > 9999) {
          el.remove();
        }
      }
    }
  };
  
  // 2. 移除常见广告 class/id
  var adSelectors = [
    '.ad', '.ads', '.advert', '.advertisement',
    '.popup', '.modal', '.overlay', '.mask',
    '.float-ad', '.floating', '.sidebar-ad',
    '.download-app', '.app-download', '.open-app',
    '.guide-download', '.read-more-mask',
    '[class*="popup"]', '[class*="modal"]',
    '[class*="overlay"]', '[class*="banner-ad"]',
    '[id*="popup"]', '[id*="modal"]', '[id*="mask"]',
    '[id*="float"]', '[id*="advert"]',
    '.layui-layer', '.layer-mask',
    '.weui-mask', '.weui-dialog',
  ];
  adSelectors.forEach(function(sel) {
    try {
      document.querySelectorAll(sel).forEach(function(el) {
        // 保留正文内的合理元素
        if (el.closest('article') || el.closest('.content') || el.closest('.chapter-content')) return;
        el.remove();
      });
    } catch(e) {}
  });
  
  // 3. 恢复页面滚动（部分站点锁定 body overflow）
  document.body.style.overflow = 'auto';
  document.documentElement.style.overflow = 'auto';
  document.body.style.position = '';
  document.body.style.top = '';
  
  // 4. 移除 body 上的遮罩层
  var bodyChildren = document.body.children;
  for (var j = bodyChildren.length - 1; j >= 0; j--) {
    var child = bodyChildren[j];
    var s = window.getComputedStyle(child);
    if (s.position === 'fixed' && s.display !== 'none') {
      var r = child.getBoundingClientRect();
      if (r.width > window.innerWidth * 0.5 && r.height > window.innerHeight * 0.3) {
        child.remove();
      }
    }
  }
  
  // 执行清理
  removeFloating();
  
  // 监听 DOM 变化，持续清理动态插入的广告
  if (window.MutationObserver) {
    var observer = new MutationObserver(function(mutations) {
      var needClean = false;
      mutations.forEach(function(m) {
        m.addedNodes.forEach(function(node) {
          if (node.nodeType === 1) {
            var st = window.getComputedStyle(node);
            if (st.position === 'fixed' && parseInt(st.zIndex) > 999) {
              needClean = true;
            }
          }
        });
      });
      if (needClean) removeFloating();
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }
  
  return 'clean_done';
})();
''';

  /// 漫画无缝续读脚本 — 检测下一章链接 + 滚动到底自动跳转
  static String get comicContinuationScript => '''
(function() {
  'use strict';
  
  // 查找「下一章」链接
  var nextKeywords = ['下一章', '下一页', '下一篇', 'next', 'next chapter', 'next page'];
  var nextLink = null;
  
  var links = document.querySelectorAll('a[href]');
  for (var i = 0; i < links.length; i++) {
    var text = (links[i].textContent || '').trim().toLowerCase();
    var href = links[i].getAttribute('href') || '';
    for (var k = 0; k < nextKeywords.length; k++) {
      if (text.indexOf(nextKeywords[k]) !== -1 && href && href !== '#' && href.indexOf('javascript') === -1) {
        nextLink = links[i].href;
        break;
      }
    }
    if (nextLink) break;
  }
  
  if (!nextLink) return JSON.stringify({hasNext: false});
  
  // 预加载下一章（后台 fetch 缓存）
  try {
    var prefetch = document.createElement('link');
    prefetch.rel = 'prefetch';
    prefetch.href = nextLink;
    document.head.appendChild(prefetch);
  } catch(e) {}
  
  // 滚动到底部 90% 时自动跳转
  var jumped = false;
  var onScroll = function() {
    if (jumped) return;
    var scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    var scrollHeight = document.documentElement.scrollHeight;
    var clientHeight = window.innerHeight;
    if (scrollTop + clientHeight >= scrollHeight * 0.9) {
      jumped = true;
      window.removeEventListener('scroll', onScroll);
      // 短暂延迟让用户看到底部
      setTimeout(function() {
        window.location.href = nextLink;
      }, 500);
    }
  };
  window.addEventListener('scroll', onScroll, {passive: true});
  
  return JSON.stringify({hasNext: true, nextUrl: nextLink});
})();
''';
}
