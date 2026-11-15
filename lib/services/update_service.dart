import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'language_service.dart';

/// App Auto-Updater Service for Musixa Admin
/// Features:
/// - Real-time version check against Cloudflare R2 update manifest
/// - Automatic popup dialog on app launch when a new version is detected
/// - Background download with live progress bar and status indicator
/// - Automatic dismissal of update dialog once download completes & installer is launched
/// - Default 100% clean English UI with full Hindi toggle support
class UpdateService {
  static const String manifestUrl = 'https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/musixa_admin_version.json';
  static const String adminManifestUrl = 'https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/musixa_admin_version.json';
  static const MethodChannel _channel = MethodChannel('com.musixa.admin/app_share');
  static const String _prefKeyLastChecked = 'musixa_last_update_check';
  static const String _prefKeyDismissedVersion = 'musixa_dismissed_update_version';
  static const String _prefKeyLastPromptTime = 'musixa_last_update_prompt_time';
  static final ValueNotifier<Map<String, dynamic>?> availableUpdateNotifier = ValueNotifier(null);
  static final ValueNotifier<Map<String, dynamic>?> adminAvailableUpdateNotifier = ValueNotifier(null);

  /// Read exact installed package version dynamically from Android PackageManager
  static Future<Map<String, dynamic>> getInstalledVersion() async {
    try {
      final res = await _channel.invokeMethod<Map>('getAppVersion');
      if (res != null) {
        return {
          'versionCode': (res['versionCode'] as num?)?.toInt() ?? 1,
          'versionName': res['versionName']?.toString() ?? '1.0.0',
        };
      }
    } catch (_) {}
    return {'versionCode': 1, 'versionName': '1.0.0'};
  }

  /// Check for latest update from Cloudflare R2
  static Future<void> checkForUpdate(BuildContext context, {bool autoPrompt = false, bool isAdmin = true}) async {
    final isHindi = LanguageService().isHindi;

    // Show immediate progress feedback for manual button click
    if (!autoPrompt && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
              ),
              const SizedBox(width: 12),
              Text(
                isHindi ? 'Musixa Admin अपडेट चेक किया जा रहा है...' : 'Checking Musixa Admin updates...',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF131B2C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    try {
      final targetManifest = adminManifestUrl;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$targetManifest?t=$ts');
      final resp = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) {
        if (!autoPrompt && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showToast(
            context,
            isHindi
                ? 'अपडेट सर्वर से कनेक्ट नहीं हो सका (HTTP ${resp.statusCode})'
                : 'Could not connect to update server (HTTP ${resp.statusCode})',
          );
        }
        return;
      }

      final Map<String, dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));
      final remoteCode = data['version_code'] as int? ?? 1;
      final remoteName = data['version_name'] as String? ?? '1.0.0';
      final apkUrl = data['apk_url'] as String? ?? '';
      final sizeMb = (data['file_size_mb'] as num?)?.toDouble() ?? 24.0;
      final releaseNotes = data['release_notes'] as String? ?? (isHindi ? 'नए फीचर्स और बग फिक्स!' : 'New features & bug fixes!');
      final forceUpdate = data['force_update'] as bool? ?? false;

      final prefs = await SharedPreferences.getInstance();
      const prefKeyDismissed = '${_prefKeyDismissedVersion}_admin';
      const prefKeyPrompt = '${_prefKeyLastPromptTime}_admin';

      await prefs.setInt(_prefKeyLastChecked, ts);

      // Get exact installed version from device OS
      final installed = await getInstalledVersion();
      final installedCode = installed['versionCode'] as int;
      final installedName = installed['versionName'] as String;

      debugPrint('Musixa Admin Version Check: Installed=$installedCode (v$installedName), Remote=$remoteCode (v$remoteName)');

      // If remote version is newer, register available update & prompt
      if (remoteCode > installedCode && apkUrl.isNotEmpty) {
        final updateInfo = {
          'remoteCode': remoteCode,
          'remoteName': remoteName,
          'sizeMb': sizeMb,
          'releaseNotes': releaseNotes,
          'apkUrl': apkUrl,
          'forceUpdate': forceUpdate,
        };
        adminAvailableUpdateNotifier.value = updateInfo;
        availableUpdateNotifier.value = updateInfo;

        if (autoPrompt && !forceUpdate) {
          final dismissedCode = prefs.getInt(prefKeyDismissed) ?? 0;
          final lastPromptTime = prefs.getInt(prefKeyPrompt) ?? 0;
          // Only suppress if user clicked Later in this exact 15-minute window
          if (dismissedCode >= remoteCode && (ts - lastPromptTime) < 15 * 60 * 1000) {
            return;
          }
        }

        await prefs.setInt(prefKeyPrompt, ts);
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showUpdateDialog(
            context,
            remoteName: remoteName,
            sizeMb: sizeMb,
            releaseNotes: releaseNotes,
            apkUrl: apkUrl,
            forceUpdate: forceUpdate,
            remoteCode: remoteCode,
            isAdmin: true,
          );
        }
      } else {
        adminAvailableUpdateNotifier.value = null;
        availableUpdateNotifier.value = null;
        if (!autoPrompt && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showUpToDateDialog(
            context,
            installedName: installedName,
            installedCode: installedCode,
            isAdmin: true,
          );
        }
      }
    } catch (e) {
      if (!autoPrompt && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showToast(
          context,
          isHindi ? 'अपडेट चेक करने में त्रुटि: $e' : 'Error checking for updates: $e',
        );
      }
    }
  }

  static void _showUpToDateDialog(
    BuildContext context, {
    required String installedName,
    required int installedCode,
    bool isAdmin = true,
  }) {
    final isHindi = LanguageService().isHindi;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 26),
            const SizedBox(width: 10),
            Text(
              isHindi ? 'ऐप अप-टू-डेट है!' : 'App is Up to Date!',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi
                  ? 'Musixa Admin पहले से नवीनतम वर्ज़न पर चल रहा है!'
                  : 'Musixa Admin is already running on the latest version!',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Installed: v$installedName (Build $installedCode)',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isHindi
                  ? 'क्लाउड पर कोई नया अपडेट पेंडिंग नहीं है। आपका ऐप पूरी तरह से अप-टू-डेट है।'
                  : 'No new updates pending on cloud. Your app is completely up to date.',
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'ठीक है' : 'OK', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF101726),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String remoteName,
    required double sizeMb,
    required String releaseNotes,
    required String apkUrl,
    required bool forceUpdate,
    required int remoteCode,
    bool isAdmin = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) {
        double downloadProgress = 0.0;
        bool isDownloading = false;
        String statusText = '';
        int downloadedBytes = 0;
        int totalBytes = (sizeMb * 1024 * 1024).toInt();
        const prefKeyDismissed = '${_prefKeyDismissedVersion}_admin';
        const prefKeyPrompt = '${_prefKeyLastPromptTime}_admin';
        final isHindi = LanguageService().isHindi;

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return PopScope(
              canPop: !forceUpdate && !isDownloading,
              child: AlertDialog(
                backgroundColor: const Color(0xFF131B2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.system_update_rounded, color: Color(0xFFFFB300), size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHindi ? 'नया Musixa Admin अपडेट उपलब्ध है!' : 'New Musixa Admin Update Available!',
                            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'v$remoteName | ${sizeMb.toStringAsFixed(1)} MB',
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHindi ? 'क्या नया है:' : 'What\'s New:',
                            style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            releaseNotes,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isDownloading) ...[
                      LinearProgressIndicator(
                        value: totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : null,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFF00E5FF),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            statusText,
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        isHindi
                            ? 'यह अपडेट 1-क्लिक में सीधे आपके फ़ोन में इंस्टॉल हो जाएगा।'
                            : 'This update will install directly on your phone with 1-click OTA.',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (!isDownloading && !forceUpdate)
                    TextButton(
                      onPressed: () async {
                        try {
                          final p = await SharedPreferences.getInstance();
                          await p.setInt(prefKeyDismissed, remoteCode);
                          await p.setInt(prefKeyPrompt, DateTime.now().millisecondsSinceEpoch);
                        } catch (_) {}
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: Text(isHindi ? 'बाद में' : 'Later', style: const TextStyle(color: Colors.grey)),
                    ),
                  if (!isDownloading)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        isHindi ? 'अभी अपडेट करें' : 'Update Now',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        // 1. Check if Android "Install Unknown Apps" permission is granted
                        try {
                          final canInstall = await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
                          if (!canInstall) {
                            if (dialogContext.mounted) {
                              final shouldOpenSettings = await showDialog<bool>(
                                context: dialogContext,
                                builder: (permCtx) => AlertDialog(
                                  backgroundColor: const Color(0xFF131B2C),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.security_rounded, color: Color(0xFFFFB300), size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isHindi ? 'अनुमति आवश्यक है' : 'Permission Required',
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    isHindi
                                        ? 'ऐप को सीधे अपडेट करने के लिए कृपया सेटिंग्स में "Allow from this source" की अनुमति चालू करें।\n\nअनुमति देने के बाद तुरंत अपडेट शुरू हो जाएगा।'
                                        : 'To update the app directly, please enable "Allow from this source" in Android settings.\n\nUpdate will resume immediately after enabling.',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(permCtx, false),
                                      child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFB300),
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: () => Navigator.pop(permCtx, true),
                                      child: Text(
                                        isHindi ? 'सेटिंग्स खोलें' : 'Open Settings',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldOpenSettings == true) {
                                await _channel.invokeMethod('openInstallSettings');
                              }
                              return;
                            }
                          }
                        } catch (_) {}

                        setState(() {
                          isDownloading = true;
                          statusText = isHindi ? 'डाउनलोड शुरू हो रहा है...' : 'Starting download...';
                        });

                        try {
                          final client = http.Client();
                          final request = http.Request('GET', Uri.parse(apkUrl));
                          final response = await client.send(request);

                          if (response.statusCode != 200) {
                            throw 'Download failed with status ${response.statusCode}';
                          }

                          totalBytes = response.contentLength ?? (sizeMb * 1024 * 1024).toInt();
                          downloadedBytes = 0;

                          final tempDir = Directory.systemTemp;
                          const apkName = 'musixa_admin_latest.apk';
                          final apkFile = File('${tempDir.path}/$apkName');
                          if (await apkFile.exists()) {
                            await apkFile.delete();
                          }

                          final sink = apkFile.openWrite();

                          await response.stream.listen((chunk) {
                            sink.add(chunk);
                            downloadedBytes += chunk.length;
                            setState(() {
                              downloadProgress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.5;
                              final mbDown = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
                              final mbTot = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
                              statusText = isHindi
                                  ? 'डाउनलोड हो रहा है: $mbDown / $mbTot MB'
                                  : 'Downloading: $mbDown / $mbTot MB';
                            });
                          }).asFuture();

                          await sink.flush();
                          await sink.close();

                          // 1. Reset isDownloading immediately
                          setState(() {
                            isDownloading = false;
                            downloadProgress = 1.0;
                            statusText = isHindi ? 'डाउनलोड पूरा हुआ! इंस्टॉलेशन...' : 'Download complete! Installing...';
                          });

                          // 2. Remember dismissed version
                          try {
                            final p = await SharedPreferences.getInstance();
                            await p.setInt(prefKeyDismissed, remoteCode);
                            await p.setInt(prefKeyPrompt, DateTime.now().millisecondsSinceEpoch);
                          } catch (_) {}

                          // 3. Clear banner notifiers immediately
                          adminAvailableUpdateNotifier.value = null;
                          availableUpdateNotifier.value = null;

                          // 4. Automatically dismiss the popup dialog immediately
                          try {
                            Navigator.of(dialogContext, rootNavigator: true).pop();
                          } catch (_) {}

                          // 5. Show floating success notification
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isHindi
                                      ? '✅ डाउनलोड पूरा हुआ! इंस्टॉलेशन शुरू हो रहा है...'
                                      : '✅ Download complete! Starting installation...',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                backgroundColor: const Color(0xFF00E5FF),
                                duration: const Duration(seconds: 4),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }

                          // 6. Launch Native APK Installer
                          try {
                            await _channel.invokeMethod('installApk', {'filePath': apkFile.path});
                          } on PlatformException catch (pe) {
                            if (context.mounted) {
                              if (pe.code == 'NEED_PERMISSION') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isHindi
                                          ? 'कृपया सेटिंग्स में "Allow from this source" चालू करें और पुनः अपडेट दबाएं।'
                                          : 'Please enable "Allow from this source" in settings and tap update again.',
                                    ),
                                    backgroundColor: Colors.amber,
                                    duration: const Duration(seconds: 5),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isHindi ? 'इंस्टॉलर खोलने में त्रुटि: ${pe.message}' : 'Installer error: ${pe.message}',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          setState(() {
                            isDownloading = false;
                            statusText = isHindi ? 'डाउनलोड विफल: $e' : 'Download failed: $e';
                          });
                          if (context.mounted) {
                            _showToast(context, isHindi ? 'डाउनलोड विफल: $e' : 'Download failed: $e');
                          }
                        }
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
