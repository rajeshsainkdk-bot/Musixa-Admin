import '../models/song.dart';
import 'song_artwork_resolver.dart';

class AiArtworkService {
  static final AiArtworkService _instance = AiArtworkService._internal();
  factory AiArtworkService() => _instance;
  AiArtworkService._internal();

  /// Suggests a professional AI curated cover for a song based on its title, singer, culture, and genre
  String getAiCoverForSong(Song song) {
    final url = song.coverUrl.trim();
    if (url.startsWith('http') && !SongArtworkResolver.isGenericMicUrl(url)) {
      return url;
    }

    return SongArtworkResolver.resolveArtwork(
      title: song.title,
      artist: song.artist,
      genre: song.genre,
    );
  }

  /// Batch update all songs lacking a proper cover with high-resolution studio AI artwork
  List<Song> batchAutoAssignCovers(List<Song> songs) {
    return songs.map((s) {
      if (!s.coverUrl.trim().startsWith('http') || SongArtworkResolver.isGenericMicUrl(s.coverUrl)) {
        final newCover = getAiCoverForSong(s);
        return s.copyWith(coverUrl: newCover);
      }
      return s;
    }).toList();
  }
}
