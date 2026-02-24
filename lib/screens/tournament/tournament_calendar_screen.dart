import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'tournament_detail_screen.dart';

class TournamentCalendarScreen extends StatefulWidget {
  const TournamentCalendarScreen({super.key});

  @override
  State<TournamentCalendarScreen> createState() => _TournamentCalendarScreenState();
}

class _TournamentCalendarScreenState extends State<TournamentCalendarScreen> {
  final _firestore = FirebaseFirestore.instance;
  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // 自分がエントリーした大会を取得
    final allTournaments = await _firestore.collection('tournaments').get();

    final myTournaments = <Map<String, dynamic>>[];
    for (final doc in allTournaments.docs) {
      final data = doc.data();
      // 主催者 or エントリー済み
      if (data['organizerId'] == uid ||
          (data['entryTeamIds'] is List && (data['entryTeamIds'] as List).isNotEmpty)) {
        // エントリーを確認
        final entries = await _firestore
            .collection('tournaments').doc(doc.id)
            .collection('entries').where('enteredBy', isEqualTo: uid).get();
        if (data['organizerId'] == uid || entries.docs.isNotEmpty) {
          myTournaments.add({...data, 'id': doc.id, 'name': data['title'] ?? ''});
        }
      }
    }

    final eventsByDate = <String, List<Map<String, dynamic>>>{};
    for (final t in myTournaments) {
      final date = t['date'] as String? ?? '';
      if (date.isNotEmpty) {
        eventsByDate.putIfAbsent(date, () => []);
        eventsByDate[date]!.add(t);
      }
    }

    if (mounted) {
      setState(() {
        _eventsByDate
          ..clear()
          ..addAll(eventsByDate);
        _loading = false;
      });
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('マイ大会')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadTournaments,
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCalendar(),
                  const SizedBox(height: 16),
                  _buildSelectedDateEvents(),
                  const SizedBox(height: 16),
                  _buildUpcomingSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // 日曜=0
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // ヘッダー: 月の移動
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
              ),
              Text(
                '$year年$month月',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 曜日ヘッダー
          Row(
            children: ['日', '月', '火', '水', '木', '金', '土'].map((d) {
              final color = d == '日' ? AppTheme.error : d == '土' ? AppTheme.info : AppTheme.textSecondary;
              return Expanded(
                child: Center(
                  child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // カレンダーグリッド
          ...List.generate(6, (week) {
            return Row(
              children: List.generate(7, (weekday) {
                final dayIndex = week * 7 + weekday - firstWeekday + 1;
                if (dayIndex < 1 || dayIndex > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 44));
                }

                final dateKey = _formatDateKey(DateTime(year, month, dayIndex));
                final hasEvent = _eventsByDate.containsKey(dateKey);
                final isToday = today.year == year && today.month == month && today.day == dayIndex;
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == year &&
                    _selectedDate!.month == month &&
                    _selectedDate!.day == dayIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = DateTime(year, month, dayIndex);
                      });
                    },
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : isToday
                                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayIndex',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isToday || hasEvent ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : weekday == 0
                                      ? AppTheme.error
                                      : weekday == 6
                                          ? AppTheme.info
                                          : AppTheme.textPrimary,
                            ),
                          ),
                          if (hasEvent)
                            Container(
                              width: 6, height: 6,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedDateEvents() {
    if (_selectedDate == null) return const SizedBox.shrink();
    final dateKey = _formatDateKey(_selectedDate!);
    final events = _eventsByDate[dateKey] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedDate!.month}/${_selectedDate!.day}の大会',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('この日の大会はありません', style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
            ),
          )
        else
          ...events.map((t) => _buildTournamentCard(t)),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];
    _eventsByDate.forEach((dateStr, tournaments) {
      final date = _parseDate(dateStr);
      if (!date.isBefore(DateTime(now.year, now.month, now.day))) {
        upcoming.addAll(tournaments);
      }
    });
    upcoming.sort((a, b) {
      final da = a['date'] as String? ?? '';
      final db = b['date'] as String? ?? '';
      return da.compareTo(db);
    });

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今後の大会',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        ...upcoming.take(10).map((t) => _buildTournamentCard(t)),
      ],
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> t) {
    final title = t['title'] ?? t['name'] ?? '無名大会';
    final date = t['date'] ?? '';
    final location = t['location'] ?? '';
    final status = t['status'] ?? '準備中';
    final isOrganizer = t['organizerId'] == FirebaseAuth.instance.currentUser?.uid;

    Color statusColor;
    switch (status) {
      case '募集中': statusColor = AppTheme.success; break;
      case '準備中': statusColor = AppTheme.warning; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      case '決勝中': statusColor = Colors.amber; break;
      case '順位決定中': statusColor = Colors.amber; break;
      default: statusColor = AppTheme.textSecondary;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: t)),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // 日付カラム
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.split('/').length >= 2 ? date.split('/')[1] : '',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  Text(
                    date.split('/').length >= 3 ? date.split('/')[2] : '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(location, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isOrganizer)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('主催', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}
