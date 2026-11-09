import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class StorageService {
  static const String _keyFavorites = 'musixa_favorites';
  static const String _keyRecent = 'musixa_recently_played';
  static const String _keyCustomPlaylists = 'musixa_user_playlists';
  static const String _keyEqPreset = 'musixa_eq_preset';
  static const String _keyEqGains = 'musixa_eq_gains';

  static String _cleanPhone(String? p) => p == null ? '' : p.replaceAll(RegExp(r'[^0-9]'), '');
  static String _favKey([String? phone]) => _cleanPhone(phone).isNotEmpty ? 'musixa_fav_${_cleanPhone(phone)}' : 'musixa_favorites';
  static String _recentKey([String? phone]) => _cleanPhone(phone).isNotEmpty ? 'musixa_rec_${_cleanPhone(phone)}' : 'musixa_recently_played';
  static String _plKey([String? phone]) => _cleanPhone(phone).isNotEmpty ? 'musixa_pl_${_cleanPhone(phone)}' : 'musixa_user_playlists';

  Future<List<Song>> loadFavorites([String? userPhone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? list;
      if (userPhone != null && userPhone.isNotEmpty) {
        list = prefs.getStringList(_favKey(userPhone));
      }
      list ??= prefs.getStringList(_keyFavorites) ?? [];
      return list.map((item) => Song.fromJson(json.decode(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFavorites(List<Song> songs, [String? userPhone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = songs.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_keyFavorites, list);
      if (userPhone != null && userPhone.isNotEmpty) {
        await prefs.setStringList(_favKey(userPhone), list);
      }
    } catch (_) {}
  }

  Future<List<Song>> loadRecentlyPlayed([String? userPhone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? list;
      if (userPhone != null && userPhone.isNotEmpty) {
        list = prefs.getStringList(_recentKey(userPhone));
      }
      list ??= prefs.getStringList(_keyRecent) ?? [];
      return list.map((item) => Song.fromJson(json.decode(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecentlyPlayed(List<Song> songs, [String? userPhone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = songs.take(30).map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_keyRecent, trimmed);
      if (userPhone != null && userPhone.isNotEmpty) {
        await prefs.setStringList(_recentKey(userPhone), trimmed);
      }
    } catch (_) {}
  }

  Future<List<Playlist>> loadCustomPlaylists([String? userPhone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? list;
      if (userPhone != null && userPhone.isNotEmpty) {
        list = prefs.getStringList(_plKey(userPhone));
      }
      list ??= prefs.getStringList(_keyCustomPlaylists) ?? [];
      return list.map((item) => Playlist.fromJson(json.decode(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomPlaylists(List<Playlist> playlists, [String? userPhone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = playlists.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList(_keyCustomPlaylists, list);
      if (userPhone != null && userPhone.isNotEmpty) {
        await prefs.setStringList(_plKey(userPhone), list);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> loadEqualizerSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetName = prefs.getString(_keyEqPreset) ?? 'Flat';
      final gainsStr = prefs.getStringList(_keyEqGains);
      List<double> gains = [0.0, 0.0, 0.0, 0.0, 0.0];
      if (gainsStr != null && gainsStr.length == 5) {
        gains = gainsStr.map((e) => double.tryParse(e) ?? 0.0).toList();
      }
      return {'preset': presetName, 'gains': gains};
    } catch (_) {
      return {'preset': 'Flat', 'gains': [0.0, 0.0, 0.0, 0.0, 0.0]};
    }
  }

  Future<void> saveEqualizerSettings(String presetName, List<double> gains) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEqPreset, presetName);
      await prefs.setStringList(_keyEqGains, gains.map((e) => e.toString()).toList());
    } catch (_) {}
  }
}
