import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/cloud_backend_service.dart';
import '../services/language_service.dart';
import '../services/update_service.dart';
import '../services/app_share_service.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        final backend = Provider.of<CloudBackendService>(context);
        final lang = LanguageService();
        final user = backend.currentUser;

        final joinDateFormatted = user != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(user.createdAt)
            : 'N/A';

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          appBar: AppBar(
            backgroundColor: const Color(0xFF131A2A),
            elevation: 0,
            title: Text(
              lang.t('profile_title'),
              style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              // Language switcher pill in Profile AppBar
              InkWell(
                onTap: () => lang.toggleLanguage(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B101D),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, size: 14, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 4),
                      Text(
                        lang.displayLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. User Header Avatar Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF131A2A),
                    const Color(0xFF101B33),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.4),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (user?.fullName.isNotEmpty == true)
                            ? user!.fullName.substring(0, 1).toUpperCase()
                            : 'M',
                        style: GoogleFonts.syne(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Msixa Listener',
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified Listener',
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Account Details Section
            Text(
              lang.t('account_info'),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00E5FF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  _buildDetailTile(
                    icon: Icons.person_outline_rounded,
                    title: lang.t('full_name'),
                    value: user?.fullName ?? 'N/A',
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  _buildDetailTile(
                    icon: Icons.phone_android_rounded,
                    title: lang.t('user_id_label'),
                    value: user?.phoneNumber ?? 'N/A',
                    isHighlight: true,
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  _buildDetailTile(
                    icon: Icons.alternate_email_rounded,
                    title: lang.t('email_mandatory'),
                    value: user?.email ?? 'N/A',
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  _buildDetailTile(
                    icon: Icons.check_circle_outline_rounded,
                    title: lang.t('account_status'),
                    value: lang.t('status_active'),
                    valueColor: Colors.greenAccent,
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  _buildDetailTile(
                    icon: Icons.calendar_today_rounded,
                    title: lang.t('member_since'),
                    value: joinDateFormatted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. App Preferences & Utilities
            Text(
              lang.t('preferences_heading'),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00E5FF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: Color(0xFF00E5FF), size: 22),
                    title: Text(lang.t('app_language'), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    trailing: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF0B101D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF00E5FF)),
                      label: Text(
                        lang.displayLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => lang.toggleLanguage(),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  ListTile(
                    leading: const Icon(Icons.folder_open_rounded, color: Color(0xFF00E5FF), size: 22),
                    title: Text(
                      lang.isHindi ? 'फ़ोन स्टोरेज स्कैन करें (Offline Audio)' : 'Scan Device Audio Storage',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      lang.isHindi ? 'फ़ोन के गानों को लाइब्रेरी में जोड़ें' : 'Scan local MP3s into library',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                      onPressed: () {
                        Provider.of<PlayerProvider>(context, listen: false).scanDeviceSongs();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              lang.isHindi ? 'फ़ोन स्टोरेज स्कैन हो रहा है...' : 'Scanning device storage...',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  ListTile(
                    leading: const Icon(Icons.share_rounded, color: Color(0xFF00E5FF), size: 22),
                    title: Text(lang.t('share_apk_title'), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(lang.t('share_apk_desc'), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF00E5FF), size: 20),
                      onPressed: () => AppShareService.shareAppApk(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Check for Updates Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.system_update_rounded, size: 18),
              label: Text(
                'अपडेट जांचें (Check for Updates)',
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: () => UpdateService.checkForUpdate(context, autoPrompt: false),
            ),
            const SizedBox(height: 12),

            // 4. Sign Out Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                lang.t('logout_btn'),
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _confirmSignOut(context, backend, lang),
            ),
            const SizedBox(height: 16),

            // App Version Footer
            Center(
              child: Text(
                'Msixa Player • v2.0 (Dual-APK Edition)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
    bool isHighlight = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? (isHighlight ? const Color(0xFF00E5FF) : Colors.white),
                    fontSize: 14,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, CloudBackendService backend, LanguageService lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang.t('logout_confirm_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          lang.t('logout_confirm_msg'),
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close ProfileScreen
              await backend.signOut();
            },
            child: Text(
              lang.isHindi ? 'हाँ, लॉग आउट करें' : 'Yes, Sign Out',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

