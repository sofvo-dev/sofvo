import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfGenerator {
  final _firestore = FirebaseFirestore.instance;

  /// 大会要項PDF
  Future<Uint8List> generateTournamentSummary(String tournamentId) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final t = tournDoc.data() ?? {};
    final rules = t['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final scoring = rules['scoring'] as Map<String, dynamic>? ?? {};
    final finalRules = rules['final'] as Map<String, dynamic>? ?? {};

    final font = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      build: (context) => [
        pw.Header(level: 0, child: pw.Text(t['name'] ?? '大会要項', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 10),
        _pdfSection('基本情報', [
          _pdfRow('開催日', t['date'] ?? ''),
          _pdfRow('会場', t['location'] ?? ''),
          if ((t['venueAddress'] ?? '').toString().isNotEmpty) _pdfRow('住所', t['venueAddress'] ?? ''),
          _pdfRow('コート数', '${t['courts'] ?? 0}コート'),
          _pdfRow('種別', '${t['format'] ?? "4人制"} / ${t['type'] ?? "混合"}'),
          _pdfRow('参加費', t['entryFee'] ?? ''),
          _pdfRow('定員', '${t['maxTeams'] ?? 0}チーム'),
        ]),
        _pdfSection('当日スケジュール', [
          _pdfRow('開場', t['openTime'] ?? '8:00'),
          _pdfRow('受付', t['receptionTime'] ?? '8:30'),
          _pdfRow('開会式', t['openingTime'] ?? '9:00'),
          _pdfRow('試合開始', t['matchStartTime'] ?? '9:15'),
          if ((t['lunchTime'] ?? '').toString().isNotEmpty) _pdfRow('昼休憩', t['lunchTime'] ?? ''),
          _pdfRow('決勝予定', t['finalTime'] ?? '14:00'),
          _pdfRow('閉会式', t['closingTime'] ?? '16:00'),
        ]),
        _pdfSection('大会ルール', [
          _pdfRow('試合形式', '${t['format'] ?? "4人制"}（15点先取）'),
          _pdfRow('予選', '${preliminary['sets'] ?? 2}セットマッチ'),
          _pdfRow('ジュース', (preliminary['deuce'] ?? false) ? 'あり（${preliminary['deuceCap'] ?? 17}点キャップ）' : 'なし'),
          if (scoring['enabled'] == true) ...[
            _pdfRow('勝ち点制', 'あり'),
            _pdfRow('2-0勝ち', '${scoring['win20'] ?? 10}点'),
            _pdfRow('1-1得失差勝ち', '${scoring['win11'] ?? 7}点'),
            _pdfRow('1-1引き分け', '${scoring['draw'] ?? 4}点'),
            _pdfRow('1-1得失差負け', '${scoring['lose11'] ?? 2}点'),
            _pdfRow('0-2負け', '${scoring['lose02'] ?? 0}点'),
          ],
          if ((finalRules['enabled'] ?? false) == true)
            _pdfRow('決勝', '${finalRules['sets'] ?? 3}セットマッチ'),
        ]),
      ],
    ));
    return pdf.save();
  }

  /// 対戦表PDF
  Future<Uint8List> generateMatchTable(String tournamentId) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final t = tournDoc.data() ?? {};
    final font = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();

    final roundsSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').get();

    final pdf = pw.Document();

    for (var roundDoc in roundsSnap.docs) {
      final roundData = roundDoc.data();
      final roundNum = roundData['roundNumber'] ?? 1;
      final matchesSnap = await roundDoc.reference.collection('matches')
          .orderBy('matchOrder').get();

      final courtGroups = <String, List<Map<String, dynamic>>>{};
      for (var m in matchesSnap.docs) {
        final data = m.data();
        final courtId = data['courtId'] ?? '';
        courtGroups.putIfAbsent(courtId, () => []);
        courtGroups[courtId]!.add(data);
      }

      final sortedCourts = courtGroups.entries.toList()
        ..sort((a, b) => ((a.value.first['courtNumber'] ?? 0) as int)
            .compareTo((b.value.first['courtNumber'] ?? 0) as int));

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('${t['name'] ?? ""} - 予選$roundNum 対戦表',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          ...sortedCourts.map((court) {
            final courtNum = court.value.first['courtNumber'] ?? 0;
            final courtLabel = String.fromCharCode(64 + (courtNum as int));
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(height: 10),
              pw.Text('${courtLabel}コート', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headers: ['#', 'チームA', 'スコア', 'チームB', '主審', '副審'],
                data: court.value.map((m) {
                  final result = m['result'] as Map<String, dynamic>? ?? {};
                  final status = m['status'] ?? 'pending';
                  final score = status == 'completed'
                      ? '${result['setsA'] ?? 0}-${result['setsB'] ?? 0}'
                      : 'vs';
                  return [
                    '${m['matchOrder'] ?? ""}',
                    m['teamAName'] ?? '',
                    score,
                    m['teamBName'] ?? '',
                    m['refereeTeamName'] ?? '',
                    m['subRefereeTeamName'] ?? '',
                  ];
                }).toList(),
              ),
            ]);
          }),
        ],
      ));

      // Standings page
      final standingsSnap = await roundDoc.reference.collection('standings').get();
      if (standingsSnap.docs.isNotEmpty) {
        final standingsWidgets = <pw.Widget>[];
        for (var courtDoc in standingsSnap.docs) {
          final courtData = courtDoc.data();
          final courtNum = courtData['courtNumber'] ?? 0;
          final teamsSnap = await courtDoc.reference.collection('teams')
              .orderBy('matchPoints', descending: true).get();
          if (teamsSnap.docs.isEmpty) continue;
          final courtLabel = String.fromCharCode(64 + (courtNum as int));
          standingsWidgets.addAll([
            pw.SizedBox(height: 10),
            pw.Text('${courtLabel}コート 順位表', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.amber50),
              headers: ['順位', 'チーム', '勝点', '勝', '負', '分', '得失', '総得点'],
              data: teamsSnap.docs.asMap().entries.map((e) {
                final s = e.value.data();
                return ['${e.key + 1}', s['teamName'] ?? '', '${s['matchPoints'] ?? 0}',
                  '${s['wins'] ?? 0}', '${s['losses'] ?? 0}', '${s['draws'] ?? 0}',
                  '${s['pointDiff'] ?? 0}', '${s['totalPoints'] ?? 0}'];
              }).toList(),
            ),
          ]);
        }
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          build: (context) => [
            pw.Header(level: 0, child: pw.Text('予選$roundNum 順位表',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            ...standingsWidgets,
          ],
        ));
      }
    }
    return pdf.save();
  }

  /// トーナメント表PDF
  Future<Uint8List> generateBracketPdf(String tournamentId) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final t = tournDoc.data() ?? {};
    final font = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();

    final bracketsSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').get();

    final pdf = pw.Document();

    for (var bDoc in bracketsSnap.docs) {
      final bData = bDoc.data();
      final matchesSnap = await bDoc.reference.collection('matches')
          .orderBy('matchNumber').get();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('${t['name'] ?? ""} - ${bData['bracketName'] ?? "決勝"}トーナメント',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 11),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.amber100),
            headers: ['ラウンド', 'チームA', 'スコア', 'チームB', '状態'],
            data: matchesSnap.docs.map((mDoc) {
              final m = mDoc.data();
              final result = m['result'] as Map<String, dynamic>? ?? {};
              final status = m['status'] ?? 'pending';
              final roundLabel = m['round'] == 'semi' ? '準決勝' :
                  m['round'] == 'final' ? '決勝' :
                  m['round'] == '3rd' ? '3位決定戦' : (m['round'] ?? '');
              final score = status == 'completed'
                  ? '${result['setsA'] ?? 0}-${result['setsB'] ?? 0}'
                  : (status == 'waiting' ? '待機中' : 'vs');
              return [roundLabel, m['teamAName'] ?? '', score, m['teamBName'] ?? '',
                status == 'completed' ? '完了' : (status == 'waiting' ? '待機' : '未')];
            }).toList(),
          ),
        ],
      ));
    }
    return pdf.save();
  }

  // Helper methods
  pw.Widget _pdfSection(String title, List<pw.Widget> children) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(height: 16),
      pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Divider(),
      ...children,
    ]);
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.SizedBox(width: 140, child: pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ]),
    );
  }

  /// Print or share PDF
  static Future<void> printPdf(Uint8List bytes, String title) async {
    await Printing.layoutPdf(onLayout: (_) => bytes, name: title);
  }

  static Future<void> sharePdf(Uint8List bytes, String title) async {
    await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
  }
}
