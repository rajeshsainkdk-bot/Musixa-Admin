import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class AppShareService {
  static const MethodChannel _channel = MethodChannel('com.musixa.admin/app_share');

  /// Shares Musixa Player APK FILE directly via native Android sharesheet
  /// (WhatsApp, Bluetooth, Quick Share, Nearby Share, Telegram, etc.)
  /// Directly sends the .apk installer file, NOT a link.
  static Future<void> shareAppApk() async {
    try {
      // 1. Try Native Android Extraction from app's own base.apk
      final bool? shared = await _channel.invokeMethod<bool>('shareApk');
      if (shared == true) return;
    } catch (_) {}

    try {
      // 2. Fallback: Search common device download locations for the APK file
      final candidatePaths = [
        '/storage/emulated/0/Download/Musixa-Player-APK/Musixa-player-release.apk',
        '/storage/emulated/0/Download/Musixa-Player-APK/app-release.apk',
        '/storage/emulated/0/Download/MusixaPlayer.apk',
        '/storage/emulated/0/Download/app-release.apk',
        '/storage/emulated/0/Download/Musixa-player-release.apk',
      ];

      for (final path in candidatePaths) {
        final f = File(path);
        if (await f.exists()) {
          await Share.shareXFiles(
            [XFile(f.path, mimeType: 'application/vnd.android.package-archive', name: 'MusixaPlayer.apk')],
            subject: 'Musixa Player APK Installer',
          );
          return;
        }
      }

      // Check if any .apk exists in Download directory
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final list = downloadDir.listSync();
        for (final item in list) {
          if (item is File && item.path.toLowerCase().endsWith('.apk') && item.path.toLowerCase().contains('Musixa')) {
            await Share.shareXFiles(
              [XFile(item.path, mimeType: 'application/vnd.android.package-archive', name: 'MusixaPlayer.apk')],
              subject: 'Musixa Player APK Installer',
            );
            return;
          }
        }
      }
    } catch (_) {}
  }
}
