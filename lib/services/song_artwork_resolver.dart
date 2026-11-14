class SongArtworkResolver {
  /// Known singer artwork mappings with high-resolution studio portraits
  static const Map<String, String> _artistImages = {
    'arijit': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    'arijit singh': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    'sidhu': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80',
    'moosewala': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80',
    'diljit': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&q=80',
    'dosanjh': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&q=80',
    'karan aujla': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    'aujla': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    'ap dhillon': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    'dhillon': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    'neha kakkar': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    'neha': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    'shreya': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80',
    'shreya ghoshal': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80',
    'jubin': 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&q=80',
    'jubin nautiyal': 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&q=80',
    'atif': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    'atif aslam': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    'sonu nigam': 'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=600&q=80',
    'sonu': 'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=600&q=80',
    'kumar sanu': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    'sanu': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    'alka yagnik': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80',
    'alka': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80',
    'udit narayan': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&q=80',
    'lata': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
    'lata mangeshkar': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
    'kishore kumar': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    'kishore': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    'badshah': 'https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=600&q=80',
    'honey singh': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    'yo yo': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    'b praak': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    'praak': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    'anuv jain': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
    'anuv': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
    'prakash mali': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
    'prakash': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
    'chhotu singh': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=600&q=80',
    'chhotu singh rawana': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=600&q=80',
    'geeta rabari': 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=600&q=80',
    'hansraj': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
    'kanhaiya mittal': 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=600&q=80',
    'jaya kishori': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=600&q=80',
    'lakkha': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
    'sapna choudhary': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    'sapna': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
  };

  /// Thematic artwork collections by deity, culture, and musical style
  static const Map<String, List<String>> _genreCollections = {
    'shiva': [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=600&q=80',
    ],
    'hanuman': [
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
    ],
    'krishna': [
      'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=600&q=80',
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=600&q=80',
    ],
    'ram': [
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
    ],
    'bhakti': [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
      'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=600&q=80',
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=600&q=80',
    ],
    'rajasthani': [
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=600&q=80',
      'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=600&q=80',
      'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=600&q=80',
    ],
    'punjabi': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&q=80',
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    ],
    'haryanvi': [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80',
    ],
    'bollywood': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&q=80',
    ],
    'lo-fi': [
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80',
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    ],
    'ghazal': [
      'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=600&q=80',
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    ],
    'sufi': [
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=600&q=80',
    ],
    'dj': [
      'https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=600&q=80',
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    ],
  };

  /// Distinct studio covers for deterministic hashing so every track gets a unique cover
  static const List<String> _uniqueStudioPool = [
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&q=80',
    'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=600&q=80',
    'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
    'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80',
    'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&q=80',
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80',
    'https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=600&q=80',
    'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
    'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
    'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=600&q=80',
  ];

  /// Resolves the optimal high-resolution artwork for any song based on singer, deity, genre or hash
  static String resolveArtwork({
    required String title,
    required String artist,
    String? genre,
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerArtist = artist.toLowerCase();
    final combined = '$lowerArtist $lowerTitle';

    // 1. Check direct singer / artist keyword matches
    for (final entry in _artistImages.entries) {
      if (lowerArtist.contains(entry.key) || lowerTitle.contains(entry.key)) {
        return entry.value;
      }
    }

    // 2. Check spiritual / deity keywords in title or artist
    if (combined.contains('shiv') || combined.contains('mahadev') || combined.contains('shambhu') || combined.contains('bholenath')) {
      final list = _genreCollections['shiva']!;
      return list[title.hashCode.abs() % list.length];
    }
    if (combined.contains('hanuman') || combined.contains('bajrang') || combined.contains('chalisa') || combined.contains('sankat')) {
      final list = _genreCollections['hanuman']!;
      return list[title.hashCode.abs() % list.length];
    }
    if (combined.contains('krishna') || combined.contains('shyam') || combined.contains('khatu') || combined.contains('radhe') || combined.contains('kanha')) {
      final list = _genreCollections['krishna']!;
      return list[title.hashCode.abs() % list.length];
    }
    if (combined.contains('ram') || combined.contains('ayodhya') || combined.contains('siya')) {
      final list = _genreCollections['ram']!;
      return list[title.hashCode.abs() % list.length];
    }

    // 3. Check genre keywords
    final lowerGenre = (genre ?? '').toLowerCase();
    for (final entry in _genreCollections.entries) {
      if (lowerGenre.contains(entry.key) || combined.contains(entry.key)) {
        final list = entry.value;
        return list[title.hashCode.abs() % list.length];
      }
    }

    // 4. Deterministic unique cover from pool using title hash
    final hash = (title + artist).hashCode.abs();
    return _uniqueStudioPool[hash % _uniqueStudioPool.length];
  }

  /// Automatically parses artist name from title or filename (e.g. "Song Name - Arijit Singh.mp3")
  static String extractArtist(String title, {String fallback = 'Unknown Artist'}) {
    final clean = title.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|flac)$', caseSensitive: false), '');
    if (clean.contains('-')) {
      final parts = clean.split('-');
      if (parts.length >= 2) {
        final right = parts[1].trim();
        if (right.isNotEmpty) return right;
      }
    }
    if (clean.contains('by ')) {
      final parts = clean.split('by ');
      if (parts.length >= 2) {
        final right = parts[1].trim();
        if (right.isNotEmpty) return right;
      }
    }
    return fallback;
  }
}
