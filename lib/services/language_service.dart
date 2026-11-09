import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { hindi, english }

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _prefKey = 'Musixa_app_language_v3';
  AppLanguage _currentLanguage = AppLanguage.english; // Default is strictly English!

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isHindi => _currentLanguage == AppLanguage.hindi;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  String get languageCode => _currentLanguage == AppLanguage.hindi ? 'hi' : 'en';
  String get displayLabel => _currentLanguage == AppLanguage.hindi ? '🇮🇳 हिंदी' : '🇬🇧 English';
  String get switchTargetLabel => _currentLanguage == AppLanguage.hindi ? 'English' : 'हिंदी';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefKey);
    if (savedCode == 'hi') {
      _currentLanguage = AppLanguage.hindi;
    } else {
      // By default, or if set to 'en', language is ALWAYS English!
      _currentLanguage = AppLanguage.english;
    }
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    if (_currentLanguage == AppLanguage.hindi) {
      await setLanguage(AppLanguage.english);
    } else {
      await setLanguage(AppLanguage.hindi);
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang == AppLanguage.hindi ? 'hi' : 'en');
    notifyListeners();
  }

  /// Translation Lookup Dictionary
  String t(String key) {
    final translations = _localizedValues[key];
    if (translations == null) return key;
    return translations[languageCode] ?? key;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    // Auth & Onboarding
    'auth_title': {'hi': 'Musixa Admin', 'en': 'Musixa Admin'},
    'auth_subtitle': {'hi': 'मोबाइल नंबर (User ID) व पासवर्ड आधारित सुरक्षित एक्सेस', 'en': 'Secure Mobile Number & Password Access'},
    'tab_login': {'hi': 'लॉगिन (Login)', 'en': 'Login'},
    'tab_register': {'hi': 'नया रजिस्ट्रेशन (Register)', 'en': 'Register'},
    'user_id_label': {'hi': 'यूज़र आईडी (10-Digit Mobile Number) *', 'en': 'User ID (10-Digit Mobile Number) *'},
    'user_id_hint': {'hi': '9876543210', 'en': '9876543210'},
    'full_name': {'hi': 'पूरा नाम (Full Name) *', 'en': 'Full Name *'},
    'full_name_hint': {'hi': 'उदा. Rajesh Kumar', 'en': 'e.g. Rajesh Kumar'},
    'phone_number': {'hi': 'मोबाइल नंबर (User ID) *', 'en': 'Mobile Number (User ID) *'},
    'phone_number_hint': {'hi': '9876543210', 'en': '9876543210'},
    'email_mandatory': {'hi': 'ईमेल आईडी (Email ID) *', 'en': 'Email ID *'},
    'email_hint': {'hi': 'rajesh@example.com', 'en': 'rajesh@example.com'},
    'password_label': {'hi': 'पासवर्ड (Password) *', 'en': 'Password *'},
    'password_hint': {'hi': 'अपना पासवर्ड दर्ज करें', 'en': 'Enter your password'},
    'create_password_label': {'hi': 'पासवर्ड बनाएं (Create Password) *', 'en': 'Create Password *'},
    'create_password_hint': {'hi': 'नया पासवर्ड दर्ज करें (कम से कम 4 अक्षर)', 'en': 'Create password (min 4 characters)'},
    'btn_login': {'hi': '🔑 लॉगिन करें व संगीत सुनें', 'en': '🔑 Login & Listen'},
    'btn_register': {'hi': '✨ खाता बनाएं व शुरू करें', 'en': '✨ Create Account & Start'},
    'switch_to_register_prompt': {'hi': 'नया यूज़र हैं? नया खाता बनाएं', 'en': 'New user? Create an account'},
    'switch_to_login_prompt': {'hi': 'पहले से अकाउंट है? सीधे लॉगिन करें', 'en': 'Already registered? Login here'},
    'auth_tagline': {'hi': '100% मुफ़्त एवं सुरक्षित • OTP का कोई झंझट नहीं', 'en': '100% Free & Secure • No OTP Hassle'},
    'account_recovery_banner': {
      'hi': '⚡ रजिस्टर्ड नंबर व पासवर्ड से लॉगिन करने पर आपकी सभी प्लेलिस्ट व गाने तुरंत लोड होंगे!',
      'en': '⚡ Login with your registered number & password to restore all your playlists & songs!'
    },
    'err_name_required': {'hi': 'कृपया अपना पूरा नाम दर्ज करें (कम से कम 2 अक्षर)', 'en': 'Please enter your full name (at least 2 characters)'},
    'err_phone_required': {'hi': 'कृपया 10 अंकों का वैध मोबाइल नंबर दर्ज करें', 'en': 'Please enter a valid 10-digit mobile number'},
    'err_email_required': {'hi': 'कृपया एक वैध ईमेल आईडी दर्ज करें (उदा. user@mail.com)', 'en': 'Please enter a valid email address (e.g. user@mail.com)'},
    'err_password_required': {'hi': 'कृपया पासवर्ड दर्ज करें', 'en': 'Please enter your password'},
    'err_password_short': {'hi': 'पासवर्ड कम से कम 4 अक्षरों का होना चाहिए', 'en': 'Password must be at least 4 characters'},
    'err_not_registered': {
      'hi': '⚠️ यह मोबाइल नंबर रजिस्टर्ड नहीं है! कृपया पहले नया रजिस्ट्रेशन करें।',
      'en': '⚠️ This mobile number is not registered! Please register first.'
    },
    'err_already_registered': {
      'hi': 'ℹ️ यह नंबर पहले से रजिस्टर्ड है! कृपया सीधे पासवर्ड डालकर लॉगिन करें।',
      'en': 'ℹ️ Already registered! Please login directly with your password.'
    },
    'err_wrong_password': {
      'hi': '❌ गलत पासवर्ड! कृपया सही पासवर्ड दर्ज करें।',
      'en': '❌ Incorrect password! Please enter the correct password.'
    },
    'welcome_back': {'hi': 'वापसी पर स्वागत है! आपकी प्लेलिस्ट व गाने लोड हो गए हैं।', 'en': 'Welcome back! Your playlists & songs have been loaded.'},
    'welcome_new': {'hi': 'स्वागत है! आपका Musixa खाता सफलतापूर्वक बन गया है।', 'en': 'Welcome! Your Musixa account has been created successfully.'},
    'create_playlist': {'hi': '+ नई प्लेलिस्ट बनाएं', 'en': '+ Create Playlist'},
    'my_playlist_badge': {'hi': 'मेरी प्लेलिस्ट', 'en': 'My Playlist'},
    'playlist_name': {'hi': 'प्लेलिस्ट का नाम', 'en': 'Playlist Name'},

    // Library Tabs
    'tab_all_songs': {'hi': 'सभी गाने (All Songs)', 'en': 'All Songs'},
    'tab_favorites': {'hi': 'पसंदीदा (Favorites)', 'en': 'Favorites'},
    'tab_playlists': {'hi': 'प्लेलिस्ट्स (Playlists)', 'en': 'Playlists'},
    'tab_device': {'hi': 'फ़ोन स्टोरेज (Device)', 'en': 'Device'},
    'tab_recent': {'hi': 'हाल में सुने (Recent)', 'en': 'Recent'},
    'all_tracks_title': {'hi': 'सभी उपलब्ध संगीत ट्रैक्स (All Tracks)', 'en': 'All Available Tracks'},
    'no_songs_in_playlist': {'hi': 'इस प्लेलिस्ट में अभी कोई गाना नहीं है', 'en': 'No tracks in this playlist yet'},
    'expand_view_songs': {'hi': 'गाने देखें', 'en': 'View Tracks'},
    'collapse_songs': {'hi': 'छुपाएं', 'en': 'Hide Tracks'},

    // Profile & Settings Screen
    'profile_title': {'hi': 'प्रोफ़ाइल एवं सेटिंग्स', 'en': 'Profile & Settings'},
    'profile_subtitle': {'hi': 'श्रोता खाता विवरण व प्राथमिकताएं', 'en': 'Listener Account Details & Preferences'},
    'account_info': {'hi': 'खाता विवरण (Account Info)', 'en': 'Account Information'},
    'account_status': {'hi': 'अकाउंट स्थिति (Status)', 'en': 'Account Status'},
    'status_active': {'hi': 'सक्रिय (Active / Online) 🟢', 'en': 'Active / Online 🟢'},
    'member_since': {'hi': 'रजिस्ट्रेशन तिथि (Member Since)', 'en': 'Member Since'},
    'preferences_heading': {'hi': 'ऐप प्राथमिकताएं (Preferences)', 'en': 'App Preferences'},
    'app_language': {'hi': 'ऐप की भाषा (App Language)', 'en': 'App Language'},
    'logout_btn': {'hi': 'लॉग आउट करें (Sign Out)', 'en': 'Sign Out'},
    'logout_confirm_title': {'hi': 'लॉग आउट करें?', 'en': 'Sign Out?'},
    'logout_confirm_msg': {'hi': 'क्या आप वाकई अपने खाते से लॉग आउट करना चाहते हैं?', 'en': 'Are you sure you want to sign out of your account?'},
    'refresh_data': {'hi': 'डेटा रीफ्रेश करें', 'en': 'Refresh Data'},
    'data_refreshed': {'hi': 'डेटा सफलतापूर्वक अपडेट हो गया!', 'en': 'Data updated successfully!'},

    // User App Home Screen
    'upload_song': {'hi': '+ Upload Song', 'en': '+ Upload Song'},
    'share_apk_title': {'hi': 'दोस्तों के साथ ऐप APK शेयर करें', 'en': 'Share App APK with Friends'},
    'share_apk_desc': {'hi': 'सीधे WhatsApp, Bluetooth व Nearby Share से भेजें', 'en': 'Send directly via WhatsApp, Bluetooth & Nearby Share'},
    'share_apk_btn': {'hi': 'Share APK', 'en': 'Share APK'},
    'offline_audio_title': {'hi': 'डिवाइस ऑफ़लाइन गाने (Device Audio)', 'en': 'Device Offline Audio'},
    'offline_audio_scan': {'hi': 'फ़ोन स्टोरेज स्कैन करें', 'en': 'Scan phone folders (Downloads, Music)'},
    'offline_ready': {'hi': 'ऑफ़लाइन गाने तैयार हैं', 'en': 'offline songs ready'},
    'scan_btn': {'hi': 'Scan', 'en': 'Scan'},
    'rescan_btn': {'hi': 'Rescan', 'en': 'Rescan'},
    'community_shelf_title': {'hi': '🔥 कम्युनिटी द्वारा जोड़े गए नए गाने', 'en': '🔥 Newly Added by Community'},
    'live_badge': {'hi': 'लाइव', 'en': 'Live'},
    'free_forever': {'hi': '100% मुफ़्त हमेशा के लिए', 'en': '100% Free Forever'},
    'all_free_tracks': {'hi': 'सभी मुफ़्त भारतीय गाने', 'en': 'All Free Indian Tracks'},
    'browse_category': {'hi': 'कैटेगरी के अनुसार सुनें', 'en': 'Browse by Category'},
    'show_all': {'hi': 'सभी देखें (Show All)', 'en': 'Show All'},
    'listen_free': {'hi': 'Listen Free', 'en': 'Listen Free'},

    // Upload Screen
    'upload_heading': {'hi': 'नया गाना अपलोड करें', 'en': 'Upload New Song'},
    'pick_audio_file': {'hi': 'ऑडियो फ़ाइल चुनें (.mp3, .m4a)', 'en': 'Pick Audio File (.mp3, .m4a)'},
    'file_selected': {'hi': 'फ़ाइल चुनी गई', 'en': 'File Selected'},
    'song_title': {'hi': 'गाने का नाम (Song Title)', 'en': 'Song Title'},
    'artist_name': {'hi': 'गायक / कलाकार (Artist)', 'en': 'Artist Name'},
    'album_name': {'hi': 'एल्बम (Album)', 'en': 'Album Name'},
    'genre_label': {'hi': 'शैली / श्रेणी (Genre)', 'en': 'Genre / Category'},
    'cover_url': {'hi': 'पोस्टर इमेज लिंक (Cover URL)', 'en': 'Cover Image URL'},
    'submit_upload': {'hi': 'समीक्षा हेतु भेजें (Submit Song)', 'en': 'Submit for Review'},
    'dup_alert_title': {'hi': '⚠️ गाना पहले से मौजूद है!', 'en': '⚠️ Song Already Exists!'},
    'dup_alert_msg': {'hi': 'यह गाना पहले से ही लाइब्रेरी में उपलब्ध है। क्या आप इसे अभी सुनना चाहते हैं?', 'en': 'This song is already in the library. Would you like to play it now?'},
    'play_now': {'hi': 'गाना अभी सुनें (Play Now)', 'en': 'Play Song Now'},
    'cancel': {'hi': 'रद्द करें (Cancel)', 'en': 'Cancel'},

    // Admin Dashboard
    'admin_title': {'hi': 'Musixa Admin', 'en': 'Musixa Admin'},
    'tab_pending': {'hi': 'लंबित गाने', 'en': 'Pending Songs'},
    'tab_users': {'hi': 'यूज़र्स डेटा', 'en': 'Users Directory'},
    'tab_live': {'hi': 'लाइव गाने', 'en': 'Live Songs'},
    'metric_total_users': {'hi': 'कुल यूज़र्स', 'en': 'Total Users'},
    'metric_active_users': {'hi': 'सक्रिय (Active)', 'en': 'Active (Online)'},
    'metric_pending': {'hi': 'लंबित अप्रूवल', 'en': 'Pending Approval'},
    'metric_live': {'hi': 'लाइव गाने', 'en': 'Live Songs'},
    'preview_play': {'hi': 'सुनें (Preview)', 'en': 'Preview'},
    'preview_stop': {'hi': 'रुकें (Stop)', 'en': 'Stop'},
    'approve_btn': {'hi': 'स्वीकार करें (Approve)', 'en': 'Approve'},
    'reject_btn': {'hi': 'हटाएँ (Reject)', 'en': 'Reject'},
    'delete_btn': {'hi': 'हटाएँ (Delete)', 'en': 'Delete'},
    'edit_btn': {'hi': 'एडिट करें (Edit)', 'en': 'Edit'},
    'add_song_admin': {'hi': '+ नया गाना जोड़ें', 'en': '+ Add New Song'},
    'save_changes': {'hi': 'बदलाव सेव करें', 'en': 'Save Changes'},
    'search_users': {'hi': 'यूज़र का नाम, फ़ोन या ईमेल खोजें...', 'en': 'Search by name, phone or email...'},
    'call_tooltip': {'hi': 'कॉल करें', 'en': 'Call User'},
    'whatsapp_tooltip': {'hi': 'WhatsApp मैसेज', 'en': 'WhatsApp Message'},
    'email_tooltip': {'hi': 'ईमेल भेजें', 'en': 'Send Email'},
    'sign_out': {'hi': 'लॉग आउट', 'en': 'Sign Out'},
    'confirm_delete_title': {'hi': 'गाना हटाएँ?', 'en': 'Delete Song?'},
    'confirm_delete_msg': {'hi': 'क्या आप वाकई इस गाने को हमेशा के लिए हटाना चाहते हैं?', 'en': 'Are you sure you want to permanently remove this song?'},
    'confirm_yes': {'hi': 'हाँ, हटाएँ', 'en': 'Yes, Delete'},
    'no_pending_songs': {'hi': 'कोई लंबित गाना नहीं है!', 'en': 'No pending songs!'},
    'all_songs_approved': {'hi': 'सभी गाने अप्रूव हो चुके हैं।', 'en': 'All songs have been approved.'},
    'no_users_found': {'hi': 'कोई यूज़र नहीं मिला', 'en': 'No users found'},
    'switch_lang': {'hi': 'English में बदलें', 'en': 'हिंदी में बदलें'},

    // Navigation & Global UI
    'nav_discover': {'hi': 'डिस्कवर (Discover)', 'en': 'Discover'},
    'nav_search': {'hi': 'सर्च (Search)', 'en': 'Search'},
    'nav_library': {'hi': 'लाइब्रेरी (Library)', 'en': 'Library'},
    'nav_sound_fx': {'hi': 'साउंड FX', 'en': 'Sound FX'},
    'your_library': {'hi': 'आपकी लाइब्रेरी', 'en': 'Your Library'},
    'search_title': {'hi': 'सर्च व एक्सप्लोर', 'en': 'Search & Explore'},
    'search_hint': {'hi': 'गाने, आर्टिस्ट या शैली खोजें...', 'en': 'Search songs, artists, or genres...'},
    'sound_fx_title': {'hi': 'साउंड व इक्वलाइज़र', 'en': 'Sound & Equalizer'},
    'reset_btn': {'hi': 'रीसेट', 'en': 'Reset'},
    'presets_title': {'hi': 'प्रीसेट्स', 'en': 'PRESETS'},
    'hero_free_badge': {'hi': '🇮🇳 100% मुफ़्त • कोई शुल्क नहीं', 'en': '🇮🇳 100% FREE • NO PAYMENT'},
    'hero_subtitle': {'hi': '100% मुफ़्त भारतीय एवं ऑफ़लाइन म्यूज़िक प्लेयर', 'en': '100% Free Indian & Offline Music Player'},
    'see_all': {'hi': 'सभी देखें', 'en': 'See All'},
    'clear_all_btn': {'hi': 'सभी हटाएं', 'en': 'Clear All'},
    'admin_pin_title': {'hi': 'सुरक्षित एडमिनिस्ट्रेटर कंसोल', 'en': 'Secure Administrator Console'},
    'admin_pin_subtitle': {'hi': 'सुरक्षित एडमिनिस्ट्रेटर कंसोल (Executive Access Only)', 'en': 'Secure Administrator Console (Executive Access Only)'},
    'admin_pin_label': {'hi': 'एडमिन मास्टर पिन (Master PIN)', 'en': 'Admin Master PIN'},
    'enter_pin_hint': {'hi': 'मास्टर पिन दर्ज करें (उदा. 9999)', 'en': 'Enter Master PIN (e.g. 9999)'},
    'admin_login_btn': {'hi': 'लॉगिन करें (Admin Access)', 'en': 'Login (Admin Access)'},
  };
}

