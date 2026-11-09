import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/song_list_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _quickTags = [
    'Hanuman',
    'Bhakti',
    'Satinder Sartaaj',
    'Sufi',
    'Bollywood',
    'Ghazal',
    'Ram Siya Ram',
    'Lo-Fi',
    'Mantra',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        final provider = Provider.of<PlayerProvider>(context);
        final lang = LanguageService();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(lang.t('search_title')),
            centerTitle: false,
          ),
          body: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: lang.t('search_hint'),
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentCyan),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                provider.search('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (query) {
                      provider.search(query);
                    },
                  ),
                ),
              ),

          // Quick Tag Chips
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _quickTags.length,
              itemBuilder: (context, index) {
                final tag = _quickTags[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: AppColors.card,
                    side: BorderSide(color: Colors.white.withOpacity(0.08)),
                    label: Text(tag),
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    onPressed: () {
                      _searchController.text = tag;
                      provider.search(tag);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Results or Initial State
          Expanded(
            child: provider.isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentCyan,
                    ),
                  )
                : provider.searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_off_rounded, size: 56, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No matching tracks found in legal catalog',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : provider.searchResults.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.stream_rounded, size: 56, color: AppColors.accentCyan),
                                const SizedBox(height: 16),
                                const Text(
                                  'Explore Free Legal Streams',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Stream millions of Creative Commons and royalty-free MP3s licensed under CC-BY and Public Domain directly from open indie catalogs.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 120),
                            itemCount: provider.searchResults.length,
                            itemBuilder: (context, index) {
                              final song = provider.searchResults[index];
                              final isCurrent = provider.currentSong?.id == song.id;

                              return SongListTile(
                                song: song,
                                isCurrent: isCurrent,
                                onTap: () => provider.playSong(song, queueContext: provider.searchResults),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
      },
    );
  }
}
