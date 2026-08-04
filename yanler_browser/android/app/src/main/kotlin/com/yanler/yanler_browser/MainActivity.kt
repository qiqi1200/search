package com.yanler.yanler_browser

import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "yanler/apk_version"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getApkVersion") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("BAD_ARGS", "missing path", null)
                        return@setMethodCallHandler
                    }
                    val info = parseApkVersion(path)
                    if (info == null) {
                        // 解析失败 → Dart 侧按「校验不通过」处理，绝不放行安装
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "versionName" to info.first,
                                "versionCode" to info.second,
                            )
                        )
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /// 用 PackageManager.getPackageArchiveInfo 解析已下载 APK 的真实版本号。
    /// 关键：必须先给 applicationInfo 设置 sourceDir/publicSourceDir，才能取到版本字段。
    /// 返回 (versionName, versionCode)。
    @Suppress("DEPRECATION")
    private fun parseApkVersion(path: String): Pair<String, Long>? {
        return try {
            val pm = packageManager
            val file = File(path)
            if (!file.exists() || file.length() < 512 * 1024) return null
            val pkgInfo = pm.getPackageArchiveInfo(path, 0) ?: return null
            // 关键：必须先设置 sourceDir/publicSourceDir，才能取到正确版本字段
            pkgInfo.applicationInfo?.let {
                it.sourceDir = path
                it.publicSourceDir = path
            }
            val code: Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode
            } else {
                pkgInfo.versionCode.toLong()
            }
            val name = pkgInfo.versionName ?: ""
            Log.i("UpdateCheck", "APK 解析结果 versionName=$name versionCode=$code size=${file.length()}")
            Pair(name, code)
        } catch (e: Throwable) {
            Log.e("UpdateCheck", "解析 APK 版本失败 path=$path err=$e")
            null
        }
    }
}
