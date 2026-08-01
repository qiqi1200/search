import '../adblock/popup_block_script.dart';

/// 洁净浏览模式 — 阅读页自动去广告/弹窗/浮层
///
/// 在页面加载完成后注入清理脚本，移除：
/// - 固定定位浮层（fixed/absolute 广告）
/// - 弹窗遮罩（overlay/modal）
/// - 悬浮客服/下载提示
/// - 正文外的推广区块
///
/// 清理脚本已委派给 `PopupBlockScript.cleanScript`（带幂等守卫，
/// 与全局弹窗屏蔽共享同一脚本，避免两处实现漂移）。
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

  /// 洁净模式注入脚本 — 委派到通用弹窗屏蔽脚本（幂等守卫防重复挂载）
  static String get cleanScript => PopupBlockScript.cleanScript;

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
