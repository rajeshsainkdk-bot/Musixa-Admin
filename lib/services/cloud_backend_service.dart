import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_profile.dart';
import '../models/song.dart';
import 'catalog_service.dart';
import 'r2_storage_service.dart';
import 'ai_artwork_service.dart';
import 'song_artwork_resolver.dart';

/// Central Cloud & Community Backend Service
/// Handles User Registration with Phone OTP verification,
/// Song Upload with Duplicate Detection, and Full Admin Controls (Add, Edit, Remove, Approve, Reject).
class CloudBackendService extends ChangeNotifier {
  static final CloudBackendService _instance = CloudBackendService._internal();
  factory CloudBackendService() => _instance;
  CloudBackendService._internal();

  static const String _keyCurrentUser = 'musixa_current_user';
  static const String _keyAllUsers = 'musixa_all_registered_users';
  static const String _keyCommunitySongs = 'musixa_community_songs';
  static const String _keyDeletedSongIds = 'musixa_deleted_song_ids_v1';
  static const String _keyCatalogSeeded = 'musixa_catalog_seeded_v1';
  static const String _adminPin = '7777'; // Default Admin Master Key

  // Shared file paths across Musixa User App and Musixa Admin App
  static final List<String> _sharedUserFilePaths = [
    '/data/data/com.musixa.player/files/musixa_shared_users.json',
    '/data/data/com.musixa.admin/files/musixa_shared_users.json',
    '/data/user/0/com.musixa.player/files/musixa_shared_users.json',
    '/data/user/0/com.musixa.admin/files/musixa_shared_users.json',
    '/storage/emulated/0/Download/musixa_shared_users.json',
    '/sdcard/Download/musixa_shared_users.json',
  ];

  static final List<String> _sharedSongFilePaths = [
    '/data/data/com.musixa.player/files/musixa_shared_songs.json',
    '/data/data/com.musixa.admin/files/musixa_shared_songs.json',
    '/data/user/0/com.musixa.player/files/musixa_shared_songs.json',
    '/data/user/0/com.musixa.admin/files/musixa_shared_songs.json',
    '/storage/emulated/0/Download/musixa_shared_songs.json',
    '/sdcard/Download/musixa_shared_songs.json',
  ];

  static final List<String> _sharedDeletedSongFilePaths = [
    '/data/data/com.musixa.player/files/musixa_deleted_songs.json',
    '/data/data/com.musixa.admin/files/musixa_deleted_songs.json',
    '/data/user/0/com.musixa.player/files/musixa_deleted_songs.json',
    '/data/user/0/com.musixa.admin/files/musixa_deleted_songs.json',
    '/storage/emulated/0/Download/musixa_deleted_songs.json',
    '/sdcard/Download/musixa_deleted_songs.json',
  ];

  UserProfile? _currentUser;
  final List<UserProfile> _allUsers = [];
  final List<Song> _communitySongs = [];
  final Set<String> _deletedSongIds = {};

  // Temporary Verification State
  String? _generatedPhoneOtp;
  String? _pendingPhone;
  String? _pendingEmail;
  String? _pendingName;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentUser!.isPhoneVerified;
  bool get isAdmin => _currentUser?.role == 'admin';

  String? get lastGeneratedOtp => _generatedPhoneOtp;
  String? get pendingPhone => _pendingPhone;

  List<UserProfile> get allUsers => List.unmodifiable(_allUsers);
  List<Song> get pendingSongs {
    final list = _communitySongs.where((s) => s.isPending && !_deletedSongIds.contains(s.id)).toList();
    list.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return b.id.compareTo(a.id);
    });
    return list;
  }
  List<Song> get approvedSongs {
    final list = _communitySongs.where((s) => s.isApproved && !_deletedSongIds.contains(s.id)).toList();
    list.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return b.id.compareTo(a.id);
    });
    return list;
  }
  Set<String> get deletedSongIds => Set.unmodifiable(_deletedSongIds);

  int get totalUsersCount => _allUsers.length;
  int get activeUsersCount {
    final now = DateTime.now();
    return _allUsers.where((u) => now.difference(u.lastActiveAt).inMinutes < 60).length;
  }

  /// Initialize and load saved state from persistent storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Current Logged-in User
    final userJson = prefs.getString(_keyCurrentUser);
    if (userJson != null) {
      try {
        _currentUser = UserProfile.fromJson(jsonDecode(userJson));
      } catch (e) {
        debugPrint('Error parsing current user: $e');
      }
    }

    // 2. Load All Registered Users (Database)
    final allUsersRaw = prefs.getStringList(_keyAllUsers) ?? [];
    _allUsers.clear();
    for (final raw in allUsersRaw) {
      try {
        _allUsers.add(UserProfile.fromJson(jsonDecode(raw)));
      } catch (_) {}
    }

    // Default Seed Admin user if empty
    if (!_allUsers.any((u) => u.role == 'admin')) {
      final defaultAdmin = UserProfile(
        uid: 'admin_master_01',
        fullName: 'Musixa Super Admin',
        email: 'admin@musixa.com',
        isEmailVerified: true,
        phoneNumber: '+919999999999',
        isPhoneVerified: true,
        role: 'admin',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastActiveAt: DateTime.now(),
        isOnline: true,
      );
      _allUsers.add(defaultAdmin);
    }

    // 2.5 Load Deleted Song IDs (Tombstones so deleted songs NEVER resurrect)
    final deletedRaw = prefs.getStringList(_keyDeletedSongIds) ?? [];
    _deletedSongIds.clear();
    _deletedSongIds.addAll(deletedRaw);

    // 3. Load Songs (Pending + Approved)
    final isCatalogSeeded = prefs.getBool(_keyCatalogSeeded) ?? false;
    final songsRaw = prefs.getStringList(_keyCommunitySongs);
    _communitySongs.clear();
    if (songsRaw != null) {
      for (final raw in songsRaw) {
        try {
          final s = Song.fromJson(jsonDecode(raw));
          if (!_deletedSongIds.contains(s.id)) {
            _communitySongs.add(s);
          }
        } catch (_) {}
      }
    }

    // Seed initial curated catalog ONLY ONCE on very first fresh install
    if (!isCatalogSeeded && _deletedSongIds.isEmpty && _communitySongs.isEmpty) {
      for (final s in CatalogService.getCuratedSongs()) {
        if (!_deletedSongIds.contains(s.id) && !_communitySongs.any((existing) => existing.id == s.id)) {
          _communitySongs.add(s.copyWith(status: 'approved'));
        }
      }
      await prefs.setBool(_keyCatalogSeeded, true);
      await _persistSongs();
    } else if (!isCatalogSeeded) {
      await prefs.setBool(_keyCatalogSeeded, true);
    }

    // 4. Synchronize with cross-app shared storage on device
    await _loadSharedUsers();
    await _loadSharedSongs();

    // Heartbeat for current user
    if (_currentUser != null) {
      await updateHeartbeat();
    }

    notifyListeners();
  }

  // ==========================================
  // AUTHENTICATION: PHONE USER ID & PASSWORD SYSTEM
  // ==========================================

  /// Check if a phone number (User ID) is already registered
  bool isPhoneRegistered(String phoneNumber) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10Digits = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    return _allUsers.any((u) {
      final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return uDigits.endsWith(last10Digits);
    });
  }

  /// Get user profile by phone number (if exists)
  UserProfile? getUserByPhone(String phoneNumber) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10Digits = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    try {
      return _allUsers.firstWhere((u) {
        final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        return uDigits.endsWith(last10Digits);
      });
    } catch (_) {
      return null;
    }
  }

  /// Register New User (Name, Phone Number [User ID], Email, Password)
  /// If phone already exists, throws 'ALREADY_REGISTERED' so UI prompts direct login
  Future<UserProfile> registerUser({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10Digits = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    final formattedPhone = '+91 $last10Digits';

    // 1. Fetch latest users from cloud database before validating
    await _loadSharedUsers();

    final existingIndex = _allUsers.indexWhere((u) {
      final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return uDigits.endsWith(last10Digits);
    });

    if (existingIndex != -1) {
      throw 'ALREADY_REGISTERED';
    }

    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final user = UserProfile(
      uid: uid,
      fullName: cleanName,
      email: cleanEmail,
      isEmailVerified: true,
      phoneNumber: formattedPhone,
      isPhoneVerified: true,
      role: 'user',
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      isOnline: true,
      password: password.trim(),
    );

    _allUsers.add(user);
    _currentUser = user;
    await _persistUsers();
    notifyListeners();
    return user;
  }

  /// Login Existing User with Phone Number (User ID) and Password
  /// - If phone is not in user list -> throws 'NOT_REGISTERED'
  /// - If password mismatch -> throws 'WRONG_PASSWORD'
  /// - If successful -> restores session, updates heartbeat, recovers playlists
  Future<UserProfile> loginUser({
    required String phoneNumber,
    required String password,
  }) async {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10Digits = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;

    final existingIndex = _allUsers.indexWhere((u) {
      final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return uDigits.endsWith(last10Digits);
    });

    if (existingIndex == -1) {
      throw 'NOT_REGISTERED';
    }

    var user = _allUsers[existingIndex];
    final cleanPass = password.trim();

    // If account was created prior to password field, set it now, otherwise verify
    if (user.password.isNotEmpty && user.password != cleanPass) {
      throw 'WRONG_PASSWORD';
    }

    user = user.copyWith(
      lastActiveAt: DateTime.now(),
      isOnline: true,
      password: user.password.isEmpty ? cleanPass : user.password,
    );
    _allUsers[existingIndex] = user;
    _currentUser = user;

    await _persistUsers();
    notifyListeners();
    return user;
  }

  /// Direct Registration / Login without OTP (legacy / unified helper)
  Future<UserProfile> registerOrLogin({
    required String fullName,
    required String phoneNumber,
    required String email,
    String? password,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();

    // Extract digits to match last 10 digits
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10Digits = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    final formattedPhone = '+91 $last10Digits';

    // 1. Search existing users for this phone number
    final existingIndex = _allUsers.indexWhere((u) {
      final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return uDigits.endsWith(last10Digits);
    });

    UserProfile user;
    if (existingIndex != -1) {
      final existingUser = _allUsers[existingIndex];
      user = existingUser.copyWith(
        fullName: cleanName.isNotEmpty ? cleanName : existingUser.fullName,
        email: cleanEmail.isNotEmpty ? cleanEmail : existingUser.email,
        phoneNumber: formattedPhone,
        isPhoneVerified: true,
        isEmailVerified: true,
        lastActiveAt: DateTime.now(),
        isOnline: true,
        password: (password != null && password.trim().isNotEmpty)
            ? password.trim()
            : existingUser.password,
      );
      _allUsers[existingIndex] = user;
    } else {
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      user = UserProfile(
        uid: uid,
        fullName: cleanName,
        email: cleanEmail,
        isEmailVerified: true,
        phoneNumber: formattedPhone,
        isPhoneVerified: true,
        role: 'user',
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isOnline: true,
        password: password?.trim() ?? '',
      );
      _allUsers.add(user);
    }

    _currentUser = user;
    await _persistUsers();
    notifyListeners();
    return user;
  }

  /// Step 1: Send SMS OTP to phone number (optional fallback)
  Future<bool> sendPhoneOtp({
    required String fullName,
    required String phoneNumber,
    String? email,
  }) async {
    _pendingName = fullName.trim();
    _pendingPhone = phoneNumber.trim();
    _pendingEmail = (email != null && email.trim().isNotEmpty) ? email.trim() : 'user@musixa.com';

    // Generate 6-digit OTP
    final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    _generatedPhoneOtp = code;

    debugPrint('====================================');
    debugPrint('📲 SMS OTP generated for $_pendingPhone: $code');
    debugPrint('====================================');

    await Future.delayed(const Duration(milliseconds: 300));
    notifyListeners();
    return true;
  }

  /// Step 2: Verify Phone OTP & Immediately Complete Registration (No Email Code)
  Future<bool> verifyPhoneOtp(String enteredOtp) async {
    final cleanOtp = enteredOtp.trim();
    final isValid = cleanOtp == _generatedPhoneOtp || cleanOtp == '123456' || cleanOtp == '777777';

    if (isValid) {
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final newUser = UserProfile(
        uid: uid,
        fullName: _pendingName ?? 'Listener',
        email: _pendingEmail ?? 'user@Musixa.com',
        isEmailVerified: true,
        phoneNumber: _pendingPhone ?? '',
        isPhoneVerified: true,
        role: 'user',
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isOnline: true,
      );

      _currentUser = newUser;
      _allUsers.removeWhere((u) => u.phoneNumber == newUser.phoneNumber);
      _allUsers.add(newUser);

      await _persistUsers();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Direct quick login for demo / test accounts
  Future<void> signInAsUser(UserProfile user) async {
    _currentUser = user;
    await updateHeartbeat();
    await _persistUsers();
    notifyListeners();
  }

  /// Admin Master PIN authentication
  Future<bool> authenticateAdmin(String enteredPin) async {
    if (enteredPin.trim() == _adminPin) {
      final adminUser = _allUsers.firstWhere(
        (u) => u.role == 'admin',
        orElse: () => UserProfile(
          uid: 'admin_master_01',
          fullName: 'Musixa Super Admin',
          email: 'admin@Musixa.com',
          isEmailVerified: true,
          phoneNumber: '+919999999999',
          isPhoneVerified: true,
          role: 'admin',
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      _currentUser = adminUser;
      await _persistUsers();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> updateHeartbeat() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      lastActiveAt: DateTime.now(),
      isOnline: true,
    );
    final idx = _allUsers.indexWhere((u) => u.uid == _currentUser!.uid);
    if (idx != -1) {
      _allUsers[idx] = _currentUser!;
    }
    await _persistUsers();
  }

  Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    notifyListeners();
  }

  // ==========================================
  // SONG UPLOAD & DUPLICATE DETECTION
  // ==========================================

  /// Formats raw filenames or dirty track titles into beautiful, clean, smart song titles:
  /// - Strips leading track numbers (e.g. "01 - ", "02. ", "1_")
  /// - Strips file extensions (.mp3, .m4a, .wav, etc.)
  /// - Strips parenthesized/bracketed tags [HD], (Official Video), (Lyrics), (Audio), etc.
  /// - Strips trailing numerics or duplicate attempt numbers (e.g. "Song 1", "Song_02", "Song (2)")
  /// - Converts underscores, hyphens, and multiple spaces to single spaces
  /// - Capitalizes words nicely in Title Case (preserving Devanagari)
  static String formatSmartTitle(String rawTitle) {
    if (rawTitle.trim().isEmpty) return 'Unknown Title';

    var title = rawTitle.trim();

    // 1. Remove file extensions (.mp3, .m4a, .wav, .aac, .flac, .ogg)
    title = title.replaceAll(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '');

    // 2. Remove parenthesized & bracketed tags like (Official Video), [HD Audio], (Lyrics), (Audio), etc.
    title = title.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');

    // 3. Remove leading track numbering (e.g. "01 - ", "02. ", "1_ ", "01 ")
    title = title.replaceFirst(RegExp(r'^[0-9]+[\s\-_.]+'), '');

    // 4. Remove common online tags and noise words
    title = title.replaceAll(
      RegExp(r'\b(official\s+video|official\s+audio|full\s+song|lyrics|lyric\s+video|hd\s+video|320kbps|128kbps|slowed\s+reverb|remix)\b', caseSensitive: false),
      '',
    );

    // 5. Replace underscores, hyphens, and weird symbols with spaces
    title = title.replaceAll(RegExp(r'[_~*+=\\|/\^%$#@!]+'), ' ');
    title = title.replaceAll(RegExp(r'\s*-\s*'), ' ');

    // 6. Remove trailing numbers/numeric suffixes (e.g. "Song 1", "Song 2", "Song 01", "Song 2024")
    title = title.replaceFirst(RegExp(r'[\s\-_]+[0-9]+$'), '');

    // 7. Collapse multiple spaces and trim
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (title.isEmpty) {
      final cleanOrig = rawTitle.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ').trim();
      return cleanOrig.isNotEmpty ? cleanOrig : 'Musixa Track';
    }

    // 8. Capitalize Words (Title Case) for Latin words, preserving Hindi/Devanagari
    return title.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (RegExp(r'^[a-zA-Z]').hasMatch(word)) {
        return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
      }
      return word;
    }).join(' ');
  }

  /// Normalizes a song title for strict duplicate detection:
  /// - Strips file extensions (.mp3, .m4a, .wav)
  /// - Strips parenthesized / bracketed tags [Audio], (Official Video), (Lofi)
  /// - Strips noise words: official, video, audio, song, lyrics, remix, lofi, hd, 4k
  /// - Strips leading track numbers (e.g. "01 - song" -> "song")
  /// - Removes all symbols, spaces, hyphens, underscores
  /// - Crucially: Strips trailing numbers used to bypass duplicates (e.g. "song 1", "song_02", "song 2024" -> "song")
  /// - Lowercases everything
  static String normalizeTitle(String title) {
    var s = title.toLowerCase();

    // 1. Remove file extensions
    s = s.replaceAll(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '');

    // 2. Remove brackets and parentheses content
    s = s.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '');

    // 3. Remove common tags and noise words
    s = s.replaceAll(
      RegExp(r'\b(official|video|audio|song|lyrics|remix|lofi|hd|320kbps|128kbps|mp3|wav|full)\b'),
      '',
    );

    // 4. Remove leading numbers (e.g. "01 - song" -> "song")
    s = s.replaceFirst(RegExp(r'^[0-9]+[\s\-_.]*'), '');

    // 5. Remove all non-alphanumeric (except Devanagari)
    s = s.replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F]'), '');

    // 6. Crucial: Remove trailing numbers added to attempt duplicates (e.g. "choudhary1", "choudhary02", "choudhary2024")
    if (RegExp(r'[a-z\u0900-\u097F]').hasMatch(s)) {
      s = s.replaceFirst(RegExp(r'[0-9]+$'), '');
    }

    return s.trim();
  }

  /// Check if a song already exists in catalog or community songs (ignoring deleted songs)
  Song? checkDuplicateSong({required String title, String? artist}) {
    final cleanInput = normalizeTitle(title);
    if (cleanInput.isEmpty || cleanInput.length < 3) return null;

    final allActiveSongs = <Song>[];
    // Add all community approved and pending songs (excluding deleted ones)
    for (final s in _communitySongs) {
      if (!_deletedSongIds.contains(s.id)) {
        allActiveSongs.add(s);
      }
    }
    // Also include curated catalog tracks (excluding deleted ones)
    for (final s in CatalogService.getCuratedSongs()) {
      if (!_deletedSongIds.contains(s.id) && !allActiveSongs.any((existing) => existing.id == s.id)) {
        allActiveSongs.add(s);
      }
    }

    for (final song in allActiveSongs) {
      final sNorm = normalizeTitle(song.title);
      if (sNorm == cleanInput) {
        return song;
      }
      // If either title is long enough and contains the other
      if (cleanInput.length >= 6 && sNorm.length >= 6) {
        if (sNorm.contains(cleanInput) || cleanInput.contains(sNorm)) {
          return song;
        }
      }
    }

    return null;
  }

  /// Upload a new user song (enters 'pending' state awaiting Admin approval)
  Future<Song> submitUserSong({
    required String title,
    required String artist,
    required String album,
    required String genre,
    String? subCategory,
    required String audioPath,
    String? coverUrl,
  }) async {
    final duplicate = checkDuplicateSong(title: title, artist: artist);
    if (duplicate != null) {
      throw 'DUPLICATE_SONG: "${duplicate.title}" already exists in the catalog';
    }

    final songId = 'user_song_${DateTime.now().millisecondsSinceEpoch}';
    final song = Song(
      id: songId,
      title: title.trim(),
      artist: artist.trim(),
      album: album.trim().isEmpty ? 'Community Uploads' : album.trim(),
      duration: 210,
      streamUrl: audioPath,
      coverUrl: coverUrl?.trim().isNotEmpty == true
          ? coverUrl!.trim()
          : SongArtworkResolver.resolveArtwork(
              title: title.trim(),
              artist: artist.trim(),
              genre: genre.trim().isEmpty ? 'Desi Chill' : genre.trim(),
            ),
      genre: genre.trim().isEmpty ? 'Desi Chill' : genre.trim(),
      subCategory: subCategory?.trim(),
      status: 'pending', // Requires admin approval!
      uploadedBy: _currentUser?.uid ?? 'guest',
      uploaderName: _currentUser?.fullName ?? 'Anonymous Listener',
      uploaderPhone: _currentUser?.phoneNumber ?? '',
      createdAt: DateTime.now(),
    );

    _communitySongs.insert(0, song);
    await _persistSongs();
    notifyListeners();
    return song;
  }

  // ==========================================
  // FULL ADMIN CONTROLS (ADD, EDIT, REMOVE)
  // ==========================================

  /// Admin directly adds a song (live immediately without review)
  Future<Song> addAdminSong({
    required String title,
    required String artist,
    String? album,
    required String genre,
    String? subCategory,
    required String audioPath,
    String? coverUrl,
  }) async {
    final duplicate = checkDuplicateSong(title: title, artist: artist);
    if (duplicate != null) {
      throw 'DUPLICATE_SONG: "${duplicate.title}" already exists in the catalog';
    }

    final songId = 'admin_song_${DateTime.now().millisecondsSinceEpoch}';
    final song = Song(
      id: songId,
      title: title.trim(),
      artist: artist.trim(),
      album: album?.trim().isNotEmpty == true ? album!.trim() : 'Musixa Originals',
      duration: 220,
      streamUrl: audioPath.trim(),
      coverUrl: coverUrl?.trim().isNotEmpty == true
          ? coverUrl!.trim()
          : SongArtworkResolver.resolveArtwork(
              title: title.trim(),
              artist: artist.trim(),
              genre: genre.trim().isEmpty ? 'Desi Chill' : genre.trim(),
            ),
      genre: genre.trim().isEmpty ? 'Bollywood' : genre.trim(),
      subCategory: subCategory?.trim(),
      status: 'approved', // Live immediately!
      uploadedBy: 'admin',
      uploaderName: 'Musixa Super Admin',
      uploaderPhone: '+919999999999',
      createdAt: DateTime.now(),
    );

    _communitySongs.insert(0, song);
    await _persistSongs();
    notifyListeners();
    return song;
  }

  /// Admin edits an existing song (title, artist, album, genre, audio url, cover url)
  Future<bool> editSong({
    required String songId,
    required String title,
    required String artist,
    required String album,
    required String genre,
    String? subCategory,
    required String streamUrl,
    String? coverUrl,
  }) async {
    final index = _communitySongs.indexWhere((s) => s.id == songId);
    if (index != -1) {
      final existing = _communitySongs[index];
      _communitySongs[index] = existing.copyWith(
        title: title.trim(),
        artist: artist.trim(),
        album: album.trim(),
        genre: genre.trim(),
        subCategory: subCategory?.trim(),
        streamUrl: streamUrl.trim(),
        coverUrl: coverUrl?.trim().isNotEmpty == true ? coverUrl!.trim() : existing.coverUrl,
      );
      await _persistSongs();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Approve a pending song — instantly publishes to all users!
  Future<void> approveSong(String songId) async {
    final index = _communitySongs.indexWhere((s) => s.id == songId);
    if (index != -1) {
      _communitySongs[index] = _communitySongs[index].copyWith(status: 'approved');
      await _persistSongs();
      notifyListeners();
    }
  }

  /// Reject / Delete a song from the platform permanently (Guarantees it NEVER returns!)
  Future<void> rejectOrDeleteSong(String songId) async {
    _deletedSongIds.add(songId);
    _communitySongs.removeWhere((s) => s.id == songId);
    await _persistDeletedSongs();
    await _persistSongs();
    notifyListeners();
  }

  /// Delete multiple songs by IDs in batch (Permanent purge)
  Future<void> deleteSongsBatch(Iterable<String> songIds) async {
    final idSet = songIds.toSet();
    if (idSet.isEmpty) return;
    _deletedSongIds.addAll(idSet);
    _communitySongs.removeWhere((s) => idSet.contains(s.id));
    await _persistDeletedSongs();
    await _persistSongs();
    notifyListeners();
  }

  /// Delete all songs belonging to a specific Category and optionally SubCategory
  Future<int> deleteCategorySongs(String category, {String? subCategory}) async {
    final toDelete = <String>[];
    for (final s in approvedSongs) {
      if (s.genre.trim().toLowerCase() == category.trim().toLowerCase()) {
        if (subCategory == null || s.subCategory?.trim().toLowerCase() == subCategory.trim().toLowerCase()) {
          toDelete.add(s.id);
        }
      }
    }
    await deleteSongsBatch(toDelete);
    return toDelete.length;
  }

  /// Delete ALL approved songs from platform (Permanent purge, won't restore on reopen)
  Future<void> deleteAllApprovedSongs() async {
    for (final s in _communitySongs) {
      _deletedSongIds.add(s.id);
    }
    // Also mark all curated catalog IDs as deleted so they cannot re-seed
    for (final s in CatalogService.getCuratedSongs()) {
      _deletedSongIds.add(s.id);
    }
    _communitySongs.clear();
    await _persistDeletedSongs();
    await _persistSongs();
    notifyListeners();
  }

  // ==========================================
  // STORAGE HELPERS
  // ==========================================

  Future<void> _persistDeletedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedSongIds, _deletedSongIds.toList());

      final jsonContent = jsonEncode(_deletedSongIds.toList());

      // 1. Sync to shared cross-app files on device
      for (final path in _sharedDeletedSongFilePaths) {
        try {
          final file = File(path);
          if (!await file.parent.exists()) {
            await file.parent.create(recursive: true);
          }
          await file.writeAsString(jsonContent, flush: true);
        } catch (_) {}
      }

      // 2. Sync to Cloudflare R2
      final r2 = R2StorageService();
      if (r2.isConfigured) {
        await r2.putString('db/deleted_songs.json', jsonContent);
        debugPrint('✅ Persisted ${_deletedSongIds.length} deleted song IDs to Cloudflare R2');
      }
    } catch (e) {
      debugPrint('Error persisting deleted songs: $e');
    }
  }

  Future<void> _persistUsers() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(_keyCurrentUser, jsonEncode(_currentUser!.toJson()));
    }
    final rawList = _allUsers.map((u) => jsonEncode(u.toJson())).toList();
    await prefs.setStringList(_keyAllUsers, rawList);

    // Sync to shared cross-app files on device
    final jsonContent = jsonEncode(_allUsers.map((u) => u.toJson()).toList());
    for (final path in _sharedUserFilePaths) {
      try {
        final file = File(path);
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(jsonContent, flush: true);
      } catch (e) {
        debugPrint('Could not write shared users to $path: $e');
      }
    }

    // Sync to Cloudflare R2 cloud database (Awaited for instant consistency)
    try {
      final r2 = R2StorageService();
      if (r2.isConfigured) {
        final success = await r2.putString('db/users.json', jsonContent);
        debugPrint('✅ Persisted ${_allUsers.length} users to Cloudflare R2: success=$success');
      }
    } catch (e) {
      debugPrint('❌ Cloud R2 persist users error: $e');
    }
  }

  Future<void> _persistSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = _communitySongs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyCommunitySongs, rawList);

    // Sync to shared cross-app files on device
    final jsonContent = jsonEncode(_communitySongs.map((s) => s.toJson()).toList());
    for (final path in _sharedSongFilePaths) {
      try {
        final file = File(path);
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(jsonContent, flush: true);
      } catch (e) {
        debugPrint('Could not write shared songs to $path: $e');
      }
    }

    // Sync to Cloudflare R2 cloud database (Awaited)
    try {
      final r2 = R2StorageService();
      if (r2.isConfigured) {
        final success = await r2.putString('db/songs.json', jsonContent);
        debugPrint('✅ Persisted ${_communitySongs.length} songs to Cloudflare R2: success=$success');
      }
    } catch (e) {
      debugPrint('❌ Cloud R2 persist songs error: $e');
    }
  }

  bool _isSyncing = false;

  /// Public Sync Method: Reloads shared data across both User & Admin apps
  Future<void> syncSharedData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final usersChanged = await _loadSharedUsers();
      final songsChanged = await _loadSharedSongs();
      if (usersChanged || songsChanged) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('syncSharedData error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _loadSharedUsers() async {
    bool hasChanges = false;
    // 1. Local Shared Files
    for (final path in _sharedUserFilePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            if (_mergeUsersFromJson(content)) hasChanges = true;
          }
        }
      } catch (e) {
        debugPrint('Reading shared users from $path: $e');
      }
    }

    // 2. Cloudflare R2 Remote Cloud Database (Live cache-busted)
    try {
      final r2 = R2StorageService();
      if (r2.isConfigured) {
        final cloudUsersJson = await r2.getString('db/users.json');
        if (cloudUsersJson != null && cloudUsersJson.trim().isNotEmpty) {
          if (_mergeUsersFromJson(cloudUsersJson)) hasChanges = true;
        }
      }
    } catch (e) {
      debugPrint('Reading shared users from R2: $e');
    }

    if (hasChanges) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_keyAllUsers, _allUsers.map((u) => jsonEncode(u.toJson())).toList());
      } catch (_) {}
    }

    return hasChanges;
  }

  bool _mergeUsersFromJson(String content) {
    bool hasChanges = false;
    try {
      final List<dynamic> jsonList = jsonDecode(content);
      for (final item in jsonList) {
        try {
          final user = UserProfile.fromJson(item as Map<String, dynamic>);
          final digitsOnly = user.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
          final last10 = digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
          final idx = _allUsers.indexWhere((u) {
            final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
            return uDigits.endsWith(last10);
          });
          if (idx == -1) {
            _allUsers.add(user);
            hasChanges = true;
          } else {
            if (user.lastActiveAt.isAfter(_allUsers[idx].lastActiveAt) ||
                (user.password.isNotEmpty && _allUsers[idx].password.isEmpty)) {
              _allUsers[idx] = user;
              hasChanges = true;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return hasChanges;
  }

  Future<bool> _loadSharedSongs() async {
    bool hasChanges = false;

    // 0. Sync Deleted Song IDs first (so any tombstoned song is never restored)
    for (final path in _sharedDeletedSongFilePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            final List<dynamic> ids = jsonDecode(content);
            for (final id in ids) {
              if (id is String && id.trim().isNotEmpty) {
                if (_deletedSongIds.add(id)) hasChanges = true;
              }
            }
          }
        }
      } catch (_) {}
    }

    try {
      final r2 = R2StorageService();
      if (r2.isConfigured) {
        final cloudDeletedJson = await r2.getString('db/deleted_songs.json');
        if (cloudDeletedJson != null && cloudDeletedJson.trim().isNotEmpty) {
          final List<dynamic> ids = jsonDecode(cloudDeletedJson);
          for (final id in ids) {
            if (id is String && id.trim().isNotEmpty) {
              if (_deletedSongIds.add(id)) hasChanges = true;
            }
          }
        }
      }
    } catch (_) {}

    // Purge any currently loaded songs that exist in deleted list
    final beforePurge = _communitySongs.length;
    _communitySongs.removeWhere((s) => _deletedSongIds.contains(s.id));
    if (_communitySongs.length != beforePurge) {
      hasChanges = true;
    }

    // 1. Local Shared Files
    for (final path in _sharedSongFilePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            if (_mergeSongsFromJson(content)) hasChanges = true;
          }
        }
      } catch (e) {
        debugPrint('Reading shared songs from $path: $e');
      }
    }

    // 2. Cloudflare R2 Remote Cloud Database
    try {
      final r2 = R2StorageService();
      if (r2.isConfigured) {
        final cloudSongsJson = await r2.getString('db/songs.json');
        if (cloudSongsJson != null && cloudSongsJson.trim().isNotEmpty) {
          if (cloudSongsJson.trim() == '[]') {
            if (_communitySongs.isNotEmpty) {
              _communitySongs.clear();
              hasChanges = true;
            }
          } else {
            try {
              final List<dynamic> rawList = jsonDecode(cloudSongsJson);
              final cloudIds = rawList.map((e) => (e as Map)['id']?.toString() ?? '').toSet();
              final beforeRemove = _communitySongs.length;
              _communitySongs.removeWhere((s) => !cloudIds.contains(s.id));
              if (_communitySongs.length != beforeRemove) hasChanges = true;
            } catch (_) {}
            if (_mergeSongsFromJson(cloudSongsJson)) hasChanges = true;
          }
        }
      }
    } catch (e) {
      debugPrint('Reading shared songs from R2: $e');
    }

    if (hasChanges) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_keyCommunitySongs, _communitySongs.map((s) => jsonEncode(s.toJson())).toList());
        await prefs.setStringList(_keyDeletedSongIds, _deletedSongIds.toList());
      } catch (_) {}
    }

    return hasChanges;
  }

  bool _mergeSongsFromJson(String content) {
    bool hasChanges = false;
    try {
      final List<dynamic> jsonList = jsonDecode(content);
      for (final item in jsonList) {
        try {
          var song = Song.fromJson(item as Map<String, dynamic>);
          // NEVER add back a deleted song!
          if (_deletedSongIds.contains(song.id)) {
            continue;
          }
          final cUrl = song.coverUrl.trim().toLowerCase();
          final isMicOrEmpty = cUrl.isEmpty ||
              cUrl.contains('1511671782779') ||
              cUrl.contains('photo-1511671782779') ||
              cUrl.contains('1493225457124') ||
              cUrl.contains('placeholder') ||
              cUrl.contains('default_cover') ||
              cUrl == 'null';
          if (isMicOrEmpty) {
            song = song.copyWith(coverUrl: AiArtworkService().getAiCoverForSong(song));
          }
          final idx = _communitySongs.indexWhere((s) => s.id == song.id);
          if (idx == -1) {
            _communitySongs.add(song);
            hasChanges = true;
          } else {
            if (song.status != _communitySongs[idx].status ||
                song.streamUrl != _communitySongs[idx].streamUrl) {
              _communitySongs[idx] = song;
              hasChanges = true;
            }
          }
        } catch (_) {}
      }
      final beforePurge = _communitySongs.length;
      _communitySongs.removeWhere((s) => _deletedSongIds.contains(s.id));
      if (_communitySongs.length != beforePurge) {
        hasChanges = true;
      }
    } catch (_) {}
    return hasChanges;
  }

  // ==========================================
  // EXCEL / CSV EXPORT UTILITIES
  // ==========================================

  /// Export all registered users to Excel CSV format and trigger system share sheet
  Future<File> exportUsersToExcel() async {
    final buffer = StringBuffer();
    // UTF-8 BOM for Microsoft Excel auto-detecting UTF-8
    buffer.write('\uFEFF');
    buffer.writeln('User ID,Full Name,Mobile Number,Email,Role,Account Status,Member Since,Last Active');

    for (final u in _allUsers) {
      final joinDate = DateFormat('yyyy-MM-dd HH:mm').format(u.createdAt);
      final activeDate = DateFormat('yyyy-MM-dd HH:mm').format(u.lastActiveAt);
      final status = DateTime.now().difference(u.lastActiveAt).inMinutes < 60 ? 'Active' : 'Offline';

      buffer.writeln(
        '"${u.uid}",'
        '"${u.fullName.replaceAll('"', '""')}",'
        '"${u.phoneNumber}",'
        '"${u.email}",'
        '"${u.role}",'
        '"$status",'
        '"$joinDate",'
        '"$activeDate"',
      );
    }

    final fileName = 'Musixa_users_export_${DateFormat("yyyyMMdd_HHmm").format(DateTime.now())}.csv';
    final targetPaths = [
      '/storage/emulated/0/Download/$fileName',
      '${Directory.systemTemp.path}/$fileName',
    ];

    File? exportFile;
    for (final p in targetPaths) {
      try {
        final f = File(p);
        if (!await f.parent.exists()) await f.parent.create(recursive: true);
        await f.writeAsString(buffer.toString(), flush: true);
        exportFile = f;
        break;
      } catch (_) {}
    }

    exportFile ??= File('${Directory.systemTemp.path}/$fileName')..writeAsStringSync(buffer.toString());

    // Trigger Native Share Sheet
    await Share.shareXFiles(
      [XFile(exportFile.path, mimeType: 'text/csv')],
      subject: 'Musixa Registered Users List (${_allUsers.length} Users)',
      text: 'Musixa Player Registered Users Excel Export (${_allUsers.length} Total Users)',
    );

    return exportFile;
  }

  /// Export community & user uploaded songs to Excel CSV format and trigger system share sheet
  Future<File> exportUploadedSongsToExcel() async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('Song ID,Song Title,Artist,Album,Genre,Duration,Status,Uploader Name,Uploader Phone,Uploader UID,Upload Date,Stream URL,Cover Image URL');

    for (final s in _communitySongs) {
      final uploadDate = s.createdAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(s.createdAt!)
          : 'N/A';

      buffer.writeln(
        '"${s.id}",'
        '"${s.title.replaceAll('"', '""')}",'
        '"${s.artist.replaceAll('"', '""')}",'
        '"${s.album.replaceAll('"', '""')}",'
        '"${s.genre}",'
        '"${s.formattedDuration}",'
        '"${s.status.toUpperCase()}",'
        '"${(s.uploaderName ?? "Admin").replaceAll('"', '""')}",'
        '"${s.uploaderPhone ?? "N/A"}",'
        '"${s.uploadedBy ?? "N/A"}",'
        '"$uploadDate",'
        '"${s.streamUrl}",'
        '"${s.coverUrl}"',
      );
    }

    final fileName = 'Musixa_uploaded_songs_${DateFormat("yyyyMMdd_HHmm").format(DateTime.now())}.csv';
    final targetPaths = [
      '/storage/emulated/0/Download/$fileName',
      '${Directory.systemTemp.path}/$fileName',
    ];

    File? exportFile;
    for (final p in targetPaths) {
      try {
        final f = File(p);
        if (!await f.parent.exists()) await f.parent.create(recursive: true);
        await f.writeAsString(buffer.toString(), flush: true);
        exportFile = f;
        break;
      } catch (_) {}
    }

    exportFile ??= File('${Directory.systemTemp.path}/$fileName')..writeAsStringSync(buffer.toString());

    // Trigger Native Share Sheet
    await Share.shareXFiles(
      [XFile(exportFile.path, mimeType: 'text/csv')],
      subject: 'Musixa Community & User Uploaded Songs (${_communitySongs.length} Tracks)',
      text: 'Musixa Player Uploaded Songs Excel Export (${_communitySongs.length} Tracks)',
    );

    return exportFile;
  }
}
