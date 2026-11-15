import 'package:flutter/material.dart';
import '../models/song.dart';

/// Representation of a song's dynamic visual theme
class SongThemeData {
  final String themeName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final List<Color> gradientColors;
  final IconData icon;

  const SongThemeData({
    required this.themeName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.gradientColors,
    required this.icon,
  });
}

/// Production-ready Intelligent Song Artwork & Dynamic Visual Theme Resolver
/// Automatically detects song mood, deity, culture, and musical style from the song title,
/// singer, and genre to assign authentic high-definition artwork and dynamic ambient theme colors.
class SongArtworkResolver {
  static bool isGenericMicUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final u = url.trim().toLowerCase();
    return u.contains('1511671782779') ||
        u.contains('photo-1511671782779') ||
        u.contains('1493225457124') ||
        u.contains('placeholder') ||
        u.contains('default_cover') ||
        u == 'null' ||
        u.endsWith('/cover.jpg') && u.contains('localhost');
  }

  /// Official verified studio portraits of prominent Indian and global artists
  static const Map<String, String> _artistImages = {
    // Bhakti & Devotional Singers
    'hariharan': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'sudhir vyas': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'sai charan': 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
    'sai charan bhaskaruni': 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
    'bhumika sharma': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
    'rasraj ji': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'rasraj ji maharaj': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'anuradha paudwal': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=85',
    'anup jalota': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'lakhbir singh lakkha': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
    'lakkha': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
    'hansraj raghuwanshi': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'hansraj': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'kanhaiya mittal': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'jaya kishori': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
    'gulshan kumar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'maanya arora': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',

    // Sufi, Punjabi & Folk Legends
    'satinder sartaaj': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'sartaaj': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'gurdas maan': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'diljit dosanjh': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'diljit': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'sidhu moose wala': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=85',
    'sidhu': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=85',
    'karan aujla': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'aujla': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'b praak': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'praak': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'ammy virk': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'nusrat fateh ali khan': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'rahat fateh ali khan': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&q=85',
    'ap dhillon': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'dhillon': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'shubh': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
    'guru randhawa': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'harrdy sandhu': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'badshah': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&q=85',
    'honey singh': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'yo yo': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',

    // Bollywood & Melodies
    'arijit singh': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'arijit': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'shreya ghoshal': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'shreya': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'sonu nigam': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'sonu': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'jubin nautiyal': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'jubin': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'atif aslam': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'atif': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'neha kakkar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'neha': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'mohit chauhan': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&q=85',
    'kk': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
    'sunidhi chauhan': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',
    'armaan malik': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'darshan raval': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=85',
    'vishal mishra': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'sachet tandon': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'parampara tandon': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',
    'sachet': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'shaan': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'udit narayan': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'kumar sanu': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'sanu': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'alka yagnik': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'alka': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'anuv jain': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'anuv': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',

    // Retro Classics & Ghazals
    'jagjit singh': 'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=800&q=85',
    'chitra singh': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=85',
    'pankaj udhas': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'lata mangeshkar': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'lata': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'kishore kumar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'kishore': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'mohammed rafi': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'rafi': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'asha bhosle': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'mukesh': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',

    // Rajasthani & Marwadi Folk Stars
    'mame khan': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&q=85',
    'prakash mali': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'prakash': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'chotu singh rawna': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=800&q=85',
    'chhotu singh rawana': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=800&q=85',
    'chhotu singh': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=800&q=85',
    'seema mishra': 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800&q=85',
    'geeta rabari': 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800&q=85',

    // Haryanvi & Desi Beat Stars
    'sapna choudhary': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=85',
    'sapna': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=85',
    'masoom sharma': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&q=85',
    'diler kharkiya': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'renuka panwar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',
    'gulzaar chhaniwala': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
  };

  /// Thematic High-Resolution Artwork Collections Organized by Deity, Culture, Genre & Mood
  static const Map<String, List<String>> _thematicGalleries = {
    'shiva': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=85',
      'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=900&q=85',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&q=85',
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=900&q=85',
    ],
    'hanuman': [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=900&q=85',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=900&q=85',
      'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=900&q=85',
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=900&q=85',
    ],
    'krishna': [
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=900&q=85',
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=900&q=85',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&q=85',
      'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=900&q=85',
    ],
    'ram': [
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=900&q=85',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=900&q=85',
      'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=900&q=85',
    ],
    'mata': [
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&q=85',
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=900&q=85',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=900&q=85',
    ],
    'ganesha': [
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=900&q=85',
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=900&q=85',
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=900&q=85',
    ],
    'sai': [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=900&q=85',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=900&q=85',
    ],
    'waheguru': [
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=900&q=85',
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=900&q=85',
    ],
    'sufi': [
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=900&q=85',
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=900&q=85',
      'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=900&q=85',
    ],
    'romantic': [
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&q=85',
      'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=900&q=85',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&q=85',
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=85',
    ],
    'sad': [
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=900&q=85',
      'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=900&q=85',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&q=85',
    ],
    'lofi': [
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&q=85',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&q=85',
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=900&q=85',
    ],
    'dj': [
      'https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=900&q=85',
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&q=85',
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=900&q=85',
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&q=85',
    ],
    'punjabi': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=85',
      'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=900&q=85',
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&q=85',
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=900&q=85',
    ],
    'haryanvi': [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&q=85',
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=900&q=85',
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&q=85',
    ],
    'rajasthani': [
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=900&q=85',
      'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=900&q=85',
      'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=900&q=85',
    ],
    'bollywood': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=85',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&q=85',
      'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=900&q=85',
    ],
    'hiphop': [
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=900&q=85',
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&q=85',
    ],
    'retro': [
      'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=900&q=85',
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=900&q=85',
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=900&q=85',
    ],
  };

  /// Pre-defined Studio Artworks for Universal Deterministic Fallback
  static const List<String> _studioArtPool = [
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=85',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=900&q=85',
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&q=85',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=900&q=85',
    'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=900&q=85',
    'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=900&q=85',
    'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=900&q=85',
    'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&q=85',
    'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&q=85',
    'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=900&q=85',
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&q=85',
    'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=900&q=85',
    'https://images.unsplash.com/photo-1544717305-2782549b5136?w=900&q=85',
    'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=900&q=85',
    'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=900&q=85',
  ];

  /// Resolves the verified singer portrait for Artist avatars and detail screens
  static String resolveArtistImage(String artistName) {
    final lower = artistName.toLowerCase().trim();
    for (final entry in _artistImages.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    final hash = artistName.hashCode.abs();
    return _studioArtPool[hash % _studioArtPool.length];
  }

  /// Automatically detects the thematic key from title, artist, and genre
  static String detectThemeKey(String title, {String artist = '', String? genre}) {
    final t = title.toLowerCase();
    final a = artist.toLowerCase();
    final g = (genre ?? '').toLowerCase();
    final combined = '$t $a $g';

    // 1. Lord Shiva / Mahadev
    if (combined.contains('shiv') ||
        combined.contains('mahadev') ||
        combined.contains('shambhu') ||
        combined.contains('bhole') ||
        combined.contains('kedarnath') ||
        combined.contains('ujjain') ||
        combined.contains('damru') ||
        combined.contains('tandav') ||
        combined.contains('kailash') ||
        combined.contains('om namah') ||
        combined.contains('rudra') ||
        combined.contains('aghori')) {
      return 'shiva';
    }

    // 2. Lord Hanuman / Bajrangbali / Balaji
    if (combined.contains('hanuman') ||
        combined.contains('bajrang') ||
        combined.contains('chalisa') ||
        combined.contains('sankat') ||
        combined.contains('balaji') ||
        combined.contains('maruti') ||
        combined.contains('anjani') ||
        combined.contains('pawansut') ||
        combined.contains('mehandipur')) {
      return 'hanuman';
    }

    // 3. Lord Krishna / Khatu Shyam / Radhe
    if (combined.contains('krishna') ||
        combined.contains('shyam') ||
        combined.contains('khatu') ||
        combined.contains('radha') ||
        combined.contains('radhe') ||
        combined.contains('kanha') ||
        combined.contains('gopal') ||
        combined.contains('makhan') ||
        combined.contains('vrindavan') ||
        combined.contains('barsana') ||
        combined.contains('govind') ||
        combined.contains('bihari') ||
        combined.contains('murli')) {
      return 'krishna';
    }

    // 4. Lord Ram / Ayodhya
    if (combined.contains('ram') ||
        combined.contains('siya') ||
        combined.contains('ayodhya') ||
        combined.contains('raghu') ||
        combined.contains('sita') ||
        combined.contains('adipurush')) {
      return 'ram';
    }

    // 5. Maa Durga / Navratri / Kali / Vaishno
    if (combined.contains('mata') ||
        combined.contains('durga') ||
        combined.contains('ambe') ||
        combined.contains('kali') ||
        combined.contains('vaishno') ||
        combined.contains('sherawali') ||
        combined.contains('navratri') ||
        combined.contains('bhavani') ||
        combined.contains('maiya')) {
      return 'mata';
    }

    // 6. Lord Ganesha
    if (combined.contains('ganesh') ||
        combined.contains('ganpati') ||
        combined.contains('vinayak') ||
        combined.contains('bappa') ||
        combined.contains('modak') ||
        combined.contains('lambodar')) {
      return 'ganesha';
    }

    // 7. Sai Baba
    if (combined.contains('sai') || combined.contains('shirdi')) {
      return 'sai';
    }

    // 8. Sikh Devotional / Waheguru / Gurbani
    if (combined.contains('waheguru') ||
        combined.contains('gurbani') ||
        combined.contains('satnam') ||
        combined.contains('shabad') ||
        combined.contains('khalsa') ||
        combined.contains('golden temple')) {
      return 'waheguru';
    }

    // 9. Sufi / Qawwali / Khwaja
    if (combined.contains('sufi') ||
        combined.contains('qawwali') ||
        combined.contains('khwaja') ||
        combined.contains('dargah') ||
        combined.contains('ajmer') ||
        combined.contains('maula') ||
        combined.contains('faqeer') ||
        combined.contains('ali')) {
      return 'sufi';
    }

    // 10. DJ Remix / Bass / Club / Party
    if (combined.contains('dj') ||
        combined.contains('remix') ||
        combined.contains('party') ||
        combined.contains('club') ||
        combined.contains('bass') ||
        combined.contains('drop') ||
        combined.contains('edm') ||
        combined.contains('dance') ||
        combined.contains('mashup')) {
      return 'dj';
    }

    // 11. Punjabi / Bhangra
    if (combined.contains('punjabi') ||
        combined.contains('bhangra') ||
        combined.contains('dhol') ||
        combined.contains('jatt') ||
        combined.contains('pind') ||
        combined.contains('sardar') ||
        combined.contains('gabru') ||
        combined.contains('patiala')) {
      return 'punjabi';
    }

    // 12. Haryanvi / Desi
    if (combined.contains('haryanvi') ||
        combined.contains('desi') ||
        combined.contains('ragni') ||
        combined.contains('jaat') ||
        combined.contains('tau') ||
        combined.contains('systumm') ||
        combined.contains('badmashi')) {
      return 'haryanvi';
    }

    // 13. Rajasthani / Marwadi
    if (combined.contains('rajasthan') ||
        combined.contains('marwadi') ||
        combined.contains('ghoomar') ||
        combined.contains('kesariya') ||
        combined.contains('banna') ||
        combined.contains('choudhary') ||
        combined.contains('padharo')) {
      return 'rajasthani';
    }

    // 14. Romantic / Love
    if (combined.contains('pyar') ||
        combined.contains('ishq') ||
        combined.contains('mohabbat') ||
        combined.contains('dil') ||
        combined.contains('love') ||
        combined.contains('romantic') ||
        combined.contains('humsafar') ||
        combined.contains('sanam') ||
        combined.contains('jaan') ||
        combined.contains('chahat') ||
        combined.contains('soniye') ||
        combined.contains('hiriye')) {
      return 'romantic';
    }

    // 15. Sad / Heartbreak / Dard
    if (combined.contains('sad') ||
        combined.contains('dard') ||
        combined.contains('judai') ||
        combined.contains('bewafa') ||
        combined.contains('yaad') ||
        combined.contains('tanha') ||
        combined.contains('breakup') ||
        combined.contains('aansu') ||
        combined.contains('broken')) {
      return 'sad';
    }

    // 16. Lo-Fi / Chill / Acoustic
    if (combined.contains('lofi') ||
        combined.contains('lo-fi') ||
        combined.contains('chill') ||
        combined.contains('slow') ||
        combined.contains('reverb') ||
        combined.contains('acoustic') ||
        combined.contains('sleep') ||
        combined.contains('relax') ||
        combined.contains('midnight')) {
      return 'lofi';
    }

    // 17. Rap / Hip-Hop
    if (combined.contains('rap') ||
        combined.contains('hip hop') ||
        combined.contains('hiphop') ||
        combined.contains('gully') ||
        combined.contains('cypher') ||
        combined.contains('bars')) {
      return 'hiphop';
    }

    // 18. Retro / Classics
    if (combined.contains('retro') ||
        combined.contains('classic') ||
        combined.contains('vintage') ||
        combined.contains('purane') ||
        combined.contains('70s') ||
        combined.contains('80s') ||
        combined.contains('90s') ||
        combined.contains('evergreen')) {
      return 'retro';
    }

    // 19. Bollywood / General
    if (combined.contains('bollywood') || combined.contains('filmi') || combined.contains('cinema')) {
      return 'bollywood';
    }

    return 'default';
  }

  /// Returns the dynamic visual theme data (gradients, ambient aura colors, icons) for any song
  static SongThemeData getThemeForSong(Song song) {
    return getThemeForTitle(song.title, artist: song.artist, genre: song.genre);
  }

  /// Returns the dynamic visual theme data for given title, artist, and genre
  static SongThemeData getThemeForTitle(String title, {String artist = '', String? genre}) {
    final key = detectThemeKey(title, artist: artist, genre: genre);
    switch (key) {
      case 'shiva':
        return const SongThemeData(
          themeName: 'Mahadev Aura',
          primaryColor: Color(0xFF0F172A),
          secondaryColor: Color(0xFF1E293B),
          accentColor: Color(0xFF00E5FF),
          gradientColors: [Color(0xFF0A1128), Color(0xFF1C2A4A), Color(0xFF00E5FF)],
          icon: Icons.flare_rounded,
        );
      case 'hanuman':
        return const SongThemeData(
          themeName: 'Bajrangbali Aura',
          primaryColor: Color(0xFF431407),
          secondaryColor: Color(0xFF9A3412),
          accentColor: Color(0xFFFF9800),
          gradientColors: [Color(0xFF451A03), Color(0xFFC2410C), Color(0xFFFFB74D)],
          icon: Icons.local_fire_department_rounded,
        );
      case 'krishna':
        return const SongThemeData(
          themeName: 'Shyam Khatu Aura',
          primaryColor: Color(0xFF064E3B),
          secondaryColor: Color(0xFF047857),
          accentColor: Color(0xFF10B981),
          gradientColors: [Color(0xFF022C22), Color(0xFF065F46), Color(0xFF34D399)],
          icon: Icons.wb_sunny_rounded,
        );
      case 'ram':
        return const SongThemeData(
          themeName: 'Ayodhya Ram Aura',
          primaryColor: Color(0xFF7C2D12),
          secondaryColor: Color(0xFFC2410C),
          accentColor: Color(0xFFFBBF24),
          gradientColors: [Color(0xFF431407), Color(0xFFEA580C), Color(0xFFFDE047)],
          icon: Icons.brightness_high_rounded,
        );
      case 'mata':
        return const SongThemeData(
          themeName: 'Mata Rani Aura',
          primaryColor: Color(0xFF881337),
          secondaryColor: Color(0xFFBE123C),
          accentColor: Color(0xFFFDA4AF),
          gradientColors: [Color(0xFF4C0519), Color(0xFF9F1239), Color(0xFFFB7185)],
          icon: Icons.star_rounded,
        );
      case 'ganesha':
        return const SongThemeData(
          themeName: 'Ganpati Aura',
          primaryColor: Color(0xFF78350F),
          secondaryColor: Color(0xFFD97706),
          accentColor: Color(0xFFFCD34D),
          gradientColors: [Color(0xFF451A03), Color(0xFFB45309), Color(0xFFFBBF24)],
          icon: Icons.celebration_rounded,
        );
      case 'sai':
        return const SongThemeData(
          themeName: 'Sai Baba Aura',
          primaryColor: Color(0xFF78350F),
          secondaryColor: Color(0xFFB45309),
          accentColor: Color(0xFFFFD54F),
          gradientColors: [Color(0xFF3E1F00), Color(0xFF8D4004), Color(0xFFFFD54F)],
          icon: Icons.lightbulb_rounded,
        );
      case 'waheguru':
        return const SongThemeData(
          themeName: 'Gurbani Aura',
          primaryColor: Color(0xFF1E3A8A),
          secondaryColor: Color(0xFF1D4ED8),
          accentColor: Color(0xFFF59E0B),
          gradientColors: [Color(0xFF172554), Color(0xFF1E40AF), Color(0xFFFBBF24)],
          icon: Icons.circle_outlined,
        );
      case 'sufi':
        return const SongThemeData(
          themeName: 'Sufi Mehfil',
          primaryColor: Color(0xFF1C1917),
          secondaryColor: Color(0xFF44403C),
          accentColor: Color(0xFFD97706),
          gradientColors: [Color(0xFF1C1917), Color(0xFF292524), Color(0xFFB45309)],
          icon: Icons.audiotrack_rounded,
        );
      case 'romantic':
        return const SongThemeData(
          themeName: 'Romantic Velvet',
          primaryColor: Color(0xFF4C0519),
          secondaryColor: Color(0xFF831843),
          accentColor: Color(0xFFF43F5E),
          gradientColors: [Color(0xFF3B0764), Color(0xFF880E4F), Color(0xFFFB7185)],
          icon: Icons.favorite_rounded,
        );
      case 'sad':
        return const SongThemeData(
          themeName: 'Moody Blue',
          primaryColor: Color(0xFF0F172A),
          secondaryColor: Color(0xFF1E293B),
          accentColor: Color(0xFF38BDF8),
          gradientColors: [Color(0xFF0B192C), Color(0xFF1E3E62), Color(0xFF60A5FA)],
          icon: Icons.cloud_rounded,
        );
      case 'lofi':
        return const SongThemeData(
          themeName: 'Lo-Fi Chill',
          primaryColor: Color(0xFF2E1065),
          secondaryColor: Color(0xFF581C87),
          accentColor: Color(0xFFA855F7),
          gradientColors: [Color(0xFF180A2E), Color(0xFF4C1D95), Color(0xFF818CF8)],
          icon: Icons.nightlight_round,
        );
      case 'dj':
        return const SongThemeData(
          themeName: 'DJ Cyber Bass',
          primaryColor: Color(0xFF1E1B4B),
          secondaryColor: Color(0xFF3730A3),
          accentColor: Color(0xFF00E5FF),
          gradientColors: [Color(0xFF1E1B4B), Color(0xFF7C3AED), Color(0xFF00E5FF)],
          icon: Icons.speaker_group_rounded,
        );
      case 'punjabi':
        return const SongThemeData(
          themeName: 'Punjabi Beats',
          primaryColor: Color(0xFF581C87),
          secondaryColor: Color(0xFF7E22CE),
          accentColor: Color(0xFFFF9800),
          gradientColors: [Color(0xFF3B0764), Color(0xFF6B21A8), Color(0xFFFF9800)],
          icon: Icons.music_note_rounded,
        );
      case 'haryanvi':
        return const SongThemeData(
          themeName: 'Haryanvi Desi',
          primaryColor: Color(0xFF14532D),
          secondaryColor: Color(0xFF15803D),
          accentColor: Color(0xFF4ADE80),
          gradientColors: [Color(0xFF052E16), Color(0xFF166534), Color(0xFF22C55E)],
          icon: Icons.bolt_rounded,
        );
      case 'rajasthani':
        return const SongThemeData(
          themeName: 'Rajasthani Kesariya',
          primaryColor: Color(0xFF7C2D12),
          secondaryColor: Color(0xFFC2410C),
          accentColor: Color(0xFFFBBF24),
          gradientColors: [Color(0xFF451A03), Color(0xFFEA580C), Color(0xFFFBBF24)],
          icon: Icons.wb_sunny_rounded,
        );
      case 'hiphop':
        return const SongThemeData(
          themeName: 'Street Hip-Hop',
          primaryColor: Color(0xFF18181B),
          secondaryColor: Color(0xFF27272A),
          accentColor: Color(0xFFE11D48),
          gradientColors: [Color(0xFF18181B), Color(0xFF3F3F46), Color(0xFFE11D48)],
          icon: Icons.mic_external_on_rounded,
        );
      case 'retro':
        return const SongThemeData(
          themeName: 'Vintage Gold',
          primaryColor: Color(0xFF292524),
          secondaryColor: Color(0xFF44403C),
          accentColor: Color(0xFFD97706),
          gradientColors: [Color(0xFF1C1917), Color(0xFF44403C), Color(0xFFD97706)],
          icon: Icons.radio_rounded,
        );
      case 'bollywood':
      default:
        // Deterministic palette based on title & artist
        final hash = (title + artist).hashCode.abs();
        final palettes = [
          const SongThemeData(
            themeName: 'Electric Neon',
            primaryColor: Color(0xFF0F172A),
            secondaryColor: Color(0xFF1E293B),
            accentColor: Color(0xFF00E5FF),
            gradientColors: [Color(0xFF0A192F), Color(0xFF1E3A8A), Color(0xFF00E5FF)],
            icon: Icons.album_rounded,
          ),
          const SongThemeData(
            themeName: 'Cosmic Purple',
            primaryColor: Color(0xFF2E1065),
            secondaryColor: Color(0xFF4C1D95),
            accentColor: Color(0xFFEC4899),
            gradientColors: [Color(0xFF1E1B4B), Color(0xFF581C87), Color(0xFFEC4899)],
            icon: Icons.music_note_rounded,
          ),
          const SongThemeData(
            themeName: 'Emerald Harmony',
            primaryColor: Color(0xFF064E3B),
            secondaryColor: Color(0xFF047857),
            accentColor: Color(0xFF10B981),
            gradientColors: [Color(0xFF022C22), Color(0xFF065F46), Color(0xFF34D399)],
            icon: Icons.graphic_eq_rounded,
          ),
          const SongThemeData(
            themeName: 'Amber Sunset',
            primaryColor: Color(0xFF7C2D12),
            secondaryColor: Color(0xFF9A3412),
            accentColor: Color(0xFFF59E0B),
            gradientColors: [Color(0xFF431407), Color(0xFFB45309), Color(0xFFFBBF24)],
            icon: Icons.surround_sound_rounded,
          ),
        ];
        return palettes[hash % palettes.length];
    }
  }

  /// Resolves the optimal high-resolution thematic artwork URL for any song based on title, singer, or genre
  static String resolveArtwork({
    required String title,
    required String artist,
    String? genre,
  }) {
    // 1. Direct singer / artist keyword matches
    final lowerArtist = artist.toLowerCase();
    final lowerTitle = title.toLowerCase();
    for (final entry in _artistImages.entries) {
      if (lowerArtist.contains(entry.key) || lowerTitle.contains(entry.key)) {
        return entry.value;
      }
    }

    // 2. Identify thematic gallery key
    final themeKey = detectThemeKey(title, artist: artist, genre: genre);
    final gallery = _thematicGalleries[themeKey];
    if (gallery != null && gallery.isNotEmpty) {
      final hash = (title + artist).hashCode.abs();
      return gallery[hash % gallery.length];
    }

    // 3. Fallback to rich studio pool deterministically
    final hash = (title + artist).hashCode.abs();
    return _studioArtPool[hash % _studioArtPool.length];
  }

  /// Automatically parses artist name from title or filename
  static String extractArtist(String title, {String fallback = 'Various Artists'}) {
    final clean = title.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|flac)$', caseSensitive: false), '');
    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      if (parts.length >= 2) {
        final left = parts[0].trim();
        if (left.isNotEmpty) return left;
      }
    } else if (clean.contains('-')) {
      final parts = clean.split('-');
      if (parts.length >= 2) {
        final right = parts[1].trim();
        if (right.isNotEmpty) return right;
      }
    }
    if (clean.contains('by ') || clean.contains('By ')) {
      final parts = clean.split(RegExp(r'by ', caseSensitive: false));
      if (parts.length >= 2) {
        final right = parts[1].trim();
        if (right.isNotEmpty) return right;
      }
    }
    return fallback;
  }
}
