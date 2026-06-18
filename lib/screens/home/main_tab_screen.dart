import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/ban_guard.dart';
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

  // ホーム・チャット = 白背景 → ダークアイコン, マイページ = 暗い背景 → ライトアイコン
  // さがす・マイ大会 = AppBarが自動でハンドル
  SystemUiOverlayStyle _statusBarStyle() {
    switch (_currentIndex) {
      case 4: // マイページ（ダークヘッダー）
        return SystemUiOverlayStyle.light;
      default: // ホーム・さがす・マイ大会・チャット
        return SystemUiOverlayStyle.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BanGuard(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _statusBarStyle(),
        child: Scaffold(
          body: ConnectivityBanner(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          bottomNavigationBar: _BottomNav(
            currentIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
          ),
        ),
      ),
    );
  }
}

/// 分離されたナビゲーションバー — チャットバッジの更新で他のタブがリビルドされない
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onDestinationSelected});
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
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
            final lastMessage = (data['lastMessage'] as String?) ?? '';
            if (lastMessage.isEmpty) continue;
            // lastRead vs lastMessageAt のタイムスタンプ比較で判定
            final lastRead = (data['lastRead'] as Map<String, dynamic>?)?[uid];
            final lastMsg = data['lastMessageAt'];
            if (lastMsg is Timestamp) {
              if (lastRead == null || (lastRead is Timestamp && lastMsg.toDate().isAfter(lastRead.toDate()))) {
                // unreadCountマップから件数を取得（あれば）
                final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
                final raw = unreadMap?[uid];
                final cnt = (raw is int) ? raw : (raw is num) ? raw.toInt() : 0;
                unreadCount += cnt > 0 ? cnt : 1;
              }
            }
          }
        }

        final items = <_NavItemData>[
          const _NavItemData(Icons.home_outlined, Icons.home, 'ホーム'),
          const _NavItemData(Icons.search_outlined, Icons.search, 'さがす'),
          const _NavItemData(Icons.calendar_today_outlined, Icons.calendar_today, 'マイ大会'),
          _NavItemData(Icons.chat_bubble_outline, Icons.chat_bubble, 'チャット', badge: unreadCount),
          const _NavItemData(Icons.person_outline, Icons.person, 'マイページ'),
        ];

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      data: items[i],
                      selected: i == currentIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 浮島型ボトムナビのタブ定義
class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  const _NavItemData(this.icon, this.activeIcon, this.label, {this.badge = 0});
}

/// 1タブ分。選択時は角丸カプセルで強調する。
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryColor : AppTheme.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _icon(color),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(Color color) {
    final iconWidget = Icon(selected ? data.activeIcon : data.icon, size: 22, color: color);
    if (data.badge > 0) {
      return Badge(
        label: Text('${data.badge}', style: const TextStyle(fontSize: 10, color: Colors.white)),
        backgroundColor: AppTheme.error,
        child: iconWidget,
      );
    }
    return iconWidget;
  }
}
