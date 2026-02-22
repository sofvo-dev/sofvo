import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfGenerator {
  final _firestore = FirebaseFirestore.instance;

  // ━━━ カラーパレット ━━━
  static const _navy = PdfColor.fromInt(0xFF1B3A5C);
  static const _navyLight = PdfColor.fromInt(0xFFE8EDF3);
  static const _accent = PdfColor.fromInt(0xFF2196F3);
  static const _accentLight = PdfColor.fromInt(0xFFE3F2FD);
  static const _gold = PdfColor.fromInt(0xFFF9A825);
  static const _goldLight = PdfColor.fromInt(0xFFFFF8E1);
  static const _green = PdfColor.fromInt(0xFF43A047);
  static const _greenLight = PdfColor.fromInt(0xFFE8F5E9);
  static const _textDark = PdfColor.fromInt(0xFF212121);
  static const _textMedium = PdfColor.fromInt(0xFF616161);
  static const _divider = PdfColor.fromInt(0xFFE0E0E0);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 大会要項PDF
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
      margin: const pw.EdgeInsets.all(40),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      header: (context) => context.pageNumber == 1 ? pw.SizedBox.shrink() : _pageHeader(t['name'] ?? ''),
      footer: (context) => _pageFooter(context),
      build: (context) => [
        // ── タイトルヘッダー ──
        _buildTitleBanner(t['name'] ?? '\u5927\u4f1a\u8981\u9805'),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text(
          '\u30bd\u30d5\u30c8\u30d0\u30ec\u30fc\u30dc\u30fc\u30eb\u5927\u4f1a\u8981\u9805',
          style: pw.TextStyle(fontSize: 11, color: _textMedium, letterSpacing: 2),
        )),
        pw.SizedBox(height: 24),

        // ── 基本情報 ──
        _sectionCard('\u57FA\u672C\u60C5\u5831', _navy, [
          _infoTable([
            ['\u958B\u50AC\u65E5', t['date'] ?? ''],
            ['\u4F1A\u5834', t['location'] ?? ''],
            if ((t['venueAddress'] ?? '').toString().isNotEmpty)
              ['\u4F4F\u6240', t['venueAddress'] ?? ''],
            ['\u30B3\u30FC\u30C8\u6570', '${t['courts'] ?? 0}\u30B3\u30FC\u30C8'],
            ['\u7A2E\u5225', t['type'] ?? '\u6DF7\u5408'],
            ['\u53C2\u52A0\u8CBB', t['entryFee'] ?? ''],
            ['\u5B9A\u54E1', '${t['maxTeams'] ?? 0}\u30C1\u30FC\u30E0'],
          ]),
        ]),
        pw.SizedBox(height: 16),

        // ── 当日スケジュール ──
        _sectionCard('\u5F53\u65E5\u30B9\u30B1\u30B8\u30E5\u30FC\u30EB', _accent, [
          _scheduleTimeline([
            [t['openTime'] ?? '8:00', '\u958B\u5834'],
            [t['receptionTime'] ?? '8:30', '\u53D7\u4ED8'],
            [t['openingTime'] ?? '9:00', '\u958B\u4F1A\u5F0F'],
            [t['matchStartTime'] ?? '9:15', '\u8A66\u5408\u958B\u59CB'],
            if ((t['lunchTime'] ?? '').toString().isNotEmpty)
              [t['lunchTime'] ?? '', '\u6627\u4F11\u61A9'],
            [t['finalTime'] ?? '14:00', '\u6C7A\u52DD\u4E88\u5B9A'],
            [t['closingTime'] ?? '16:00', '\u9589\u4F1A\u5F0F'],
          ]),
        ]),
        pw.SizedBox(height: 16),

        // ── 大会ルール ──
        _sectionCard('\u5927\u4F1A\u30EB\u30FC\u30EB', _green, [
          _ruleBlock('\u8A66\u5408\u5F62\u5F0F', '15\u70B9\u5148\u53D6'),
          _ruleBlock('\u4E88\u9078', '${preliminary['sets'] ?? 2}\u30BB\u30C3\u30C8\u30DE\u30C3\u30C1'),
          _ruleBlock('\u30B8\u30E5\u30FC\u30B9',
              (preliminary['deuce'] ?? false)
                  ? '\u3042\u308A\uFF08${preliminary['deuceCap'] ?? 17}\u70B9\u30AD\u30E3\u30C3\u30D7\uFF09'
                  : '\u306A\u3057'),
          if ((finalRules['enabled'] ?? false) == true)
            _ruleBlock('\u6C7A\u52DD', '${finalRules['sets'] ?? 3}\u30BB\u30C3\u30C8\u30DE\u30C3\u30C1'),
        ]),

        // ── 勝ち点制 ──
        if (scoring['enabled'] == true) ...[
          pw.SizedBox(height: 16),
          _sectionCard('\u52DD\u3061\u70B9\u5236', _gold, [
            _scoringTable(scoring),
          ]),
        ],
      ],
    ));
    return pdf.save();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 対戦表PDF
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _pageHeader('${t['name'] ?? ""} - \u4E88\u9078$roundNum'),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          pw.Center(child: pw.Text(
            '\u5BFE\u6226\u8868',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _navy),
          )),
          pw.SizedBox(height: 16),
          ...sortedCourts.map((court) {
            final courtNum = court.value.first['courtNumber'] ?? 0;
            final courtLabel = String.fromCharCode(64 + (courtNum as int));
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(height: 12),
              _courtBadge('${courtLabel}\u30B3\u30FC\u30C8'),
              pw.SizedBox(height: 6),
              _matchTable(
                headers: ['#', '\u30C1\u30FC\u30E0A', '\u30B9\u30B3\u30A2', '\u30C1\u30FC\u30E0B', '\u4E3B\u5BE9', '\u526F\u5BE9'],
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
                headerColor: _navyLight,
              ),
            ]);
          }),
        ],
      ));

      // 順位表ページ
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
            pw.SizedBox(height: 14),
            _courtBadge('${courtLabel}\u30B3\u30FC\u30C8 \u9806\u4F4D\u8868'),
            pw.SizedBox(height: 6),
            _matchTable(
              headers: ['\u9806\u4F4D', '\u30C1\u30FC\u30E0', '\u52DD\u70B9', '\u52DD', '\u8CA0', '\u5206', '\u5F97\u5931', '\u7DCF\u5F97\u70B9'],
              data: teamsSnap.docs.asMap().entries.map((e) {
                final s = e.value.data();
                return ['${e.key + 1}', s['teamName'] ?? '', '${s['matchPoints'] ?? 0}',
                  '${s['wins'] ?? 0}', '${s['losses'] ?? 0}', '${s['draws'] ?? 0}',
                  '${s['pointDiff'] ?? 0}', '${s['totalPoints'] ?? 0}'];
              }).toList(),
              headerColor: _goldLight,
              highlightFirst: true,
            ),
          ]);
        }
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (context) => _pageHeader('${t['name'] ?? ""} - \u4E88\u9078$roundNum'),
          footer: (context) => _pageFooter(context),
          build: (context) => [
            pw.Center(child: pw.Text(
              '\u9806\u4F4D\u8868',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _navy),
            )),
            pw.SizedBox(height: 12),
            ...standingsWidgets,
          ],
        ));
      }
    }
    return pdf.save();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // トーナメント表PDF
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _pageHeader(t['name'] ?? ''),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _buildTitleBanner('${bData['bracketName'] ?? "\u6C7A\u52DD"}\u30C8\u30FC\u30CA\u30E1\u30F3\u30C8'),
          pw.SizedBox(height: 20),
          ...matchesSnap.docs.map((mDoc) {
            final m = mDoc.data();
            final result = m['result'] as Map<String, dynamic>? ?? {};
            final status = m['status'] ?? 'pending';
            final roundLabel = m['round'] == 'semi' ? '\u6E96\u6C7A\u52DD' :
                m['round'] == 'final' ? '\u6C7A\u52DD' :
                m['round'] == '3rd' ? '3\u4F4D\u6C7A\u5B9A\u6226' : (m['round'] ?? '');
            final isCompleted = status == 'completed';
            final score = isCompleted
                ? '${result['setsA'] ?? 0} - ${result['setsB'] ?? 0}'
                : (status == 'waiting' ? '\u5F85\u6A5F\u4E2D' : 'vs');

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: _bracketMatchCard(
                roundLabel: roundLabel,
                teamA: m['teamAName'] ?? '',
                teamB: m['teamBName'] ?? '',
                score: score,
                isCompleted: isCompleted,
              ),
            );
          }),
        ],
      ));
    }
    return pdf.save();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 共通ウィジェット
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// タイトルバナー（ネイビー帯）
  pw.Widget _buildTitleBanner(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      )),
    );
  }

  /// セクションカード
  pw.Widget _sectionCard(String title, PdfColor accentColor, List<pw.Widget> children) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _divider, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // セクションヘッダー
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: pw.BoxDecoration(
            color: accentColor,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8),
              topRight: pw.Radius.circular(8),
            ),
          ),
          child: pw.Text(title, style: pw.TextStyle(
            fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
          )),
        ),
        // コンテンツ
        pw.Padding(
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }

  /// 基本情報テーブル（ストライプ行）
  pw.Widget _infoTable(List<List<String>> rows) {
    return pw.Column(children: rows.asMap().entries.map((entry) {
      final isEven = entry.key % 2 == 0;
      return pw.Container(
        color: isEven ? _navyLight : PdfColors.white,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: pw.Row(children: [
          pw.SizedBox(width: 100, child: pw.Text(entry.value[0],
              style: pw.TextStyle(fontSize: 10, color: _textMedium, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(entry.value[1],
              style: pw.TextStyle(fontSize: 11, color: _textDark))),
        ]),
      );
    }).toList());
  }

  /// スケジュール タイムライン
  pw.Widget _scheduleTimeline(List<List<String>> items) {
    return pw.Column(children: items.asMap().entries.map((entry) {
      final isLast = entry.key == items.length - 1;
      return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // 時刻
        pw.SizedBox(width: 60, child: pw.Text(entry.value[0],
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _accent))),
        // ドット+ライン
        pw.Column(children: [
          pw.Container(
            width: 10, height: 10,
            decoration: pw.BoxDecoration(
              color: _accent,
              borderRadius: pw.BorderRadius.circular(5),
            ),
          ),
          if (!isLast) pw.Container(width: 2, height: 20, color: _accentLight),
        ]),
        pw.SizedBox(width: 12),
        // ラベル
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 0),
          child: pw.Text(entry.value[1], style: pw.TextStyle(fontSize: 11, color: _textDark)),
        ),
      ]);
    }).toList());
  }

  /// ルール行
  pw.Widget _ruleBlock(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(children: [
        pw.Container(
          width: 6, height: 6,
          decoration: pw.BoxDecoration(color: _green, borderRadius: pw.BorderRadius.circular(3)),
        ),
        pw.SizedBox(width: 10),
        pw.SizedBox(width: 100, child: pw.Text(label,
            style: pw.TextStyle(fontSize: 10, color: _textMedium))),
        pw.Expanded(child: pw.Text(value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _textDark))),
      ]),
    );
  }

  /// 勝ち点テーブル
  pw.Widget _scoringTable(Map<String, dynamic> scoring) {
    final rows = [
      ['2-0 \u52DD\u3061', '${scoring['win20'] ?? 10}\u70B9'],
      ['1-1 \u5F97\u5931\u5DEE\u52DD\u3061', '${scoring['win11'] ?? 7}\u70B9'],
      ['1-1 \u5F15\u304D\u5206\u3051', '${scoring['draw'] ?? 4}\u70B9'],
      ['1-1 \u5F97\u5931\u5DEE\u8CA0\u3051', '${scoring['lose11'] ?? 2}\u70B9'],
      ['0-2 \u8CA0\u3051', '${scoring['lose02'] ?? 0}\u70B9'],
    ];
    return pw.Row(children: [
      pw.Expanded(child: pw.Column(children: rows.map((r) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _divider, width: 0.5)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(r[0], style: pw.TextStyle(fontSize: 10, color: _textDark)),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: _goldLight,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(r[1], style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _gold)),
            ),
          ]),
        );
      }).toList())),
    ]);
  }

  /// コートバッジ
  pw.Widget _courtBadge(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(label, style: pw.TextStyle(
        fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
      )),
    );
  }

  /// 試合テーブル
  pw.Widget _matchTable({
    required List<String> headers,
    required List<List<String>> data,
    PdfColor headerColor = _navyLight,
    bool highlightFirst = false,
  }) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _divider, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: _navy),
      headerAlignment: pw.Alignment.center,
      cellStyle: pw.TextStyle(fontSize: 10, color: _textDark),
      cellAlignment: pw.Alignment.center,
      headerDecoration: pw.BoxDecoration(color: headerColor),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _divider, width: 0.5))),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFAFA)),
      cellHeight: 28,
      headerHeight: 32,
      headers: headers,
      data: data,
    );
  }

  /// トーナメント対戦カード
  pw.Widget _bracketMatchCard({
    required String roundLabel,
    required String teamA,
    required String teamB,
    required String score,
    required bool isCompleted,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _divider),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(children: [
        // ラウンドラベル
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            color: isCompleted ? _greenLight : _navyLight,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8),
              topRight: pw.Radius.circular(8),
            ),
          ),
          child: pw.Center(child: pw.Text(roundLabel, style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold,
            color: isCompleted ? _green : _navy,
          ))),
        ),
        // チーム vs チーム
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(teamA, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 14),
              decoration: pw.BoxDecoration(
                color: isCompleted ? _navy : _accentLight,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(score, style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold,
                color: isCompleted ? PdfColors.white : _accent,
              )),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(child: pw.Text(teamB, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          ]),
        ),
      ]),
    );
  }

  /// ページヘッダー（2ページ目以降）
  pw.Widget _pageHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1.5)),
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, color: _navy, fontWeight: pw.FontWeight.bold)),
        pw.Text('Sofvo', style: pw.TextStyle(fontSize: 9, color: _textMedium)),
      ]),
    );
  }

  /// ページフッター
  pw.Widget _pageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _divider, width: 0.5)),
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Powered by Sofvo', style: pw.TextStyle(fontSize: 8, color: _textMedium)),
        pw.Text('${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _textMedium)),
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
