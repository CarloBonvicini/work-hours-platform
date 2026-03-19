package com.carlobonvicini.workhours

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "work_hours_mobile/update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    when {
                        url.isNullOrBlank() -> result.success(false)
                        url.endsWith(".apk", ignoreCase = true) -> downloadAndInstallApk(url, result)
                        else -> result.success(openBrowserUrl(url))
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun downloadAndInstallApk(url: String, result: MethodChannel.Result) {
        Thread {
            val updatesDir = File(cacheDir, "updates")
            if (!updatesDir.exists()) {
                updatesDir.mkdirs()
            }

            val apkFile = File(updatesDir, "work-hours-update.apk")

            val didDownload = try {
                downloadFile(url, apkFile)
                true
            } catch (_: Exception) {
                false
            }

            runOnUiThread {
                if (!didDownload) {
                    result.success(false)
                    return@runOnUiThread
                }

                result.success(openInstaller(apkFile))
            }
        }.start()
    }

    private fun downloadFile(url: String, outputFile: File) {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connectTimeout = 15000
        connection.readTimeout = 120000
        connection.requestMethod = "GET"

        try {
            connection.connect()
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("Unexpected response code ${connection.responseCode}")
            }

            connection.inputStream.use { input ->
                outputFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun openInstaller(apkFile: File): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(settingsIntent)
            return true
        }

        val authority = "${applicationContext.packageName}.fileprovider"
        val apkUri = FileProvider.getUriForFile(this, authority, apkFile)
        val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = apkUri
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
        }

        return try {
            startActivity(installIntent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    private fun openBrowserUrl(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
