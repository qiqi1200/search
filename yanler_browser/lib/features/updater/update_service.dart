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
  static const String _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const Duration _timeout = Duration(seconds: 12);

  /// 检查最新 Release。返回 null 表示无更新或检查失败（error 区分原因）。
  static Future<UpdateCheckResult> checkForUpdates() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version;

      final resp = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'User-Agent': 'Yanler-Browser', 'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);

      if (resp.statusCode != 200) {
        return UpdateCheckResult(error: '服务器响应异常（HTTP ${resp.statusCode}）');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      final assets = (data['assets'] as List? ?? []);
      String? url;
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          url = a['browser_download_url'] as String?;
          break;
        }
      }
      if (tag.isEmpty || url == null) {
        return const UpdateCheckResult(error: 'Release 中没有找到 APK 文件');
      }

      final notes = (data['body'] as String? ?? '').trim();
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
  static Future<String?> downloadAndInstall(
    String url, {
    ValueChanged<double>? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/yanler-update.apk');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..headers['User-Agent'] = 'Yanler-Browser';
      final resp = await client.send(request).timeout(_timeout * 5);
      if (resp.statusCode != 200) {
        return '下载失败（HTTP ${resp.statusCode}）';
      }

      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // 调起系统安装器（open_filex 内部处理 FileProvider）
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        return '无法打开安装器：${result.message}';
      }
      return null;
    } catch (e) {
      return '下载失败：$e';
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

  /// 下载（进度弹窗）→ 安装
  Future<void> _downloadAndInstallFlow(BuildContext context, UpdateInfo info) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);

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
              const SizedBox(height: 8),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    final error = await UpdateService.downloadAndInstall(
      info.url,
      onProgress: (p) => progress.value = p,
    );
    progress.dispose();

    if (!navigator.mounted) return;
    navigator.pop(); // 关闭进度弹窗

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
