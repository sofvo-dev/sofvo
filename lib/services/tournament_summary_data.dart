import 'package:cloud_firestore/cloud_firestore.dart';

/// 大会要項（PDF／画像）の元になるデータ。
/// Firestore から1回だけ読み取り、PDF版・画像版の両方の描画コードで共有する。
class TournamentSummaryData {
  final String title;
  final String date;
  final String venueName;
  final String venueAddress;
  final String venuePhone;
  final int parking;
  final List<(String, String)> schedule;
  final String teamCountText;
  final String feeText;
  final String courtText;
  final String typeText;
  final List<String> matchFormatLines;
  final List<String> noticeLines;

  const TournamentSummaryData({
    required this.title,
    required this.date,
    required this.venueName,
    required this.venueAddress,
    required this.venuePhone,
    required this.parking,
    required this.schedule,
    required this.teamCountText,
    required this.feeText,
    required this.courtText,
    required this.typeText,
    required this.matchFormatLines,
    required this.noticeLines,
  });

  static Future<TournamentSummaryData> build(String tournamentId) async {
    final firestore = FirebaseFirestore.instance;
    final tournDoc = await firestore.collection('tournaments').doc(tournamentId).get();
    final t = tournDoc.data() ?? {};
    final rules = t['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final scoring = rules['scoring'] as Map<String, dynamic>? ?? {};
    final finalRules = rules['final'] as Map<String, dynamic>? ?? {};
    final other = rules['other'] as Map<String, dynamic>? ?? {};

    String venuePhone = '';
    int parking = 0;
    final venueId = (t['venueId'] ?? '').toString();
    if (venueId.isNotEmpty) {
      final venueDoc = await firestore.collection('venues').doc(venueId).get();
      final v = venueDoc.data();
      if (v != null) {
        venuePhone = (v['phone'] ?? '').toString();
        parking = (v['parking'] as num?)?.toInt() ?? 0;
      }
    }

    final entryFee = t['entryFee'];
    final feeText = entryFee is int ? '¥$entryFee' : (entryFee ?? '').toString();

    return TournamentSummaryData(
      title: (t['name'] ?? t['title'] ?? '大会要項').toString(),
      date: (t['date'] ?? '').toString(),
      venueName: (t['location'] ?? '').toString(),
      venueAddress: (t['venueAddress'] ?? '').toString(),
      venuePhone: venuePhone,
      parking: parking,
      schedule: [
        ((t['openTime'] ?? '8:00').toString(), '開場'),
        ((t['receptionTime'] ?? '8:30').toString(), '受付'),
        ((t['captainMeetingTime'] ?? '8:45').toString(), 'キャプテン会議'),
        ((t['openingTime'] ?? '9:00').toString(), '開会式'),
        ((t['matchStartTime'] ?? '9:15').toString(), '試合開始'),
        ((t['finalTime'] ?? '15:00').toString(), '試合終了'),
        ((t['closingTime'] ?? '15:30').toString(), '撤収完了'),
      ],
      teamCountText: '${t['maxTeams'] ?? 0}チーム',
      feeText: feeText,
      courtText: '${t['courts'] ?? 0}コート',
      typeText: (t['type'] ?? '混合').toString(),
      matchFormatLines: _buildMatchFormatLines(preliminary, scoring, finalRules),
      noticeLines: _buildNoticeLines(other),
    );
  }

  static List<String> _buildMatchFormatLines(
    Map<String, dynamic> preliminary,
    Map<String, dynamic> scoring,
    Map<String, dynamic> finalRules,
  ) {
    final lines = <String>[];
    final prelimSets = preliminary['sets'] ?? 2;
    final prelimDeuce = preliminary['deuce'] == true;
    final deuceCap = preliminary['deuceCap'] ?? 17;
    lines.add('・予選: 15点先取${prelimSets}セットマッチ'
        '（デュース${prelimDeuce ? "あり（$deuceCap点キャップ）" : "なし"}）');

    if (scoring['enabled'] == true) {
      lines.add('　予選の順位は勝ち点制で決定します（勝ち点が同点の場合は得失点差）');
      lines.add('　${_scoringSummary(prelimSets, scoring)}');
    } else {
      lines.add('　予選の順位は勝敗数で決定します（同数の場合は得失点差）');
    }

    if (finalRules['enabled'] == true) {
      final finalSets = finalRules['sets'] ?? 3;
      final finalDeuce = finalRules['deuce'] == true;
      final finalDeuceCap = finalRules['deuceCap'] ?? 17;
      final format = finalRules['format'] ?? '順位別複数';
      lines.add('・決勝トーナメント: ${finalSets}セットマッチ'
          '（デュース${finalDeuce ? "あり（$finalDeuceCap点キャップ）" : "なし"}）');
      if (format == '順位別複数') {
        final tierCount = finalRules['tierCount'] ?? 3;
        const tierLabels = {1: '区分なし', 2: '上位・下位', 3: '上位・中位・下位', 4: '上位・中位①・中位②・下位'};
        lines.add('　予選順位を${tierLabels[tierCount] ?? "複数の区分"}に分けてトーナメントを行います');
      } else {
        lines.add('　全チームで1つのトーナメントを行います');
      }
    }
    return lines;
  }

  static String _scoringSummary(int sets, Map<String, dynamic> scoring) {
    switch (sets) {
      case 1:
        return '勝利 = ${scoring['win'] ?? 3}点　敗北 = ${scoring['lose'] ?? 0}点';
      case 3:
        return '2-0 = ${scoring['win20'] ?? 10}点　2-1 = ${scoring['win21'] ?? 7}点　'
            '1-2 = ${scoring['lose12'] ?? 2}点　0-2 = ${scoring['lose02'] ?? 0}点';
      default:
        return '2-0 = ${scoring['win20'] ?? 10}点　1-1(得失点差勝ち) = ${scoring['win11'] ?? 7}点　'
            '1-1(同点) = ${scoring['draw'] ?? 4}点　1-1(得失点差負け) = ${scoring['lose11'] ?? 2}点　'
            '0-2 = ${scoring['lose02'] ?? 0}点';
    }
  }

  static List<String> _buildNoticeLines(Map<String, dynamic> other) {
    final lines = <String>[];
    if (other['uniformRequired'] == true) {
      lines.add('番号付きのユニフォームで参加をお願いします。');
    }
    if (other['snsVideoAllowed'] == false) {
      lines.add('撮影した動画について、不特定多数の方が閲覧可能なSNS等への投稿は禁止とします。');
    }
    final lunchBreak = (other['lunchBreak'] ?? 'なし').toString();
    if (lunchBreak != 'なし' && lunchBreak.isNotEmpty) {
      lines.add('昼休憩は$lunchBreakを設けます。');
    } else {
      lines.add('長時間の昼休憩は設けないため、各チーム空き時間で昼食をとっていただくようお願いします。');
    }
    return lines;
  }
}
