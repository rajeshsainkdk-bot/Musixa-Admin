import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../services/cloud_backend_service.dart';
import '../../services/language_service.dart';
import '../../services/r2_storage_service.dart';
import '../../services/update_service.dart';
import '../../services/background_upload_service.dart';
import '../../services/storage_service.dart';
import '../../services/song_artwork_resolver.dart';
import '../../models/song.dart';
import '../../models/user_profile.dart';
import '../../models/playlist.dart';

class DetectedFolderHierarchy {
  final String category;
  final String? subCategory;

  const DetectedFolderHierarchy({required this.category, this.subCategory});

  static DetectedFolderHierarchy fromPath(String filePath, {String? rootFolderPath}) {
    final cleanPath = filePath.replaceAll(r'\', '/');

    // 1. If rootFolderPath was picked, use relative folder structure
    if (rootFolderPath != null && rootFolderPath.trim().isNotEmpty) {
      final cleanRoot = rootFolderPath.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
      if (cleanPath.startsWith(cleanRoot)) {
        final relative = cleanPath.substring(cleanRoot.length).replaceAll(RegExp(r'^/+'), '');
        final relParts = relative.split('/').where((p) => p.trim().isNotEmpty).toList();
        final rootParts = cleanRoot.split('/').where((p) => p.trim().isNotEmpty).toList();
        final rootFolderName = rootParts.isNotEmpty ? rootParts.last : 'Rajasthani';

        if (relParts.length <= 1) {
          // File directly in root folder: Category = rootFolderName, SubCategory = null
          return DetectedFolderHierarchy(category: rootFolderName, subCategory: null);
        } else {
          // File in subfolder inside root folder: Category = rootFolderName, SubCategory = immediate subfolder
          final subFolder = relParts.first;
          return DetectedFolderHierarchy(category: rootFolderName, subCategory: subFolder);
        }
      }
    }

    // 2. Generic path inspection
    final parts = cleanPath.split('/').where((p) => p.trim().isNotEmpty).toList();
    if (parts.length < 2) {
      return const DetectedFolderHierarchy(category: 'Rajasthani');
    }
    const systemFolders = {
      'storage', 'emulated', '0', '1', 'sdcard', 'android', 'media', 'data',
      'download', 'downloads', 'music', 'audio', 'documents', 'dcim', 'desktop',
      'c:', 'd:', 'e:', 'users', 'user', 'home', 'appdata', 'temp', 'tmp'
    };
    final parentDir = parts[parts.length - 2];
    final grandParentDir = parts.length >= 3 ? parts[parts.length - 3] : null;

    if (grandParentDir != null && !systemFolders.contains(grandParentDir.toLowerCase())) {
      return DetectedFolderHierarchy(
        category: grandParentDir,
        subCategory: parentDir,
      );
    } else {
      final cat = systemFolders.contains(parentDir.toLowerCase()) ? 'Rajasthani' : parentDir;
      return DetectedFolderHierarchy(
        category: cat,
        subCategory: null,
      );
    }
  }

  /// Resolves Android SAF (content://) tree URIs to standard device storage paths
  static String resolveSafPath(String pathOrUri) {
    if (!pathOrUri.startsWith('content://')) return pathOrUri;
    try {
      final decoded = Uri.decodeFull(pathOrUri);
      if (decoded.contains('primary:')) {
        final sub = decoded.split('primary:').last;
        return '/storage/emulated/0/$sub';
      } else if (decoded.contains('raw:')) {
        return decoded.split('raw:').last;
      } else {
        final match = RegExp(r'tree\/([A-Za-z0-9\-]+):(.*)').firstMatch(decoded);
        if (match != null) {
          return '/storage/${match.group(1)}/${match.group(2)}';
        }
      }
    } catch (e) {
      debugPrint('SAF resolve error: $e');
    }
    return pathOrUri;
  }

  /// BFS queue-based safe recursive directory scanner that traverses all subfolders
  static Future<List<PlatformFile>> scanAudioFilesFromDirectory(String pathOrUri) async {
    final rawPath = resolveSafPath(pathOrUri);
    final rootDir = Directory(rawPath);
    if (!rootDir.existsSync()) {
      return [];
    }

    final List<PlatformFile> found = [];
    final List<Directory> queue = [rootDir];
    final Set<String> visited = {};
    const audioExts = {'mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg'};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current.path)) continue;
      visited.add(current.path);

      try {
        final entries = current.listSync(followLinks: false);
        for (final e in entries) {
          if (e is File) {
            final ext = e.path.split('.').last.toLowerCase();
            if (audioExts.contains(ext)) {
              try {
                final len = e.lengthSync();
                final nm = e.path.split(RegExp(r'[\\/]')).last;
                found.add(PlatformFile(path: e.path, name: nm, size: len));
              } catch (_) {}
            }
          } else if (e is Directory) {
            final name = e.path.split(RegExp(r'[\\/]')).last;
            if (!name.startsWith('.')) {
              queue.add(e);
            }
          }
        }
      } catch (e) {
        debugPrint('Skip dir scan error for ${current.path}: $e');
      }
    }
    return found;
  }
}

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onSignOut;

  const AdminDashboardScreen({Key? key, required this.onSignOut}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final _backend = CloudBackendService();
  final _lang = LanguageService();
  final _player = AudioPlayer();
  late TabController _tabController;

  static const List<String> _allGenres = [
    'Rajasthani',
    'Bhakti',
    'Haryanvi',
    'Punjabi',
    'Sufi',
    'Bollywood',
    'Desi Lo-Fi',
    'Ghazal',
    'DJ Remix',
    'Bhojpuri',
    'Spiritual',
    'Folk Fusion',
    'Classical',
    'Pop / Indie',
  ];

  String? _currentlyPlayingSongId;
  bool _isPlaying = false;
  String _userSearchQuery = '';
  Timer? _syncTimer;
  Map<String, dynamic>? _storageStats;
  bool _isLoadingStorageStats = false;
  bool _adminGroupByCategory = true;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedSongIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _backend.syncSharedData();
      }
    });
    _backend.addListener(_onUpdate);
    _lang.addListener(_onUpdate);

    // Initial sync with shared storage
    _backend.syncSharedData();
    _refreshStorageStats();

    // Check for Admin App Auto-Update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context, autoPrompt: true, isAdmin: true);
    });

    // Periodic background sync every 2 seconds for instant updates
    int tickCount = 0;
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _backend.syncSharedData();
        tickCount++;
        if (tickCount % 15 == 0) {
          _refreshStorageStats();
        }
      }
    });

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing && state.processingState != ProcessingState.completed;
        });
      }
    });
  }

  Future<void> _refreshStorageStats() async {
    if (_isLoadingStorageStats) return;
    _isLoadingStorageStats = true;
    try {
      final stats = await R2StorageService().getStorageUsageStats(
        knownSongsCount: _backend.approvedSongs.length,
      );
      if (mounted) {
        setState(() {
          _storageStats = stats;
        });
      }
    } catch (_) {} finally {
      _isLoadingStorageStats = false;
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tabController.dispose();
    _backend.removeListener(_onUpdate);
    _lang.removeListener(_onUpdate);
    _player.dispose();
    super.dispose();
  }

  Future<void> _playSongPreview(Song song) async {
    try {
      if (_currentlyPlayingSongId == song.id && _isPlaying) {
        await _player.pause();
        return;
      }

      setState(() => _currentlyPlayingSongId = song.id);

      if (song.streamUrl.startsWith('assets/')) {
        await _player.setAsset(song.streamUrl);
      } else if (song.streamUrl.startsWith('/') || song.streamUrl.startsWith('file://')) {
        await _player.setFilePath(song.streamUrl.replaceFirst('file://', ''));
      } else {
        await _player.setUrl(song.streamUrl);
      }
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio Preview Error: $e')),
      );
    }
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean?text=Hello%20from%20Musixa%20Admin');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchMail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Musixa%20Support');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static DetectedFolderHierarchy detectFolderHierarchy(String filePath, {String? rootFolderPath}) =>
      DetectedFolderHierarchy.fromPath(filePath, rootFolderPath: rootFolderPath);

  /// Shows an in-app visual dialog with all real folders containing songs on the device
  Future<void> _showDeviceFolderPicker(
    BuildContext context, {
    required Function(List<PlatformFile> files, String folderName, String folderPath) onFolderSelected,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB300)),
      ),
    );

    final Map<String, List<PlatformFile>> folderMap = {};
    try {
      final audioQuery = OnAudioQuery();
      final songs = await audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      for (final s in songs) {
        final path = s.data;
        if (path.isEmpty) continue;
        final nm = path.split(RegExp(r'[\\/]')).last;
        final clean = path.replaceAll(r'\', '/');
        final lastSlash = clean.lastIndexOf('/');
        if (lastSlash == -1) continue;
        final parent = clean.substring(0, lastSlash);
        final pf = PlatformFile(path: path, name: nm, size: s.size);
        folderMap.putIfAbsent(parent, () => []).add(pf);
      }
    } catch (e) {
      debugPrint('Error querying audio folders: $e');
    }

    if (context.mounted) Navigator.pop(context);

    if (folderMap.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('डिवाइस पर कोई ऑडियो फ़ोल्डर नहीं मिला। "सिस्टम फ़ोल्डर" या "गाने चुनें" आज़माएं।')),
        );
      }
      return;
    }

    final sortedFolders = folderMap.keys.toList()
      ..sort((a, b) => (folderMap[b]?.length ?? 0).compareTo(folderMap[a]?.length ?? 0));

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (bCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.folder_special_rounded, color: Color(0xFFFFB300), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'डिवाइस पर मिले गानों वाले फ़ोल्डर',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${sortedFolders.length} फ़ोल्डर',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                itemCount: sortedFolders.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (ctx, i) {
                  final folderPath = sortedFolders[i];
                  final cleanPath = folderPath.replaceAll(r'\', '/');
                  final folderName = cleanPath.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => 'Folder');

                  final List<PlatformFile> allInFolderAndSub = [];
                  for (final entry in folderMap.entries) {
                    if (entry.key == folderPath || entry.key.startsWith('$folderPath/')) {
                      allInFolderAndSub.addAll(entry.value);
                    }
                  }

                  final rel = cleanPath
                      .replaceFirst(RegExp(r'^/storage/emulated/[0-9]+/?'), '')
                      .replaceFirst(RegExp(r'^/storage/[^/]+/?'), '')
                      .replaceFirst(RegExp(r'^[A-Za-z]:/[^/]+/[^/]+/?'), '');

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_rounded, color: Color(0xFFFFB300), size: 22),
                    ),
                    title: Text(
                      folderName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      rel.isNotEmpty ? rel : cleanPath,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                      ),
                      child: Text(
                        '${allInFolderAndSub.length} गाने',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(bCtx);
                      onFolderSelected(allInFolderAndSub, folderName, folderPath);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkUploadDialog({String? prefillGenre, String? prefillSubCategory}) {
    List<PlatformFile> pickedFiles = [];
    final Map<String, DetectedFolderHierarchy> fileHierarchyMap = {};
    bool isUploading = false;
    int currentIndex = 0;
    double currentTrackProgress = 0.0;
    String statusMessage = '';
    String selectedGenre = prefillGenre ?? 'Rajasthani';
    final genres = List<String>.from(_allGenres);
    if (!genres.contains(selectedGenre)) genres.insert(0, selectedGenre);
    final playlistTitleCtrl = TextEditingController();
    final subCategoryCtrl = TextEditingController(text: prefillSubCategory ?? '');
    bool createPlaylistWithFolder = true;

    void updateFilesHierarchy(List<PlatformFile> files, {String? rootFolderPath}) {
      pickedFiles = files;
      for (final f in pickedFiles) {
        if (f.path != null) {
          final detected = detectFolderHierarchy(f.path!, rootFolderPath: rootFolderPath);
          if (prefillGenre != null) {
            fileHierarchyMap[f.path!] = DetectedFolderHierarchy(
              category: prefillGenre,
              subCategory: prefillSubCategory ?? detected.subCategory ?? (subCategoryCtrl.text.trim().isNotEmpty ? subCategoryCtrl.text.trim() : null),
            );
          } else {
            fileHierarchyMap[f.path!] = detected;
          }
        }
      }
      if (pickedFiles.isNotEmpty && pickedFiles.first.path != null) {
        final fh = fileHierarchyMap[pickedFiles.first.path!];
        if (prefillGenre == null && fh != null) {
          selectedGenre = fh.category;
          if (!genres.contains(selectedGenre)) genres.insert(0, selectedGenre);
          if (fh.subCategory != null && subCategoryCtrl.text.isEmpty) {
            subCategoryCtrl.text = fh.subCategory!;
          }
        }
        if (rootFolderPath != null && rootFolderPath.isNotEmpty) {
          final folderName = rootFolderPath.replaceAll(r'\', '/').split('/').lastWhere((s) => s.isNotEmpty, orElse: () => 'Bulk Playlist');
          playlistTitleCtrl.text = folderName;
        } else {
          final parentDir = File(pickedFiles.first.path!).parent;
          final folderName = parentDir.path.split(RegExp(r'[\\/]')).lastWhere((s) => s.isNotEmpty, orElse: () => 'Bulk Playlist');
          playlistTitleCtrl.text = folderName;
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.folder_copy_rounded, color: Color(0xFFFFB300), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'बल्क / फ़ोल्डर गाने अपलोड करें',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'डिवाइस से फ़ोल्डर या कई MP3s चुनें। फ़ोल्डर का नाम Category और अंदर के सब-फ़ोल्डर का नाम Sub-Category बन जाएगा। स्क्रीन लॉक होने पर भी बैकग्राउंड में अपलोड जारी रहेगा।',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 14),

                  if (!isUploading) ...[
                    Row(
                      children: [
                        // Button 1: Device Folders Explorer (100% Reliable In-App)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFFFFB300),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: const Color(0xFFFFB300).withOpacity(0.6)),
                              ),
                            ),
                            icon: const Icon(Icons.folder_special_rounded, size: 15),
                            label: const Text(
                              '📁 डिवाइस फ़ोल्डर',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            onPressed: () {
                              _showDeviceFolderPicker(
                                context,
                                onFolderSelected: (files, folderName, folderPath) {
                                  setDialogState(() {
                                    updateFilesHierarchy(files, rootFolderPath: folderPath);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ फ़ोल्डर "$folderName" से ${files.length} गाने लोड हुए!'),
                                      backgroundColor: const Color(0xFF1E293B),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Button 2: System SAF Folder Picker
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFFFFB300),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.white24),
                              ),
                            ),
                            icon: const Icon(Icons.drive_folder_upload_rounded, size: 15),
                            label: const Text(
                              '📂 सिस्टम फ़ोल्डर',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            onPressed: () async {
                              try {
                                final dirPath = await FilePicker.platform.getDirectoryPath();
                                if (dirPath != null) {
                                  final found = await DetectedFolderHierarchy.scanAudioFilesFromDirectory(dirPath);
                                  if (found.isNotEmpty) {
                                    setDialogState(() {
                                      final rawPath = DetectedFolderHierarchy.resolveSafPath(dirPath);
                                      updateFilesHierarchy(found, rootFolderPath: rawPath);
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('चयनित फ़ोल्डर में कोई गाना नहीं मिला। "डिवाइस फ़ोल्डर" आज़माएं।')),
                                    );
                                  }
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Folder picker error: $e')));
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Button 3: Multi-Select Songs
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFF00E5FF),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                              ),
                            ),
                            icon: const Icon(Icons.file_open_rounded, size: 15),
                            label: Text(
                              pickedFiles.isEmpty ? '🎵 गाने चुनें' : '🎵 (${pickedFiles.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            onPressed: () async {
                              try {
                                final result = await FilePicker.platform.pickFiles(
                                  allowMultiple: true,
                                  type: FileType.custom,
                                  allowedExtensions: ['mp3', 'm4a', 'wav'],
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  setDialogState(() {
                                    final files = result.files.where((f) => f.path != null).toList();
                                    updateFilesHierarchy(files);
                                  });
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File picker error: $e')));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (pickedFiles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'डिफ़ॉल्ट श्रेणी (Default Category / Genre):',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedGenre,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: isUploading
                          ? null
                          : (val) {
                              if (val != null) setDialogState(() => selectedGenre = val);
                            },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'डिफ़ॉल्ट उप-श्रेणी (Default Sub-Category - Optional):',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: subCategoryCtrl,
                      enabled: !isUploading,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'उदा. Marwadi Hits, Folk (वैकल्पिक)',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Folder Name Playlist Option
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1728),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: createPlaylistWithFolder,
                            onChanged: isUploading
                                ? null
                                : (val) => setDialogState(() => createPlaylistWithFolder = val ?? false),
                            activeColor: const Color(0xFFFFB300),
                            checkColor: Colors.black,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              '📁 फ़ोल्डर के नाम से प्लेलिस्ट बनाएं',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'सभी अपलोड किए गए गानों से नई प्लेलिस्ट तैयार होगी',
                              style: TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ),
                          if (createPlaylistWithFolder) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: playlistTitleCtrl,
                              enabled: !isUploading,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'प्लेलिस्ट का नाम (Playlist Title)',
                                labelStyle: const TextStyle(color: Color(0xFFFFB300), fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'चयनित गाने (${pickedFiles.length}):',
                      style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1728),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: pickedFiles.length,
                        itemBuilder: (context, idx) {
                          final f = pickedFiles[idx];
                          final isCurrent = isUploading && currentIndex == idx;
                          final isDone = isUploading && idx < currentIndex;
                          final mb = (f.size / (1024 * 1024)).toStringAsFixed(1);
                          final smartTitle = CloudBackendService.formatSmartTitle(f.name);
                          final isDup = _backend.checkDuplicateSong(title: smartTitle, artist: '') != null;
                          final h = fileHierarchyMap[f.path] ?? (prefillGenre != null
                              ? DetectedFolderHierarchy(category: prefillGenre, subCategory: prefillSubCategory)
                              : detectFolderHierarchy(f.path ?? ''));

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  isDone
                                      ? Icons.check_circle_rounded
                                      : isCurrent
                                          ? Icons.cloud_upload_rounded
                                          : (isDup ? Icons.warning_amber_rounded : Icons.music_note_rounded),
                                  size: 14,
                                  color: isDone
                                      ? Colors.greenAccent
                                      : isCurrent
                                          ? const Color(0xFF00E5FF)
                                          : (isDup ? Colors.amberAccent : Colors.grey),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        smartTitle,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? const Color(0xFF00E5FF)
                                              : (isDup ? Colors.amberAccent : Colors.white70),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Row(
                                        children: [
                                          Text('$mb MB', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E5FF).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              h.subCategory != null ? '${h.category} › ${h.subCategory}' : h.category,
                                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDup && !isDone)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Duplicate',
                                      style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: pickedFiles.isNotEmpty ? (currentIndex + currentTrackProgress) / pickedFiles.length : null,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFFFFB300),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusMessage,
                      style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (!isUploading)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('रद्द करें (Cancel)', style: TextStyle(color: Colors.grey)),
              ),
            if (pickedFiles.isNotEmpty && !isUploading)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(
                  'R2 पर अपलोड शुरू करें (${pickedFiles.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () async {
                  setDialogState(() {
                    isUploading = true;
                    currentIndex = 0;
                    currentTrackProgress = 0.0;
                    statusMessage = 'अपलोड शुरू हो रहा है... (स्क्रीन ऑन और बैकग्राउंड एक्टिव)';
                  });

                  // 1. Keep Screen Awake & CPU Running in Background
                  await BackgroundUploadService.acquireWakeLock();

                  final r2 = R2StorageService();
                  int successCount = 0;
                  int skippedCount = 0;
                  final Set<String> batchUploadedTitles = {};
                  final List<Song> uploadedSongsList = [];

                  try {
                    for (int i = 0; i < pickedFiles.length; i++) {
                      final pf = pickedFiles[i];
                      if (pf.path == null) continue;

                      final smartTitle = CloudBackendService.formatSmartTitle(pf.name);

                      // Strict Duplicate Check: Skip if already in catalog or in current upload batch
                      final duplicate = _backend.checkDuplicateSong(title: smartTitle, artist: '');
                      final isBatchDup = batchUploadedTitles.contains(CloudBackendService.normalizeTitle(smartTitle));

                      if (duplicate != null || isBatchDup) {
                        skippedCount++;
                        setDialogState(() {
                          currentIndex = i;
                          currentTrackProgress = 1.0;
                          statusMessage = '⚠️ स्किप किया (Duplicate): $smartTitle (पहले से मौजूद)';
                        });
                        await Future.delayed(const Duration(milliseconds: 250));
                        continue;
                      }

                      batchUploadedTitles.add(CloudBackendService.normalizeTitle(smartTitle));

                      setDialogState(() {
                        currentIndex = i;
                        currentTrackProgress = 0.1;
                        statusMessage = 'अपलोड हो रहा है (${i + 1}/${pickedFiles.length}): $smartTitle...';
                      });

                      try {
                        final file = File(pf.path!);

                        final cloudUrl = await r2.uploadAudioFile(
                          file,
                          customId: 'bulk_${DateTime.now().millisecondsSinceEpoch}_$i',
                          onProgress: (p) => setDialogState(() => currentTrackProgress = p),
                        );

                        if (cloudUrl != null && cloudUrl.isNotEmpty) {
                          final h = fileHierarchyMap[pf.path] ?? (prefillGenre != null
                              ? DetectedFolderHierarchy(category: prefillGenre, subCategory: prefillSubCategory)
                              : detectFolderHierarchy(pf.path!));
                          final targetCategory = prefillGenre ?? (h.category.isNotEmpty ? h.category : selectedGenre);
                          final targetSubCategory = prefillSubCategory ?? (h.subCategory ?? (subCategoryCtrl.text.trim().isNotEmpty ? subCategoryCtrl.text.trim() : null));

                          final detectedSinger = SongArtworkResolver.extractArtist(smartTitle, fallback: 'Various Artists');
                          final newSong = await _backend.addAdminSong(
                            title: smartTitle,
                            artist: detectedSinger,
                            album: playlistTitleCtrl.text.trim().isNotEmpty ? playlistTitleCtrl.text.trim() : 'Musixa Cloud Hits',
                            genre: targetCategory,
                            subCategory: targetSubCategory,
                            audioPath: cloudUrl,
                          );
                          uploadedSongsList.add(newSong);
                          successCount++;
                        }
                      } catch (e) {
                        debugPrint('Error uploading ${pf.name}: $e');
                      }
                    }

                    // 2. Auto-Create Playlist with Folder Name if Enabled
                    if (createPlaylistWithFolder && playlistTitleCtrl.text.trim().isNotEmpty && uploadedSongsList.isNotEmpty) {
                      try {
                        final pl = Playlist(
                          id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
                          title: playlistTitleCtrl.text.trim(),
                          description: 'Folder bulk upload (${uploadedSongsList.length} tracks)',
                          coverUrl: uploadedSongsList.first.coverUrl,
                          songs: uploadedSongsList,
                        );
                        final storage = StorageService();
                        final existingPlaylists = await storage.loadCustomPlaylists();
                        final updated = [pl, ...existingPlaylists];
                        await storage.saveCustomPlaylists(updated);
                      } catch (pe) {
                        debugPrint('Playlist create error: $pe');
                      }
                    }
                  } finally {
                    // 3. Release WakeLock & Show Native Background Status Notification
                    await BackgroundUploadService.releaseWakeLock();
                    await BackgroundUploadService.showUploadNotification(
                      title: '🎉 बल्क अपलोड पूरा हुआ!',
                      message: '$successCount गाने Cloudflare R2 पर लाइव हो गए!' + (skippedCount > 0 ? ' ($skippedCount डुप्लीकेट स्किप)' : ''),
                    );
                    _refreshStorageStats();
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                    final summaryMsg = skippedCount > 0
                        ? '🎉 $successCount गाने लाइव हुए • ⚠️ $skippedCount डुप्लीकेट गाने स्किप कर दिए गए!'
                        : '🎉 $successCount / ${pickedFiles.length} गाने Cloudflare R2 पर सफलतापूर्वक लाइव हो गए!';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(summaryMsg),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddSongDialog({String? prefillGenre, String? prefillSubCategory}) {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    final albumCtrl = TextEditingController(text: 'Musixa Originals');
    final subCategoryCtrl = TextEditingController(text: prefillSubCategory ?? '');
    final audioCtrl = TextEditingController();
    final coverCtrl = TextEditingController();
    String selectedGenre = prefillGenre ?? 'Rajasthani';
    final genres = List<String>.from(_allGenres);
    if (!genres.contains(selectedGenre)) genres.insert(0, selectedGenre);
    bool isUploadingToR2 = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFFFB300)),
              const SizedBox(width: 8),
              Text(
                _lang.t('add_song_admin'),
                style: GoogleFonts.syne(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAdminTextField(titleCtrl, _lang.t('song_title'), 'उदा. Shree Ram Dhun'),
                const SizedBox(height: 10),
                _buildAdminTextField(artistCtrl, _lang.t('artist_name'), 'उदा. Hariharan'),
                const SizedBox(height: 10),
                _buildAdminTextField(albumCtrl, _lang.t('album_name'), 'Musixa Originals'),
                const SizedBox(height: 10),

                // Cloudflare R2 Upload Button
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: isUploadingToR2
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)))
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(
                      isUploadingToR2 ? 'R2 क्लाउड पर अपलोड हो रहा है...' : '📁 डिवाइस से MP3 चुनें और R2 पर अपलोड करें',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isUploadingToR2
                        ? null
                        : () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['mp3', 'm4a', 'wav'],
                              );
                              if (result != null && result.files.single.path != null) {
                                setDialogState(() => isUploadingToR2 = true);
                                final pickedFile = File(result.files.single.path!);
                                final r2 = R2StorageService();
                                final cloudUrl = await r2.uploadAudioFile(pickedFile);
                                setDialogState(() {
                                  isUploadingToR2 = false;
                                  if (cloudUrl != null) {
                                    audioCtrl.text = cloudUrl;
                                    if (titleCtrl.text.isEmpty) {
                                      titleCtrl.text = CloudBackendService.formatSmartTitle(result.files.single.name);
                                    }
                                  }
                                });
                              }
                            } catch (e) {
                              setDialogState(() => isUploadingToR2 = false);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 6),

                _buildAdminTextField(audioCtrl, 'ऑडियो लिंक या पाथ (Audio Stream URL)', 'https://pub-d4f2... or assets/audio/...'),
                const SizedBox(height: 10),
                _buildAdminTextField(coverCtrl, _lang.t('cover_url'), 'https://.../cover.jpg'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGenre,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: _lang.t('genre_label'),
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
                  ),
                  items: genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedGenre = val);
                  },
                ),
                const SizedBox(height: 10),
                _buildAdminTextField(subCategoryCtrl, 'उप-श्रेणी (Sub-Category - Optional)', 'उदा. Marwadi Hits, Folk, 90s'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
              onPressed: () async {
                final title = CloudBackendService.formatSmartTitle(titleCtrl.text.trim());
                final artist = artistCtrl.text.trim();
                if (title.isEmpty || artist.isEmpty) return;

                final duplicate = _backend.checkDuplicateSong(title: title, artist: artist);
                if (duplicate != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _lang.isHindi
                            ? '⚠️ गाना "$title" पहले से मौजूद है! डुप्लीकेट गाना लाइव नहीं किया जा सकता।'
                            : '⚠️ Song "$title" already exists in library! Duplicates not allowed.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                try {
                  await _backend.addAdminSong(
                    title: title,
                    artist: artist,
                    album: albumCtrl.text,
                    genre: selectedGenre,
                    subCategory: subCategoryCtrl.text.trim().isNotEmpty ? subCategoryCtrl.text.trim() : null,
                    audioPath: audioCtrl.text.trim().isNotEmpty ? audioCtrl.text.trim() : 'assets/audio/sankat_mochan_hanuman_ashtak.mp3',
                    coverUrl: coverCtrl.text.trim().isNotEmpty ? coverCtrl.text.trim() : null,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('🎉 "$title" ${_lang.isHindi ? "सफलतापूर्वक लाइव कर दिया गया!" : "successfully published live!"}')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: Text(_lang.isHindi ? 'गाना लाइव करें' : 'Publish Live', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSongDialog(Song song) {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    final albumCtrl = TextEditingController(text: song.album);
    final subCategoryCtrl = TextEditingController(text: song.subCategory ?? '');
    final audioCtrl = TextEditingController(text: song.streamUrl);
    final coverCtrl = TextEditingController(text: song.coverUrl);
    String selectedGenre = song.genre;
    final genres = List<String>.from(_allGenres);
    if (!genres.contains(selectedGenre)) genres.add(selectedGenre);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_lang.t('edit_btn')}: ${song.title}',
                  style: GoogleFonts.syne(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAdminTextField(titleCtrl, _lang.t('song_title'), ''),
                const SizedBox(height: 10),
                _buildAdminTextField(artistCtrl, _lang.t('artist_name'), ''),
                const SizedBox(height: 10),
                _buildAdminTextField(albumCtrl, _lang.t('album_name'), ''),
                const SizedBox(height: 10),
                _buildAdminTextField(audioCtrl, 'ऑडियो लिंक या पाथ (Audio Stream URL)', ''),
                const SizedBox(height: 10),
                _buildAdminTextField(coverCtrl, _lang.t('cover_url'), ''),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGenre,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: _lang.t('genre_label'),
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00E5FF))),
                  ),
                  items: genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedGenre = val);
                  },
                ),
                const SizedBox(height: 10),
                _buildAdminTextField(subCategoryCtrl, 'उप-श्रेणी (Sub-Category)', 'उदा. Marwadi Hits'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
              onPressed: () async {
                await _backend.editSong(
                  songId: song.id,
                  title: titleCtrl.text,
                  artist: artistCtrl.text,
                  album: albumCtrl.text,
                  genre: selectedGenre,
                  subCategory: subCategoryCtrl.text.trim().isNotEmpty ? subCategoryCtrl.text.trim() : null,
                  streamUrl: audioCtrl.text,
                  coverUrl: coverCtrl.text,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ "${titleCtrl.text}" ${_lang.t('save_changes')}')),
                  );
                }
              },
              child: Text(_lang.t('save_changes'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTextField(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildR2CloudStatusCard() {
    final r2 = R2StorageService();
    final isConnected = r2.isConfigured;

    final stats = _storageStats;
    final usedMb = (stats?['usedMb'] as num?)?.toDouble() ?? (17 * 6.2 + 52);
    final usedGb = (stats?['usedGb'] as num?)?.toDouble() ?? (usedMb / 1024);
    final remainingGb = (stats?['remainingGb'] as num?)?.toDouble() ?? (10.0 - usedGb);
    final usedPercentage = (stats?['usedPercentage'] as num?)?.toDouble() ?? ((usedGb / 10.0) * 100);
    final estimatedSongsRemaining = (stats?['estimatedSongsRemaining'] as num?)?.toInt() ?? 1600;

    final progressColor = usedPercentage >= 90
        ? Colors.redAccent
        : (usedPercentage >= 70 ? Colors.amberAccent : const Color(0xFF10B981));

    return InkWell(
      onTap: _showStorageDetailsDialog,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isConnected ? progressColor.withOpacity(0.4) : const Color(0xFFFFB300).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? progressColor.withOpacity(0.15) : const Color(0xFFFFB300).withOpacity(0.15),
                  ),
                  child: Icon(
                    isConnected ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                    color: isConnected ? progressColor : const Color(0xFFFFB300),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cloudflare R2 Storage (10 GB Free)',
                            style: GoogleFonts.syne(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isConnected ? progressColor.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isConnected ? '${usedPercentage.toStringAsFixed(1)}% Used' : '⚠️ Setup',
                              style: TextStyle(
                                color: isConnected ? progressColor : Colors.amberAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bucket: ${r2.bucketName ?? "musixa-music"} • CDN Live Edge',
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: _isLoadingStorageStats
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)))
                      : const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF00E5FF)),
                  tooltip: _lang.isHindi ? 'स्टोरेज रिफ्रेश करें' : 'Refresh Storage',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _refreshStorageStats,
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _showR2SettingsDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.settings_rounded, size: 13, color: Color(0xFF00E5FF)),
                        SizedBox(width: 4),
                        Text(
                          'Settings',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live Storage Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (usedPercentage / 100).clamp(0.01, 1.0),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),

            // Used & Remaining Metrics (respects English/Hindi language mode)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    children: [
                      TextSpan(
                        text: _lang.isHindi ? 'उपयोग (Used): ' : 'Used: ',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      TextSpan(
                        text: usedMb < 1024 ? '${usedMb.toStringAsFixed(1)} MB' : '${usedGb.toStringAsFixed(2)} GB',
                        style: TextStyle(color: progressColor, fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' / 10 GB'),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    children: [
                      TextSpan(
                        text: _lang.isHindi ? 'बची हुई (Free): ' : 'Free: ',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      TextSpan(
                        text: '${remainingGb.toStringAsFixed(2)} GB',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' (~$estimatedSongsRemaining ${_lang.isHindi ? "गाने" : "Songs"})',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStorageDetailsDialog() {
    final stats = _storageStats;
    final usedMb = (stats?['usedMb'] as num?)?.toDouble() ?? 157.0;
    final usedGb = (stats?['usedGb'] as num?)?.toDouble() ?? (usedMb / 1024);
    final remainingGb = (stats?['remainingGb'] as num?)?.toDouble() ?? (10.0 - usedGb);
    final usedPercentage = (stats?['usedPercentage'] as num?)?.toDouble() ?? ((usedGb / 10.0) * 100);
    final totalObjects = (stats?['totalObjects'] as num?)?.toInt() ?? _backend.approvedSongs.length;
    final estimatedSongsRemaining = (stats?['estimatedSongsRemaining'] as num?)?.toInt() ?? 1600;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.pie_chart_rounded, color: Color(0xFF00E5FF), size: 22),
            const SizedBox(width: 8),
            Text(
              _lang.isHindi ? 'Cloudflare R2 स्टोरेज विवरण' : 'Cloudflare R2 Storage Details',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStorageDetailRow(
              _lang.isHindi ? 'कुल मुफ़्त कोटा (Free Plan):' : 'Total Free Quota (Free Plan):',
              '10.00 GB (10,240 MB)',
              Colors.white,
            ),
            const Divider(color: Colors.white10),
            _buildStorageDetailRow(
              _lang.isHindi ? 'उपयोग की गई स्टोरेज (Used):' : 'Used Storage:',
              '${usedMb < 1024 ? "${usedMb.toStringAsFixed(1)} MB" : "${usedGb.toStringAsFixed(2)} GB"} (${usedPercentage.toStringAsFixed(1)}%)',
              const Color(0xFFFFB300),
            ),
            const Divider(color: Colors.white10),
            _buildStorageDetailRow(
              _lang.isHindi ? 'बची हुई मुफ़्त स्टोरेज (Remaining):' : 'Remaining Free Storage:',
              '${remainingGb.toStringAsFixed(2)} GB (${(100 - usedPercentage).toStringAsFixed(1)}% Free)',
              const Color(0xFF10B981),
            ),
            const Divider(color: Colors.white10),
            _buildStorageDetailRow(
              _lang.isHindi ? 'कुल क्लाउड फ़ाइलें (Files):' : 'Total Cloud Files:',
              '$totalObjects Objects',
              Colors.cyanAccent,
            ),
            const Divider(color: Colors.white10),
            _buildStorageDetailRow(
              _lang.isHindi ? 'अनुमानित शेष गाने (Can Upload):' : 'Estimated Songs Remaining:',
              '~$estimatedSongsRemaining MP3 Songs',
              const Color(0xFF00E5FF),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _refreshStorageStats();
            },
            child: Text(
              _lang.isHindi ? 'रिफ्रेश (Refresh)' : 'Refresh',
              style: const TextStyle(color: Color(0xFF00E5FF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              _showR2SettingsDialog();
            },
            child: Text(
              _lang.isHindi ? 'R2 सेटिंग्स' : 'R2 Settings',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showR2SettingsDialog() {
    final r2 = R2StorageService();
    final accountIdCtrl = TextEditingController(text: r2.accountId ?? R2StorageService.defaultAccountId);
    final bucketNameCtrl = TextEditingController(text: r2.bucketName ?? R2StorageService.defaultBucketName);
    final accessKeyCtrl = TextEditingController(text: r2.accessKeyId ?? R2StorageService.defaultAccessKeyId);
    final secretKeyCtrl = TextEditingController(text: r2.secretAccessKey ?? R2StorageService.defaultSecretAccessKey);
    final publicDomainCtrl = TextEditingController(text: r2.publicDomain ?? R2StorageService.defaultPublicDomain);

    bool isTesting = false;
    String? testResultMsg;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.cloud_circle_rounded, color: Color(0xFF00E5FF), size: 26),
              SizedBox(width: 8),
              Text(
                'Cloudflare R2 Server Settings',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '10 GB Free Storage • 0 Bandwidth Fees • Fast Global Edge Streaming',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 14),
                _buildAdminTextField(accountIdCtrl, 'Account ID', '25622df2e...'),
                const SizedBox(height: 10),
                _buildAdminTextField(bucketNameCtrl, 'Bucket Name', 'musixa-music'),
                const SizedBox(height: 10),
                _buildAdminTextField(accessKeyCtrl, 'Access Key ID', '3857da306...'),
                const SizedBox(height: 10),
                _buildAdminTextField(secretKeyCtrl, 'Secret Access Key', '77ef640b7...'),
                const SizedBox(height: 10),
                _buildAdminTextField(publicDomainCtrl, 'Public CDN Domain / r2.dev', 'pub-xxxx.r2.dev'),
                const SizedBox(height: 14),

                if (isTesting)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: const [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))),
                        SizedBox(width: 10),
                        Text('Testing connection to Cloudflare R2...', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                      ],
                    ),
                  ),

                if (testResultMsg != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: testSuccess == true ? const Color(0xFF10B981).withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: testSuccess == true ? Colors.greenAccent : Colors.redAccent),
                    ),
                    child: Text(
                      testResultMsg!,
                      style: TextStyle(
                        color: testSuccess == true ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
              ),
              onPressed: isTesting
                  ? null
                  : () async {
                      setDialogState(() {
                        isTesting = true;
                        testResultMsg = null;
                      });
                      await r2.saveConfig(
                        accountId: accountIdCtrl.text,
                        bucketName: bucketNameCtrl.text,
                        accessKeyId: accessKeyCtrl.text,
                        secretAccessKey: secretKeyCtrl.text,
                        publicDomain: publicDomainCtrl.text,
                      );
                      final res = await r2.testConnection();
                      setDialogState(() {
                        isTesting = false;
                        testSuccess = res['success'] == true;
                        testResultMsg = res['message']?.toString();
                      });
                      if (mounted) setState(() {});
                    },
              child: const Text('⚡ Test Connection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
              onPressed: () async {
                await r2.saveConfig(
                  accountId: accountIdCtrl.text,
                  bucketName: bucketNameCtrl.text,
                  accessKeyId: accessKeyCtrl.text,
                  secretAccessKey: secretKeyCtrl.text,
                  publicDomain: publicDomainCtrl.text,
                );
                if (mounted) {
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Cloudflare R2 Credentials Saved & Synced!')),
                  );
                }
              },
              child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _backend.pendingSongs;
    final approved = _backend.approvedSongs;
    final users = _backend.allUsers;

    final filteredUsers = users.where((u) {
      final q = _userSearchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          u.phoneNumber.contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101726),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF6F00)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _lang.t('admin_title'),
                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Language Switcher Toggle Button
          InkWell(
            onTap: () => _lang.toggleLanguage(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFFFFB300), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _lang.displayLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'एडमिन अपडेट चेक करें (Check Update)',
            icon: const Icon(Icons.system_update_rounded, color: Color(0xFF00E5FF), size: 21),
            onPressed: () => UpdateService.checkForUpdate(context, autoPrompt: false, isAdmin: true),
          ),
          IconButton(
            tooltip: _lang.t('refresh_data'),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFFB300), size: 22),
            onPressed: () async {
              await _backend.syncSharedData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_lang.t('data_refreshed')} (${_backend.allUsers.length} Users)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    backgroundColor: const Color(0xFFFFB300),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: _lang.t('sign_out'),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            onPressed: widget.onSignOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFB300),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFB300),
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: '${_lang.t('tab_pending')} (${pending.length})'),
            Tab(text: '${_lang.t('tab_users')} (${users.length})'),
            Tab(text: '${_lang.t('tab_live')} (${approved.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Live Analytics Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF121B2D),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCard(
                  title: _lang.t('metric_total_users'),
                  value: '${_backend.totalUsersCount}',
                  icon: Icons.people_alt_rounded,
                  color: Colors.cyanAccent,
                ),
                _buildMetricCard(
                  title: _lang.t('metric_active_users'),
                  value: '${_backend.activeUsersCount}',
                  icon: Icons.wifi_tethering_rounded,
                  color: Colors.greenAccent,
                ),
                _buildMetricCard(
                  title: _lang.t('metric_pending'),
                  value: '${pending.length}',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.amberAccent,
                ),
                _buildMetricCard(
                  title: _lang.t('metric_live'),
                  value: '${approved.length}',
                  icon: Icons.library_music_rounded,
                  color: Colors.indigoAccent,
                ),
              ],
            ),
          ),

          // Cloudflare R2 Cloud Server Status & Control Pill
          _buildR2CloudStatusCard(),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Pending Songs Moderation
                _buildPendingSongsTab(pending),

                // TAB 2: Users Directory
                _buildUsersDirectoryTab(filteredUsers),

                // TAB 3: Live Songs Catalog (with Add, Edit, Delete)
                _buildLiveSongsTab(approved),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
      ],
    );
  }

  // TAB 1: Song Moderation
  Widget _buildPendingSongsTab(List<Song> pending) {
    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent.withOpacity(0.5), size: 54),
            const SizedBox(height: 12),
            Text(_lang.t('no_pending_songs'), style: GoogleFonts.syne(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_lang.t('all_songs_approved'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final song = pending[index];
        final isThisPlaying = _currentlyPlayingSongId == song.id && _isPlaying;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isThisPlaying ? const Color(0xFFFFB300) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      song.coverUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.music_note, color: Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${song.artist} • ${song.genre}',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 12, color: Colors.cyanAccent),
                            const SizedBox(width: 4),
                            Text(
                              '${song.uploaderName ?? "User"} (${song.uploaderPhone ?? ""})',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF), size: 22),
                    tooltip: _lang.t('edit_btn'),
                    onPressed: () => _showEditSongDialog(song),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 10),

              // Action Buttons
              Row(
                children: [
                  // Play / Pause Preview Button
                  ElevatedButton.icon(
                    onPressed: () => _playSongPreview(song),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isThisPlaying ? const Color(0xFFFFB300) : const Color(0xFF1E293B),
                      foregroundColor: isThisPlaying ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      isThisPlaying ? _lang.t('preview_stop') : _lang.t('preview_play'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),

                  // Reject Button
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF131A2A),
                          title: Text(_lang.t('confirm_delete_title'), style: const TextStyle(color: Colors.white)),
                          content: Text('${_lang.t('confirm_delete_msg')} ("${song.title}")', style: const TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_lang.t('cancel'))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(_lang.t('confirm_yes')),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _backend.rejectOrDeleteSong(song.id);
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${song.title}" removed.')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                    label: Text(_lang.t('reject_btn'), style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),

                  // Approve Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _backend.approveSong(song.id);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🎉 "${song.title}" live!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(_lang.t('approve_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 2: Users Directory
  Widget _buildUsersDirectoryTab(List<UserProfile> users) {
    return Column(
      children: [
        // Users Export & Stats Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              Text(
                '${_lang.t('tab_users')} (${users.length})',
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.file_download_rounded, size: 16),
                label: const Text('Excel Export', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating Users Excel Sheet...')),
                    );
                    await _backend.exportUsersToExcel();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
                  }
                },
              ),
            ],
          ),
        ),

        // Search Box
        Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131B2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _userSearchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: _lang.t('search_users'),
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFFB300), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Users List
        Expanded(
          child: users.isEmpty
              ? Center(child: Text(_lang.t('no_users_found'), style: const TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final u = users[index];
                    final isOnline = DateTime.now().difference(u.lastActiveAt).inMinutes < 60;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2C),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: u.role == 'admin' ? const Color(0xFFFFB300) : const Color(0xFF4F46E5),
                                child: Text(
                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.greenAccent : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // User Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        u.fullName,
                                        style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (u.role == 'admin')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB300).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('ADMIN', style: TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 11, color: Colors.greenAccent),
                                    const SizedBox(width: 3),
                                    Text(
                                      u.phoneNumber.isNotEmpty ? u.phoneNumber : 'No phone',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, size: 12, color: Colors.cyanAccent),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.mail_outline_rounded, size: 11, color: Colors.cyanAccent),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        u.email,
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Quick Action Buttons
                          if (u.phoneNumber.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.phone_outlined, color: Colors.greenAccent, size: 18),
                              onPressed: () => _launchCall(u.phoneNumber),
                              tooltip: _lang.t('call_tooltip'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.tealAccent, size: 18),
                              onPressed: () => _launchWhatsApp(u.phoneNumber),
                              tooltip: _lang.t('whatsapp_tooltip'),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.mail_outline_rounded, color: Colors.cyanAccent, size: 18),
                            onPressed: () => _launchMail(u.email),
                            tooltip: _lang.t('email_tooltip'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedSongIds.clear();
      }
    });
  }

  void _toggleSongSelection(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _selectAllSongs(List<Song> songs) {
    setState(() {
      _selectedSongIds.addAll(songs.map((s) => s.id));
    });
  }

  void _deselectAllSongs() {
    setState(() {
      _selectedSongIds.clear();
    });
  }

  void _toggleFolderSelection(List<Song> folderSongs) {
    setState(() {
      final ids = folderSongs.map((s) => s.id).toSet();
      final allSelected = ids.isNotEmpty && ids.every(_selectedSongIds.contains);
      if (allSelected) {
        _selectedSongIds.removeAll(ids);
      } else {
        _selectedSongIds.addAll(ids);
        _isMultiSelectMode = true;
      }
    });
  }

  Future<void> _confirmDeleteSelectedSongs() async {
    if (_selectedSongIds.isEmpty) return;
    final count = _selectedSongIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _lang.isHindi ? 'चुने हुए $count गाने हटाएं?' : 'Delete $count Selected Songs?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          _lang.isHindi
              ? 'क्या आप सचमुच चुने गए $count गानों को हमेशा के लिए हटाना चाहते हैं?'
              : 'Are you sure you want to permanently delete $count selected songs?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_lang.isHindi ? 'हाँ, हटाएं' : 'Yes, Delete', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final countDeleted = _selectedSongIds.length;
      await _backend.deleteSongsBatch(_selectedSongIds);
      setState(() {
        _selectedSongIds.clear();
        _isMultiSelectMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lang.isHindi ? '✅ $countDeleted गाने हटा दिए गए!' : '✅ $countDeleted songs deleted!'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteCategory(String category, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.folder_delete_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _lang.isHindi ? 'पूरी श्रेणी हटाएं: $category' : 'Delete Category: $category',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          _lang.isHindi
              ? 'क्या आप श्रेणी "$category" के सभी $count गाने हटाना चाहते हैं? यह सभी गाने स्थायी रूप से हटा देगा।'
              : 'Are you sure you want to permanently delete all $count songs in "$category"?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_lang.isHindi ? 'हाँ, श्रेणी हटाएं' : 'Yes, Delete Category', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await _backend.deleteCategorySongs(category);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lang.isHindi ? '✅ श्रेणी "$category" ($deleted गाने) हटा दी गई!' : '✅ Category "$category" ($deleted songs) deleted!'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteSubCategory(String category, String subCategory, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.folder_delete_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _lang.isHindi ? 'सब-फ़ोल्डर हटाएं: $subCategory' : 'Delete Sub-Folder: $subCategory',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          _lang.isHindi
              ? 'क्या आप "$category › $subCategory" के सभी $count गाने हटाना चाहते हैं?'
              : 'Are you sure you want to permanently delete all $count songs in "$category › $subCategory"?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_lang.isHindi ? 'हाँ, हटाएं' : 'Yes, Delete Sub-Folder', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await _backend.deleteCategorySongs(category, subCategory: subCategory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lang.isHindi ? '✅ सब-फ़ोल्डर "$subCategory" ($deleted गाने) हटा दिया गया!' : '✅ Sub-Folder "$subCategory" ($deleted songs) deleted!'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // TAB 3: All Live Songs (with Add, Edit, and Delete)
  Widget _buildLiveSongsTab(List<Song> songs) {
    return Column(
      children: [
        // Add Song & Export Header Button Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF0F1728),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '${_lang.t('tab_live')} (${songs.length})',
                  style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(width: 12),

                // Toggle View: Category/Subcategory Accordion vs Flat List
                InkWell(
                  onTap: () => setState(() => _adminGroupByCategory = !_adminGroupByCategory),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _adminGroupByCategory ? const Color(0xFFFFB300).withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _adminGroupByCategory ? const Color(0xFFFFB300) : Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _adminGroupByCategory ? Icons.folder_copy_rounded : Icons.list_rounded,
                          size: 14,
                          color: _adminGroupByCategory ? const Color(0xFFFFB300) : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _adminGroupByCategory ? '📁 कैटेगरी व्यू' : '🎵 फ्लैट लिस्ट',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _adminGroupByCategory ? const Color(0xFFFFB300) : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Multi-Select Toggle Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMultiSelectMode ? const Color(0xFF6366F1) : Colors.white10,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    side: BorderSide(color: _isMultiSelectMode ? const Color(0xFF818CF8) : Colors.white24),
                  ),
                  icon: Icon(_isMultiSelectMode ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 16),
                  label: Text(
                    _isMultiSelectMode
                        ? (_lang.isHindi ? 'सेलेक्ट बंद (${_selectedSongIds.length})' : 'Exit Select (${_selectedSongIds.length})')
                        : (_lang.isHindi ? 'मल्टी-सेलेक्ट' : 'Multi-Select'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _toggleMultiSelectMode,
                ),
                const SizedBox(width: 8),

                // Bulk Folder / Multi-File Upload Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.drive_folder_upload_rounded, size: 16),
                  label: const Text('बल्क / फ़ोल्डर अपलोड', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showBulkUploadDialog(),
                ),
                const SizedBox(width: 8),

                // Single Add Song Dialog
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(_lang.t('add_song_admin'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddSongDialog(),
                ),
                const SizedBox(width: 8),

                // Export Songs to Excel
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.file_download_rounded, size: 16),
                  label: const Text('Excel Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Generating Uploaded Songs Excel Sheet...')),
                      );
                      await _backend.exportUploadedSongsToExcel();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Clear All Live Songs (Permanent Purge)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text(_lang.isHindi ? 'सभी हटाएं' : 'Clear All', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: songs.isEmpty
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF131A2A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    _lang.isHindi ? 'सभी गाने हटाएं?' : 'Delete All Songs?',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              content: Text(
                                _lang.isHindi
                                    ? 'क्या आप सचमुच सभी गानों को हटाना चाहते हैं? इसके बाद ऐप में कोई भी गाना (डिफ़ॉल्ट 17 गानों सहित) ऐप दोबारा खोलने पर भी वापस नहीं आएगा।'
                                    : 'Are you sure you want to delete all songs? All tracks including default 17 tracks will be permanently removed and will not return on restart.',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(_lang.isHindi ? 'हाँ, सब हटाएं' : 'Yes, Delete All', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await _backend.deleteAllApprovedSongs();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_lang.isHindi ? '✅ सभी गाने सफलतापूर्वक हटा दिए गए!' : '✅ All songs purged successfully!'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),

        // Multi-Select Action Banner
        if (_isMultiSelectMode)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF6366F1).withOpacity(0.25), const Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_box_outlined, color: Color(0xFF818CF8), size: 18),
                const SizedBox(width: 8),
                Text(
                  _lang.isHindi
                      ? '${_selectedSongIds.length} / ${songs.length} चुने गए'
                      : '${_selectedSongIds.length} / ${songs.length} selected',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Select All / Deselect All
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    if (_selectedSongIds.length == songs.length) {
                      _deselectAllSongs();
                    } else {
                      _selectAllSongs(songs);
                    }
                  },
                  child: Text(
                    _selectedSongIds.length == songs.length
                        ? (_lang.isHindi ? 'सभी हटाएं' : 'Deselect All')
                        : (_lang.isHindi ? 'सभी चुनें' : 'Select All'),
                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete Selected Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSongIds.isNotEmpty ? const Color(0xFFDC2626) : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 14),
                  label: Text(
                    _lang.isHindi ? 'हटाएं (${_selectedSongIds.length})' : 'Delete (${_selectedSongIds.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _selectedSongIds.isEmpty ? null : _confirmDeleteSelectedSongs,
                ),
                const SizedBox(width: 8),
                // Close button
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                  tooltip: _lang.t('cancel'),
                  onPressed: _toggleMultiSelectMode,
                ),
              ],
            ),
          ),

        Expanded(
          child: songs.isEmpty
              ? Center(child: Text(_lang.t('no_pending_songs'), style: const TextStyle(color: Colors.grey)))
              : _adminGroupByCategory
                  ? _buildAdminCategorizedSongs(songs)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount: songs.length,
                      itemBuilder: (context, index) => _buildAdminSongCard(songs[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildAdminCategorizedSongs(List<Song> songs) {
    final Map<String, List<Song>> categoryMap = {};
    for (final s in songs) {
      final cat = s.genre.trim().isNotEmpty ? s.genre.trim() : 'Uncategorized';
      categoryMap.putIfAbsent(cat, () => []).add(s);
    }
    final categories = categoryMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 40),
      itemCount: categories.length,
      itemBuilder: (context, idx) {
        final category = categories[idx];
        final catSongs = categoryMap[category] ?? [];

        final Map<String, List<Song>> subMap = {};
        final List<Song> directSongs = [];
        for (final s in catSongs) {
          final sub = s.subCategory?.trim();
          if (sub != null && sub.isNotEmpty && sub.toLowerCase() != category.toLowerCase()) {
            subMap.putIfAbsent(sub, () => []).add(s);
          } else {
            directSongs.add(s);
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1728),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: idx == 0,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_rounded, color: Color(0xFFFFB300), size: 18),
              ),
              title: Text(
                category,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${catSongs.length} Tracks',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isMultiSelectMode)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      icon: Icon(
                        catSongs.isNotEmpty && catSongs.every((s) => _selectedSongIds.contains(s.id))
                            ? Icons.check_box_rounded
                            : catSongs.any((s) => _selectedSongIds.contains(s.id))
                                ? Icons.indeterminate_check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                        color: const Color(0xFF818CF8),
                        size: 20,
                      ),
                      tooltip: 'पूरी श्रेणी चुनें/हटाएं',
                      onPressed: () => _toggleFolderSelection(catSongs),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'श्रेणी / फ़ोल्डर विकल्प',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.more_vert_rounded, color: Color(0xFFFFB300), size: 14),
                          SizedBox(width: 2),
                          Text(
                            'विकल्प',
                            style: TextStyle(color: Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    color: const Color(0xFF1E293B),
                    onSelected: (val) {
                      if (val == 'single') {
                        _showAddSongDialog(prefillGenre: category);
                      } else if (val == 'bulk') {
                        _showBulkUploadDialog(prefillGenre: category);
                      } else if (val == 'select_folder') {
                        _toggleFolderSelection(catSongs);
                      } else if (val == 'delete_category') {
                        _confirmDeleteCategory(category, catSongs.length);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'single',
                        child: Row(
                          children: const [
                            Icon(Icons.music_note_rounded, color: Color(0xFFFFB300), size: 16),
                            SizedBox(width: 8),
                            Text('+ एकल गाना जोड़ें', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'bulk',
                        child: Row(
                          children: const [
                            Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF00E5FF), size: 16),
                            SizedBox(width: 8),
                            Text('📁 बल्क / फ़ोल्डर अपलोड', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      PopupMenuItem(
                        value: 'select_folder',
                        child: Row(
                          children: [
                            Icon(
                              catSongs.isNotEmpty && catSongs.every((s) => _selectedSongIds.contains(s.id))
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              color: const Color(0xFF818CF8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              catSongs.isNotEmpty && catSongs.every((s) => _selectedSongIds.contains(s.id))
                                  ? 'श्रेणी अन-सेलेक्ट करें'
                                  : 'पूरी श्रेणी चुनें (Multi-Select)',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete_category',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 16),
                            SizedBox(width: 8),
                            Text('🗑️ पूरी श्रेणी/फ़ोल्डर हटाएं', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded, color: Colors.white54),
                ],
              ),
              children: [
                const Divider(color: Colors.white10, height: 1),
                if (subMap.isNotEmpty) ...[
                  ...subMap.entries.map((entry) {
                    final subCat = entry.key;
                    final subSongs = entry.value;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2C),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.folder_copy_rounded, color: Color(0xFF00E5FF), size: 15),
                          ),
                          title: Text(
                            subCat,
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${subSongs.length} Tracks',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isMultiSelectMode)
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  icon: Icon(
                                    subSongs.isNotEmpty && subSongs.every((s) => _selectedSongIds.contains(s.id))
                                        ? Icons.check_box_rounded
                                        : subSongs.any((s) => _selectedSongIds.contains(s.id))
                                            ? Icons.indeterminate_check_box_rounded
                                            : Icons.check_box_outline_blank_rounded,
                                    color: const Color(0xFF818CF8),
                                    size: 18,
                                  ),
                                  tooltip: 'सब-फ़ोल्डर चुनें/हटाएं',
                                  onPressed: () => _toggleFolderSelection(subSongs),
                                ),
                              PopupMenuButton<String>(
                                tooltip: 'इस सब-कैटेगरी में विकल्प',
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.more_vert_rounded, color: Color(0xFF00E5FF), size: 12),
                                      SizedBox(width: 2),
                                      Text(
                                        'विकल्प',
                                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                color: const Color(0xFF1E293B),
                                onSelected: (val) {
                                  if (val == 'single') {
                                    _showAddSongDialog(prefillGenre: category, prefillSubCategory: subCat);
                                  } else if (val == 'bulk') {
                                    _showBulkUploadDialog(prefillGenre: category, prefillSubCategory: subCat);
                                  } else if (val == 'select_subfolder') {
                                    _toggleFolderSelection(subSongs);
                                  } else if (val == 'delete_subcategory') {
                                    _confirmDeleteSubCategory(category, subCat, subSongs.length);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'single',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.music_note_rounded, color: Color(0xFFFFB300), size: 14),
                                        SizedBox(width: 6),
                                        Text('+ एकल गाना जोड़ें', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'bulk',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF00E5FF), size: 14),
                                        SizedBox(width: 6),
                                        Text('📁 बल्क अपलोड', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(height: 6),
                                  PopupMenuItem(
                                    value: 'select_subfolder',
                                    child: Row(
                                      children: [
                                        Icon(
                                          subSongs.isNotEmpty && subSongs.every((s) => _selectedSongIds.contains(s.id))
                                              ? Icons.check_box_rounded
                                              : Icons.check_box_outline_blank_rounded,
                                          color: const Color(0xFF818CF8),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          subSongs.isNotEmpty && subSongs.every((s) => _selectedSongIds.contains(s.id))
                                              ? 'अन-सेलेक्ट करें'
                                              : 'सब-फ़ोल्डर चुनें',
                                          style: const TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete_subcategory',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 14),
                                        SizedBox(width: 6),
                                        Text('🗑️ यह सब-फ़ोल्डर हटाएं', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.expand_more_rounded, color: Colors.white54, size: 18),
                            ],
                          ),
                          children: subSongs.map((s) => _buildAdminSongCard(s)).toList(),
                        ),
                      ),
                    );
                  }),
                ],
                if (directSongs.isNotEmpty) ...[
                  if (subMap.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                      child: Text(
                        '🎵 $category मुख्य ट्रैक्स (${directSongs.length}):',
                        style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ...directSongs.map((s) => _buildAdminSongCard(s)),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminSongCard(Song s) {
    final isThisPlaying = _currentlyPlayingSongId == s.id && _isPlaying;
    final isSelected = _selectedSongIds.contains(s.id);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isMultiSelectMode ? () => _toggleSongSelection(s.id) : null,
      onLongPress: () {
        if (!_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = true;
            _selectedSongIds.add(s.id);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.18) : const Color(0xFF131B2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF818CF8)
                : isThisPlaying
                    ? const Color(0xFFFFB300)
                    : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            if (_isMultiSelectMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF6366F1),
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _toggleSongSelection(s.id),
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                s.coverUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.grey.shade800),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.artist,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                      ),
                      child: Text(
                        s.subCategory != null && s.subCategory!.isNotEmpty && s.subCategory!.toLowerCase() != s.genre.toLowerCase()
                            ? '${s.genre} › ${s.subCategory}'
                            : s.genre,
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Preview Button
          IconButton(
            icon: Icon(
              isThisPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: isThisPlaying ? const Color(0xFFFFB300) : Colors.white70,
              size: 26,
            ),
            tooltip: _lang.t('preview_play'),
            onPressed: () => _playSongPreview(s),
          ),
          // Edit Button
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF), size: 22),
            tooltip: _lang.t('edit_btn'),
            onPressed: () => _showEditSongDialog(s),
          ),
          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            tooltip: _lang.t('delete_btn'),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF131A2A),
                  title: Text(_lang.t('confirm_delete_title'), style: const TextStyle(color: Colors.white)),
                  content: Text('${_lang.t('confirm_delete_msg')} ("${s.title}")', style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_lang.t('cancel'))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(_lang.t('confirm_yes')),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _backend.rejectOrDeleteSong(s.id);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${s.title}" removed.')),
                  );
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}
}
