import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../home/main_tab_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _iconAnimController;
  late final Animation<double> _iconScaleAnim;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.sports_volleyball,
      title: '大会をさがす',
      description: 'お近くのソフトバレーボール大会を\n検索してエントリーできます。\n地域・日程・レベルで絞り込みも可能です。',
      accentColor: Color(0xFF2E5C8A),
      subIcons: [Icons.search, Icons.place, Icons.calendar_month],
    ),
    _OnboardingPage(
      icon: Icons.how_to_reg,
      title: 'かんたんエントリー',
      description: '気になる大会を見つけたら\n「エントリー」ボタンをタップするだけ。\nチームメンバーを登録して参加しましょう。',
      accentColor: Color(0xFF2E7D56),
      subIcons: [Icons.touch_app, Icons.group_add, Icons.check_circle],
    ),
    _OnboardingPage(
      icon: Icons.dynamic_feed,
      title: 'タイムライン',
      description: '他のプレイヤーの投稿をチェックしたり\n自分の活動を共有できます。\n大会の感想や練習の様子を発信しましょう。',
      accentColor: Color(0xFF8E5BB5),
      subIcons: [Icons.photo_camera, Icons.chat_bubble_outline, Icons.favorite],
    ),
    _OnboardingPage(
      icon: Icons.people_outline,
      title: '仲間とつながる',
      description: 'フォロー機能で仲間とつながれます。\n友達招待リンクを送って\n一緒にSofvoを楽しみましょう！',
      accentColor: Color(0xFFC4A962),
      subIcons: [Icons.person_add, Icons.share, Icons.emoji_people],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _iconScaleAnim = CurvedAnimation(
      parent: _iconAnimController,
      curve: Curves.elasticOut,
    );
    _iconAnimController.forward();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabScreen()),
      (route) => false,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _iconAnimController.reset();
    _iconAnimController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'スキップ',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // ページコンテンツ
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final p = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // イラスト風のビジュアル
                        _buildIllustration(p),
                        const SizedBox(height: 40),
                        Text(
                          p.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          p.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // サブアイコン（機能ヒント）
                        _buildSubIcons(p),
                      ],
                    ),
                  );
                },
              ),
            ),
            // ドットインジケーター + ページ番号
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = _currentPage == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? page.accentColor
                              : page.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currentPage + 1} / ${_pages.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // ボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: page.accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Sofvo をはじめる'
                          : '次へ',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
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

  Widget _buildIllustration(_OnboardingPage page) {
    return ScaleTransition(
      scale: _iconScaleAnim,
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景の装飾円（大）
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withValues(alpha: 0.08),
                      page.accentColor.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
            // 装飾ドット
            ...List.generate(6, (i) {
              final angle = (i * 60) * pi / 180;
              final radius = 80.0 + (i % 2 == 0 ? 0 : 10);
              final size = 6.0 + (i % 3) * 3;
              return Positioned(
                left: 100 + cos(angle) * radius - size / 2,
                top: 100 + sin(angle) * radius - size / 2,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: page.accentColor.withValues(alpha: 0.15 + (i % 3) * 0.1),
                  ),
                ),
              );
            }),
            // メインアイコンの背景
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: page.accentColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: page.accentColor.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                page.icon,
                size: 52,
                color: page.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubIcons(_OnboardingPage page) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: page.subIcons.map((icon) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: page.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 22,
            color: page.accentColor.withValues(alpha: 0.6),
          ),
        );
      }).toList(),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final List<IconData> subIcons;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.subIcons,
  });
}
