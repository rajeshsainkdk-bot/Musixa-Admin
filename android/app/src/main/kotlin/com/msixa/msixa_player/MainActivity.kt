package com.msixa.msixa_player

import android.content.Intent
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.msixa.player/app_share"
    private var wakeLock: android.os.PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "acquireWakeLock") {
                try {
                    window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    val powerManager = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                    if (wakeLock == null) {
                        wakeLock = powerManager.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "Msixa:BulkUploadWakeLock")
                    }
                    if (wakeLock?.isHeld != true) {
                        wakeLock?.acquire(45 * 60 * 1000L) // up to 45 mins
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("WAKELOCK_ERR", e.localizedMessage, null)
                }
            } else if (call.method == "releaseWakeLock") {
                try {
                    window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    if (wakeLock?.isHeld == true) {
                        wakeLock?.release()
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("WAKELOCK_RELEASE_ERR", e.localizedMessage, null)
                }
            } else if (call.method == "showUploadNotification") {
                try {
                    val title = call.argument<String>("title") ?: "Msixa Bulk Upload"
                    val message = call.argument<String>("message") ?: "Upload Completed!"
                    val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    val channelId = "msixa_upload_channel"
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        val channel = android.app.NotificationChannel(
                            channelId,
                            "Msixa Upload Status",
                            android.app.NotificationManager.IMPORTANCE_HIGH
                        ).apply {
                            description = "Notifications for bulk upload completion"
                        }
                        notificationManager.createNotificationChannel(channel)
                    }
                    val builder = androidx.core.app.NotificationCompat.Builder(this, channelId)
                        .setSmallIcon(android.R.drawable.stat_sys_upload_done)
                        .setContentTitle(title)
                        .setContentText(message)
                        .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                        .setAutoCancel(true)
                    notificationManager.notify(101, builder.build())
                    result.success(true)
                } catch (e: Exception) {
                    result.error("NOTIF_ERR", e.localizedMessage, null)
                }
            } else if (call.method == "shareApk") {
                try {
                    val appInfo = applicationContext.applicationInfo
                    val srcApk = File(appInfo.sourceDir)
                    val destApk = File(cacheDir, "MsixaPlayer.apk")
                    FileInputStream(srcApk).use { input ->
                        FileOutputStream(destApk).use { output ->
                            input.copyTo(output)
                        }
                    }

                    val apkUri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        destApk
                    )

                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/vnd.android.package-archive"
                        putExtra(Intent.EXTRA_STREAM, apkUri)
                        putExtra(Intent.EXTRA_SUBJECT, "Msixa Player APK")
                        putExtra(Intent.EXTRA_TEXT, "Download & Install Msixa Player - Enjoy 100% Free Indian Music & Offline Player!")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }

                    startActivity(Intent.createChooser(intent, "Share Msixa Player APK"))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHARE_ERROR", e.localizedMessage, null)
                }
            } else if (call.method == "installApk") {
                try {
                    val filePath = call.argument<String>("filePath") ?: throw IllegalArgumentException("filePath required")
                    val file = File(filePath)

                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            val permIntent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = android.net.Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(permIntent)
                            result.error("NEED_PERMISSION", "Please allow installing apps from Msixa Player in Settings", null)
                            return@setMethodCallHandler
                        }
                    }

                    val apkUri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        file
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(apkUri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.localizedMessage, null)
                }
            } else if (call.method == "getAppVersion") {
                try {
                    val pInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        packageManager.getPackageInfo(packageName, 0).longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0).versionCode.toLong()
                    }
                    val versionName = packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"
                    result.success(mapOf(
                        "versionCode" to pInfo,
                        "versionName" to versionName
                    ))
                } catch (e: Exception) {
                    result.error("VERSION_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

