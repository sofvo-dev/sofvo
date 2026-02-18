import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamName;
  final bool isMain;
  final bool isOwner;

  const TeamDetailScreen({
    super.key,
    required this.teamName,
    this.isMain = false,
    this.isOwner = false,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  late List<Map<String, dynamic>> _members;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _members = widget.teamName == 'サンダース'
        ? [
            {'name': '自分', 'role': 'オーナー', 'experience': '5〜10年', 'isMe': true},
            {'name': 'たけし', 'role': 'メンバー', 'experience': '10年以上', 'isMe': false},
            {'name': 'ゆうた', 'role': 'メンバー', 'experience': '3〜5年', 'isMe': false},
            {'name': 'けんじ', 'role': 'メンバー', 'experience': '3〜5年', 'isMe': false},
            {'name': 'さとし', 'role': 'メンバー', 'experience': '1〜3年', 'isMe': false},
            {'name': 'りょう', 'role': 'メンバー', 'experience': '10年以上', 'isMe': false},
          ]
        : [
            {'name': '自分', 'role': 'メンバー', 'experience': '5〜10年', 'isMe': true},
            {'name': 'ゆうき', 'role': 'オーナー', 'experience': '3〜5年', 'isMe': false},
            {'name': 'あきら', 'role': 'メンバー', 'experience': '3〜5年', 'isMe': false},
            {'name': 'りく', 'role': 'メンバー', 'experience': '1年未満', 'isMe': false},
          ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.teamName),
        actions: [
          if (widget.isOwner)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = !_isEditing),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'leave') _showLeaveDialog();
              else if (value == 'delete') _showDeleteDialog();
            },
            itemBuilder: (context) => [
              if (!widget.isOwner)
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(children: [
                    Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('チームを脱退', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              if (widget.isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('チームを削除', style: TextStyle(color: Colors.red)),
                  ]),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTeamInfoCard(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('メンバー',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_members.length}人',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
              ),
              const Spacer(),
              if (widget.isOwner)
                TextButton.icon(
                  onPressed: () => _showInviteSheet(),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('招待'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: List.generate(_members.length, (index) {
                final member = _members[index];
                return Column(
                  children: [
                    if (index > 0)
                      Divider(
                          height: 1, indent: 72, color: Colors.grey[100]),
                    _buildMemberTile(member, index),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          _buildTeamStatsCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTeamInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(widget.teamName[0],
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(widget.teamName,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary)),
                        ),
                        if (widget.isMain) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('メイン',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentColor)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('メンバー ${_members.length}人',
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem(
                  Icons.location_on_outlined, 'エリア', '東京都')),
              Expanded(child: _buildInfoItem(
                  Icons.calendar_today_outlined, '作成日', '2024/10/15')),
              Expanded(child: _buildInfoItem(
                  Icons.emoji_events_outlined, '参加大会', '3回')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, int index) {
    final isOwner = member['role'] == 'オーナー';
    final isMe = member['isMe'] == true;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: isOwner
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : AppTheme.primaryColor.withValues(alpha: 0.12),
        child: Text(member['name'][0],
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isOwner
                    ? AppTheme.accentColor
                    : AppTheme.primaryColor)),
      ),
      title: Row(
        children: [
          Text(member['name'],
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          if (isMe) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('あなた',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ),
          ],
          const SizedBox(width: 6),
          if (isOwner)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('オーナー',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor)),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('競技歴 ${member['experience']}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ),
      trailing: _isEditing && !isMe && widget.isOwner
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'promote') {
                  setState(() => _members[index]['role'] = 'オーナー');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${member['name']}さんをオーナーに変更しました')),
                  );
                } else if (value == 'remove') {
                  _showRemoveMemberDialog(member, index);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'promote', child: Text('オーナーに変更')),
                const PopupMenuItem(
                    value: 'remove',
                    child: Text('メンバーを除外',
                        style: TextStyle(color: Colors.red))),
              ],
            )
          : null,
    );
  }

  Widget _buildTeamStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('チーム戦績',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem(
                  '参加大会', '3', AppTheme.primaryColor)),
              Expanded(child: _buildStatItem(
                  '優勝', '1', AppTheme.accentColor)),
              Expanded(child: _buildStatItem(
                  '勝率', '67%', AppTheme.success)),
              Expanded(child: _buildStatItem(
                  '通算ポイント', '450', AppTheme.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  void _showInviteSheet() {
    final followUsers = [
      {'name': 'たけし', 'experience': '10年以上', 'isMember': true},
      {'name': 'ゆうた', 'experience': '3〜5年', 'isMember': true},
      {'name': 'みさき', 'experience': '3〜5年', 'isMember': false},
      {'name': 'はるか', 'experience': '1年未満', 'isMember': false},
      {'name': 'だいき', 'experience': '10年以上', 'isMember': false},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('メンバーを招待',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('フォロー中のユーザーから招待できます',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: followUsers.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey[100]),
                          itemBuilder: (context, index) {
                            final u = followUsers[index];
                            final isMember = u['isMember'] as bool;
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.12),
                                child: Text(
                                    (u['name'] as String)[0],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor)),
                              ),
                              title: Text(u['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '競技歴 ${u['experience']}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              trailing: isMember
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text('参加済み',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme
                                                  .textSecondary)),
                                    )
                                  : ElevatedButton(
                                      onPressed: () {
                                        setSheetState(() {
                                          followUsers[index] = {
                                            ...u,
                                            'isMember': true,
                                          };
                                        });
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              '${u['name']}さんに招待を送りました'),
                                          behavior:
                                              SnackBarBehavior.floating,
                                        ));
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.primaryColor,
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('招待',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white)),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRemoveMemberDialog(Map<String, dynamic> member, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('メンバーを除外',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('${member['name']}さんをチームから除外しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _members.removeAt(index));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${member['name']}さんを除外しました')),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                minimumSize: const Size(100, 40)),
            child: const Text('除外する'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('チームを脱退',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('${widget.teamName}から脱退しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${widget.teamName}から脱退しました')),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                minimumSize: const Size(100, 40)),
            child: const Text('脱退する'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('チームを削除',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('${widget.teamName}を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${widget.teamName}を削除しました')),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                minimumSize: const Size(100, 40)),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }
}
