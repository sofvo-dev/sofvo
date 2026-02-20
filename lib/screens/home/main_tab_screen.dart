import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Widget _buildBadgeIcon(IconData icon, Color color, int count) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: AppTheme.error,
      child: Icon(icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: uid.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('chats')
                .where('members', arrayContains: uid)
                .snapshots()
            : null,
        builder: (context, chatSnap) {
          int unreadCount = 0;
          if (chatSnap.hasData) {
            for (final doc in chatSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final lastRead = (data['lastRead'] as Map<String, dynamic>?)?[uid];
              final lastMsg = data['lastMessageAt'];
              if (lastMsg is Timestamp) {
                if (lastRead == null || (lastRead is Timestamp && lastMsg.toDate().isAfter(lastRead.toDate()))) {
                  unreadCount++;
                }
              }
            }
          }

          return NavigationBar(
            selectedIndex: _currentIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: Colors.white,
            indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: AppTheme.textSecondary),
                selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
                label: 'ホーム',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined, color: AppTheme.textSecondary),
                selectedIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                label: 'さがす',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined, color: AppTheme.textSecondary),
                selectedIcon: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                label: 'マイ大会',
              ),
              NavigationDestination(
                icon: _buildBadgeIcon(Icons.chat_bubble_outline, AppTheme.textSecondary, unreadCount),
                selectedIcon: _buildBadgeIcon(Icons.chat_bubble, AppTheme.primaryColor, unreadCount),
                label: 'チャット',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                selectedIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                label: 'マイページ',
              ),
            ],
          );
        },
      ),
    );
  }
}
