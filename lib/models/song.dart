import '../services/song_artwork_resolver.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration; // in seconds
  final String streamUrl;
  final String coverUrl;
  final String genre;
  final String? subCategory;
  final String license;
  final String licenseUrl;
  final String source;
  bool isFavorite;

  // Community Upload & Moderation
  final String status; // 'approved' | 'pending' | 'rejected'
  final String? uploadedBy;
  final String? uploaderName;
  final String? uploaderPhone;
  final DateTime? createdAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.streamUrl,
    required this.coverUrl,
    this.genre = 'Electronic',
    this.subCategory,
    this.license = 'Creative Commons BY-SA',
    this.licenseUrl = 'https://creativecommons.org/licenses/',
    this.source = 'Jamendo Free Catalog',
    this.isFavorite = false,
    this.status = 'approved',
    this.uploadedBy,
    this.uploaderName,
    this.uploaderPhone,
    this.createdAt,
  });

  String get formattedDuration {
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get durationFormatted => formattedDuration;

  String get displayCoverUrl {
    final c = coverUrl.trim();
    if (c.startsWith('http') &&
        !c.contains('1511671782779') &&
        !c.contains('1493225457124') &&
        !c.contains('placeholder') &&
        !c.contains('default_cover') &&
        c != 'null') {
      return c;
    }
    return SongArtworkResolver.resolveArtwork(
      title: title,
      artist: artist,
      genre: genre,
    );
  }

  bool get isOffline =>
      streamUrl.startsWith('/') ||
      streamUrl.startsWith('assets/') ||
      streamUrl.startsWith('content://') ||
      streamUrl.startsWith('file://') ||
      id.startsWith('device_') ||
      genre == 'Offline';

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? streamUrl,
    String? coverUrl,
    String? genre,
    String? subCategory,
    String? license,
    String? licenseUrl,
    String? source,
    bool? isFavorite,
    String? status,
    String? uploadedBy,
    String? uploaderName,
    String? uploaderPhone,
    DateTime? createdAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      genre: genre ?? this.genre,
      subCategory: subCategory ?? this.subCategory,
      license: license ?? this.license,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      status: status ?? this.status,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploaderName: uploaderName ?? this.uploaderName,
      uploaderPhone: uploaderPhone ?? this.uploaderPhone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'streamUrl': streamUrl,
      'coverUrl': coverUrl,
      'genre': genre,
      'subCategory': subCategory,
      'license': license,
      'licenseUrl': licenseUrl,
      'source': source,
      'isFavorite': isFavorite,
      'status': status,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'uploaderPhone': uploaderPhone,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? 'Musixa Player Catalog',
      duration: (json['duration'] as num?)?.toInt() ?? 180,
      streamUrl: json['streamUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      genre: json['genre'] as String? ?? 'Chill',
      subCategory: json['subCategory'] as String? ?? json['sub_category'] as String?,
      license: json['license'] as String? ?? 'Creative Commons',
      licenseUrl: json['licenseUrl'] as String? ?? 'https://creativecommons.org/',
      source: json['source'] as String? ?? 'Legal Free Music',
      isFavorite: json['isFavorite'] as bool? ?? false,
      status: json['status'] as String? ?? 'approved',
      uploadedBy: json['uploadedBy'] as String?,
      uploaderName: json['uploaderName'] as String?,
      uploaderPhone: json['uploaderPhone'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
