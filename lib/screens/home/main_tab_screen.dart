import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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

  // 下スクロールでボトムナビを縮める（Instagram 風）
  final ValueNotifier<bool> _navCollapsed = ValueNotifier<bool>(false);

  final List<Widget> _screens = [
    const HomeScreen(),
    const TournamentSearchScreen(),
    const RecruitmentScreen(),
    const ChatListScreen(),
    const MyPageScreen(),
  ];

  @override
  void dispose() {
    _navCollapsed.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification n) {
    // ネストしたスクロール（横スクロール等）は無視
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse) {
      _navCollapsed.value = true; // 下にスクロール → 縮める
    } else if (n.direction == ScrollDirection.forward) {
      _navCollapsed.value = false; // 上にスクロール → 戻す
    }
    return false;
  }

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
          extendBody: true,
          body: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: ConnectivityBanner(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),
          bottomNavigationBar: _BottomNav(
            currentIndex: _currentIndex,
            collapsed: _navCollapsed,
            onDestinationSelected: (index) {
              _navCollapsed.value = false; // タブ切替時は展開して見せる
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
  const _BottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.collapsed,
  });
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final ValueListenable<bool> collapsed;

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

        // セーフエリア（ホームインジケータ領域）の余白を一部だけ残して下に詰める
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom * 0.75),
          child: ValueListenableBuilder<bool>(
            valueListenable: collapsed,
            builder: (context, isCollapsed, _) {
              final n = items.length;
              // 比率ベース配置: 縮小（幅変化）に追従しつつ、タブ切替時だけスライド
              final alignX =
                  n <= 1 ? 0.0 : (currentIndex / (n - 1)) * 2 - 1;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                // 縮小時は左右に絞って小さく見せる
                padding: EdgeInsets.fromLTRB(
                  isCollapsed ? 64 : 16, 4, isCollapsed ? 64 : 16, 6),
                child: Stack(
                  // 移動中に膨らむ選択カプセルをクリップしない
                  clipBehavior: Clip.none,
                  children: [
                    // すりガラスのバー本体（背景のみ・タブは最前面のRowが描く）
                    DecoratedBox(
                      decoration: BoxDecoration(
                        // 高さ以上の角丸を指定して常に完全なカプセル形にする
                        borderRadius: BorderRadius.circular(33),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      // すりガラス（屈折）: 後ろのコンテンツをぼかして透かす
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(33),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            height: isCollapsed ? 52 : 66,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(33),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 選択カプセル（バー内に収まる横長ピル・うっすらネイビーのガラス）
                    Positioned.fill(
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(alignX, 0),
                        child: FractionallySizedBox(
                          widthFactor: 1 / n,
                          heightFactor: 1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: isCollapsed ? 6 : 8),
                            child: TweenAnimationBuilder<double>(
                              // タブ切替のたびに0→1を再生。移動中（中間）だけ
                              // ガラス化して膨らみ、着地すると元の薄いピルに戻る
                              // （iOS 26 Liquid Glass の挙動の近似）
                              key: ValueKey<int>(currentIndex),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOut,
                              builder: (context, t, _) {
                                final s = math.sin(math.pi * t);
                                return Transform.scale(
                                  scaleX: 1 + 0.16 * s,
                                  scaleY: 1 + 0.10 * s,
                                  child: _LiquidCapsule(glass: s),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    // タブ（アイコン＋ラベル）はカプセルより前面に置いて滲ませない
                    Positioned.fill(
                      child: Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Expanded(
                              child: _NavItem(
                                data: items[i],
                                selected: i == currentIndex,
                                collapsed: isCollapsed,
                                onTap: () => onDestinationSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 選択カプセル。静止時はうっすらネイビーの横長ピル、タブ間を移動する間だけ
/// 「液体ガラス」になる（iOS 26 の挙動の近似）: 縁に白い光とネイビーのフリンジが
/// 現れ、下のガラスを軽くぼかしながら少し膨らんで滑り、着地すると元に戻る。
/// 本物の屈折歪みはシェーダーが必要（Web非対応）なため行わない。
class _LiquidCapsule extends StatelessWidget {
  const _LiquidCapsule({required this.glass});

  /// 0 = 静止（薄いネイビーのピル）〜 1 = 移動中のピーク（ガラスの水滴）
  final double glass;

  @override
  Widget build(BuildContext context) {
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.10 + 0.05 * glass),
        borderRadius: BorderRadius.circular(25),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        // 高さの半分以上の角丸で常に完全なカプセル形
        borderRadius: BorderRadius.circular(26),
        // 移動中だけ縁が白く光り、ネイビーのフリンジが乗る（静止時は透明）
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.90 * glass),
            AppTheme.primaryLight.withValues(alpha: 0.30 * glass),
            Colors.white.withValues(alpha: 0.12 * glass),
            AppTheme.primaryColor.withValues(alpha: 0.32 * glass),
            Colors.white.withValues(alpha: 0.60 * glass),
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        ),
      ),
      child: Padding(
        // 縁の線の太さ（グラデーションが見える幅）
        padding: const EdgeInsets.all(1.4),
        // 静止時は BackdropFilter を組み込まない（コスト削減＋濁り防止）
        child: glass < 0.01
            ? fill
            : ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: 4 * glass, sigmaY: 4 * glass),
                  child: fill,
                ),
              ),
      ),
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
    required this.collapsed,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.black : Colors.black87;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: EdgeInsets.symmetric(horizontal: 5, vertical: collapsed ? 6 : 9),
        // 選択カプセルはスライドする背面側（_LiquidCapsule）が描くためここは透明
        decoration: const BoxDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _icon(color),
            // 縮小時はラベルを畳んでアイコンだけにする
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: collapsed
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.0,
                            color: color,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(Color color) {
    final iconWidget = Icon(selected ? data.activeIcon : data.icon, size: 25, color: color);
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
