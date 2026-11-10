import 'package:flutter/services.dart';

/// Service to handle background wake locks and status bar notifications
/// so bulk audio uploads never stop when the device locks or screen turns off.
class BackgroundUploadService {
  static const MethodChannel _channel = MethodChannel('com.musixa.admin/app_share');

  /// Keep screen on & CPU running (PARTIAL_WAKE_LOCK) even if phone is locked
  static Future<void> acquireWakeLock() async {
    try {
      await _channel.invokeMethod('acquireWakeLock');
    } catch (_) {}
  }

  /// Release wake lock and allow screen/CPU to rest normally
  static Future<void> releaseWakeLock() async {
    try {
      await _channel.invokeMethod('releaseWakeLock');
    } catch (_) {}
  }

  /// Show high-priority native notification in Android notification shade & lock screen
  static Future<void> showUploadNotification({
    required String title,
    required String message,
  }) async {
    try {
      await _channel.invokeMethod('showUploadNotification', {
        'title': title,
        'message': message,
      });
    } catch (_) {}
  }
}

