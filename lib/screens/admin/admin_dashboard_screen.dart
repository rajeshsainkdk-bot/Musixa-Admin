import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../models/song.dart';
import '../../models/user_profile.dart';
import '../../models/playlist.dart';
import '../../models/folder_hierarchy.dart';
import '../../widgets/song_thumbnail_widget.dart';
import '../../services/song_artwork_resolver.dart';
export '../../models/folder_hierarchy.dart';

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
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  String _userSearchQuery = '';
  Timer? _syncTimer;
  Map<String, dynamic>? _storageStats;
  bool _isLoadingStorageStats = false;
  bool _adminGroupByCategory = true;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedSongIds = {};

  DateTime _lastAdminPosTime = DateTime.fromMillisecondsSinceEpoch(0);

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
    R2StorageService().addListener(_onR2Update);

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
          if (state.processingState == ProcessingState.completed) {
            _currentlyPlayingSongId = null;
            _previewPosition = Duration.zero;
          }
        });
      }
    });

    _posSub = _player.positionStream.listen((pos) {
      if (mounted) {
        final now = DateTime.now();
        if (now.difference(_lastAdminPosTime).inMilliseconds >= 400) {
          _lastAdminPosTime = now;
          setState(() => _previewPosition = pos);
        }
      }
    });

    _durSub = _player.durationStream.listen((dur) {
      if (mounted) {
        setState(() => _previewDuration = dur ?? Duration.zero);
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

  void _onR2Update() {
    if (mounted) {
      setState(() {
        _storageStats = R2StorageService().lastCalculatedStats ?? _storageStats;
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _tabController.dispose();
    _backend.removeListener(_onUpdate);
    _lang.removeListener(_onUpdate);
    R2StorageService().removeListener(_onR2Update);
    _player.dispose();
    super.dispose();
  }

  String _formatPreviewDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _seekPreview(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> _seekPreviewRelative(int seconds) async {
    final targetMs = _previewPosition.inMilliseconds + (seconds * 1000);
    final maxMs = _previewDuration.inMilliseconds > 0 ? _previewDuration.inMilliseconds : 600000;
    final clamped = targetMs.clamp(0, maxMs);
    await _player.seek(Duration(milliseconds: clamped));
  }

  Future<void> _stopSongPreview() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _currentlyPlayingSongId = null;
        _previewPosition = Duration.zero;
        _previewDuration = Duration.zero;
      });
    }
  }

  Future<void> _playSongPreview(Song song) async {
    try {
      if (_currentlyPlayingSongId == song.id && _isPlaying) {
        await _player.pause();
        return;
      }

      setState(() {
        _currentlyPlayingSongId = song.id;
        _previewPosition = Duration.zero;
        _previewDuration = Duration(seconds: song.duration > 0 ? song.duration : 0);
      });

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
    final uri = Uri.parse('https://wa.me/$clean?text=Hello%20from%20Msixa%20Admin');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchMail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Msixa%20Player%20Support');
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
          SnackBar(
            content: Text(_lang.isHindi
                ? 'डिवाइस पर कोई ऑडियो फ़ोल्डर नहीं मिला। "सिस्टम फ़ोल्डर" या "गाने चुनें" आज़माएं।'
                : 'No audio folders found on device. Try "System Folder" or "Pick Songs".'),
          ),
        );
      }
      return;
    }

    final sortedFolders = folderMap.keys.toList()
      ..sort((a, b) => (folderMap[b]?.length ?? 0).compareTo(folderMap[a]?.length ?? 0));

    if (!context.mounted) return;

    final Set<String> selectedFolders = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          int totalSelectedSongs = 0;
          for (final f in selectedFolders) {
            for (final entry in folderMap.entries) {
              if (entry.key == f || entry.key.startsWith('$f/')) {
                totalSelectedSongs += entry.value.length;
              }
            }
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
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
                      Expanded(
                        child: Text(
                          selectedFolders.isEmpty
                              ? (_lang.isHindi ? 'डिवाइस पर मिले फ़ोल्डर (${sortedFolders.length})' : 'Folders on Device (${sortedFolders.length})')
                              : (_lang.isHindi ? 'चयनित: ${selectedFolders.length} फ़ोल्डर ($totalSelectedSongs गाने)' : 'Selected: ${selectedFolders.length} Folders ($totalSelectedSongs Songs)'),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00E5FF),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: Icon(
                          selectedFolders.length == sortedFolders.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                          size: 18,
                        ),
                        label: Text(
                          selectedFolders.length == sortedFolders.length
                              ? (_lang.isHindi ? 'सभी हटाएं' : 'Deselect All')
                              : (_lang.isHindi ? 'सभी चुनें' : 'Select All'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          setSheetState(() {
                            if (selectedFolders.length == sortedFolders.length) {
                              selectedFolders.clear();
                            } else {
                              selectedFolders.addAll(sortedFolders);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: sortedFolders.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, i) {
                      final folderPath = sortedFolders[i];
                      final isSelected = selectedFolders.contains(folderPath);
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

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: const Color(0xFF00E5FF),
                        checkColor: Colors.black,
                        tileColor: isSelected ? const Color(0xFF00E5FF).withOpacity(0.08) : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isSelected ? const Color(0xFF00E5FF) : const Color(0xFFFFB300)).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isSelected ? Icons.folder_shared_rounded : Icons.folder_rounded,
                            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          folderName,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${allInFolderAndSub.length} ${_lang.isHindi ? "गाने" : "Tracks"} | ${rel.isNotEmpty ? rel : cleanPath}',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            if (val == true) {
                              selectedFolders.add(folderPath);
                            } else {
                              selectedFolders.remove(folderPath);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                // Bottom Sticky Confirm Button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F1626),
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedFolders.isNotEmpty ? const Color(0xFF00E5FF) : Colors.white12,
                            foregroundColor: selectedFolders.isNotEmpty ? Colors.black : Colors.white38,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            selectedFolders.isEmpty
                                ? (_lang.isHindi ? 'कम से कम एक फ़ोल्डर चुनें' : 'Select at least one folder')
                                : (_lang.isHindi ? 'चयनित ${selectedFolders.length} फ़ोल्डर जोड़ें ($totalSelectedSongs गाने)' : 'Add ${selectedFolders.length} Folders ($totalSelectedSongs Tracks)'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: selectedFolders.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(bCtx);
                                  final List<PlatformFile> combinedFiles = [];
                                  for (final fp in selectedFolders) {
                                    for (final entry in folderMap.entries) {
                                      if (entry.key == fp || entry.key.startsWith('$fp/')) {
                                        combinedFiles.addAll(entry.value);
                                      }
                                    }
                                  }
                                  // Deduplicate by path
                                  final seenPaths = <String>{};
                                  final uniqueFiles = <PlatformFile>[];
                                  for (final f in combinedFiles) {
                                    if (f.path != null && seenPaths.add(f.path!)) {
                                      uniqueFiles.add(f);
                                    }
                                  }
                                  final titleLabel = selectedFolders.length == 1
                                      ? selectedFolders.first.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => 'Folder')
                                      : (_lang.isHindi ? '${selectedFolders.length} फ़ोल्डर्स (${uniqueFiles.length} गाने)' : '${selectedFolders.length} Folders (${uniqueFiles.length} Tracks)');
                                  onFolderSelected(uniqueFiles, titleLabel, selectedFolders.first);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
            children: [
              const Icon(Icons.folder_copy_rounded, color: Color(0xFFFFB300), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lang.isHindi ? 'बल्क / फ़ोल्डर गाने अपलोड करें' : 'Bulk / Folder Upload',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                  Text(
                    _lang.isHindi
                        ? 'डिवाइस से फ़ोल्डर या कई MP3s चुनें। फ़ोल्डर का नाम Category और अंदर के सब-फ़ोल्डर का नाम Sub-Category बन जाएगा। स्क्रीन लॉक होने पर भी बैकग्राउंड में अपलोड जारी रहेगा।'
                        : 'Select folders or multiple audio files from device. Folder name becomes Category, sub-folders become Sub-Categories. Background upload continues even if screen is locked.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                            label: Text(
                              _lang.isHindi ? 'फ़ोल्डर (Multi)' : 'Folders (Multi)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            onPressed: () {
                              _showDeviceFolderPicker(
                                context,
                                onFolderSelected: (files, folderName, folderPath) {
                                  setDialogState(() {
                                    if (playlistTitleCtrl.text.isEmpty) {
                                      playlistTitleCtrl.text = folderName;
                                    }
                                    updateFilesHierarchy(files, rootFolderPath: folderPath);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_lang.isHindi ? '✅ "$folderName" से ${files.length} गाने लोड हुए!' : '✅ Loaded ${files.length} songs from "$folderName"!'),
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
                            label: Text(
                              _lang.isHindi ? 'सिस्टम फ़ोल्डर' : 'System Folder',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
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
                                      SnackBar(content: Text(_lang.isHindi ? 'चयनित फ़ोल्डर में कोई गाना नहीं मिला। "डिवाइस फ़ोल्डर" आज़माएं।' : 'No audio files found in selected folder. Try "Device Folders".')),
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
                              pickedFiles.isEmpty
                                  ? (_lang.isHindi ? 'गाने चुनें' : 'Pick Songs')
                                  : (_lang.isHindi ? 'गाने (${pickedFiles.length})' : 'Songs (${pickedFiles.length})'),
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
                    Text(
                      _lang.isHindi ? 'डिफ़ॉल्ट श्रेणी (Category / Genre):' : 'Default Category / Genre:',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
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
                    Text(
                      _lang.isHindi ? 'डिफ़ॉल्ट उप-श्रेणी (वैकल्पिक):' : 'Default Sub-Category (Optional):',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: subCategoryCtrl,
                      enabled: !isUploading,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: _lang.isHindi ? 'उदा. Marwadi Hits, Folk (वैकल्पिक)' : 'e.g. Marwadi Hits, Folk (Optional)',
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
                            title: Text(
                              _lang.isHindi ? 'फ़ोल्डर के नाम से प्लेलिस्ट बनाएं' : 'Create Playlist from Folder Name',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              _lang.isHindi ? 'सभी अपलोड किए गए गानों से नई प्लेलिस्ट तैयार होगी' : 'Generate new playlist from all uploaded tracks',
                              style: const TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ),
                          if (createPlaylistWithFolder) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: playlistTitleCtrl,
                              enabled: !isUploading,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: _lang.isHindi ? 'प्लेलिस्ट का नाम' : 'Playlist Title',
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
                      _lang.isHindi ? 'चयनित गाने (${pickedFiles.length}):' : 'Selected Songs (${pickedFiles.length}):',
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
                child: Text(_lang.isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.grey)),
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
                  _lang.isHindi ? 'R2 पर अपलोड शुरू करें (${pickedFiles.length})' : 'Start Upload to R2 (${pickedFiles.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () async {
                  setDialogState(() {
                    isUploading = true;
                    currentIndex = 0;
                    currentTrackProgress = 0.0;
                    statusMessage = _lang.isHindi ? 'अपलोड शुरू हो रहा है... (स्क्रीन ऑन और बैकग्राउंड एक्टिव)' : 'Starting upload... (Screen awake & background active)';
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
                          statusMessage = _lang.isHindi ? '⚠️ स्किप किया (Duplicate): $smartTitle (पहले से मौजूद)' : '⚠️ Skipped (Duplicate): $smartTitle (Already exists)';
                        });
                        await Future.delayed(const Duration(milliseconds: 250));
                        continue;
                      }

                      batchUploadedTitles.add(CloudBackendService.normalizeTitle(smartTitle));

                      setDialogState(() {
                        currentIndex = i;
                        currentTrackProgress = 0.1;
                        statusMessage = _lang.isHindi ? 'अपलोड हो रहा है (${i + 1}/${pickedFiles.length}): $smartTitle...' : 'Uploading (${i + 1}/${pickedFiles.length}): $smartTitle...';
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

                          // Look for cover image in the same directory (e.g. cover.jpg, folder.jpg)
                          String? discoveredCoverUrl;
                          try {
                            final parentDir = file.parent;
                            final imageCandidates = parentDir.listSync().whereType<File>().where((f) {
                              final name = f.path.split(Platform.pathSeparator).last.toLowerCase();
                              return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp');
                            }).toList();
                            if (imageCandidates.isNotEmpty) {
                              // If there is cover.jpg or folder.jpg, prefer it
                              final preferred = imageCandidates.firstWhere(
                                (f) => f.path.toLowerCase().contains('cover') || f.path.toLowerCase().contains('folder') || f.path.toLowerCase().contains('art'),
                                orElse: () => imageCandidates.first,
                              );
                              discoveredCoverUrl = await r2.uploadImageFile(preferred);
                            }
                          } catch (_) {}

                          String detectedArtist = 'Various Artists';
                          String detectedTitle = smartTitle;
                          if (smartTitle.contains(' - ')) {
                            final split = smartTitle.split(' - ');
                            if (split.length >= 2) {
                              detectedArtist = split[0].trim();
                              detectedTitle = split.sublist(1).join(' - ').trim();
                            }
                          } else {
                            detectedArtist = SongArtworkResolver.extractArtist(smartTitle, fallback: 'Various Artists');
                          }

                          discoveredCoverUrl ??= SongArtworkResolver.resolveArtwork(
                            title: detectedTitle,
                            artist: detectedArtist,
                            genre: targetCategory,
                          );

                          final newSong = await _backend.addAdminSong(
                            title: detectedTitle,
                            artist: detectedArtist,
                            album: playlistTitleCtrl.text.trim().isNotEmpty ? playlistTitleCtrl.text.trim() : 'Msixa Cloud Hits',
                            genre: targetCategory,
                            subCategory: targetSubCategory,
                            audioPath: cloudUrl,
                            coverUrl: discoveredCoverUrl,
                          );
                          uploadedSongsList.add(newSong);
                          successCount++;
                          setDialogState(() {
                            _storageStats = R2StorageService().lastCalculatedStats ?? _storageStats;
                          });
                          _onR2Update();
                        }
                      } catch (e) {
                        debugPrint('Error uploading ${pf.name}: $e');
                      }
                    }

                    // 2. Auto-Create Playlists with Folder Hierarchy (Cloud & Local)
                    if (uploadedSongsList.isNotEmpty) {
                      try {
                        final storage = StorageService();
                        final existingPlaylists = await storage.loadCustomPlaylists();
                        final List<Playlist> newGeneratedPlaylists = [];

                        final rootTitle = playlistTitleCtrl.text.trim().isNotEmpty
                            ? playlistTitleCtrl.text.trim()
                            : (prefillSubCategory ?? (uploadedSongsList.first.subCategory ?? '${uploadedSongsList.first.genre} Collection'));

                        // Group by subcategory/subfolder
                        final Map<String, List<Song>> subFolderMap = {};
                        for (final s in uploadedSongsList) {
                          final sub = s.subCategory?.trim();
                          if (sub != null && sub.isNotEmpty) {
                            subFolderMap.putIfAbsent(sub, () => []).add(s);
                          }
                        }

                        // Create distinct playlist for each subfolder
                        for (final entry in subFolderMap.entries) {
                          final subPlTitle = '$rootTitle › ${entry.key}';
                          newGeneratedPlaylists.add(Playlist(
                            id: 'pl_${DateTime.now().millisecondsSinceEpoch}_${entry.key.hashCode.abs()}',
                            title: subPlTitle,
                            description: 'Sub-folder collection (${entry.value.length} tracks)',
                            coverUrl: entry.value.first.coverUrl,
                            songs: entry.value,
                          ));
                        }

                        // Master playlist containing all songs of root folder
                        newGeneratedPlaylists.add(Playlist(
                          id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
                          title: rootTitle,
                          description: 'Full folder collection (${uploadedSongsList.length} tracks)',
                          coverUrl: uploadedSongsList.first.coverUrl,
                          songs: uploadedSongsList,
                        ));

                        // 1. Add to Cloud Backend (persists to R2 db/playlists.json for all users!)
                        for (final pl in newGeneratedPlaylists) {
                          await _backend.addCloudPlaylist(pl);
                        }

                        // 2. Save locally
                        final updated = [...newGeneratedPlaylists, ...existingPlaylists];
                        await storage.saveCustomPlaylists(updated);
                      } catch (pe) {
                        debugPrint('Playlist auto-create error: $pe');
                      }
                    }
                  } finally {
                    // 3. Release WakeLock & Show Native Background Status Notification
                    await BackgroundUploadService.releaseWakeLock();
                    await BackgroundUploadService.showUploadNotification(
                      title: _lang.isHindi ? 'बल्क अपलोड पूरा हुआ!' : 'Bulk Upload Complete!',
                      message: _lang.isHindi
                          ? '$successCount गाने Cloudflare R2 पर लाइव हो गए!' + (skippedCount > 0 ? ' ($skippedCount डुप्लीकेट स्किप)' : '')
                          : '$successCount songs live on Cloudflare R2!' + (skippedCount > 0 ? ' ($skippedCount duplicates skipped)' : ''),
                    );
                    _refreshStorageStats();
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                    final summaryMsg = _lang.isHindi
                        ? (skippedCount > 0
                            ? '🎉 $successCount गाने लाइव हुए | ⚠️ $skippedCount डुप्लीकेट गाने स्किप कर दिए गए!'
                            : '🎉 $successCount / ${pickedFiles.length} गाने Cloudflare R2 पर सफलतापूर्वक लाइव हो गए!')
                        : (skippedCount > 0
                            ? '$successCount songs live on R2 | $skippedCount duplicates skipped'
                            : '$successCount / ${pickedFiles.length} songs live on Cloudflare R2 successfully!');
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
    final albumCtrl = TextEditingController(text: 'Msixa Originals');
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
                _buildAdminTextField(albumCtrl, _lang.t('album_name'), 'Msixa Originals'),
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
                      isUploadingToR2
                          ? (_lang.isHindi ? 'R2 क्लाउड पर अपलोड हो रहा है...' : 'Uploading to R2 Cloud...')
                          : (_lang.isHindi ? 'डिवाइस से MP3 चुनें और R2 पर अपलोड करें' : 'Pick MP3 from Device & Upload to R2'),
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

                _buildAdminTextField(audioCtrl, _lang.isHindi ? 'ऑडियो लिंक या पाथ' : 'Audio Stream URL / Path', 'https://pub-d4f2... or assets/audio/...'),
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
                _buildAdminTextField(subCategoryCtrl, _lang.isHindi ? 'उप-श्रेणी (वैकल्पिक)' : 'Sub-Category (Optional)', _lang.isHindi ? 'उदा. Marwadi Hits, Folk' : 'e.g. Marwadi Hits, Folk'),
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
                _buildAdminTextField(audioCtrl, _lang.isHindi ? 'ऑडियो लिंक या पाथ' : 'Audio Stream URL / Path', ''),
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
                _buildAdminTextField(subCategoryCtrl, _lang.isHindi ? 'उप-श्रेणी' : 'Sub-Category', _lang.isHindi ? 'उदा. Marwadi Hits' : 'e.g. Marwadi Hits'),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Cloudflare R2 Storage',
                              style: GoogleFonts.syne(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isConnected ? progressColor.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isConnected ? '${usedPercentage.toStringAsFixed(1)}%' : 'Setup',
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
                        'Bucket: ${r2.bucketName ?? "musixa-music"} | CDN Live',
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
            icon: const Icon(Icons.cloud_sync_rounded, size: 16),
            label: Text(
              _lang.isHindi ? 'क्लाउड गाने सिंक करें' : 'Sync Cloud Songs',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_lang.isHindi ? '⏳ Cloudflare R2 से गाने लोड हो रहे हैं...' : '⏳ Loading songs from Cloudflare R2...'),
              ));
              await _backend.syncWithCloud();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_lang.isHindi ? '✅ R2 से ${_backend.approvedSongs.length} गाने लोड हो गए!' : '✅ Loaded ${_backend.approvedSongs.length} songs from R2!'),
                ));
              }
            },
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
            tooltip: _lang.isHindi ? 'एडमिन अपडेट चेक करें' : 'Check Admin Update',
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

          // Admin Live OTA Update Banner
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: UpdateService.adminAvailableUpdateNotifier,
            builder: (context, updateData, _) {
              if (updateData == null) return const SizedBox.shrink();
              final vName = updateData['remoteName'] ?? '1.0.71';
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: InkWell(
                  onTap: () => UpdateService.checkForUpdate(context, autoPrompt: false, isAdmin: true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update_rounded, color: Colors.black, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _lang.isHindi
                                ? '🚀 नया एडमिन वर्ज़न उपलब्ध है: v$vName (अपडेट करने के लिए टैप करें)'
                                : '🚀 New Admin Update Available: v$vName (Tap to Install)',
                            style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _lang.isHindi ? 'अपडेट' : 'Update',
                            style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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

          // Sticky Persistent Audio Preview Player with Seek Scrubber
          if (_currentlyPlayingSongId != null)
            _buildStickyPreviewBottomBar(approved, pending),
        ],
      ),
    );
  }

  Widget _buildStickyPreviewBottomBar(List<Song> approved, List<Song> pending) {
    final allSongs = [...approved, ...pending];
    final song = allSongs.firstWhere(
      (s) => s.id == _currentlyPlayingSongId,
      orElse: () => Song(
        id: _currentlyPlayingSongId ?? 'preview',
        title: 'Audio Preview',
        artist: 'Msixa Music',
        album: 'Live Preview',
        duration: 0,
        streamUrl: '',
        coverUrl: '',
      ),
    );

    final maxMs = _previewDuration.inMilliseconds > 0 ? _previewDuration.inMilliseconds.toDouble() : 1.0;
    final currMs = _previewPosition.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: const Color(0xFFFFB300).withOpacity(0.6), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Interactive Seek Scrubber
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: const Color(0xFFFFB300),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFFFFB300),
            ),
            child: Slider(
              value: currMs,
              max: maxMs,
              onChanged: (val) => _seekPreview(Duration(milliseconds: val.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Row(
              children: [
                SongThumbnailWidget(
                  song: song,
                  size: 44,
                  borderRadius: 8,
                  isPlaying: _isPlaying,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatPreviewDuration(_previewPosition),
                            style: const TextStyle(
                              color: Color(0xFFFFB300),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' / ${_formatPreviewDuration(_previewDuration)}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '• ${song.artist}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Rewind 10s
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 22),
                  tooltip: _lang.isHindi ? '10s पीछे करें' : 'Rewind 10s',
                  onPressed: () => _seekPreviewRelative(-10),
                  visualDensity: VisualDensity.compact,
                ),
                // Play / Pause
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: const Color(0xFFFFB300),
                    size: 34,
                  ),
                  tooltip: _isPlaying ? (_lang.isHindi ? 'रोकें' : 'Pause') : (_lang.isHindi ? 'चलाएं' : 'Play'),
                  onPressed: () => _playSongPreview(song),
                  visualDensity: VisualDensity.compact,
                ),
                // Forward 10s
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 22),
                  tooltip: _lang.isHindi ? '10s आगे करें' : 'Forward 10s',
                  onPressed: () => _seekPreviewRelative(10),
                  visualDensity: VisualDensity.compact,
                ),
                // Close
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  tooltip: _lang.isHindi ? 'बंद करें' : 'Close',
                  onPressed: _stopSongPreview,
                  visualDensity: VisualDensity.compact,
                ),
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

              // Inline Preview Scrubber & Time Display when playing
              if (isThisPlaying) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _formatPreviewDuration(_previewPosition),
                        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: const Color(0xFFFFB300),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFFFFB300),
                          ),
                          child: Slider(
                            value: _previewDuration.inMilliseconds > 0
                                ? _previewPosition.inMilliseconds.clamp(0, _previewDuration.inMilliseconds).toDouble()
                                : 0.0,
                            max: _previewDuration.inMilliseconds > 0 ? _previewDuration.inMilliseconds.toDouble() : 1.0,
                            onChanged: (val) => _seekPreview(Duration(milliseconds: val.toInt())),
                          ),
                        ),
                      ),
                      Text(
                        _formatPreviewDuration(_previewDuration),
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],

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

  // ==========================================
  // BULK WHATSAPP BROADCAST SYSTEM
  // ==========================================
  void _showBulkWhatsAppDialog() {
    final allUsersWithPhone = _backend.allUsers.where((u) => u.phoneNumber.trim().isNotEmpty).toList();
    final Set<String> selectedPhones = allUsersWithPhone.map((u) => u.phoneNumber.trim()).toSet();
    final TextEditingController msgController = TextEditingController(
      text: _lang.isHindi
          ? "नमस्ते {name}!\n\nMusixa Player पर आपके लिए नए गाने रिलीज हुए हैं। अभी ऐप खोलें और बेहतरीन एचडी म्यूजिक का आनंद लें!\n\nडाउनलोड ऐप: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/apk/msixa-player.apk"
          : "Hello {name}!\n\nNew songs are now live on Musixa Player. Open the app now and enjoy premium HD music!\n\nDownload: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/apk/msixa-player.apk",
    );
    String? attachedFilePath;
    String? attachedFileName;
    int? attachedFileSize;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final validRecipients = allUsersWithPhone.where((u) => selectedPhones.contains(u.phoneNumber.trim())).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Modal Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lang.isHindi ? 'थोक व्हाट्सएप ब्रॉडकास्ट' : 'Bulk WhatsApp Broadcast',
                                style: GoogleFonts.syne(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _lang.isHindi
                                    ? '${selectedPhones.length} यूज़र्स चयनित (कुल ${allUsersWithPhone.length})'
                                    : '${selectedPhones.length} Selected (Total ${allUsersWithPhone.length})',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Modal Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Quick Templates Chips
                        Text(
                          _lang.isHindi ? 'त्वरित संदेश टेम्पलेट (Quick Templates)' : 'Quick Templates',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ActionChip(
                                backgroundColor: const Color(0xFF1E293B),
                                avatar: const Icon(Icons.music_note_rounded, size: 14, color: Color(0xFF00E5FF)),
                                label: Text(
                                  _lang.isHindi ? '🎵 नया गाना अलर्ट' : '🎵 New Song',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    msgController.text = _lang.isHindi
                                        ? "नमस्ते {name}!\n\nMusixa Player पर आज नया धमाकेदार गाना रिलीज हुआ है। अभी ऐप खोलें और सुनें!\n\nडाउनलोड ऐप: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/apk/msixa-player.apk"
                                        : "Hello {name}!\n\nA brand new hit track is live on Musixa Player. Open the app now and listen in HD!\n\nDownload: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/apk/msixa-player.apk";
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                backgroundColor: const Color(0xFF1E293B),
                                avatar: const Icon(Icons.system_update_rounded, size: 14, color: Colors.greenAccent),
                                label: Text(
                                  _lang.isHindi ? '🚀 नया ऐप अपडेट' : '🚀 App Update',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    msgController.text = _lang.isHindi
                                        ? "नमस्ते {name}!\n\nMusixa Player का नया अपडेट लाइव हो गया है जिसमें हाई क्वालिटी वीडियो प्लेयर, ईक्वलाइज़र और फास्ट डाउनलोडिंग शामिल है। तुरंत अपडेट करें!\n\nअपडेट लिंक: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/apk/msixa-player.apk"
                                        : "Hello {name}!\n\nA major update for Musixa Player is live featuring 4K video player, smart equalizer, and instant streaming. Update now!\n\nDownload: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/apk/msixa-player.apk";
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                backgroundColor: const Color(0xFF1E293B),
                                avatar: const Icon(Icons.celebration_rounded, size: 14, color: Colors.amberAccent),
                                label: Text(
                                  _lang.isHindi ? '🌟 शुभकामनाएं' : '🌟 Wishes',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    msgController.text = _lang.isHindi
                                        ? "नमस्ते {name}!\n\nMusixa Player परिवार की ओर से आपको और आपके पूरे परिवार को हार्दिक शुभकामनाएं! सदा खुश रहें और मधुर संगीत का आनंद लें।"
                                        : "Warm greetings {name}!\n\nBest wishes from the Musixa Player family. Enjoy pure music with us!";
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Message Box
                        Text(
                          _lang.isHindi ? 'संदेश टाइप करें (Personalized Message Box)' : 'Message Content',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: TextField(
                            controller: msgController,
                            maxLines: 5,
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(12),
                              border: InputBorder.none,
                              hintText: _lang.isHindi ? 'यहाँ अपना संदेश लिखें...' : 'Type your broadcast message...',
                              hintStyle: const TextStyle(color: Colors.white38),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 4),
                            Text(
                              _lang.isHindi
                                  ? '{name} की जगह यूज़र का असली नाम अपने आप आएगा'
                                  : '{name} will be replaced with user\'s full name',
                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Attachment Picker Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: attachedFilePath != null ? const Color(0xFF25D366).withOpacity(0.5) : Colors.white10,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF25D366)),
                                  const SizedBox(width: 6),
                                  Text(
                                    _lang.isHindi ? 'अटैचमेंट जोड़ें (Attachment)' : 'Attachment',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  if (attachedFilePath != null)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setModalState(() {
                                          attachedFilePath = null;
                                          attachedFileName = null;
                                          attachedFileSize = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                              if (attachedFilePath != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF25D366), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          attachedFileName ?? 'file',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (attachedFileSize != null)
                                        Text(
                                          '${(attachedFileSize! / (1024 * 1024)).toStringAsFixed(1)} MB',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        icon: const Icon(Icons.image_outlined, size: 15, color: Color(0xFF00E5FF)),
                                        label: Text(
                                          _lang.isHindi ? 'पोस्टर/इमेज' : 'Image',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        onPressed: () async {
                                          final res = await FilePicker.platform.pickFiles(type: FileType.image);
                                          if (res != null && res.files.single.path != null) {
                                            setModalState(() {
                                              attachedFilePath = res.files.single.path;
                                              attachedFileName = res.files.single.name;
                                              attachedFileSize = res.files.single.size;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        icon: const Icon(Icons.audiotrack_rounded, size: 15, color: Colors.purpleAccent),
                                        label: Text(
                                          _lang.isHindi ? 'गाना (Audio)' : 'Audio',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        onPressed: () async {
                                          final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                                          if (res != null && res.files.single.path != null) {
                                            setModalState(() {
                                              attachedFilePath = res.files.single.path;
                                              attachedFileName = res.files.single.name;
                                              attachedFileSize = res.files.single.size;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        icon: const Icon(Icons.android_rounded, size: 15, color: Colors.greenAccent),
                                        label: Text(
                                          _lang.isHindi ? 'APK/फ़ाइल' : 'APK / Doc',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        onPressed: () async {
                                          final res = await FilePicker.platform.pickFiles(type: FileType.any);
                                          if (res != null && res.files.single.path != null) {
                                            setModalState(() {
                                              attachedFilePath = res.files.single.path;
                                              attachedFileName = res.files.single.name;
                                              attachedFileSize = res.files.single.size;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Recipient Selection Header
                        Row(
                          children: [
                            Text(
                              _lang.isHindi ? 'प्राप्तकर्ता चुनें (Select Recipients)' : 'Select Recipients',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  if (selectedPhones.length == allUsersWithPhone.length) {
                                    selectedPhones.clear();
                                  } else {
                                    selectedPhones.addAll(allUsersWithPhone.map((u) => u.phoneNumber.trim()));
                                  }
                                });
                              },
                              child: Text(
                                selectedPhones.length == allUsersWithPhone.length
                                    ? (_lang.isHindi ? 'सभी हटाएं' : 'Deselect All')
                                    : (_lang.isHindi ? 'सभी चुनें' : 'Select All'),
                                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        // Recipients List
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: allUsersWithPhone.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                            itemBuilder: (_, i) {
                              final u = allUsersWithPhone[i];
                              final isSelected = selectedPhones.contains(u.phoneNumber.trim());
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                activeColor: const Color(0xFF25D366),
                                checkColor: Colors.black,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  u.fullName,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  u.phoneNumber,
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      selectedPhones.add(u.phoneNumber.trim());
                                    } else {
                                      selectedPhones.remove(u.phoneNumber.trim());
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0F1D),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Button 1: Direct Share to WhatsApp
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: Text(
                                  _lang.isHindi ? 'व्हाट्सएप पर शेयर करें' : 'Share to WhatsApp',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                onPressed: selectedPhones.isEmpty
                                    ? null
                                    : () async {
                                        Navigator.pop(ctx);
                                        final firstUser = validRecipients.isNotEmpty ? validRecipients.first : null;
                                        final customText = msgController.text.replaceAll('{name}', firstUser?.fullName ?? 'Music Lover');

                                        if (attachedFilePath != null && File(attachedFilePath!).existsSync()) {
                                          await Share.shareXFiles(
                                            [XFile(attachedFilePath!)],
                                            text: customText,
                                          );
                                        } else {
                                          await Share.share(customText);
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Button 2: Sequential Queue Dispatcher
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF25D366),
                                  side: const BorderSide(color: Color(0xFF25D366)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.queue_play_next_rounded, size: 16),
                                label: Text(
                                  _lang.isHindi ? '1-by-1 कतार' : '1-by-1 Queue',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                onPressed: selectedPhones.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(ctx);
                                        _startSequentialWhatsAppBroadcastQueue(
                                          recipients: validRecipients,
                                          rawTemplate: msgController.text,
                                        );
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Copy All Numbers Option
                        TextButton.icon(
                          icon: const Icon(Icons.copy_all_rounded, size: 15, color: Colors.white60),
                          label: Text(
                            _lang.isHindi
                                ? 'सभी ${selectedPhones.length} मोबाइल नंबर कॉपी करें'
                                : 'Copy all ${selectedPhones.length} phone numbers',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          onPressed: selectedPhones.isEmpty
                              ? null
                              : () {
                                  final text = selectedPhones.join(', ');
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_lang.isHindi ? 'सभी नंबर कॉपी हो गए!' : 'All numbers copied!')),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startSequentialWhatsAppBroadcastQueue({
    required List<UserProfile> recipients,
    required String rawTemplate,
  }) {
    if (recipients.isEmpty) return;
    int currentIndex = 0;

    void openNextChat(StateSetter setDialogState) async {
      if (currentIndex >= recipients.length) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_lang.isHindi ? 'ब्रॉडकास्ट पूरा हुआ!' : 'Broadcast complete!')),
        );
        return;
      }

      final u = recipients[currentIndex];
      final personalized = rawTemplate.replaceAll('{name}', u.fullName);
      final rawDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanDigits = rawDigits.startsWith('91') && rawDigits.length == 12
          ? rawDigits
          : (rawDigits.length == 10 ? '91$rawDigits' : rawDigits);

      final uri = Uri.parse('https://wa.me/$cleanDigits?text=${Uri.encodeComponent(personalized)}');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Error launching WhatsApp: $e');
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (queueCtx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            final u = recipients[currentIndex];
            return AlertDialog(
              backgroundColor: const Color(0xFF131B2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _lang.isHindi ? 'कतार: ${currentIndex + 1} / ${recipients.length}' : 'Queue: ${currentIndex + 1} / ${recipients.length}',
                    style: GoogleFonts.syne(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.fullName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    u.phoneNumber,
                    style: const TextStyle(color: Color(0xFF25D366), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      rawTemplate.replaceAll('{name}', u.fullName),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(queueCtx),
                  child: Text(_lang.isHindi ? 'रोकें' : 'Stop', style: const TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      currentIndex++;
                      if (currentIndex >= recipients.length) {
                        Navigator.pop(queueCtx);
                      }
                    });
                  },
                  child: Text(_lang.isHindi ? 'छोड़ें' : 'Skip', style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(_lang.isHindi ? 'चैट खोलें और भेजें' : 'Open Chat & Send', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    openNextChat(setDialogState);
                    setDialogState(() {
                      currentIndex++;
                    });
                  },
                ),
              ],
            );
          },
        );
      },
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
                          _adminGroupByCategory
                              ? (_lang.isHindi ? '📁 कैटेगरी व्यू' : '📁 Category View')
                              : (_lang.isHindi ? '🎵 फ्लैट लिस्ट' : '🎵 Flat List'),
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
                  label: Text(_lang.isHindi ? 'बल्क / फ़ोल्डर अपलोड' : 'Bulk / Folder Upload', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                      tooltip: _lang.isHindi ? 'पूरी श्रेणी चुनें/हटाएं' : 'Select/Deselect Category',
                      onPressed: () => _toggleFolderSelection(catSongs),
                    ),
                  PopupMenuButton<String>(
                    tooltip: _lang.isHindi ? 'श्रेणी / फ़ोल्डर विकल्प' : 'Folder Options',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.more_vert_rounded, color: Color(0xFFFFB300), size: 14),
                          const SizedBox(width: 2),
                          Text(
                            _lang.isHindi ? 'विकल्प' : 'Options',
                            style: const TextStyle(color: Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.bold),
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
                          children: [
                            const Icon(Icons.music_note_rounded, color: Color(0xFFFFB300), size: 16),
                            const SizedBox(width: 8),
                            Text(_lang.isHindi ? '+ एकल गाना जोड़ें' : '+ Add Single Track', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'bulk',
                        child: Row(
                          children: [
                            const Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF00E5FF), size: 16),
                            const SizedBox(width: 8),
                            Text(_lang.isHindi ? 'बल्क / फ़ोल्डर अपलोड' : 'Bulk / Folder Upload', style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                                  ? (_lang.isHindi ? 'श्रेणी अन-सेलेक्ट करें' : 'Deselect Category')
                                  : (_lang.isHindi ? 'पूरी श्रेणी चुनें (Multi-Select)' : 'Select Entire Category'),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete_category',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 8),
                            Text(_lang.isHindi ? 'पूरी श्रेणी/फ़ोल्डर हटाएं' : 'Delete Entire Folder', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
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
                                  tooltip: _lang.isHindi ? 'सब-फ़ोल्डर चुनें/हटाएं' : 'Select Sub-folder',
                                  onPressed: () => _toggleFolderSelection(subSongs),
                                ),
                              PopupMenuButton<String>(
                                tooltip: _lang.isHindi ? 'इस सब-कैटेगरी में विकल्प' : 'Sub-folder Options',
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.more_vert_rounded, color: Color(0xFF00E5FF), size: 12),
                                      const SizedBox(width: 2),
                                      Text(
                                        _lang.isHindi ? 'विकल्प' : 'Options',
                                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
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
                                      children: [
                                        const Icon(Icons.music_note_rounded, color: Color(0xFFFFB300), size: 14),
                                        const SizedBox(width: 6),
                                        Text(_lang.isHindi ? '+ एकल गाना जोड़ें' : '+ Add Single Track', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'bulk',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF00E5FF), size: 14),
                                        const SizedBox(width: 6),
                                        Text(_lang.isHindi ? 'बल्क अपलोड' : 'Bulk Upload', style: const TextStyle(color: Colors.white, fontSize: 11)),
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
                                              ? (_lang.isHindi ? 'अन-सेलेक्ट करें' : 'Deselect')
                                              : (_lang.isHindi ? 'सब-फ़ोल्डर चुनें' : 'Select Sub-folder'),
                                          style: const TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete_subcategory',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 14),
                                        const SizedBox(width: 6),
                                        Text(_lang.isHindi ? 'यह सब-फ़ोल्डर हटाएं' : 'Delete Sub-folder', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
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
                        _lang.isHindi ? '🎵 $category मुख्य ट्रैक्स (${directSongs.length}):' : '🎵 $category Main Tracks (${directSongs.length}):',
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
                if (isThisPlaying) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatPreviewDuration(_previewPosition),
                        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                            activeTrackColor: const Color(0xFFFFB300),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFFFFB300),
                          ),
                          child: Slider(
                            value: _previewDuration.inMilliseconds > 0
                                ? _previewPosition.inMilliseconds.clamp(0, _previewDuration.inMilliseconds).toDouble()
                                : 0.0,
                            max: _previewDuration.inMilliseconds > 0 ? _previewDuration.inMilliseconds.toDouble() : 1.0,
                            onChanged: (val) => _seekPreview(Duration(milliseconds: val.toInt())),
                          ),
                        ),
                      ),
                      Text(
                        _formatPreviewDuration(_previewDuration),
                        style: const TextStyle(color: Colors.white60, fontSize: 9),
                      ),
                    ],
                  ),
                ],
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

