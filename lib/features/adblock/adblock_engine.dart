import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdblockRule {
  final String rawRule;
  final String pattern;
  final bool isException;
  final bool isDomainRule;
  final bool isUrlPattern;

  const AdblockRule({
    required this.rawRule,
    required this.pattern,
    this.isException = false,
    this.isDomainRule = false,
    this.isUrlPattern = false,
  });
}

class AdblockEngine extends ChangeNotifier {
  final List<AdblockRule> _rules = [];
  bool _isInitialized = false;
  bool _isEnabled = true;

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  List<AdblockRule> get rules => List.unmodifiable(_rules);
  int get ruleCount => _rules.length;

  // 基础规则（离线可用 — EasyList 核心子集）
  static const List<String> _builtInRules = [
    // === 广告联盟/追踪器 ===
    '||doubleclick.net^',
    '||googlesyndication.com^',
    '||googleadservices.com^',
    '||googletagmanager.com^',
    '||google-analytics.com^',
    '||googletagservices.com^',
    '||adservice.google.com^',
    '||pagead2.googlesyndication.com^',
    '||cm.g.doubleclick.net^',
    '||ad.doubleclick.net^',
    '||adservice.google.com^',
    '||securepubads.g.doubleclick.net^',
    '||tpc.googlesyndication.com^',
    '||partner.googleadservices.com^',

    // === 中国广告联盟 ===
    '||cnzz.com^',
    '||cnzz.mmstat.com^',
    '||s21.cnzz.com^',
    '||s22.cnzz.com^',
    '||s23.cnzz.com^',
    '||s24.cnzz.com^',
    '||s25.cnzz.com^',
    '||s26.cnzz.com^',
    '||s27.cnzz.com^',
    '||s28.cnzz.com^',
    '||s29.cnzz.com^',
    '||s30.cnzz.com^',
    '||hm.baidu.com^',
    '||hm.*.baidu.com^',
    '||pos.baidu.com^',
    '||cpro.baidu.com^',
    '||utk.baidu.com^',
    '||zz.bdstatic.com^',
    '||dup.baidustatic.com^',
    '||nsclick.baidu.com^',
    '||wangmeng.baidu.com^',
    '||eclick.baidu.com^',
    '||union.baidu.com^',
    '||cb.baidu.com^',
    '||als.baidu.com^',
    '||qingting.baidu.com^',
    '||fc.baidu.com^',
    '||ad.qq.com^',
    '||adserver.qq.com^',
    '||adsrv.qq.com^',
    '||gdt.qq.com^',
    '||btrace.qq.com^',
    '||qzs.qq.com^',
    '||qlogo.cn^',
    '||pindao.huopin.qq.com^',
    '||adsame.qq.com^',
    '||adslvfile.qq.com^',
    '||adsfile.qq.com^',
    '||appic.qq.com^',
    '||android.bugly.qq.com^',
    '||oth.eve.mdt.qq.com^',
    '||oth.str.mdt.qq.com^',
    '||ad.3g.qq.com^',

    // === 阿里巴巴/淘宝 ===
    '||tanx.com^',
    '||tanx.alimama.com^',
    '||alimama.com^',
    '||mmstat.com^',
    '||srd.simba.taobao.com^',
    '||simba.taobao.com^',
    '||wuzei.taobao.com^',
    '||atb.apps.alimama.com^',
    '||atm.apps.alimama.com^',
    '||log.mmstat.com^',
    '||gm.mmstat.com^',
    '||cn.mmstat.com^',
    '||s.mmstat.com^',

    // === 字节跳动 ===
    '||pangolin-sdk-toutiao.com^',
    '||pangolin.snssdk.com^',
    '||pglstatp-toutiao.com^',
    '||i.snssdk.com^',
    '||ad.toutiao.com^',
    '||ad.snssdk.com^',
    '||dm.toutiao.com^',
    '||log.snssdk.com^',
    '||mon.snssdk.com^',
    '||analytics.snssdk.com^',
    '||is.snssdk.com^',

    // === 通用追踪器 ===
    '||facebook.com/tr^',
    '||connect.facebook.net^',
    '||analytics.twitter.com^',
    '||ads.linkedin.com^',
    '||bat.bing.com^',
    '||c.bing.com^',
    '||ib.adnxs.com^',
    '||secure.adnxs.com^',
    '||adnxs.com^',
    '||exelator.com^',
    '||scorecardresearch.com^',
    '||cloudflareinsights.com^',
    '||cdn.ampproject.org^',

    // === 广告网络 ===
    '||adzerk.net^',
    '||adsrvr.org^',
    '||serving-sys.com^',
    '||adsafeprotected.com^',
    '||moatads.com^',
    '||outbrain.com^',
    '||taboola.com^',
    '||taboolasyndication.com^',
    '||criteo.com^',
    '||criteo.net^',
    '||casalemedia.com^',
    '||pubmatic.com^',
    '||openx.net^',
    '||rubiconproject.com^',
    '||appnexus.com^',
    '||advertising.com^',
    '||tribalfusion.com^',
    '||turn.com^',
    '||contextweb.com^',
    '||indexww.com^',
    '||spotxchange.com^',
    '||adsmoloco.com^',
    '||innovid.com^',
    '||instreamatic.com^',

    // === 弹窗/浮动广告 ===
    '###ad',
    '###advert',
    '###advertisement',
    '###ads',
    '###adsense',
    '###ad-',
    '##.ad',
    '##.ads',
    '##.advertisement',
    '##.advert',
    '##.adsbygoogle',
    '##.banner_ad',
    '##.popup_ad',
    '##.ad-container',
    '##.ad-wrapper',
    '##.ad-slot',
    '##.ad-placement',
    '##.ad-label',
    '##.google-ad',
    '##.advertisement-banner',
    '##.ad_box',
    '##.ad_content',
    '##.ad_unit',
    '##.ad_placeholder',
    '##.adblock-banner',
    '##.ad-banner',
    '##.ad-300',
    '##.ad_300x250',
    '##.ad_728x90',
    '##.ad_970x90',
    '##.fixed-ad',
    '##.floating-ad',
    '##.sticky-ad',
    '##.popup-ad',
    '##.overlay-ad',
    '##.interstitial-ad',

    // === 视频广告 ===
    '||imasdk.googleapis.com^',
    '||gcdn.2mdn.net^',
    '||g.doubleclick.net^',
    '||pubads.g.doubleclick.net^',
    '||adex.betweendigital.com^',
    '||adserver.adtech.de^',
    '||adserver.yahoo.com^',
    '||adserver.bing.com^',
    '||adserver.daum.net^',
    '||adserver.ebay.com^',
    '||adserver.kakao.com^',
    '||adserver.mediaplex.com^',
    '||adserver.msn.com^',
    '||adserver.nydailynews.com^',
    '||adserver.o2.pl^',
    '||adserver.skyrock.com^',
    '||adserver.tiscali.com^',
    '||adserver.virginmedia.com^',
    '||adserver.yahoo.com^',
    '||adserver.ynet.com^',
    '||vast.bp3858272.betweendigital.com^',
    '||g.doubleclick.net/gampad/ads^',

    // === 推送通知/服务弹窗 ===
    '||onesignal.com^',
    '||pushwoosh.com^',
    '||pushalert.co^',
    '||notifyvisitors.com^',
    '||subiz.com^',
    '||tawk.to^',
    '||livechatinc.com^',
    '||olark.com^',
    '||intercom.com^',
    '||intercomcdn.com^',
    '||crisp.chat^',
    '||tidio.co^',

    // === 百度全家桶 ===
    '||bdstatic.com^',
    '||baidustatic.com^',
    '||bcebos.com^',
    '||baidubce.com^',
    '||bdimg.com^',
    '||bdydns.com^',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 加载内置规则
    for (final rule in _builtInRules) {
      _rules.addAll(_parseRule(rule));
    }

    // 尝试从 SharedPreferences 加载缓存规则
    final prefs = await SharedPreferences.getInstance();
    final cachedRules = prefs.getStringList('adblock_cached_rules');
    if (cachedRules != null) {
      for (final rule in cachedRules) {
        _rules.addAll(_parseRule(rule));
      }
    }

    // 后台尝试从网络更新规则
    _tryUpdateRules();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _tryUpdateRules() async {
    try {
      final response = await http
          .get(Uri.parse('https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final lines = const LineSplitter().convert(response.body);
        final newRules = <String>[];

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty ||
              trimmed.startsWith('!') ||
              trimmed.startsWith('[')) {
            continue;
          }
          newRules.add(trimmed);
        }

        // 缓存规则
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('adblock_cached_rules', newRules);

        // 添加到已有规则
        for (final rule in newRules) {
          _rules.addAll(_parseRule(rule));
        }
        notifyListeners();
      }
    } catch (_) {
      // 离线正常，用内置规则就够
    }
  }

  List<AdblockRule> _parseRule(String rawRule) {
    final rules = <AdblockRule>[];
    final trimmed = rawRule.trim();

    if (trimmed.isEmpty ||
        trimmed.startsWith('!') ||
        trimmed.startsWith('[')) {
      return rules;
    }

    // 检查是否为例外规则
    final isException = trimmed.startsWith('@@');

    // 去除 @@ 前缀
    String pattern = isException ? trimmed.substring(2) : trimmed;

    // 检查是否为域名规则（以 || 开头）
    final isDomainRule = pattern.startsWith('||');
    if (isDomainRule) {
      pattern = pattern.substring(2);
    }

    final isUrlPattern = pattern.startsWith('|');

    return [
      AdblockRule(
        rawRule: rawRule,
        pattern: pattern.replaceAll('^', ''),
        isException: isException,
        isDomainRule: isDomainRule,
        isUrlPattern: isUrlPattern,
      ),
    ];
  }

  bool shouldBlock(String url, String? resourceType) {
    if (!_isInitialized || !_isEnabled) return false;

    final urlLower = url.toLowerCase();

    // 先检查例外规则
    for (final rule in _rules) {
      if (rule.isException && _matchRule(rule, urlLower)) {
        return false; // 例外规则优先
      }
    }

    // 再检查拦截规则
    for (final rule in _rules) {
      if (!rule.isException && _matchRule(rule, urlLower)) {
        return true;
      }
    }

    return false;
  }

  bool _matchRule(AdblockRule rule, String urlLower) {
    final pattern = rule.pattern.toLowerCase();

    if (rule.isDomainRule) {
      // 域名规则：匹配域名部分
      return urlLower.contains(pattern) || urlLower.contains('.$pattern/');
    }

    if (rule.isUrlPattern) {
      // URL 路径前缀匹配
      return urlLower.contains(pattern);
    }

    // 普通模式匹配
    return urlLower.contains(pattern);
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
