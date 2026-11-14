import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/equalizer_preset.dart';
import '../services/audio_player_service.dart';
import '../services/catalog_service.dart';
import '../services/storage_service.dart';
import '../services/device_audio_service.dart';
import '../services/cloud_backend_service.dart';
import '../services/song_artwork_resolver.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();
  final CatalogService _catalogService = CatalogService();
  final StorageService _storageService = StorageService();
  final DeviceAudioService _deviceAudioService = DeviceAudioService();

  // State collections
  List<Song> _trendingSongs = [];
  List<Playlist> _curatedPlaylists = [];
  List<Song> _searchResults = [];
  List<Song> _favorites = [];
  List<Song> _recentlyPlayed = [];
  List<Playlist> _customPlaylists = [];
  List<Song> _deviceSongs = [];

  bool _isLoadingTrending = false;
  bool _isSearching = false;
  bool _isScanningDevice = false;
  bool _hasDevicePermission = false;
  String _selectedGenre = 'All';

  // Playback state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  // Sleep Timer & Cloud Sync
  Timer? _sleepTimer;
  Timer? _cloudSyncTimer;
  int _sleepMinutesRemaining = 0;

  // Equalizer
  EqualizerPreset _currentEqPreset = EqualizerPreset.defaultPresets.first;
  List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];

  // Getters
  Song? get currentSong => _audioService.currentSong;
  List<Song> get queue => _audioService.queue;
  int get currentIndex => _audioService.currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  Duration get bufferedPosition => _bufferedPosition;
  RepeatMode get repeatMode => _audioService.repeatMode;
  bool get isShuffle => _audioService.isShuffle;
  double get speed => _audioService.speed;
  double get volume => _audioService.volume;

  List<Song> get trendingSongs => _trendingSongs;
  List<Playlist> get curatedPlaylists => _curatedPlaylists;
  List<Song> get searchResults => _searchResults;
  List<Song> get favorites => _favorites;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  List<Playlist> get customPlaylists => _customPlaylists;
  List<Song> get deviceSongs => _deviceSongs;

  bool get isLoadingTrending => _isLoadingTrending;
  bool get isSearching => _isSearching;
  bool get isScanningDevice => _isScanningDevice;
  bool get hasDevicePermission => _hasDevicePermission;
  String get selectedGenre => _selectedGenre;
  int get sleepMinutesRemaining => _sleepMinutesRemaining;
  EqualizerPreset get currentEqPreset => _currentEqPreset;
  List<double> get bandGains => _bandGains;

  // Stream getters for targeted widget progress updates without full-screen rebuilds
  Stream<Duration> get positionStream => _audioService.positionStream;
  Stream<Duration?> get durationStream => _audioService.durationStream;
  Stream<Duration> get bufferedPositionStream => _audioService.bufferedPositionStream;

  PlayerProvider() {
    _init();
    // Realtime synchronization: listen to CloudBackendService so admin additions & deletions update user player immediately
    CloudBackendService().addListener(_onBackendCatalogUpdated);

    // Periodic cloud poll every 30 seconds so User app detects song updates without hammering battery/radio
    _cloudSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      CloudBackendService().syncSharedData();
    });
  }

  void _onBackendCatalogUpdated() {
    refreshCatalog();
  }

  void _init() async {
    // 1. Listen to audio playback events
    _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      notifyListeners();
    });

    _audioService.positionStream.listen((pos) {
      _currentPosition = pos;
      // Note: We deliberately do NOT call notifyListeners() on position ticks!
      // Position updates are consumed reactively via positionStream StreamBuilder
      // in MiniPlayer and NowPlayingScreen. This completely prevents full-screen rebuilds
      // and ensures 100% fluid, jank-free 60-120 FPS scrolling while music plays!
    });

    _audioService.durationStream.listen((dur) {
      if (dur != null) {
        _totalDuration = dur;
        notifyListeners();
      }
    });

    _audioService.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });

    _audioService.currentIndexStream.listen((index) {
      notifyListeners();
    });

    // 2. Load cached persistence (scoped to current user's phone if signed in)
    final currentUserPhone = CloudBackendService().currentUser?.phoneNumber;
    _favorites = await _storageService.loadFavorites(currentUserPhone);
    _recentlyPlayed = await _storageService.loadRecentlyPlayed(currentUserPhone);
    _customPlaylists = await _storageService.loadCustomPlaylists(currentUserPhone);
    final eqData = await _storageService.loadEqualizerSettings();
    final presetName = eqData['preset'] as String;
    _currentEqPreset = EqualizerPreset.defaultPresets.firstWhere(
      (p) => p.name == presetName,
      orElse: () => EqualizerPreset.defaultPresets.first,
    );
    _bandGains = List<double>.from(eqData['gains']);

    // 3. Check device storage permission and scan if already granted
    _hasDevicePermission = await _deviceAudioService.hasPermission();
    if (_hasDevicePermission) {
      _deviceSongs = await _deviceAudioService.scanDeviceSongs();
      _syncFavoritesFlag(_deviceSongs);
    }

    // 4. Load online catalog
    await refreshCatalog();
  }

  /// Scan local songs from device storage folders
  Future<void> scanDeviceSongs() async {
    _isScanningDevice = true;
    notifyListeners();

    _deviceSongs = await _deviceAudioService.scanDeviceSongs();
    _hasDevicePermission = await _deviceAudioService.hasPermission();
    _syncFavoritesFlag(_deviceSongs);

    _isScanningDevice = false;
    notifyListeners();
  }

  Future<void> refreshCatalog() async {
    _isLoadingTrending = true;
    notifyListeners();

    final backend = CloudBackendService();
    final deleted = backend.deletedSongIds;

    _trendingSongs = await _catalogService.fetchTrendingTracks();
    _curatedPlaylists = _catalogService.getCuratedPlaylists(songs: _trendingSongs);

    // If currently playing song was deleted by admin, immediately stop playback!
    if (_audioService.currentSong != null && deleted.contains(_audioService.currentSong!.id)) {
      await _audioService.stop();
    }

    // Purge deleted songs from favorites and recent history
    _favorites.removeWhere((s) => deleted.contains(s.id));
    _recentlyPlayed.removeWhere((s) => deleted.contains(s.id));

    // Also purge deleted songs from custom playlists
    for (final pl in _customPlaylists) {
      pl.songs.removeWhere((s) => deleted.contains(s.id));
    }

    _syncFavoritesFlag(_trendingSongs);
    _isLoadingTrending = false;
    notifyListeners();
  }

  void _syncFavoritesFlag(List<Song> songs) {
    final favIds = _favorites.map((f) => f.id).toSet();
    for (var song in songs) {
      song.isFavorite = favIds.contains(song.id);
    }
  }

  // Playback Controls
  Future<void> playSong(Song song, {List<Song>? queueContext}) async {
    if (queueContext != null) {
      final index = queueContext.indexWhere((s) => s.id == song.id);
      await _audioService.setQueue(queueContext, initialIndex: index != -1 ? index : 0);
    } else {
      await _audioService.playSong(song);
    }

    _addToRecentlyPlayed(song);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    await _audioService.seek(pos);
  }

  Future<void> next() async {
    await _audioService.next();
    if (currentSong != null) {
      _addToRecentlyPlayed(currentSong!);
    }
    notifyListeners();
  }

  Future<void> previous() async {
    await _audioService.previous();
    if (currentSong != null) {
      _addToRecentlyPlayed(currentSong!);
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _audioService.toggleRepeatMode();
    notifyListeners();
  }

  void toggleShuffle() {
    _audioService.toggleShuffle();
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    await _audioService.setVolume(vol);
    notifyListeners();
  }

  /// Reload user-specific data (favorites, playlists, history) upon login / account recovery
  Future<void> reloadUserData([String? userPhone]) async {
    final phone = userPhone ?? CloudBackendService().currentUser?.phoneNumber;
    _favorites = await _storageService.loadFavorites(phone);
    _recentlyPlayed = await _storageService.loadRecentlyPlayed(phone);
    _customPlaylists = await _storageService.loadCustomPlaylists(phone);
    _syncFavoritesFlag(_trendingSongs);
    _syncFavoritesFlag(_deviceSongs);
    notifyListeners();
  }

  // Favorite Management
  void toggleFavorite(Song song) {
    final index = _favorites.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      _favorites.removeAt(index);
      song.isFavorite = false;
    } else {
      song.isFavorite = true;
      _favorites.insert(0, song);
    }
    _storageService.saveFavorites(
      _favorites,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  bool isFavorite(String songId) {
    return _favorites.any((s) => s.id == songId);
  }

  void _addToRecentlyPlayed(Song song) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    _storageService.saveRecentlyPlayed(
      _recentlyPlayed,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  // User Custom Playlists Management
  void createPlaylist(String title, [List<Song>? initialSongs]) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    // Prevent duplicate playlist names: if already exists, append new songs to it
    final existingIdx = _customPlaylists.indexWhere(
      (p) => p.title.trim().toLowerCase() == cleanTitle.toLowerCase(),
    );

    if (existingIdx != -1) {
      if (initialSongs != null && initialSongs.isNotEmpty) {
        final existing = _customPlaylists[existingIdx];
        final existingIds = existing.songs.map((s) => s.id).toSet();
        final newSongs = initialSongs.where((s) => !existingIds.contains(s.id)).toList();
        if (newSongs.isNotEmpty) {
          final updatedSongs = [...existing.songs, ...newSongs];
          _customPlaylists[existingIdx] = existing.copyWith(
            songs: updatedSongs,
            coverUrl: existing.coverUrl.isNotEmpty ? existing.coverUrl : newSongs.first.displayCoverUrl,
          );
          _storageService.saveCustomPlaylists(
            _customPlaylists,
            CloudBackendService().currentUser?.phoneNumber,
          );
          notifyListeners();
        }
      }
      return;
    }

    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: cleanTitle,
      description: 'Created by you',
      coverUrl: initialSongs?.isNotEmpty == true
          ? initialSongs!.first.displayCoverUrl
          : SongArtworkResolver.resolveArtwork(title: cleanTitle, artist: 'Playlist'),
      songs: initialSongs ?? [],
    );
    _customPlaylists.insert(0, newPlaylist);
    _storageService.saveCustomPlaylists(
      _customPlaylists,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final index = _customPlaylists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final pl = _customPlaylists[index];
      if (!pl.songs.any((s) => s.id == song.id)) {
        final updatedSongs = List<Song>.from(pl.songs)..add(song);
        _customPlaylists[index] = Playlist(
          id: pl.id,
          title: pl.title,
          description: pl.description,
          coverUrl: pl.coverUrl.isNotEmpty ? pl.coverUrl : song.coverUrl,
          songs: updatedSongs,
        );
        _storageService.saveCustomPlaylists(
          _customPlaylists,
          CloudBackendService().currentUser?.phoneNumber,
        );
        notifyListeners();
      }
    }
  }

  void removePlaylist(String playlistId) {
    _customPlaylists.removeWhere((p) => p.id == playlistId);
    _storageService.saveCustomPlaylists(
      _customPlaylists,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final index = _customPlaylists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final pl = _customPlaylists[index];
      final updatedSongs = pl.songs.where((s) => s.id != songId).toList();
      _customPlaylists[index] = Playlist(
        id: pl.id,
        title: pl.title,
        description: pl.description,
        coverUrl: updatedSongs.isNotEmpty ? updatedSongs.first.coverUrl : pl.coverUrl,
        songs: updatedSongs,
      );
      _storageService.saveCustomPlaylists(
        _customPlaylists,
        CloudBackendService().currentUser?.phoneNumber,
      );
      notifyListeners();
    }
  }

  // Search & Filtering
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final catalogResults = await _catalogService.searchTracks(query);
    final lower = query.toLowerCase().trim();
    final deviceResults = _deviceSongs.where((s) =>
        s.title.toLowerCase().contains(lower) ||
        s.artist.toLowerCase().contains(lower) ||
        s.album.toLowerCase().contains(lower)).toList();

    _searchResults = [...catalogResults, ...deviceResults];
    _syncFavoritesFlag(_searchResults);
    _isSearching = false;
    notifyListeners();
  }

  Future<void> selectGenre(String genre) async {
    _selectedGenre = genre;
    _isLoadingTrending = true;
    notifyListeners();

    if (genre == 'All') {
      _trendingSongs = await _catalogService.fetchTrendingTracks();
    } else {
      _trendingSongs = await _catalogService.fetchTracksByGenre(genre);
    }
    _syncFavoritesFlag(_trendingSongs);
    _isLoadingTrending = false;
    notifyListeners();
  }

  // Sleep Timer
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      _sleepMinutesRemaining = 0;
      notifyListeners();
      return;
    }

    _sleepMinutesRemaining = minutes;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_sleepMinutesRemaining > 1) {
        _sleepMinutesRemaining--;
        notifyListeners();
      } else {
        _sleepMinutesRemaining = 0;
        _audioService.pause();
        timer.cancel();
        notifyListeners();
      }
    });
  }

  // Equalizer
  void setEqPreset(EqualizerPreset preset) {
    _currentEqPreset = preset;
    _bandGains = List<double>.from(preset.bandGains);
    _storageService.saveEqualizerSettings(preset.name, _bandGains);
    notifyListeners();
  }

  void updateBandGain(int index, double gain) {
    if (index >= 0 && index < _bandGains.length) {
      _bandGains[index] = gain;
      _currentEqPreset = const EqualizerPreset(name: 'Custom', bandGains: []);
      _storageService.saveEqualizerSettings('Custom', _bandGains);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cloudSyncTimer?.cancel();
    _sleepTimer?.cancel();
    CloudBackendService().removeListener(_onBackendCatalogUpdated);
    _audioService.dispose();
    super.dispose();
  }
}
