import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/playlist.dart';
import 'cloud_backend_service.dart';

class CatalogService {
  static const String _jamendoClientId = '56d30c95';
  static const String _jamendoBaseUrl = 'https://api.jamendo.com/v3.0';
  /// Returns the built-in curated catalog of songs
  static List<Song> getCuratedSongs() => _curatedCatalog;

  /// Musixa catalog is loaded dynamically from Musixa Cloudflare R2 bucket (musixa-music)
  static final List<Song> _curatedCatalog = [];

  /// Fetch initial trending tracks (dynamically combines curated and approved community tracks, strictly filtering deleted tracks)
  Future<List<Song>> fetchTrendingTracks() async {
    final backend = CloudBackendService();
    final deleted = backend.deletedSongIds;
    final approved = backend.approvedSongs;

    final Map<String, Song> map = {};
    for (final s in approved) {
      if (!deleted.contains(s.id)) {
        map[s.id] = s;
      }
    }
    for (final s in _curatedCatalog) {
      if (!deleted.contains(s.id) && !map.containsKey(s.id)) {
        map[s.id] = s;
      }
    }
    return map.values.toList();
  }

  /// Filter tracks by selected genre
  Future<List<Song>> fetchTracksByGenre(String genre) async {
    final all = await fetchTrendingTracks();
    final lower = genre.toLowerCase().trim();
    if (lower == 'all' || lower == 'all indian') {
      return all;
    }
    return all.where((s) => s.genre.toLowerCase() == lower).toList();
  }

  /// Get categorized curated playlists
  List<Playlist> getCuratedPlaylists({List<Song>? songs}) {
    final backend = CloudBackendService();
    final deleted = backend.deletedSongIds;
    final baseSongs = songs ?? (backend.approvedSongs.isNotEmpty
        ? backend.approvedSongs.where((s) => !deleted.contains(s.id)).toList()
        : _curatedCatalog.where((s) => !deleted.contains(s.id)).toList());

    final rajasthaniSongs = baseSongs.where((s) => s.genre == 'Rajasthani').toList();
    final bhaktiSongs = baseSongs.where((s) => s.genre == 'Bhakti' || s.genre == 'Spiritual').toList();
    final haryanviSongs = baseSongs.where((s) => s.genre == 'Haryanvi').toList();
    final sufiSongs = baseSongs.where((s) => s.genre == 'Sufi' || s.genre == 'Punjabi').toList();
    final bollywoodSongs = baseSongs.where((s) => s.genre == 'Bollywood' || s.genre == 'Indie Pop').toList();
    final lofiSongs = baseSongs.where((s) => s.genre == 'Desi Lo-Fi' || s.genre == 'Ghazal').toList();
    final spiritualSongs = baseSongs.where((s) => s.genre == 'Spiritual').toList();

    final List<Playlist> playlists = [];

    if (rajasthaniSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_rajasthani',
        title: '🐪 Rangeelo Rajasthan & Marwadi',
        description: 'Rajasthani Folk, Marwadi DJ, Bhajan & Traditional Beats',
        coverUrl: 'https://images.unsplash.com/photo-1599827552599-eeddd59551c6?w=600&q=80',
        songs: rajasthaniSongs,
      ));
    }

    if (bhaktiSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_bhakti',
        title: '🕉️ Divine Bhakti & Mantras',
        description: 'Hanuman Chalisa, Ashtak, Ram Siya Ram, Radhe Krishna & Shabar Mantras',
        coverUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
        songs: bhaktiSongs,
      ));
    }

    if (haryanviSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_haryanvi',
        title: '🌾 Haryanvi & Desi Ragni',
        description: 'Top Haryanvi Hits, Folk & High-Energy Desi Beats',
        coverUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
        songs: haryanviSongs,
      ));
    }

    if (sufiSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_sartaaj',
        title: '🪕 Sufi & Punjabi Classics (Satinder Sartaaj)',
        description: 'Guzarish, Udaarian, Sajjan Raazi, Tere Bina Na Guzara & Hit Jukebox',
        coverUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
        songs: sufiSongs,
      ));
    }

    if (bollywoodSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_bollywood',
        title: '🎬 Bollywood & Indie Melodies',
        description: 'Ram Siya Ram, Jaiye Sajana, Intezaar Reh Gya & Kagaz Ki Kashti',
        coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
        songs: bollywoodSongs,
      ));
    }

    if (lofiSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_lofi',
        title: '🌙 Late Night Desi Lo-Fi & Ghazals',
        description: 'Bajrang Baan Lo-Fi, Kagaz Ki Kashti, Intezaar Reh Gya & Soulful Beats',
        coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
        songs: lofiSongs,
      ));
    }

    if (spiritualSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_spiritual',
        title: '🔱 Aghori & Spiritual Trance',
        description: 'Alakh Niranjan Aghori, Aadesh Hanuman & Powerful Siddh Shabar Mantra',
        coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
        songs: spiritualSongs,
      ));
    }

    return playlists;
  }

  /// Search online/curated catalog with live search
  Future<List<Song>> searchTracks(String query) async {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return [];

    final all = await fetchTrendingTracks();
    return all.where((s) =>
        s.title.toLowerCase().contains(lower) ||
        s.artist.toLowerCase().contains(lower) ||
        s.album.toLowerCase().contains(lower) ||
        s.genre.toLowerCase().contains(lower)).toList();
  }
}
