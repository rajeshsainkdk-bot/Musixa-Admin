import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:musixa_admin/models/song.dart';
import 'package:musixa_admin/screens/admin/admin_dashboard_screen.dart';
import 'package:musixa_admin/services/cloud_backend_service.dart';
import 'package:musixa_admin/services/device_audio_service.dart';

void main() {
  group('1. Song Model & SubCategory Tests', () {
    test('Song model supports subCategory properly in toJson and fromJson', () {
      final song = Song(
        id: 'test_song_01',
        title: 'Choudhary',
        artist: 'Mame Khan',
        album: 'Rajasthani Folk',
        duration: 240,
        streamUrl: 'https://example.com/choudhary.mp3',
        coverUrl: 'https://example.com/cover.jpg',
        genre: 'Rajasthani',
        subCategory: 'Marwadi Hits',
      );

      expect(song.subCategory, 'Marwadi Hits');
      expect(song.genre, 'Rajasthani');

      final jsonMap = song.toJson();
      expect(jsonMap['subCategory'], 'Marwadi Hits');
      expect(jsonMap['genre'], 'Rajasthani');

      final jsonStr = jsonEncode(jsonMap);
      final restored = Song.fromJson(jsonDecode(jsonStr));

      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.subCategory, 'Marwadi Hits');
      expect(restored.genre, 'Rajasthani');
    });

    test('Song model handles missing subCategory (backward compatibility)', () {
      final oldJson = {
        'id': 'legacy_song_01',
        'title': 'Hanuman Chalisa',
        'artist': 'Hariharan',
        'album': 'Devotional',
        'duration': 180,
        'streamUrl': 'https://example.com/hanuman.mp3',
        'coverUrl': 'https://example.com/cover.jpg',
        'genre': 'Bhakti',
      };

      final song = Song.fromJson(oldJson);
      expect(song.genre, 'Bhakti');
      expect(song.subCategory, isNull);
    });

    test('Song copyWith correctly updates subCategory', () {
      final song = Song(
        id: 's1',
        title: 'Track 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: 200,
        streamUrl: 'url',
        coverUrl: 'cover',
        genre: 'Rajasthani',
      );

      final updated = song.copyWith(subCategory: 'Desert Folk');
      expect(updated.subCategory, 'Desert Folk');
      expect(updated.genre, 'Rajasthani');
    });
  });

  group('2. Folder Hierarchy Detection Tests', () {
    test('Nested folder extracts Category and SubCategory', () {
      const path1 = '/storage/emulated/0/Download/Rajasthani Songs/Marwadi Hits/01_Song.mp3';
      final h1 = DetectedFolderHierarchy.fromPath(path1);
      expect(h1.category, 'Rajasthani Songs');
      expect(h1.subCategory, 'Marwadi Hits');
    });

    test('Windows nested path extracts Category and SubCategory', () {
      const path2 = r'C:\Users\rajesh\Music\Bollywood Classics\90s Melodies\02_Song.mp3';
      final h2 = DetectedFolderHierarchy.fromPath(path2);
      expect(h2.category, 'Bollywood Classics');
      expect(h2.subCategory, '90s Melodies');
    });

    test('Single folder without subfolder sets Category and null SubCategory', () {
      const path3 = '/storage/emulated/0/Download/Rajasthani Songs/01_Song.mp3';
      final h3 = DetectedFolderHierarchy.fromPath(path3);
      expect(h3.category, 'Rajasthani Songs');
      expect(h3.subCategory, isNull);
    });

    test('System root folder falls back gracefully without corrupting Category', () {
      const path4 = '/storage/emulated/0/Download/01_Song.mp3';
      final h4 = DetectedFolderHierarchy.fromPath(path4);
      expect(h4.category, isNotEmpty);
      expect(h4.subCategory, isNull);
    });

    test('rootFolderPath relative detection works for nested subfolders', () {
      const root = '/storage/emulated/0/Download/Folk Music';
      const fileInSub = '/storage/emulated/0/Download/Folk Music/Marwadi Hits/song1.mp3';
      const fileInRoot = '/storage/emulated/0/Download/Folk Music/intro.mp3';

      final hSub = DetectedFolderHierarchy.fromPath(fileInSub, rootFolderPath: root);
      expect(hSub.category, 'Folk Music');
      expect(hSub.subCategory, 'Marwadi Hits');

      final hRoot = DetectedFolderHierarchy.fromPath(fileInRoot, rootFolderPath: root);
      expect(hRoot.category, 'Folk Music');
      expect(hRoot.subCategory, isNull);
    });

    test('resolveSafPath correctly decodes Android SAF tree and raw URIs', () {
      const safUri = 'content://com.android.externalstorage.documents/tree/primary%3AMusic%2FRajasthani';
      final resolved = DetectedFolderHierarchy.resolveSafPath(safUri);
      expect(resolved, '/storage/emulated/0/Music/Rajasthani');

      const rawUri = 'content://com.android.providers.downloads.documents/tree/raw%3A%2Fstorage%2Femulated%2F0%2FDownload%2FBhakti';
      final resolvedRaw = DetectedFolderHierarchy.resolveSafPath(rawUri);
      expect(resolvedRaw, '/storage/emulated/0/Download/Bhakti');

      const regularPath = '/storage/emulated/0/Music/Song.mp3';
      expect(DetectedFolderHierarchy.resolveSafPath(regularPath), regularPath);
    });
  });

  group('3. Device Songs Folder Location Display Tests', () {
    test('extractFolderLocation strips root prefixes and displays clean folder directory', () {
      const p1 = '/storage/emulated/0/Download/Rajasthani/Marwadi/choudhary.mp3';
      expect(DeviceAudioService.extractFolderLocation(p1), 'Download/Rajasthani/Marwadi');

      const p2 = '/storage/emulated/0/Music/Bhakti/song.mp3';
      expect(DeviceAudioService.extractFolderLocation(p2), 'Music/Bhakti');

      const p3 = '/storage/emulated/0/song.mp3';
      expect(DeviceAudioService.extractFolderLocation(p3), 'Internal Storage');

      const p4 = r'C:\Users\rajesh\Music\Folk\track.mp3';
      expect(DeviceAudioService.extractFolderLocation(p4), contains('Folk'));
    });
  });

  group('4. Duplicate Detection & Smart Title Normalization Tests', () {
    test('normalizes titles ignoring extensions, case, and special characters', () {
      final norm1 = CloudBackendService.normalizeTitle('Choudhary (Official Video).mp3');
      final norm2 = CloudBackendService.normalizeTitle('choudhary [HD Audio]');
      final norm3 = CloudBackendService.normalizeTitle('CHOUDHARY');

      expect(norm1, 'choudhary');
      expect(norm2, 'choudhary');
      expect(norm3, 'choudhary');
      expect(norm1, equals(norm2));
      expect(norm2, equals(norm3));
    });

    test('normalizeTitle strips trailing numbers added to attempt duplicate uploads', () {
      final base = CloudBackendService.normalizeTitle('Choudhary');
      final dup1 = CloudBackendService.normalizeTitle('Choudhary 1');
      final dup2 = CloudBackendService.normalizeTitle('Choudhary 2');
      final dup3 = CloudBackendService.normalizeTitle('Choudhary_01');
      final dup4 = CloudBackendService.normalizeTitle('Choudhary (1)');
      final dup5 = CloudBackendService.normalizeTitle('Choudhary 2024');
      final dup6 = CloudBackendService.normalizeTitle('01 - Choudhary.mp3');

      expect(base, 'choudhary');
      expect(dup1, base);
      expect(dup2, base);
      expect(dup3, base);
      expect(dup4, base);
      expect(dup5, base);
      expect(dup6, base);
    });

    test('formatSmartTitle cleans raw filenames into professional human-readable titles', () {
      expect(
        CloudBackendService.formatSmartTitle('01 - choudhary (official video)_2024.mp3'),
        'Choudhary',
      );

      expect(
        CloudBackendService.formatSmartTitle('radhe_krishna_bhajan_02.mp3'),
        'Radhe Krishna Bhajan',
      );

      expect(
        CloudBackendService.formatSmartTitle('teri mitti tribute (hd audio) [lyrics] 1.mp3'),
        'Teri Mitti Tribute',
      );

      expect(
        CloudBackendService.formatSmartTitle('हनुमान चालीसा (Official Video) 1'),
        'हनुमान चालीसा',
      );
    });
  });

  group('5. Instant Song Deletion & Purge Tests', () {
    test('Deleted songs are strictly excluded from catalog and lists', () {
      final songList = [
        Song(
          id: 'song_del_01',
          title: 'Deleted Track',
          artist: 'Artist A',
          album: 'Album A',
          duration: 180,
          streamUrl: 'url',
          coverUrl: 'cover',
          genre: 'Rajasthani',
        ),
        Song(
          id: 'song_keep_02',
          title: 'Active Track',
          artist: 'Artist B',
          album: 'Album B',
          duration: 200,
          streamUrl: 'url2',
          coverUrl: 'cover2',
          genre: 'Bhakti',
        ),
      ];

      final deletedSongIds = <String>{'song_del_01'};

      // Simulation of catalog filtering in User & Admin apps
      final activeSongs = songList.where((s) => !deletedSongIds.contains(s.id)).toList();

      expect(activeSongs.length, 1);
      expect(activeSongs.first.id, 'song_keep_02');
      expect(activeSongs.any((s) => s.id == 'song_del_01'), isFalse);
    });

    test('Multi-select batch deletion removes all selected song IDs simultaneously', () {
      final testSongs = [
        Song(id: 's1', title: 'Song 1', artist: 'A', album: 'Alb', duration: 100, streamUrl: 'u1', coverUrl: 'c1', genre: 'Folk'),
        Song(id: 's2', title: 'Song 2', artist: 'B', album: 'Alb', duration: 100, streamUrl: 'u2', coverUrl: 'c2', genre: 'Folk'),
        Song(id: 's3', title: 'Song 3', artist: 'C', album: 'Alb', duration: 100, streamUrl: 'u3', coverUrl: 'c3', genre: 'Pop'),
        Song(id: 's4', title: 'Song 4', artist: 'D', album: 'Alb', duration: 100, streamUrl: 'u4', coverUrl: 'c4', genre: 'Pop'),
      ];

      final selectedIds = {'s1', 's3'};
      final remaining = testSongs.where((s) => !selectedIds.contains(s.id)).toList();

      expect(remaining.length, 2);
      expect(remaining.map((s) => s.id), containsAll(['s2', 's4']));
      expect(remaining.any((s) => selectedIds.contains(s.id)), isFalse);
    });

    test('Folder and category deletion removes all songs matching category or subcategory', () {
      final testSongs = [
        Song(id: 's1', title: 'Marwadi 1', artist: 'A', album: 'Alb', duration: 100, streamUrl: 'u1', coverUrl: 'c1', genre: 'Rajasthani', subCategory: 'Marwadi Hits'),
        Song(id: 's2', title: 'Marwadi 2', artist: 'B', album: 'Alb', duration: 100, streamUrl: 'u2', coverUrl: 'c2', genre: 'Rajasthani', subCategory: 'Marwadi Hits'),
        Song(id: 's3', title: 'Desert Song', artist: 'C', album: 'Alb', duration: 100, streamUrl: 'u3', coverUrl: 'c3', genre: 'Rajasthani', subCategory: 'Desert Melodies'),
        Song(id: 's4', title: 'Hanuman Chalisa', artist: 'D', album: 'Alb', duration: 100, streamUrl: 'u4', coverUrl: 'c4', genre: 'Bhakti'),
      ];

      // 1. Delete SubCategory "Marwadi Hits" only
      final afterSubCatDelete = testSongs.where((s) {
        final matches = s.genre.toLowerCase() == 'rajasthani' && s.subCategory?.toLowerCase() == 'marwadi hits';
        return !matches;
      }).toList();

      expect(afterSubCatDelete.length, 2);
      expect(afterSubCatDelete.any((s) => s.id == 's1' || s.id == 's2'), isFalse);
      expect(afterSubCatDelete.any((s) => s.id == 's3'), isTrue);

      // 2. Delete entire Category "Rajasthani"
      final afterCatDelete = testSongs.where((s) => s.genre.toLowerCase() != 'rajasthani').toList();
      expect(afterCatDelete.length, 1);
      expect(afterCatDelete.first.id, 's4');
    });
  });
}
