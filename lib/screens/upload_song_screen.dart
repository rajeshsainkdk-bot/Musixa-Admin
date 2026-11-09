import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/cloud_backend_service.dart';
import '../services/r2_storage_service.dart';
import '../services/language_service.dart';
import '../services/background_upload_service.dart';
import '../providers/player_provider.dart';

class UploadSongScreen extends StatefulWidget {
  const UploadSongScreen({Key? key}) : super(key: key);

  @override
  State<UploadSongScreen> createState() => _UploadSongScreenState();
}

class _UploadSongScreenState extends State<UploadSongScreen> {
  final _backend = CloudBackendService();
  final _lang = LanguageService();
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();

  // Mode: 0 = Single Song, 1 = Folder Upload with Auto Playlist
  int _uploadMode = 0;
  List<PlatformFile> _folderPickedFiles = [];
  final _folderPlaylistNameCtrl = TextEditingController();
  final _folderArtistCtrl = TextEditingController(text: 'Various Artists');
  bool _createPlaylistChecked = true;
  int _folderCurrentIndex = 0;

  String _selectedGenre = 'Rajasthani';
  String? _pickedFilePath;
  String? _pickedFileName;
  int? _pickedFileSize;

  Song? _duplicateMatch;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadStatusText;
  String? _errorMessage;

  final List<String> _genres = [
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

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLangUpdate);
    _titleCtrl.addListener(_onFieldChanged);
    _artistCtrl.addListener(_onFieldChanged);
  }

  void _onLangUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lang.removeListener(_onLangUpdate);
    _titleCtrl.removeListener(_onFieldChanged);
    _artistCtrl.removeListener(_onFieldChanged);
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _subCategoryCtrl.dispose();
    _coverUrlCtrl.dispose();
    _folderPlaylistNameCtrl.dispose();
    _folderArtistCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();

    if (title.length >= 3) {
      final duplicate = _backend.checkDuplicateSong(title: title, artist: artist);
      setState(() {
        _duplicateMatch = duplicate;
      });
    } else {
      if (_duplicateMatch != null) {
        setState(() => _duplicateMatch = null);
      }
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final size = await file.length();
        final name = result.files.single.name;

        setState(() {
          _pickedFilePath = path;
          _pickedFileName = name;
          _pickedFileSize = size;
          _errorMessage = null;

          // Auto-fill smart clean title from filename if empty
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text = CloudBackendService.formatSmartTitle(name);
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'फ़ाइल चुनने में समस्या: $e');
    }
  }

  Future<void> _submitSong() async {
    final title = CloudBackendService.formatSmartTitle(_titleCtrl.text.trim());
    final artist = _artistCtrl.text.trim();
    final album = _albumCtrl.text.trim();
    final cover = _coverUrlCtrl.text.trim();

    if (_pickedFilePath == null) {
      setState(() => _errorMessage = 'कृपया फ़ोन से कोई MP3 गाना चुनें');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = 'गाने का नाम (Title) दर्ज करें');
      return;
    }
    if (artist.isEmpty) {
      setState(() => _errorMessage = _lang.isHindi ? 'गायक या आर्टिस्ट का नाम (Artist) दर्ज करें' : 'Please enter artist / singer name');
      return;
    }

    final duplicate = _backend.checkDuplicateSong(title: title, artist: artist);
    if (duplicate != null || _duplicateMatch != null) {
      final dup = duplicate ?? _duplicateMatch!;
      setState(() {
        _duplicateMatch = dup;
        _errorMessage = _lang.isHindi
            ? '⚠️ गाना "${dup.title}" पहले से मौजूद है! डुप्लीकेट गाना अपलोड नहीं किया जा सकता।'
            : '⚠️ Song "${dup.title}" already exists in catalog! Duplicates cannot be uploaded.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _uploadStatusText = 'गाना प्रोसेस हो रहा है...';
      _errorMessage = null;
    });

    try {
      String finalAudioUrl = _pickedFilePath!;
      final r2 = R2StorageService();

      if (r2.isConfigured) {
        setState(() {
          _uploadStatusText = 'Cloudflare R2 क्लाउड पर अपलोड हो रहा है...';
          _uploadProgress = 0.3;
        });

        try {
          final cloudUrl = await r2.uploadAudioFile(
            File(_pickedFilePath!),
            customId: 'user_${DateTime.now().millisecondsSinceEpoch}',
            onProgress: (p) => setState(() => _uploadProgress = p),
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalAudioUrl = cloudUrl;
          }
        } catch (e) {
          debugPrint('R2 Upload fallback: $e');
        }
      }

      final song = await _backend.submitUserSong(
        title: title,
        artist: artist,
        album: album.isEmpty ? 'Community Music' : album,
        genre: _selectedGenre,
        subCategory: _subCategoryCtrl.text.trim().isNotEmpty ? _subCategoryCtrl.text.trim() : null,
        audioPath: finalAudioUrl,
        coverUrl: cover.isNotEmpty ? cover : null,
      );

      setState(() => _isUploading = false);

      if (!mounted) return;

      // Show Celebration Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 28),
              SizedBox(width: 10),
              Text('गाना सबमिट हुआ!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'आपका गाना "${song.title}" रिव्यू के लिए एडमिन के पास भेज दिया गया है।',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B101D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.hourglass_top_rounded, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'एडमिन के अप्रूव (Approve) करते ही यह गाना सभी यूज़र्स के होम पेज पर दिखने लगेगा।',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('ठीक है (Done)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'अपलोड करने में विफल: $e';
      });
    }
  }

  Future<void> _pickFolderAudioFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac'],
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files.where((f) => f.path != null).toList();
        String detectedFolder = 'My Folder Hits';
        if (files.isNotEmpty && files.first.path != null) {
          final parentDir = File(files.first.path!).parent;
          detectedFolder = parentDir.path.split(RegExp(r'[\\/]')).lastWhere((s) => s.isNotEmpty, orElse: () => 'My Folder');
        }

        setState(() {
          _folderPickedFiles = files;
          if (_folderPlaylistNameCtrl.text.isEmpty || _folderPlaylistNameCtrl.text == 'My Folder Hits') {
            _folderPlaylistNameCtrl.text = detectedFolder;
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'फ़ाइलें चुनने में समस्या: $e');
    }
  }

  Future<void> _submitFolderUpload() async {
    if (_folderPickedFiles.isEmpty) {
      setState(() => _errorMessage = 'कृपया पहले फ़ोल्डर या MP3 गाने चुनें');
      return;
    }

    final playlistTitle = _folderPlaylistNameCtrl.text.trim().isNotEmpty
        ? _folderPlaylistNameCtrl.text.trim()
        : 'My Folder Playlist';
    final defaultArtist = _folderArtistCtrl.text.trim().isNotEmpty
        ? _folderArtistCtrl.text.trim()
        : 'Various Artists';

    setState(() {
      _isUploading = true;
      _folderCurrentIndex = 0;
      _uploadProgress = 0.05;
      _uploadStatusText = 'अपलोड शुरू हो रहा है...';
      _errorMessage = null;
    });

    // Keep screen on & background CPU active
    await BackgroundUploadService.acquireWakeLock();

    final r2 = R2StorageService();
    int successCount = 0;
    int skippedCount = 0;
    final Set<String> batchUploadedTitles = {};
    final List<Song> uploadedSongs = [];

    try {
      for (int i = 0; i < _folderPickedFiles.length; i++) {
        final pf = _folderPickedFiles[i];
        if (pf.path == null) continue;

        final cleanName = pf.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');

        // Strict duplicate check
        final duplicate = _backend.checkDuplicateSong(title: cleanName, artist: defaultArtist);
        final isBatchDup = batchUploadedTitles.contains(CloudBackendService.normalizeTitle(cleanName));

        if (duplicate != null || isBatchDup) {
          skippedCount++;
          setState(() {
            _folderCurrentIndex = i;
            _uploadProgress = (i + 1) / _folderPickedFiles.length;
            _uploadStatusText = '⚠️ स्किप किया (Duplicate): $cleanName';
          });
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        }

        batchUploadedTitles.add(CloudBackendService.normalizeTitle(cleanName));

        setState(() {
          _folderCurrentIndex = i;
          _uploadProgress = (i + 0.3) / _folderPickedFiles.length;
          _uploadStatusText = 'अपलोड हो रहा है (${i + 1}/${_folderPickedFiles.length}): $cleanName...';
        });

        String finalAudioUrl = pf.path!;
        if (r2.isConfigured) {
          try {
            final cloudUrl = await r2.uploadAudioFile(
              File(pf.path!),
              customId: 'folder_${DateTime.now().millisecondsSinceEpoch}_$i',
            );
            if (cloudUrl != null && cloudUrl.isNotEmpty) {
              finalAudioUrl = cloudUrl;
            }
          } catch (e) {
            debugPrint('R2 folder track error: $e');
          }
        }

        try {
          final newSong = await _backend.submitUserSong(
            title: cleanName,
            artist: defaultArtist,
            album: playlistTitle,
            genre: _selectedGenre,
            audioPath: finalAudioUrl,
          );
          uploadedSongs.add(newSong);
          successCount++;
        } catch (se) {
          debugPrint('Backend song submit error: $se');
        }
      }

      // Auto-create Playlist in User Library with the Folder Name
      if (_createPlaylistChecked && uploadedSongs.isNotEmpty) {
        try {
          if (mounted) {
            context.read<PlayerProvider>().createPlaylist(playlistTitle, uploadedSongs);
          }
        } catch (pe) {
          debugPrint('createPlaylist provider error: $pe');
        }
      }
    } finally {
      await BackgroundUploadService.releaseWakeLock();
      await BackgroundUploadService.showUploadNotification(
        title: '🎉 फ़ोल्डर अपलोड पूरा हुआ!',
        message: '$successCount गाने अपलोड हुए और "$playlistTitle" प्लेलिस्ट तैयार हो गई!' + (skippedCount > 0 ? ' ($skippedCount डुप्लीकेट स्किप)' : ''),
      );
    }

    setState(() => _isUploading = false);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 28),
            SizedBox(width: 10),
            Text('फ़ोल्डर अपलोड पूरा हुआ!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎉 $successCount गाने सफलतापूर्वक सबमिट हो गए!' + (skippedCount > 0 ? '\n⚠️ $skippedCount डुप्लीकेट गाने पहले से मौजूद थे इसलिए स्किप किए गए।' : ''),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_createPlaylistChecked && uploadedSongs.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B101D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.playlist_add_check_rounded, color: Color(0xFF00E5FF), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'आपकी लाइब्रेरी में "$playlistTitle" नाम से नई प्लेलिस्ट तैयार हो गई है जिसमें ये सभी $successCount गाने जोड़े गए हैं!',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('ठीक है (Done)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _lang.isHindi ? 'गाना अपलोड करें' : 'Upload Song',
          style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          InkWell(
            onTap: () => _lang.toggleLanguage(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFF00E5FF), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _lang.displayLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00E5FF).withOpacity(0.12), const Color(0xFF4F46E5).withOpacity(0.12)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFF00E5FF), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lang.isHindi ? 'कम्युनिटी म्यूज़िक शेयरिंग' : 'Community Music Sharing',
                          style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _lang.isHindi
                              ? 'कोई भी नया MP3 अपलोड करें। एडमिन अप्रूवल के बाद यह सभी के लिए लाइव होगा।'
                              : 'Upload any MP3. Once approved by Admin, it goes live for everyone on the platform.',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mode Selector: Admin can choose Single or Folder; Users are restricted to Single Song only
            if (_backend.isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isUploading ? null : () => setState(() => _uploadMode = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _uploadMode == 0 ? const Color(0xFF00E5FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              _lang.isHindi ? '🎵 एक गाना' : '🎵 Single Song',
                              style: TextStyle(
                                color: _uploadMode == 0 ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isUploading ? null : () => setState(() => _uploadMode = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _uploadMode == 1 ? const Color(0xFF00E5FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              _lang.isHindi ? '📁 फ़ोल्डर / प्लेलिस्ट (Admin)' : '📁 Folder / Playlist (Admin)',
                              style: TextStyle(
                                color: _uploadMode == 1 ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _lang.isHindi ? '🎵 एकल गाना अपलोड (One by One)' : '🎵 Single Song Upload (One by One)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            if (_uploadMode == 1)
              _buildFolderUploadView()
            else ...[
            // File Picker Box
            GestureDetector(
              onTap: _pickAudioFile,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pickedFilePath != null ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.12),
                    width: _pickedFilePath != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _pickedFilePath != null ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _pickedFilePath != null ? Icons.audio_file_rounded : Icons.folder_open_rounded,
                        color: _pickedFilePath != null ? const Color(0xFF00E5FF) : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pickedFileName ?? (_lang.isHindi ? 'फोन से MP3 ऑडियो फ़ाइल चुनें' : 'Choose MP3 audio file from phone'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _pickedFileName != null ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pickedFileSize != null
                          ? '${(_pickedFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB • ${_lang.isHindi ? "तैयार" : "Ready"}'
                          : (_lang.isHindi ? 'MP3, M4A, WAV समर्थित (चुनने के लिए क्लिक करें)' : 'MP3, M4A, WAV supported (Click to browse)'),
                      style: TextStyle(
                        fontSize: 11,
                        color: _pickedFileSize != null ? const Color(0xFF00E5FF) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Duplicate Detection Alert
            if (_duplicateMatch != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'यह गाना पहले से उपलब्ध है! (Already in Library)',
                            style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              _duplicateMatch!.coverUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.grey.shade800),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_duplicateMatch!.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                Text(_duplicateMatch!.artist, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              context.read<PlayerProvider>().playSong(_duplicateMatch!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('बजाया जा रहा है: ${_duplicateMatch!.title}')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('सुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else if (_titleCtrl.text.length >= 3) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 8),
                    Text('✅ नया गाना! यह हमारे डेटाबेस में पहले से नहीं है।', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 12),
            ],

            // Input Fields
            _buildTextField(
              controller: _titleCtrl,
              label: _lang.isHindi ? 'गाने का शीर्षक (Song Title)' : 'Song Title *',
              hint: _lang.isHindi ? 'उदा. राम सिया राम / Kesariya' : 'e.g. Ram Siya Ram / Kesariya',
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _artistCtrl,
              label: _lang.isHindi ? 'गायक / आर्टिस्ट (Artist)' : 'Artist / Singer *',
              hint: _lang.isHindi ? 'उदा. Sachet Tandon, Arijit Singh' : 'e.g. Sachet Tandon, Arijit Singh',
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _albumCtrl,
              label: _lang.isHindi ? 'एल्बम (Album - Optional)' : 'Album (Optional)',
              hint: _lang.isHindi ? 'उदा. Single / Soundtrack' : 'e.g. Single / Soundtrack',
            ),
            const SizedBox(height: 14),

            // Genre Dropdown
            Text(
              _lang.isHindi ? 'संगीत विधा (Genre / Category)' : 'Genre / Category',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGenre,
                  dropdownColor: const Color(0xFF131A2A),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
                  items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGenre = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Sub-Category Field
            _buildTextField(
              controller: _subCategoryCtrl,
              label: _lang.isHindi ? 'उप-श्रेणी (Sub-Category - Optional)' : 'Sub-Category (Optional)',
              hint: _lang.isHindi ? 'उदा. Marwadi Hits, Folk, 90s Hits' : 'e.g. Marwadi Hits, Folk, 90s Hits',
            ),
            const SizedBox(height: 14),

            _buildTextField(
              controller: _coverUrlCtrl,
              label: _lang.isHindi ? 'पोस्टर आर्ट लिंक (Cover Image URL - Optional)' : 'Cover Image URL (Optional)',
              hint: _lang.isHindi ? 'https://images.unsplash.com/... (खाली छोड़ने पर डिफ़ॉल्ट पोस्टर लगेगा)' : 'https://images.unsplash.com/... (Leave empty for default)',
            ),
            if (_isUploading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  backgroundColor: Colors.white10,
                  color: const Color(0xFF00E5FF),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _uploadStatusText ?? (_lang.isHindi ? 'अपलोड हो रहा है...' : 'Uploading track...'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: (_isUploading || _duplicateMatch != null) ? null : _submitSong,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _lang.isHindi ? 'एडमिन को सबमिट करें (Submit)' : 'Submit Song for Approval',
                          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFolderUploadView() {
    int dupCount = 0;
    for (final f in _folderPickedFiles) {
      final clean = f.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');
      if (_backend.checkDuplicateSong(title: clean, artist: _folderArtistCtrl.text.trim()) != null) {
        dupCount++;
      }
    }
    final readyCount = _folderPickedFiles.length - dupCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Picker Box
        GestureDetector(
          onTap: _isUploading ? null : _pickFolderAudioFiles,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _folderPickedFiles.isNotEmpty ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.12),
                width: _folderPickedFiles.isNotEmpty ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _folderPickedFiles.isNotEmpty ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _folderPickedFiles.isNotEmpty ? Icons.folder_copy_rounded : Icons.drive_folder_upload_rounded,
                    color: _folderPickedFiles.isNotEmpty ? const Color(0xFF00E5FF) : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _folderPickedFiles.isNotEmpty
                      ? '${_folderPickedFiles.length} ${_lang.isHindi ? "गाने चुने गए" : "Tracks Selected"}'
                      : (_lang.isHindi ? 'फ़ोल्डर या कई गाने चुनें (Select Audio Folder)' : 'Select Audio Folder / Multiple MP3s'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _folderPickedFiles.isNotEmpty ? Colors.white : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _folderPickedFiles.isNotEmpty
                      ? '$readyCount नए गाने तैयार • $dupCount डुप्लीकेट स्किप होंगे'
                      : (_lang.isHindi ? 'फ़ोल्डर के नाम से अपने आप प्लेलिस्ट बन जाएगी' : 'Folder name auto-creates playlist in your Library'),
                  style: TextStyle(
                    fontSize: 11,
                    color: _folderPickedFiles.isNotEmpty ? const Color(0xFF00E5FF) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        if (_folderPickedFiles.isNotEmpty) ...[
          // Auto Playlist creation option
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: _createPlaylistChecked,
                  onChanged: _isUploading ? null : (v) => setState(() => _createPlaylistChecked = v ?? true),
                  activeColor: const Color(0xFF00E5FF),
                  checkColor: Colors.black,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    _lang.isHindi ? '📁 इस फ़ोल्डर के नाम से प्लेलिस्ट बनाएं' : '📁 Auto-Create Playlist with Folder Name',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _lang.isHindi
                        ? 'आपकी लाइब्रेरी में इस फ़ोल्डर के सभी गानों की प्लेलिस्ट बन जाएगी'
                        : 'Saved to your Library playlists under your login account',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ),
                if (_createPlaylistChecked) ...[
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _folderPlaylistNameCtrl,
                    label: _lang.isHindi ? 'प्लेलिस्ट का नाम (फ़ोल्डर का नाम)' : 'Playlist Name (Folder Name)',
                    hint: 'My Playlist',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildTextField(
            controller: _folderArtistCtrl,
            label: _lang.isHindi ? 'डिफ़ॉल्ट आर्टिस्ट / गायक का नाम' : 'Default Artist / Singer',
            hint: 'Various Artists',
          ),
          const SizedBox(height: 14),

          // Genre Dropdown
          Text(
            _lang.isHindi ? 'संगीत विधा (Category / Genre)' : 'Category / Genre',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGenre,
                dropdownColor: const Color(0xFF131A2A),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: _isUploading ? null : (v) => setState(() => _selectedGenre = v!),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Picked Tracks Preview list
          Text(
            '${_folderPickedFiles.length} ${_lang.isHindi ? "गाने" : "Tracks"} ($readyCount ${_lang.isHindi ? "अपलोड होंगे" : "will upload"}):',
            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _folderPickedFiles.length,
              itemBuilder: (context, idx) {
                final f = _folderPickedFiles[idx];
                final clean = f.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');
                final isDup = _backend.checkDuplicateSong(title: clean, artist: _folderArtistCtrl.text.trim()) != null;
                final isDone = _isUploading && idx < _folderCurrentIndex;
                final isCurrent = _isUploading && idx == _folderCurrentIndex;
                final mb = (f.size / (1024 * 1024)).toStringAsFixed(1);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : (isCurrent
                                ? Icons.cloud_upload_rounded
                                : (isDup ? Icons.warning_amber_rounded : Icons.music_note_rounded)),
                        size: 14,
                        color: isDone
                            ? Colors.greenAccent
                            : (isCurrent
                                ? const Color(0xFF00E5FF)
                                : (isDup ? Colors.amberAccent : Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.name,
                          style: TextStyle(
                            color: isCurrent
                                ? const Color(0xFF00E5FF)
                                : (isDup ? Colors.amberAccent : Colors.white70),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          child: const Text('Duplicate', style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      Text('$mb MB', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Progress bar during bulk upload
        if (_isUploading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _uploadStatusText ?? 'अपलोड हो रहा है...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
        ],

        // Submit Button
        ElevatedButton(
          onPressed: (_isUploading || _folderPickedFiles.isEmpty) ? null : _submitFolderUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isUploading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.playlist_add_check_circle_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _lang.isHindi
                          ? 'सभी गाने अपलोड करें और प्लेलिस्ट बनाएं'
                          : 'Upload All & Create Playlist',
                      style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade300),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

