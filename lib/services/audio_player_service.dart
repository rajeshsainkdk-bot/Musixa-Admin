import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';

enum RepeatMode { off, all, one }

class AudioPlayerService {
  // Singleton pattern to guarantee only ONE AudioPlayer instance across the entire app
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal() {
    _initListener();
  }

  final AudioPlayer _player = AudioPlayer();

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _isShuffle = false;
  List<int> _shuffleIndices = [];

  // Concurrency token to cancel previous loading operations and prevent two songs playing at once
  int _sessionToken = 0;

  // Expose streams
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Song? get currentSong => _currentSong;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  RepeatMode get repeatMode => _repeatMode;
  bool get isShuffle => _isShuffle;
  double get speed => _player.speed;
  double get volume => _player.volume;

  void _initListener() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
    });

    // Synchronize UI when user changes song via system notification bar next/prev buttons
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queue.length) {
        _currentIndex = index;
        _currentSong = _queue[index];
      }
    });
  }

  void _handlePlaybackCompleted() {
    if (_repeatMode == RepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      next();
    }
  }

  AudioSource _createAudioSource(Song song) {
    final mediaItem = MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      artUri: song.displayCoverUrl.startsWith('http') ? Uri.parse(song.displayCoverUrl) : null,
    );

    // 1. Asset audio bundled in APK
    if (song.streamUrl.startsWith('assets/')) {
      return AudioSource.asset(song.streamUrl, tag: mediaItem);
    }
    // 2. Online streaming URL
    if (song.streamUrl.startsWith('http://') || song.streamUrl.startsWith('https://')) {
      return AudioSource.uri(Uri.parse(song.streamUrl), tag: mediaItem);
    }
    // 3. Android Content Provider (Device storage)
    if (song.streamUrl.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(song.streamUrl), tag: mediaItem);
    }
    // 4. File Path (Device storage file)
    if (song.streamUrl.startsWith('file://')) {
      return AudioSource.uri(Uri.parse(song.streamUrl), tag: mediaItem);
    }
    return AudioSource.file(song.streamUrl, tag: mediaItem);
  }

  Future<void> setQueue(List<Song> songs, {int initialIndex = 0}) async {
    final currentToken = ++_sessionToken;

    _queue = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _queue.isNotEmpty ? _queue.length - 1 : 0);
    if (_isShuffle) {
      _generateShuffleIndices();
    }

    if (_queue.isNotEmpty) {
      _currentSong = _queue[_currentIndex];
      try {
        // ALWAYS stop previous playback completely before loading new audio
        await _player.stop();
        if (currentToken != _sessionToken) return;

        final playlist = ConcatenatingAudioSource(
          useLazyPreparation: true,
          children: _queue.map((s) => _createAudioSource(s)).toList(),
        );

        await _player.setAudioSource(playlist, initialIndex: _currentIndex);
        if (currentToken != _sessionToken) return;

        await _player.play();
      } catch (_) {
        if (currentToken == _sessionToken) {
          await playSong(_queue[_currentIndex]);
        }
      }
    }
  }

  Future<void> playSong(Song song) async {
    final currentToken = ++_sessionToken;

    try {
      _currentSong = song;

      final idx = _queue.indexWhere((s) => s.id == song.id);
      if (idx != -1) {
        _currentIndex = idx;
      } else {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      }

      // Stop previous playback completely to ensure strictly ONE song plays
      await _player.stop();
      if (currentToken != _sessionToken) return;

      final source = _createAudioSource(song);
      await _player.setAudioSource(source);
      if (currentToken != _sessionToken) return;

      await _player.play();
    } catch (_) {}
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_currentSong != null) {
        await _player.play();
      } else if (_queue.isNotEmpty) {
        await playSong(_queue.first);
      }
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSong = null;
    _queue = [];
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      return;
    }

    if (_queue.isEmpty) return;

    if (_isShuffle && _shuffleIndices.isNotEmpty) {
      final currentPosInShuffle = _shuffleIndices.indexOf(_currentIndex);
      if (currentPosInShuffle < _shuffleIndices.length - 1) {
        _currentIndex = _shuffleIndices[currentPosInShuffle + 1];
        await playSong(_queue[_currentIndex]);
      } else if (_repeatMode == RepeatMode.all) {
        _currentIndex = _shuffleIndices.first;
        await playSong(_queue[_currentIndex]);
      }
      return;
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await playSong(_queue[_currentIndex]);
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
      await playSong(_queue[_currentIndex]);
    }
  }

  Future<void> previous() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      return;
    }

    if (_queue.isEmpty) return;

    if (_isShuffle && _shuffleIndices.isNotEmpty) {
      final currentPosInShuffle = _shuffleIndices.indexOf(_currentIndex);
      if (currentPosInShuffle > 0) {
        _currentIndex = _shuffleIndices[currentPosInShuffle - 1];
        await playSong(_queue[_currentIndex]);
      }
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      await playSong(_queue[_currentIndex]);
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = _queue.length - 1;
      await playSong(_queue[_currentIndex]);
    }
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        _player.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        _player.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _player.setShuffleModeEnabled(_isShuffle);
    if (_isShuffle) {
      _generateShuffleIndices();
    }
  }

  void _generateShuffleIndices() {
    _shuffleIndices = List.generate(_queue.length, (i) => i)..shuffle();
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  Future<void> setVolume(double vol) async {
    await _player.setVolume(vol.clamp(0.0, 1.0));
  }

  void dispose() {
    _player.dispose();
  }
}
