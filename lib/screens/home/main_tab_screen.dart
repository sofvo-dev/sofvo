import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../home/home_screen.dart';
import '../tournament/tournament_search_screen.dart';
import '../recruitment/recruitment_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/my_page_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TournamentSearchScreen(),
    const RecruitmentScreen(),
    const ChatListScreen(),
    const MyPageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: AppTheme.textSecondary),
            selectedIcon:
                Icon(Icons.home, color: AppTheme.primaryColor),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined,
                color: AppTheme.textSecondary),
            selectedIcon:
                Icon(Icons.search, color: AppTheme.primaryColor),
            label: 'さがす',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined,
                color: AppTheme.textSecondary),
            selectedIcon: Icon(Icons.calendar_today,
                color: AppTheme.primaryColor),
            label: '予定',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline,
                color: AppTheme.textSecondary),
            selectedIcon: Icon(Icons.chat_bubble,
                color: AppTheme.primaryColor),
            label: 'チャット',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline,
                color: AppTheme.textSecondary),
            selectedIcon:
                Icon(Icons.person, color: AppTheme.primaryColor),
            label: 'マイページ',
          ),
        ],
      ),
    );
  }
}
