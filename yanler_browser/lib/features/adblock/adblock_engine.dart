import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdblockEngine extends ChangeNotifier {
  // ==================== 结构化规则存储 ====================
  // 域名规则 → Set（O(1) 主机匹配），杜绝旧版「对每条请求逐条子串扫描上万条规则」的卡顿；
  // 元素隐藏规则（##/#）无法用于请求拦截，直接跳过——旧版把它们当 URL 子串匹配，
  // 是误杀图片/整站（如 .ad / stat. / log. 子串）的头号元凶。
  final Set<String> _domainBlock = {};
  final Set<String> _domainException = {};
  final List<String> _urlBlock = []; // 精确 URL 子串（少量）
  final List<String> _urlException = []; // 精确 URL 例外（少量）

  static const int _maxDomainRules = 15000;
  static const int _maxExceptionRules = 5000;
  static const int _maxUrlRules = 2000;

  bool _isInitialized = false;
  bool _isEnabled = true;
  int _blockedCount = 0;
  final List<String> _blockedUrls = [];
  Timer? _throttleTimer;
  bool _dirty = false;

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  int get blockedCount => _blockedCount;
  List<String> get blockedUrls => List.unmodifiable(_blockedUrls);
  int get ruleCount =>
      _domainBlock.length + _domainException.length + _urlBlock.length;

  // ==================== 内置规则（精挑细选，只保留精确广告/追踪域名） ====================
  // 注意：只放「特定广告域名」，绝不放 bdimg.com / qlogo.cn / bdstatic.com 这类
  // 同时承载正常图片/静态资源的 CDN——那会直接打挂网页图片。
  static const List<String> _builtInDomains = [
    // Google / DoubleClick 广告
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'googletagmanager.com',
    'google-analytics.com',
    'googletagservices.com',
    'adservice.google.com',
    'pagead2.googlesyndication.com',
    'tpc.googlesyndication.com',
    'partner.googleadservices.com',
    'ad.doubleclick.net',
    'cm.g.doubleclick.net',
    'securepubads.g.doubleclick.net',
    'imasdk.googleapis.com',
    'gcdn.2mdn.net',
    // 中国广告联盟
    'cnzz.com',
    's21.cnzz.com',
    's22.cnzz.com',
    's23.cnzz.com',
    's24.cnzz.com',
    's25.cnzz.com',
    's26.cnzz.com',
    's27.cnzz.com',
    's28.cnzz.com',
    's29.cnzz.com',
    's30.cnzz.com',
    'hm.baidu.com',
    'pos.baidu.com',
    'cpro.baidu.com',
    'utk.baidu.com',
    'zz.bdstatic.com',
    'dup.baidustatic.com',
    'nsclick.baidu.com',
    'wangmeng.baidu.com',
    'eclick.baidu.com',
    'union.baidu.com',
    'cb.baidu.com',
    'als.baidu.com',
    'qingting.baidu.com',
    'fc.baidu.com',
    'ad.qq.com',
    'adserver.qq.com',
    'adsrv.qq.com',
    'gdt.qq.com',
    'btrace.qq.com',
    'adsame.qq.com',
    'adslvfile.qq.com',
    'adsfile.qq.com',
    'pindao.huopin.qq.com',
    'ad.3g.qq.com',
    'oth.eve.mdt.qq.com',
    'oth.str.mdt.qq.com',
    // 阿里巴巴 / 淘宝
    'tanx.com',
    'tanx.alimama.com',
    'alimama.com',
    'mmstat.com',
    'log.mmstat.com',
    'gm.mmstat.com',
    'cn.mmstat.com',
    's.mmstat.com',
    'srd.simba.taobao.com',
    'simba.taobao.com',
    'wuzei.taobao.com',
    'atb.apps.alimama.com',
    'atm.apps.alimama.com',
    // 字节跳动
    'pangolin-sdk-toutiao.com',
    'pangolin.snssdk.com',
    'pglstatp-toutiao.com',
    'ad.toutiao.com',
    'ad.snssdk.com',
    'dm.toutiao.com',
    'log.snssdk.com',
    'mon.snssdk.com',
    'analytics.snssdk.com',
    'is.snssdk.com',
    // 通用追踪器
    'connect.facebook.net',
    'analytics.twitter.com',
    'ads.linkedin.com',
    'bat.bing.com',
    'c.bing.com',
    'ib.adnxs.com',
    'secure.adnxs.com',
    'adnxs.com',
    'exelator.com',
    'scorecardresearch.com',
    'cloudflareinsights.com',
    // 广告网络
    'adzerk.net',
    'adsrvr.org',
    'serving-sys.com',
    'adsafeprotected.com',
    'moatads.com',
    'outbrain.com',
    'taboola.com',
    'taboolasyndication.com',
    'criteo.com',
    'criteo.net',
    'casalemedia.com',
    'pubmatic.com',
    'openx.net',
    'rubiconproject.com',
    'appnexus.com',
    'advertising.com',
    'tribalfusion.com',
    'turn.com',
    'contextweb.com',
    'indexww.com',
    'spotxchange.com',
    'adsmoloco.com',
    'innovid.com',
    'instreamatic.com',
    // 视频广告
    'adex.betweendigital.com',
    'adserver.adtech.de',
    'adserver.yahoo.com',
    'adserver.bing.com',
    'adserver.daum.net',
    'adserver.ebay.com',
    'adserver.kakao.com',
    'adserver.mediaplex.com',
    'adserver.msn.com',
    'adserver.nydailynews.com',
    'adserver.o2.pl',
    'adserver.skyrock.com',
    'adserver.tiscali.com',
    'adserver.virginmedia.com',
    'adserver.ynet.com',
    'vast.bp3858272.betweendigital.com',
    // 推送 / 客服挂件
    'onesignal.com',
    'pushwoosh.com',
    'pushalert.co',
    'notifyvisitors.com',
    'subiz.com',
    'tawk.to',
    'livechatinc.com',
    'olark.com',
    'intercom.com',
    'intercomcdn.com',
    'crisp.chat',
    'tidio.co',
    // 新闻 / 门户广告位
    'ad.flurry.com',
    'ad.12306.cn',
    'ad.caijing.com.cn',
    'ad.hefei.cc',
    'ad.sina.com.cn',
    'ad.sohu.com',
    'ad.360.cn',
    'ad.51.la',
    'ad.jxnews.com.cn',
    'ad.dzwww.com',
    'ad.xinhuanet.com',
    'ad.chinadaily.com.cn',
    'ad.rednet.cn',
    'ad.gmw.cn',
    'ad.thepaper.cn',
    'ad.17173.com',
    'ad.duowan.com',
    'ad.pconline.com.cn',
    'ad.zol.com.cn',
    'ad.pchome.net',
    'ad.ithome.com',
    'ad.cnbeta.com',
    'ad.mydrivers.com',
    'ad.newsmth.net',
    'ad.hupu.com',
    'ad.mop.com',
    // 视频站广告
    'ad.youku.com',
    'ad.tudou.com',
    'ad.iqiyi.com',
    'ad.bilibili.com',
    'ad.mgtv.com',
    'ad.letv.com',
    'ad.pptv.com',
    'ad.fun.tv',
    'ad.kankan.com',
    'ad.xunlei.com',
    'ad.56.com',
    'ad.6.cn',
    'ad.acfun.cn',
    'ad.douyu.com',
    'ad.huya.com',
    'ad.zhanqi.tv',
    'ad.yy.com',
    'ad.9158.com',
    'ad.huajiao.com',
    'ad.inke.cn',
    'ad.yizhibo.com',
    'ad.kuaishou.com',
  ];

  /// 精确 URL 子串规则（含路径，仅少量）
  static const List<String> _builtInUrlPatterns = [
    'facebook.com/tr',
    'g.doubleclick.net/gampad/ads',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;
    _domainBlock.addAll(_builtInDomains);
    _urlBlock.addAll(_builtInUrlPatterns);

    final prefs = await SharedPreferences.getInstance();
    // 新版缓存：仅域名规则（旧版原始行缓存已废弃，见下）
    final cached = prefs.getStringList('adblock_domain_rules');
    if (cached != null) {
      for (final line in cached) {
        if (line.startsWith('@@')) {
          _addDomain(_domainException, line.substring(2), _maxExceptionRules);
        } else {
          _addDomain(_domainBlock, line, _maxDomainRules);
        }
      }
    } else {
      // 旧版缓存（原始 easylist 行）：用新解析器重读一次（自动跳过元素规则），然后清理
      final oldRaw = prefs.getStringList('adblock_cached_rules');
      if (oldRaw != null) {
        for (final line in oldRaw) {
          _addParsed(line);
        }
        prefs.remove('adblock_cached_rules');
        prefs.setStringList('adblock_domain_rules', _serializeDomains());
      }
    }

    _tryUpdateRules();
    _isInitialized = true;
    notifyListeners();
  }

  /// 解析单条规则并入结构（内置规则外的补充来源）。
  /// 元素隐藏规则（##/#）跳过——它们不是请求拦截规则，按 URL 子串匹配必然误杀。
  void _addParsed(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.startsWith('!') || trimmed.startsWith('[')) {
      return;
    }
    if (trimmed.startsWith('##') || trimmed.startsWith('#')) return;

    var isException = false;
    var rule = trimmed;
    if (rule.startsWith('@@')) {
      isException = true;
      rule = rule.substring(2);
    }

    if (rule.startsWith('||')) {
      var domain = rule.substring(2);
      final carat = domain.indexOf('^');
      if (carat >= 0) domain = domain.substring(0, carat);
      // 含路径/通配（如 ||facebook.com/tr）→ 降级为精确 URL 子串
      if (domain.contains('/') || domain.contains('*')) {
        if (isException) {
          _addUrl(_urlException, domain, _maxUrlRules);
        } else {
          _addUrl(_urlBlock, domain, _maxUrlRules);
        }
      } else {
        if (isException) {
          _addDomain(_domainException, domain, _maxExceptionRules);
        } else {
          _addDomain(_domainBlock, domain, _maxDomainRules);
        }
      }
      return;
    }

    // 其余规则：仅当带 URL 特征才作为子串模式
    final clean = rule.replaceAll('^', '').replaceAll('*', '');
    if (clean.contains('http://') ||
        clean.contains('https://') ||
        clean.contains('.')) {
      if (isException) {
        _addUrl(_urlException, clean, _maxUrlRules);
      } else {
        _addUrl(_urlBlock, clean, _maxUrlRules);
      }
    }
  }

  void _addDomain(Set<String> set, String domain, int cap) {
    if (set.length >= cap || domain.isEmpty) return;
    set.add(domain);
  }

  void _addUrl(List<String> list, String pattern, int cap) {
    if (list.length >= cap || pattern.isEmpty) return;
    list.add(pattern);
  }

  List<String> _serializeDomains() => [
        for (final d in _domainBlock) d,
        for (final d in _domainException) '@@$d',
      ];

  /// 后台从 EasyList 拉规则 → 只保留域名规则（元素规则/路径规则丢弃），
  /// 缓存域名字符串而非 5 万条原始行，控制 prefs 体积与匹配开销。
  /// 24 小时内不重复拉取。
  Future<void> _tryUpdateRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt('adblock_updated_at') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - lastUpdate <
          24 * 3600 * 1000) {
        return;
      }

      final response = await http
          .get(Uri.parse(
              'https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final newDomains = <String>[];
      for (final line in const LineSplitter().convert(response.body)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('!') || trimmed.startsWith('[')) {
          continue;
        }
        if (trimmed.startsWith('##') || trimmed.startsWith('#')) continue;
        var isException = false;
        var rule = trimmed;
        if (rule.startsWith('@@')) {
          isException = true;
          rule = rule.substring(2);
        }
        if (rule.startsWith('||')) {
          var domain = rule.substring(2);
          final carat = domain.indexOf('^');
          if (carat >= 0) domain = domain.substring(0, carat);
          if (domain.contains('/') || domain.contains('*')) continue;
          newDomains.add(isException ? '@@$domain' : domain);
          if (newDomains.length >= _maxDomainRules + _maxExceptionRules) break;
        }
      }
      if (newDomains.isEmpty) return;

      await prefs.setStringList('adblock_domain_rules', newDomains);
      await prefs.setInt('adblock_updated_at',
          DateTime.now().millisecondsSinceEpoch);
      await prefs.remove('adblock_cached_rules'); // 清空旧版原始行缓存

      for (final d in newDomains) {
        if (d.startsWith('@@')) {
          _addDomain(_domainException, d.substring(2), _maxExceptionRules);
        } else {
          _addDomain(_domainBlock, d, _maxDomainRules);
        }
      }
      notifyListeners();
    } catch (_) {
      // 离线/被墙：内置规则已够用
    }
  }

  // ==================== 拦截判定 ====================

  /// 判断是否拦截该请求。主框架请求已由调用方放行，这里只处理子资源。
  bool shouldBlock(String url, String? resourceType) {
    if (!_isInitialized || !_isEnabled) return false;

    // 关键资源（CSS/字体）一律放行，避免页面样式丢失
    if (resourceType == 'STYLESHEET' || resourceType == 'FONT') return false;
    final urlLower = url.toLowerCase();
    if (_isCriticalResource(urlLower)) return false;

    // 例外规则优先
    final host = _extractHost(urlLower);
    if (_matchesHost(host, _domainException)) return false;
    for (final p in _urlException) {
      if (urlLower.contains(p)) return false;
    }

    // 域名拦截（Set 匹配，O(1) 主机 + 父域名）
    if (_matchesHost(host, _domainBlock)) {
      _incrementBlock(url);
      return true;
    }

    // 少量精确 URL 子串
    for (final p in _urlBlock) {
      if (urlLower.contains(p)) {
        _incrementBlock(url);
        return true;
      }
    }
    return false;
  }

  bool _isCriticalResource(String urlLower) {
    return urlLower.endsWith('.css') ||
        urlLower.contains('.css?') ||
        urlLower.endsWith('.woff') ||
        urlLower.endsWith('.woff2') ||
        urlLower.endsWith('.ttf') ||
        urlLower.endsWith('.otf') ||
        urlLower.endsWith('.eot');
  }

  /// 提取 URL 主机名（小写）。一次遍历，O(length)。
  String _extractHost(String url) {
    var s = url;
    final scheme = s.indexOf('://');
    if (scheme >= 0) {
      s = s.substring(scheme + 3);
    } else if (s.startsWith('//')) {
      s = s.substring(2);
    }
    var end = s.length;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 47 || c == 63 || c == 35 || c == 58) {
        // / ? # :
        end = i;
        break;
      }
    }
    return s.substring(0, end);
  }

  /// 主机与域名集合匹配（含父域名/子域名），按域名边界匹配，无宽泛子串误杀。
  bool _matchesHost(String host, Set<String> domains) {
    if (host.isEmpty || domains.isEmpty) return false;
    if (domains.contains(host)) return true;
    var dot = host.indexOf('.');
    while (dot >= 0 && dot < host.length - 1) {
      final parent = host.substring(dot + 1);
      if (domains.contains(parent)) return true;
      dot = host.indexOf('.', dot + 1);
    }
    return false;
  }

  void _incrementBlock(String url) {
    _blockedCount++;
    if (_blockedUrls.length < 50) {
      _blockedUrls.add(url.length > 80 ? '${url.substring(0, 80)}...' : url);
    }
    // 节流通知：最多每 800ms 通知一次 UI，避免页面加载时几十个广告请求导致掉帧
    _dirty = true;
    _throttleTimer ??= Timer(const Duration(milliseconds: 800), () {
      _throttleTimer = null;
      if (_dirty) {
        _dirty = false;
        notifyListeners();
      }
    });
  }

  void resetStats() {
    _blockedCount = 0;
    _blockedUrls.clear();
    _dirty = false;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  void toggle() {
    _isEnabled = !_isEnabled;
    notifyListeners();
  }
}
