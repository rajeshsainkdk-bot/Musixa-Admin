import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import '../services/update_service.dart';
import '../services/language_service.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'equalizer_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context, autoPrompt: true);
    });
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    EqualizerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        final lang = LanguageService();
        return Consumer<PlayerProvider>(
          builder: (context, provider, child) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Stack(
                children: [
                  // Active Tab Screen
                  IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),

                  // Floating Persistent MiniPlayer above navigation
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: const MiniPlayer(),
                  ),
                ],
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppColors.accentCyan,
                  unselectedItemColor: AppColors.textMuted,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_filled),
                      label: lang.t('nav_discover'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.search_rounded),
                      label: lang.t('nav_search'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.library_music_rounded),
                      label: lang.t('nav_library'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.graphic_eq_rounded),
                      label: lang.t('nav_sound_fx'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
