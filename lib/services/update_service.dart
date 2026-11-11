import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Auto-Updater Service
/// Features:
/// - Checks live update manifest on Cloudflare R2 CDN (update/version.json)
/// - Background download with live progress indicator (0 - 100%)
/// - Launches native Android package installer automatically via FileProvider
/// - Supports both user-initiated check & silent app-startup auto-prompt
class UpdateService {
  static const String manifestUrl = 'https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/musixa_player_version.json';
  static const String adminManifestUrl = 'https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/musixa_admin_version.json';
  static const MethodChannel _channel = MethodChannel('com.musixa.admin/app_share');
  static const String _prefKeyLastChecked = 'musixa_last_update_check';
  static const String _prefKeyDismissedVersion = 'musixa_dismissed_update_version';
  static const String _prefKeyLastPromptTime = 'musixa_last_update_prompt_time';
  static bool _hasCheckedThisSession = false;

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
  static Future<void> checkForUpdate(BuildContext context, {bool autoPrompt = false, bool isAdmin = false}) async {
    if (autoPrompt && _hasCheckedThisSession) return;
    if (autoPrompt) _hasCheckedThisSession = true;

    // 1. Show immediate progress feedback for manual button click
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
                isAdmin ? '🔍 Musixa Admin अपडेट चेक किया जा रहा है...' : '🔍 अपडेट चेक किया जा रहा है...',
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
      final targetManifest = isAdmin ? adminManifestUrl : manifestUrl;
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
          _showToast(context, '⚠️ अपडेट सर्वर से कनेक्ट नहीं हो सका (HTTP ${resp.statusCode})');
        }
        return;
      }

      final Map<String, dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));
      final remoteCode = data['version_code'] as int? ?? 1;
      final remoteName = data['version_name'] as String? ?? '1.0.0';
      final apkUrl = data['apk_url'] as String? ?? '';
      final sizeMb = (data['file_size_mb'] as num?)?.toDouble() ?? 23.0;
      final releaseNotes = data['release_notes'] as String? ?? 'नए फीचर्स और बग फिक्स!';
      final forceUpdate = data['force_update'] as bool? ?? false;

      final prefs = await SharedPreferences.getInstance();
      final prefKeyDismissed = isAdmin ? '${_prefKeyDismissedVersion}_admin' : _prefKeyDismissedVersion;
      final prefKeyPrompt = isAdmin ? '${_prefKeyLastPromptTime}_admin' : _prefKeyLastPromptTime;

      await prefs.setInt(_prefKeyLastChecked, ts);

      // Get exact installed version from device OS
      final installed = await getInstalledVersion();
      final installedCode = installed['versionCode'] as int;
      final installedName = installed['versionName'] as String;

      debugPrint('📱 ${isAdmin ? "Admin" : "Player"} Version Check: Installed=$installedCode (v$installedName), Remote=$remoteCode (v$remoteName)');

      // If user dismissed this version or was prompted recently, don't show auto-prompt again
      if (autoPrompt && !forceUpdate) {
        final dismissedCode = prefs.getInt(prefKeyDismissed) ?? 0;
        final lastPromptTime = prefs.getInt(prefKeyPrompt) ?? 0;
        if (dismissedCode >= remoteCode || (ts - lastPromptTime) < 2 * 3600 * 1000) {
          return;
        }
      }

      // ONLY prompt if remote version is strictly newer than installed version
      if (remoteCode > installedCode && apkUrl.isNotEmpty) {
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
            isAdmin: isAdmin,
          );
        }
      } else {
        if (!autoPrompt && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showUpToDateDialog(
            context,
            installedName: installedName,
            installedCode: installedCode,
            isAdmin: isAdmin,
          );
        }
      }
    } catch (e) {
      if (!autoPrompt && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showToast(context, '⚠️ अपडेट चेक करने में त्रुटि: $e');
      }
    }
  }

  static void _showUpToDateDialog(
    BuildContext context, {
    required String installedName,
    required int installedCode,
    bool isAdmin = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 26),
            SizedBox(width: 10),
            Text('ऐप अप-टू-डेट है!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎉 ${isAdmin ? "Musixa Player Admin" : "Musixa Player"} पहले से नवीनतम वर्ज़न पर चल रहा है!',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'वर्ज़न: v$installedName (Build $installedCode)',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'क्लाउड पर कोई नया अपडेट पेंडिंग नहीं है। आपका ऐप पूरी तरह से अप-टू-डेट है।',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
            child: const Text('ठीक है (OK)', style: TextStyle(fontWeight: FontWeight.bold)),
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
    bool isAdmin = false,
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
        final prefKeyDismissed = isAdmin ? '${_prefKeyDismissedVersion}_admin' : _prefKeyDismissedVersion;
        final prefKeyPrompt = isAdmin ? '${_prefKeyLastPromptTime}_admin' : _prefKeyLastPromptTime;

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return WillPopScope(
              onWillPop: () async => !forceUpdate && !isDownloading,
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
                            isAdmin ? 'नया एडमिन अपडेट उपलब्ध है!' : 'नया अपडेट उपलब्ध है!',
                            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'v$remoteName • ${sizeMb.toStringAsFixed(1)} MB',
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
                          const Text(
                            '✨ क्या नया है (What\'s New):',
                            style: TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.bold),
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
                      const Text(
                        'यह अपडेट 1-क्लिक में बिना प्ले स्टोर के सीधे आपके फोन में इंस्टॉल हो जाएगा।',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
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
                      child: const Text('बाद में (Later)', style: TextStyle(color: Colors.grey)),
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
                      label: const Text(
                        'तुरंत अपडेट करें (Update Now)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        // 1. Check if Android "Install Unknown Apps" permission is granted BEFORE starting download
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
                                    children: const [
                                      Icon(Icons.security_rounded, color: Color(0xFFFFB300), size: 24),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'अनुमति आवश्यक है',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: const Text(
                                    'ऐप को बिना प्ले स्टोर के सीधे अपडेट करने के लिए कृपया सेटिंग्स में "Allow from this source" (अज्ञात ऐप्स इंस्टॉल करें) की अनुमति चालू करें।\n\nअनुमति देने के बाद तुरंत अपडेट शुरू हो जाएगा।',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(permCtx, false),
                                      child: const Text('रद्द करें (Cancel)', style: TextStyle(color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFB300),
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: () => Navigator.pop(permCtx, true),
                                      child: const Text('सेटिंग्स खोलें (Open Settings)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          statusText = 'डाउनलोड शुरू हो रहा है...';
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
                          final apkName = isAdmin ? 'Musixa_admin_latest.apk' : 'Musixa_player_latest.apk';
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
                              statusText = 'डाउनलोड हो रहा है: $mbDown / $mbTot MB';
                            });
                          }).asFuture();

                          await sink.flush();
                          await sink.close();

                          // 1. Reset isDownloading immediately so WillPopScope won't block dialog dismissal
                          setState(() {
                            isDownloading = false;
                            downloadProgress = 1.0;
                            statusText = 'डाउनलोड पूरा हुआ! इंस्टॉलेशन...';
                          });

                          // 2. Remember dismissed version code to avoid nagging on immediate restart
                          try {
                            final p = await SharedPreferences.getInstance();
                            await p.setInt(prefKeyDismissed, remoteCode);
                            await p.setInt(prefKeyPrompt, DateTime.now().millisecondsSinceEpoch);
                          } catch (_) {}

                          // 3. Automatically dismiss the popup dialog immediately
                          try {
                            Navigator.of(dialogContext).pop();
                          } catch (_) {
                            try {
                              Navigator.of(ctx, rootNavigator: true).pop();
                            } catch (_) {}
                          }

                          // 4. Show floating success notification
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ डाउनलोड पूरा हुआ! इंस्टॉलेशन शुरू हो रहा है...',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                backgroundColor: Color(0xFF00E5FF),
                                duration: Duration(seconds: 4),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }

                          // 5. Launch Native APK Installer
                          try {
                            await _channel.invokeMethod('installApk', {'filePath': apkFile.path});
                          } on PlatformException catch (pe) {
                            if (context.mounted) {
                              if (pe.code == 'NEED_PERMISSION') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('कृपया सेटिंग्स में "Allow from this source" चालू करें और पुनः अपडेट दबाएं।'),
                                    backgroundColor: Colors.amber,
                                    duration: Duration(seconds: 5),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('इंस्टॉलर त्रुटि: ${pe.message}'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        } catch (err) {
                          setState(() {
                            isDownloading = false;
                            statusText = 'डाउनलोड त्रुटि: $err';
                          });
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

