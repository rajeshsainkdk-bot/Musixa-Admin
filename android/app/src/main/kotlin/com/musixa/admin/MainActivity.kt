package com.musixa.admin

import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.msixa.player/app_share"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ctx: Context = applicationContext

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireWakeLock" -> {
                    try {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        val powerManager = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (wakeLock == null) {
                            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MusixaAdmin:BulkUploadWakeLock")
                        }
                        if (wakeLock?.isHeld != true) {
                            wakeLock?.acquire(45 * 60 * 1000L)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERR", e.localizedMessage, null)
                    }
                }
                "releaseWakeLock" -> {
                    try {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_RELEASE_ERR", e.localizedMessage, null)
                    }
                }
                "showUploadNotification" -> {
                    try {
                        val title = call.argument<String>("title") ?: "Musixa Upload"
                        val message = call.argument<String>("message") ?: "Upload Completed!"
                        val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val channelId = "musixa_upload_channel"
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = NotificationChannel(
                                channelId,
                                "Musixa Upload Status",
                                NotificationManager.IMPORTANCE_HIGH
                            )
                            notificationManager.createNotificationChannel(channel)
                        }
                        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Notification.Builder(ctx, channelId)
                        } else {
                            @Suppress("DEPRECATION")
                            Notification.Builder(ctx)
                        }
                        builder.setSmallIcon(android.R.drawable.stat_sys_upload_done)
                            .setContentTitle(title)
                            .setContentText(message)
                            .setAutoCancel(true)
                        notificationManager.notify(101, builder.build())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_ERR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    try {
                        val filePath = call.argument<String>("filePath") ?: throw IllegalArgumentException("filePath required")
                        val file = File(filePath)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (!ctx.packageManager.canRequestPackageInstalls()) {
                                val permIntent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = android.net.Uri.parse("package:${ctx.packageName}")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                ctx.startActivity(permIntent)
                                result.error("NEED_PERMISSION", "Please allow installing apps from Musixa Admin in Settings", null)
                                return@setMethodCallHandler
                            }
                        }

                        val apkUri = FileProvider.getUriForFile(
                            ctx,
                            "${ctx.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        ctx.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            ctx.packageManager.getPackageInfo(ctx.packageName, 0).longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionCode.toLong()
                        }
                        val versionName = ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName ?: "1.0.0"
                        result.success(mapOf(
                            "versionCode" to pInfo,
                            "versionName" to versionName
                        ))
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
