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
  // 大会要項PDF（1枚に収める）
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
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // ── タイトルバナー ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            pw.Text(t['name'] ?? '\u5927\u4F1A\u8981\u9805',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 2),
            pw.Text('\u30BD\u30D5\u30C8\u30D0\u30EC\u30FC\u30DC\u30FC\u30EB\u5927\u4F1A\u8981\u9805',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFFB0BEC5), letterSpacing: 1.5)),
          ]),
        ),
        pw.SizedBox(height: 14),

        // ── 上段: 基本情報（左） + スケジュール（右） ──
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          // 左カラム: 基本情報
          pw.Expanded(flex: 5, child: _sectionCardCompact('\u57FA\u672C\u60C5\u5831', _navy, [
            _compactRow('\u958B\u50AC\u65E5', t['date'] ?? ''),
            _compactRow('\u4F1A\u5834', t['location'] ?? ''),
            if ((t['venueAddress'] ?? '').toString().isNotEmpty)
              _compactRow('\u4F4F\u6240', t['venueAddress'] ?? ''),
            _compactRow('\u30B3\u30FC\u30C8\u6570', '${t['courts'] ?? 0}\u30B3\u30FC\u30C8'),
            _compactRow('\u7A2E\u5225', t['type'] ?? '\u6DF7\u5408'),
            _compactRow('\u53C2\u52A0\u8CBB', (() { final f = t['entryFee']; return f is int ? '\u00A5$f' : (f ?? '').toString(); })()),
            _compactRow('\u5B9A\u54E1', '${t['maxTeams'] ?? 0}\u30C1\u30FC\u30E0'),
          ])),
          pw.SizedBox(width: 12),
          // 右カラム: スケジュール
          pw.Expanded(flex: 4, child: _sectionCardCompact('\u5F53\u65E5\u30B9\u30B1\u30B8\u30E5\u30FC\u30EB', _accent, [
            _scheduleRow(t['openTime'] ?? '8:00', '会場'),
            _scheduleRow(t['receptionTime'] ?? '8:30', '受付'),
            _scheduleRow(t['captainMeetingTime'] ?? '8:45', 'チームキャプテン会議'),
            _scheduleRow(t['openingTime'] ?? '9:00', '開会式'),
            _scheduleRow(t['matchStartTime'] ?? '9:15', '試合開始'),
            _scheduleRow(t['finalTime'] ?? '15:00', '終了'),
            _scheduleRow(t['closingTime'] ?? '15:30', '完全撤退'),
          ])),
        ]),
        pw.SizedBox(height: 12),

        // ── 中段: ルール（左） + 勝ち点（右、あれば） ──
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 5, child: _sectionCardCompact('\u5927\u4F1A\u30EB\u30FC\u30EB', _green, [
            _compactRow('\u8A66\u5408\u5F62\u5F0F', '15\u70B9\u5148\u53D6'),
            _compactRow('\u4E88\u9078', '${preliminary['sets'] ?? 2}\u30BB\u30C3\u30C8\u30DE\u30C3\u30C1'),
            _compactRow('\u30B8\u30E5\u30FC\u30B9',
                (preliminary['deuce'] ?? false)
                    ? '\u3042\u308A\uFF08${preliminary['deuceCap'] ?? 17}\u70B9\u30AD\u30E3\u30C3\u30D7\uFF09'
                    : '\u306A\u3057'),
            if ((finalRules['enabled'] ?? false) == true)
              _compactRow('\u6C7A\u52DD', '${finalRules['sets'] ?? 3}\u30BB\u30C3\u30C8\u30DE\u30C3\u30C1'),
          ])),
          if (scoring['enabled'] == true) ...[
            pw.SizedBox(width: 12),
            pw.Expanded(flex: 4, child: _sectionCardCompact('\u52DD\u3061\u70B9\u5236', _gold,
              _pdfScoringRows(preliminary['sets'] ?? 2, scoring),
            )),
          ],
        ]),
        pw.Spacer(),

        // ── フッター ──
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _divider, width: 0.5)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Powered by Sofvo', style: pw.TextStyle(fontSize: 7, color: _textMedium)),
            pw.Text('\u203B\u5185\u5BB9\u306F\u5909\u66F4\u306B\u306A\u308B\u5834\u5408\u304C\u3042\u308A\u307E\u3059',
                style: pw.TextStyle(fontSize: 7, color: _textMedium)),
          ]),
        ),
      ]),
    ));
    return pdf.save();
  }

  // ── 要項用コンパクトヘルパー ──

  pw.Widget _sectionCardCompact(String title, PdfColor accentColor, List<pw.Widget> children) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _divider, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: accentColor,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(6),
              topRight: pw.Radius.circular(6),
            ),
          ),
          child: pw.Text(title, style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
          )),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }

  pw.Widget _compactRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(children: [
        pw.SizedBox(width: 70, child: pw.Text(label,
            style: pw.TextStyle(fontSize: 8, color: _textMedium))),
        pw.Expanded(child: pw.Text(value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark))),
      ]),
    );
  }

  pw.Widget _scheduleRow(String time, String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(children: [
        pw.Container(
          width: 50,
          padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          decoration: pw.BoxDecoration(
            color: _accentLight,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(time, style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: _accent),
              textAlign: pw.TextAlign.center),
        ),
        pw.SizedBox(width: 8),
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _textDark)),
      ]),
    );
  }

  List<pw.Widget> _pdfScoringRows(int sets, Map<String, dynamic> scoring) {
    switch (sets) {
      case 1:
        return [
          _scoringRow('\u52DD\u5229', '${scoring['win'] ?? 3}\u70B9'),
          _scoringRow('\u6557\u5317', '${scoring['lose'] ?? 0}\u70B9'),
        ];
      case 3:
        return [
          _scoringRow('2-0 \u52DD\u3061', '${scoring['win20'] ?? 10}\u70B9'),
          _scoringRow('2-1 \u52DD\u3061', '${scoring['win21'] ?? 7}\u70B9'),
          _scoringRow('1-2 \u8CA0\u3051', '${scoring['lose12'] ?? 2}\u70B9'),
          _scoringRow('0-2 \u8CA0\u3051', '${scoring['lose02'] ?? 0}\u70B9'),
        ];
      default:
        return [
          _scoringRow('2-0 \u52DD\u3061', '${scoring['win20'] ?? 10}\u70B9'),
          _scoringRow('1-1 \u5F97\u5931\u5DEE\u52DD\u3061', '${scoring['win11'] ?? 7}\u70B9'),
          _scoringRow('1-1 \u5F15\u304D\u5206\u3051', '${scoring['draw'] ?? 4}\u70B9'),
          _scoringRow('1-1 \u5F97\u5931\u5DEE\u8CA0\u3051', '${scoring['lose11'] ?? 2}\u70B9'),
          _scoringRow('0-2 \u8CA0\u3051', '${scoring['lose02'] ?? 0}\u70B9'),
        ];
    }
  }

  pw.Widget _scoringRow(String label, String pts) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _textDark)),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: _goldLight,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(pts, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _gold)),
        ),
      ]),
    );
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
                data: court.value.map<List<String>>((m) {
                  final result = m['result'] as Map<String, dynamic>? ?? {};
                  final status = m['status'] ?? 'pending';
                  final score = status == 'completed'
                      ? '${result['setsA'] ?? 0}-${result['setsB'] ?? 0}'
                      : 'vs';
                  return [
                    '${m['matchOrder'] ?? ""}',
                    (m['teamAName'] ?? '') as String,
                    score,
                    (m['teamBName'] ?? '') as String,
                    (m['refereeTeamName'] ?? '') as String,
                    (m['subRefereeTeamName'] ?? '') as String,
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
              data: teamsSnap.docs.asMap().entries.map<List<String>>((e) {
                final s = e.value.data();
                return ['${e.key + 1}', (s['teamName'] ?? '') as String, '${s['matchPoints'] ?? 0}',
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

      final bracketName = bData['bracketName'] ?? '\u9806\u4F4D\u6C7A\u5B9A';

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _pageHeader(t['name'] ?? ''),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _buildTitleBanner('$bracketName\u30C8\u30FC\u30CA\u30E1\u30F3\u30C8'),
          pw.SizedBox(height: 20),
          ...matchesSnap.docs.map((mDoc) {
            final m = mDoc.data();
            final result = m['result'] as Map<String, dynamic>? ?? {};
            final status = m['status'] ?? 'pending';
            final roundLabel = m['round'] == 'semi' ? '\u6E96\u6C7A\u52DD' :
                m['round'] == 'final' ? '\u6C7A\u52DD' : '';
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
