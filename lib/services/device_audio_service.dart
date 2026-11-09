import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';

class DeviceAudioService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Requests storage and media audio permissions from the user
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (SDK 33+), request audio permission
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;

      final audioReq = await Permission.audio.request();
      if (audioReq.isGranted) return true;

      // For Android 12 and below, fallback to storage permission
      final storageReq = await Permission.storage.request();
      return storageReq.isGranted;
    }
    return true;
  }

  /// Extracts the readable folder directory path where a song is stored on device
  static String extractFolderLocation(String fullPath) {
    if (fullPath.isEmpty) return 'Phone Storage';
    final clean = fullPath.replaceAll(r'\', '/');
    final lastSlash = clean.lastIndexOf('/');
    if (lastSlash == -1) return 'Phone Storage';
    final dirPath = clean.substring(0, lastSlash);

    // Strip common storage root prefixes like /storage/emulated/0/
    final rel = dirPath
        .replaceFirst(RegExp(r'^/storage/emulated/[0-9]+/?'), '')
        .replaceFirst(RegExp(r'^/storage/[^/]+/?'), '')
        .replaceFirst(RegExp(r'^[A-Za-z]:/[^/]+/[^/]+/?'), '');

    if (rel.trim().isEmpty) return 'Internal Storage';
    return rel.trim();
  }

  /// Checks if permission is already granted
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;

      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted;
    }
    return true;
  }

  /// Scans all local MP3 and audio files from device storage folders
  Future<List<Song>> scanDeviceSongs() async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) return [];
      }

      final songModels = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter out files shorter than 60 seconds (1 minute) to eliminate recordings, ringtones, and voice notes
      return songModels.where((s) {
        final durationMs = s.duration ?? 0;
        if (durationMs < 60000) return false; // Minimum 1 minute requirement

        final title = (s.title).toLowerCase();
        final data = (s.data).toLowerCase();

        // Filter out recording and voice note folders/files
        if (title.startsWith('audiorecord') ||
            title.startsWith('rec_') ||
            title.startsWith('voice_') ||
            title.startsWith('call_') ||
            title.startsWith('recording_') ||
            data.contains('/whatsapp/media/whatsapp voice notes/') ||
            data.contains('/whatsapp/media/whatsapp audio/') ||
            data.contains('/recordings/') ||
            data.contains('/callrecordings/') ||
            data.contains('/sound_recorder/')) {
          return false;
        }
        return true;
      }).map((s) {
        final folderLoc = extractFolderLocation(s.data);
        final artistDisplay = (s.artist != null && s.artist != '<unknown>' && s.artist!.trim().isNotEmpty && s.artist != 'Device Music')
            ? '${s.artist!} • 📁 $folderLoc'
            : '📁 $folderLoc';

        return Song(
          id: 'device_${s.id}',
          title: s.title.isNotEmpty ? s.title : 'Unknown Track',
          artist: artistDisplay,
          album: (s.album != null && s.album != '<unknown>') ? s.album! : folderLoc,
          duration: (s.duration ?? 0) ~/ 1000,
          streamUrl: s.uri ?? s.data,
          coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
          genre: 'Offline',
          subCategory: folderLoc,
          license: 'Personal Offline Audio',
          licenseUrl: 'local',
          source: 'Phone Storage ($folderLoc)',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

