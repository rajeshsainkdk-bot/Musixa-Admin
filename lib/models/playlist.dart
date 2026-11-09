import 'song.dart';

class Playlist {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final List<Song> songs;
  final bool isCurated;

  Playlist({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.songs,
    this.isCurated = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'isCurated': isCurated,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Playlist',
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      isCurated: json['isCurated'] as bool? ?? false,
      songs: (json['songs'] as List<dynamic>?)
              ?.map((item) => Song.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
