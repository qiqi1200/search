import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 应用内更新系统
///
/// 流程：GitHub Releases 检查新版本 → 下载 APK（带进度）→ 调起系统安装器。
/// 依赖 GitHub Actions 在打 tag 时自动构建并发布 Release（见 .github/workflows/build-apk.yml）。
class UpdateInfo {
  final String version;
  final String url;
  final String notes;

  const UpdateInfo({
    required this.version,
    required this.url,
    required this.notes,
  });
}

class UpdateCheckResult {
  final UpdateInfo? info;
  final String? error;

  const UpdateCheckResult({this.info, this.error});

  bool get hasUpdate => info != null;
}

class UpdateService {
  UpdateService._();

  static const String _repo = 'qiqi1200/search';
  static const String _apiPath = 'https://api.github.com/repos/$_repo/releases/latest';
  static const Duration _timeout = Duration(seconds: 8);

  /// 版本文件 CDN 源（国内可直达，无需翻墙）
  static const List<String> _versionSources = [
    // jsDelivr CDN（国内快速，主力源）
    'https://cdn.jsdelivr.net/gh/qiqi1200/search@main/yanler_browser/version.json',
    'https://fastly.jsdelivr.net/gh/qiqi1200/search@main/yanler_browser/version.json',
    // GitHub raw（备用）
    'https://raw.githubusercontent.com/qiqi1200/search/main/yanler_browser/version.json',
  ];

  /// GitHub 加速镜像（用于 APK 下载竞速）
  static const List<String> _mirrors = [
    'https://ghfast.top/',
    'https://gh-proxy.com/',
    'https://ghproxy.net/',
    'https://ghproxy.cc/',
    'https://mirror.ghproxy.com/',
    'https://gh.llkk.cc/',
  ];

  /// 并行竞速检测版本：同时请求所有源，收集结果后取版本号最高者。
  ///
  /// 为什么取最高而不是第一个成功的：jsDelivr 的 @main 缓存会滞后于 main 分支
  ///（实测已发 1.4.3 时 CDN 仍可能返回 1.4.1）。若第一个响应的是陈旧源，
  /// 应用会误判「已是最新」而漏掉更新。取最高版本让陈旧源无害——
  /// 只要任一源（通常 GitHub API）返回最新版，就一定能检测到。
  static Future<Map<String, dynamic>?> _fetchVersionInfo() async {
    final completer = Completer<Map<String, dynamic>?>();
    var pending = _versionSources.length + 1; // +1 for GitHub API
    Map<String, dynamic>? best;

    void consider(Map<String, dynamic>? result) {
      if (completer.isCompleted) return;
      if (result != null) {
        final v = result['version'] as String? ?? '';
        if (best == null || _isNewer(v, best!['version'] as String? ?? '')) {
          best = result;
        }
      }
      pending--;
      if (pending <= 0) {
        completer.complete(best);
      }
    }

    // 源 1：version.json CDN 源（轻量、快速、国内可达）
    for (final src in _versionSources) {
      unawaited(() async {
        try {
          final resp = await http
              .get(Uri.parse(src), headers: {'User-Agent': 'Yanler/1.4'})
              .timeout(_timeout);
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            if (data['version'] != null) {
              consider(data);
              return;
            }
          }
          consider(null);
        } catch (_) {
          consider(null);
        }
      }());
    }

    // 源 2：GitHub Releases API（权威源，但国内可能慢/超时）
    unawaited(() async {
      try {
        final resp = await http
            .get(Uri.parse(_apiPath), headers: {
              'User-Agent': 'Yanler/1.4',
              'Accept': 'application/vnd.github+json',
            })
            .timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final tag = (data['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
          final assets = (data['assets'] as List? ?? []);
          String? url;
          for (final a in assets) {
            final name = (a['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk') &&
                !name.contains('armv7a') &&
                !name.contains('arm64') &&
                !name.contains('x86_64')) {
              url = a['browser_download_url'] as String?;
              break;
            }
          }
          if (tag.isNotEmpty && url != null) {
            consider({
              'version': tag,
              'url': url,
              'notes': (data['body'] as String? ?? '').trim(),
            });
            return;
          }
        }
        consider(null);
      } catch (_) {
        consider(null);
      }
    }());

    // 兜底截止：5 秒内即使还有源未返回（如校园网下 GitHub API 超时），
    // 用当前已收集到的最高版本，避免检查被慢源卡死。
    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) completer.complete(best);
    });

    return completer.future;
  }

  /// 检查最新版本。返回 null 表示无更新或检查失败。
  static Future<UpdateCheckResult> checkForUpdates() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version;

      final info = await _fetchVersionInfo();
      if (info == null) {
        return const UpdateCheckResult(error: '网络不可用，请稍后重试');
      }

      final tag = (info['version'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      final url = info['url'] as String? ?? '';
      if (tag.isEmpty || url.isEmpty) {
        return const UpdateCheckResult(error: 'Release 中没有找到 APK 文件');
      }

      final notes = (info['notes'] as String? ?? '').trim();
      return UpdateCheckResult(
        info: _isNewer(tag, current)
            ? UpdateInfo(version: tag, url: url, notes: notes)
            : null,
      );
    } catch (e) {
      return const UpdateCheckResult(error: '网络不可用，请稍后重试');
    }
  }

  /// 语义化版本比较（支持 v1.2.3 / 1.2.3+4）
  static bool _isNewer(String remote, String current) {
    int part(String s, int i) {
      final seg = s.split('+').first.split('.');
      return i < seg.length ? (int.tryParse(seg[i]) ?? 0) : 0;
    }

    for (var i = 0; i < 3; i++) {
      final r = part(remote, i);
      final c = part(current, i);
      if (r != c) return r > c;
    }
    // 主版本相同，比较 build 号
    int build(String s) {
      final seg = s.split('+');
      return seg.length > 1 ? (int.tryParse(seg[1]) ?? 0) : 0;
    }

    return build(remote) > build(current);
  }

  /// 下载 APK 并调起系统安装器。返回 null 表示成功。
  ///
  /// **并行竞速下载**——直连与多个加速镜像同时下载，
  /// 先完成者胜出（哪个源快就用哪个），每个源带 6 秒停滞检测，
  /// 停滞源快速失败，不阻塞快源；进度回调上报所有源中的最大进度。
  /// 当某个源速度明显领先时，取消其他源以节省带宽。
  static Future<String?> downloadAndInstall(
    String url, {
    ValueChanged<double>? onProgress,
    ValueChanged<double>? onSpeed,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/yanler-update.apk');

    final sources = [url, for (final m in _mirrors) '$m$url'];
    final completer = Completer<String?>();
    final errs = List<String?>.filled(sources.length, null);
    final parts = <String>[];
    var finished = 0;
    var maxProgress = 0.0;

    void report(double p, double speed) {
      if (p > maxProgress) {
        maxProgress = p;
        onProgress?.call(p);
      }
      if (speed > 0) onSpeed?.call(speed);
    }

    for (var i = 0; i < sources.length; i++) {
      final part = File('${dir.path}/yanler-update.part$i');
      parts.add(part.path);
      final idx = i;
      unawaited(_downloadOne(Uri.parse(sources[i]), part, report).then((err) {
        finished++;
        errs[idx] = err;
        if (err == null && !completer.isCompleted) {
          completer.complete(sources[idx]);
        } else if (finished == sources.length && !completer.isCompleted) {
          completer.complete(null); // 全部失败
        }
      }).catchError((Object e) {
        finished++;
        errs[idx] = e.toString();
        if (finished == sources.length && !completer.isCompleted) {
          completer.complete(null);
        }
      }));
    }

    final winner = await completer.future;

    if (winner == null) {
      // 全部失败，清理所有 part 文件
      for (final p in parts) {
        try {
          await File(p).delete();
        } catch (_) {}
      }
      final firstErr = errs.firstWhere((e) => e != null, orElse: () => '未知错误');
      return '下载失败：$firstErr';
    }

    // 把胜出的 part 改名为最终文件（先重命名，再清理其余 part）
    final winIdx = sources.indexOf(winner);
    final winPart = File(parts[winIdx]);
    try {
      if (await winPart.exists()) {
        if (await file.exists()) await file.delete();
        await winPart.rename(file.path);
      }
    } catch (_) {
      try {
        await winPart.copy(file.path);
        await winPart.delete();
      } catch (_) {}
    }

    // 清理其余 part 文件（跳过已重命名的胜出文件）
    for (var i = 0; i < parts.length; i++) {
      if (i == winIdx) continue;
      try {
        await File(parts[i]).delete();
      } catch (_) {}
    }

    // 最终校验：确保下载下来的是真实 APK（魔数校验），避免损坏包进入安装器
    if (!_isValidApk(file)) {
      try {
        await file.delete();
      } catch (_) {}
      return '下载文件校验失败（可能被网络代理替换或下载不完整），请重试';
    }

    // 调起系统安装器（open_filex 内部处理 FileProvider）
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      final msg = switch (result.type) {
        ResultType.noAppToOpen =>
          '未找到可用的系统安装器。请在系统设置中允许 Yanler「安装未知应用」后重试',
        ResultType.fileNotFound => '安装包文件丢失，请重新下载',
        ResultType.permissionDenied => '缺少存储权限，无法打开安装包',
        _ => result.message,
      };
      return '无法打开安装器：$msg';
    }
    return null;
  }

  /// 校验文件是否为有效 APK（Zip 魔数 PK\x03\x04）。
  /// 部分镜像在反代失败时会返回 HTML 错误页（状态码仍是 200），
  /// 若不校验会把这个损坏文件交给系统安装器导致「无法打开/解析失败」。
  static bool _isValidApk(File file) {
    try {
      // APK 体积远大于几百 KB；过小的文件必是错误页/截断下载
      if (file.lengthSync() < 512 * 1024) return false;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final magic = raf.readSync(4);
        return magic.length == 4 &&
            magic[0] == 0x50 && // P
            magic[1] == 0x4B && // K
            magic[2] == 0x03 &&
            magic[3] == 0x04;
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  /// 单源下载到 part 文件，成功返回 null，失败返回原因字符串。
  /// 带停滞检测：连续 6 秒无数据即抛超时，让调用方快速切换源。
  static Future<String?> _downloadOne(
    Uri uri,
    File file,
    void Function(double progress, double speed) report,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14) Yanler/1.4';
      final resp = await client.send(request).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        return 'HTTP ${resp.statusCode}';
      }

      final total = resp.contentLength ?? 0;
      var received = 0;
      final start = DateTime.now();
      final sink = file.openWrite();
      try {
        // 6 秒无数据 → TimeoutException，该源失败
        await for (final chunk in resp.stream.timeout(
          const Duration(seconds: 6),
        )) {
          sink.add(chunk);
          received += chunk.length;
          final elapsed = DateTime.now().difference(start).inMilliseconds;
          if (total > 0) {
            report(
              (received / total).clamp(0.0, 1.0),
              elapsed > 0 ? received / elapsed * 1000 : 0,
            );
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (total > 0 && received != total) {
        return '下载不完整：$received/$total';
      }
      // 魔数校验：返回 HTML/错误页的源直接判失败，让其他源竞速胜出
      if (!_isValidApk(file)) {
        return '内容校验失败（非 APK 文件）';
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      client.close();
    }
  }

  // ==================== UI 辅助 ====================

  /// 设置页/启动时调用：执行检查并按结果弹窗
  static Future<void> runCheckWithUi(
    BuildContext context, {
    bool silentWhenLatest = true,
    bool silentWhenError = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckDialog(),
    );

    final result = await checkForUpdates();

    if (!navigator.mounted) return;
    navigator.pop(); // 关闭检查中弹窗

    if (result.error != null) {
      if (!silentWhenError) {
        messenger.showSnackBar(
          SnackBar(content: Text('检查更新失败：${result.error}')),
        );
      }
      return;
    }

    final info = result.info;
    if (info == null) {
      if (!silentWhenLatest) {
        messenger.showSnackBar(const SnackBar(content: Text('已是最新版本')));
      }
      return;
    }

    if (!context.mounted) return;
    showUpdateDialog(context, info);
  }

  /// 直接展示更新弹窗（启动静默检查用）
  static void showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog<void>(
      context: context,
      builder: (_) => _UpdateDialog(info: info),
    );
  }
}

/// 检查中弹窗
class _CheckDialog extends StatelessWidget {
  const _CheckDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 18),
          Text('正在检查更新…'),
        ],
      ),
    );
  }
}

/// 发现新版本弹窗
class _UpdateDialog extends StatelessWidget {
  final UpdateInfo info;

  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('发现新版本 v${info.version}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.notes.isNotEmpty) ...[
              const Text('更新内容：', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(
                    info.notes,
                    style: const TextStyle(fontSize: 12.5, height: 1.6),
                  ),
                ),
              ),
            ] else
              const Text('发现新版本，是否下载并安装？'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _downloadAndInstallFlow(context, info);
          },
          child: const Text('下载并安装'),
        ),
      ],
    );
  }

  /// 下载（进度弹窗，实时显示速度）→ 安装
  Future<void> _downloadAndInstallFlow(BuildContext context, UpdateInfo info) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);
    final speed = ValueNotifier<double>(0);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('正在下载更新包…', style: TextStyle(fontSize: 13.5)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: value),
              const SizedBox(height: 10),
              ValueListenableBuilder<double>(
                valueListenable: speed,
                builder: (context, spd, _) {
                  final speedStr = spd > 0
                      ? '${(spd / 1024 / 1024).toStringAsFixed(1)} MB/s'
                      : '连接中…';
                  return Text(
                    '${(value * 100).toStringAsFixed(0)}%  ·  $speedStr'
                    '  ·  多源竞速下载',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    final error = await UpdateService.downloadAndInstall(
      info.url,
      onProgress: (p) => progress.value = p,
      onSpeed: (s) => speed.value = s,
    );
    progress.dispose();
    speed.dispose();

    if (!navigator.mounted) return;
    navigator.pop(); // 关闭进度弹窗

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
