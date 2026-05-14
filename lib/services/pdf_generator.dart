import 'dart:typed_data';
import 'dart:math' as math;
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
  static const _white = PdfColors.white;

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
            pw.Text(t['name'] ?? t['title'] ?? '大会要項',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _white)),
            pw.SizedBox(height: 2),
            pw.Text('ソフトバレーボール大会要項',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFFB0BEC5), letterSpacing: 1.5)),
          ]),
        ),
        pw.SizedBox(height: 14),

        // ── 上段: 基本情報（左） + スケジュール（右） ──
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 5, child: _sectionCardCompact('基本情報', _navy, [
            _compactRow('開催日', t['date'] ?? ''),
            _compactRow('会場', t['location'] ?? ''),
            if ((t['venueAddress'] ?? '').toString().isNotEmpty)
              _compactRow('住所', t['venueAddress'] ?? ''),
            _compactRow('コート数', '${t['courts'] ?? 0}コート'),
            _compactRow('種別', t['type'] ?? '混合'),
            _compactRow('参加費', (() { final f = t['entryFee']; return f is int ? '¥$f' : (f ?? '').toString(); })()),
            _compactRow('定員', '${t['maxTeams'] ?? 0}チーム'),
          ])),
          pw.SizedBox(width: 12),
          pw.Expanded(flex: 4, child: _sectionCardCompact('当日スケジュール', _accent, [
            _scheduleRow(t['openTime'] ?? '8:00', '会場'),
            _scheduleRow(t['receptionTime'] ?? '8:30', '受付'),
            _scheduleRow(t['captainMeetingTime'] ?? '8:45', 'キャプテン会議'),
            _scheduleRow(t['openingTime'] ?? '9:00', '開会式'),
            _scheduleRow(t['matchStartTime'] ?? '9:15', '試合開始'),
            _scheduleRow(t['finalTime'] ?? '15:00', '終了'),
            _scheduleRow(t['closingTime'] ?? '15:30', '完全撤退'),
          ])),
        ]),
        pw.SizedBox(height: 12),

        // ── 中段: ルール（左） + 勝ち点（右、あれば） ──
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 5, child: _sectionCardCompact('大会ルール', _green, [
            _compactRow('試合形式', '15点先取'),
            _compactRow('予選', '${preliminary['sets'] ?? 2}セットマッチ'),
            _compactRow('ジュース',
                (preliminary['deuce'] ?? false)
                    ? 'あり（${preliminary['deuceCap'] ?? 17}点キャップ）'
                    : 'なし'),
            if ((finalRules['enabled'] ?? false) == true)
              _compactRow('決勝', '${finalRules['sets'] ?? 3}セットマッチ'),
          ])),
          if (scoring['enabled'] == true) ...[
            pw.SizedBox(width: 12),
            pw.Expanded(flex: 4, child: _sectionCardCompact('勝ち点制', _gold,
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
            pw.Text('※内容は変更になる場合があります',
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
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: _white,
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
          _scoringRow('勝利', '${scoring['win'] ?? 3}点'),
          _scoringRow('敗北', '${scoring['lose'] ?? 0}点'),
        ];
      case 3:
        return [
          _scoringRow('2-0 勝ち', '${scoring['win20'] ?? 10}点'),
          _scoringRow('2-1 勝ち', '${scoring['win21'] ?? 7}点'),
          _scoringRow('1-2 負け', '${scoring['lose12'] ?? 2}点'),
          _scoringRow('0-2 負け', '${scoring['lose02'] ?? 0}点'),
        ];
      default:
        return [
          _scoringRow('2-0 勝ち', '${scoring['win20'] ?? 10}点'),
          _scoringRow('1-1 得失差勝ち', '${scoring['win11'] ?? 7}点'),
          _scoringRow('1-1 引き分け', '${scoring['draw'] ?? 4}点'),
          _scoringRow('1-1 得失差負け', '${scoring['lose11'] ?? 2}点'),
          _scoringRow('0-2 負け', '${scoring['lose02'] ?? 0}点'),
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
  // 対戦表PDF（縦向き A4）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<Uint8List> generateMatchTable(String tournamentId) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final t = tournDoc.data() ?? {};
    final font = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();
    final tournamentName = t['name'] ?? t['title'] ?? '';

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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _pageHeader('$tournamentName - 予選$roundNum'),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _buildTitleBanner('対戦表 - 予選$roundNum'),
          pw.SizedBox(height: 14),
          ...sortedCourts.map((court) {
            final courtNum = court.value.first['courtNumber'] ?? 0;
            final courtLabel = String.fromCharCode(64 + (courtNum as int));
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(height: 10),
              _courtBadge('${courtLabel}コート'),
              pw.SizedBox(height: 6),
              _matchTablePortrait(court.value),
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
            pw.SizedBox(height: 12),
            _courtBadge('${courtLabel}コート 順位表'),
            pw.SizedBox(height: 6),
            _standingsTable(teamsSnap.docs),
          ]);
        }
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (context) => _pageHeader('$tournamentName - 予選$roundNum'),
          footer: (context) => _pageFooter(context),
          build: (context) => [
            _buildTitleBanner('順位表 - 予選$roundNum'),
            pw.SizedBox(height: 10),
            ...standingsWidgets,
          ],
        ));
      }
    }
    return pdf.save();
  }

  /// 対戦表（縦向き用）
  pw.Widget _matchTablePortrait(List<Map<String, dynamic>> matches) {
    return pw.Table(
      border: pw.TableBorder.all(color: _divider, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FlexColumnWidth(3),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navyLight),
          children: ['#', 'チームA', 'スコア', 'チームB', '審判'].map((h) =>
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy),
                  textAlign: pw.TextAlign.center),
            ),
          ).toList(),
        ),
        // データ行
        ...matches.asMap().entries.map((e) {
          final i = e.key;
          final m = e.value;
          final result = m['result'] as Map<String, dynamic>? ?? {};
          final status = m['status'] ?? 'pending';
          final score = status == 'completed'
              ? '${result['setsA'] ?? 0}-${result['setsB'] ?? 0}'
              : 'vs';
          final bg = i.isOdd ? PdfColor.fromInt(0xFFFAFAFA) : _white;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _tableCell('${m['matchOrder'] ?? ""}', fontSize: 8),
              _tableCell((m['teamAName'] ?? '') as String, fontSize: 8, bold: true),
              _tableCell(score, fontSize: 8, color: status == 'completed' ? _navy : _textMedium),
              _tableCell((m['teamBName'] ?? '') as String, fontSize: 8, bold: true),
              _tableCell((m['refereeTeamName'] ?? '') as String, fontSize: 7),
            ],
          );
        }),
      ],
    );
  }

  /// 順位表
  pw.Widget _standingsTable(List<QueryDocumentSnapshot> docs) {
    return pw.Table(
      border: pw.TableBorder.all(color: _divider, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(36),
        3: const pw.FixedColumnWidth(28),
        4: const pw.FixedColumnWidth(28),
        5: const pw.FixedColumnWidth(32),
        6: const pw.FixedColumnWidth(36),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _goldLight),
          children: ['順位', 'チーム', '勝点', '勝', '負', '得失', '総得点'].map((h) =>
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _navy),
                  textAlign: pw.TextAlign.center),
            ),
          ).toList(),
        ),
        ...docs.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value.data() as Map<String, dynamic>;
          final isFirst = i == 0;
          final bg = isFirst ? PdfColor.fromInt(0xFFFFF8E1) : (i.isOdd ? PdfColor.fromInt(0xFFFAFAFA) : _white);
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _tableCell('${i + 1}', fontSize: 8, bold: isFirst, color: isFirst ? _gold : _textDark),
              _tableCell((s['teamName'] ?? '') as String, fontSize: 8, bold: isFirst),
              _tableCell('${s['matchPoints'] ?? 0}', fontSize: 8, bold: true),
              _tableCell('${s['wins'] ?? 0}', fontSize: 8),
              _tableCell('${s['losses'] ?? 0}', fontSize: 8),
              _tableCell('${s['pointDiff'] ?? 0}', fontSize: 8),
              _tableCell('${s['totalPoints'] ?? 0}', fontSize: 8),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableCell(String text, {double fontSize = 9, bool bold = false, PdfColor color = _textDark}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      child: pw.Text(text,
        style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // トーナメント表PDF（ツリー形式・縦向き A4）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<Uint8List> generateBracketPdf(String tournamentId) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final t = tournDoc.data() ?? {};
    final font = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();
    final tournamentName = t['name'] ?? t['title'] ?? '';

    final bracketsSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').orderBy('bracketNumber').get();

    final pdf = pw.Document();

    for (var bDoc in bracketsSnap.docs) {
      final bData = bDoc.data();
      final matchesSnap = await bDoc.reference.collection('matches')
          .orderBy('matchNumber').get();

      final bracketName = _toFullLeagueName(bData['bracketName'] as String? ?? '順位決定');
      final teamCount = bData['teamCount'] as int? ?? 0;
      final matches = <Map<String, dynamic>>[];
      for (var mDoc in matchesSnap.docs) {
        matches.add(mDoc.data());
      }

      if (teamCount >= 8) {
        // 8チームSE: ツリー形式（勝者側 + 敗者側別ページ）
        _add8TeamBracketPages(pdf, font, fontBold, tournamentName, bracketName, matches);
      } else if (teamCount >= 4) {
        // 4チームSE: ツリー形式
        _add4TeamBracketPage(pdf, font, fontBold, tournamentName, bracketName, matches);
      } else {
        // 3チーム以下: リスト形式
        _addSimpleBracketPage(pdf, font, fontBold, tournamentName, bracketName, matches);
      }
    }
    return pdf.save();
  }

  /// 8チームSEトーナメント — 1ページに全順位決定戦を表示
  /// 上→下の自然な流れ: QF → SF → 決勝
  void _add8TeamBracketPages(
    pw.Document pdf, pw.Font font, pw.Font fontBold,
    String tournamentName, String bracketName, List<Map<String, dynamic>> matches,
  ) {
    final qfMatches = matches.where((m) => m['round'] == 'qf').toList()
      ..sort((a, b) => (a['matchNumber'] as int? ?? 0).compareTo(b['matchNumber'] as int? ?? 0));
    final sfWinner = matches.where((m) => m['round'] == 'sf_winner').toList()
      ..sort((a, b) => (a['matchNumber'] as int? ?? 0).compareTo(b['matchNumber'] as int? ?? 0));
    final sfLoser = matches.where((m) => m['round'] == 'sf_loser').toList()
      ..sort((a, b) => (a['matchNumber'] as int? ?? 0).compareTo(b['matchNumber'] as int? ?? 0));
    final final1st = matches.where((m) => m['round'] == 'final_1st').firstOrNull;
    final final3rd = matches.where((m) => m['round'] == 'final_3rd').firstOrNull;
    final final5th = matches.where((m) => m['round'] == 'final_5th').firstOrNull;
    final final7th = matches.where((m) => m['round'] == 'final_7th').firstOrNull;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      build: (context) {
        return pw.Column(children: [
          _buildTitleBanner('$bracketNameトーナメント'),
          pw.SizedBox(height: 8),

          // ━━━ 準々決勝 ━━━
          _sectionHeader('準々決勝'),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(child: qfMatches.isNotEmpty
                ? _matchBox(qfMatches[0], label: '①', compact: true)
                : pw.SizedBox()),
            pw.SizedBox(width: 4),
            pw.Expanded(child: qfMatches.length > 1
                ? _matchBox(qfMatches[1], label: '②', compact: true)
                : pw.SizedBox()),
            pw.SizedBox(width: 4),
            pw.Expanded(child: qfMatches.length > 2
                ? _matchBox(qfMatches[2], label: '③', compact: true)
                : pw.SizedBox()),
            pw.SizedBox(width: 4),
            pw.Expanded(child: qfMatches.length > 3
                ? _matchBox(qfMatches[3], label: '④', compact: true)
                : pw.SizedBox()),
          ]),
          pw.SizedBox(height: 4),
          _connectorDown4(),
          pw.SizedBox(height: 6),

          // ━━━ 準決勝 ━━━
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // 勝者準決勝
            pw.Expanded(flex: 1, child: pw.Column(children: [
              _sectionHeader('準決勝（勝者）'),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Expanded(child: sfWinner.isNotEmpty
                    ? _matchBox(sfWinner[0], label: '①勝 vs ②勝', compact: true) : pw.SizedBox()),
                pw.SizedBox(width: 4),
                pw.Expanded(child: sfWinner.length > 1
                    ? _matchBox(sfWinner[1], label: '③勝 vs ④勝', compact: true) : pw.SizedBox()),
              ]),
            ])),
            pw.SizedBox(width: 12),
            // 敗者準決勝
            pw.Expanded(flex: 1, child: pw.Column(children: [
              _sectionHeader('準決勝（敗者）'),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Expanded(child: sfLoser.isNotEmpty
                    ? _matchBox(sfLoser[0], label: '①負 vs ②負', compact: true) : pw.SizedBox()),
                pw.SizedBox(width: 4),
                pw.Expanded(child: sfLoser.length > 1
                    ? _matchBox(sfLoser[1], label: '③負 vs ④負', compact: true) : pw.SizedBox()),
              ]),
            ])),
          ]),
          pw.SizedBox(height: 6),
          _connectorDown4(),
          pw.SizedBox(height: 6),

          // ━━━ 順位決定戦 ━━━
          _sectionHeader('順位決定戦'),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(child: final7th != null
                ? _matchBox(final7th, label: '7位決定戦', compact: true)
                : pw.SizedBox()),
            pw.SizedBox(width: 4),
            pw.Expanded(child: final5th != null
                ? _matchBox(final5th, label: '5位決定戦', compact: true)
                : pw.SizedBox()),
            pw.SizedBox(width: 4),
            pw.Expanded(child: final3rd != null
                ? _matchBox(final3rd, label: '3位決定戦', compact: true)
                : pw.SizedBox()),
            pw.SizedBox(width: 4),
            pw.Expanded(child: final1st != null
                ? _matchBox(final1st, label: '決勝（1-2位）', highlight: true, compact: true)
                : pw.SizedBox()),
          ]),
          pw.SizedBox(height: 12),

          // ━━━ 対戦フロー図 ━━━
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F5F5),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _divider),
            ),
            child: pw.Column(children: [
              pw.Text('対戦フロー', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _flowLine('QF① 勝者 ┐'),
                  _flowLine('            ├→ 準決勝（勝者①）→ 勝→ 決勝（1-2位）'),
                  _flowLine('QF② 勝者 ┘                  └ 負→ 3位決定戦'),
                  pw.SizedBox(height: 3),
                  _flowLine('QF③ 勝者 ┐'),
                  _flowLine('            ├→ 準決勝（勝者②）→ 勝→ 決勝（1-2位）'),
                  _flowLine('QF④ 勝者 ┘                  └ 負→ 3位決定戦'),
                  pw.SizedBox(height: 6),
                  _flowLine('QF① 敗者 ┐'),
                  _flowLine('            ├→ 準決勝（敗者①）→ 勝→ 5位決定戦'),
                  _flowLine('QF② 敗者 ┘                  └ 負→ 7位決定戦'),
                  pw.SizedBox(height: 3),
                  _flowLine('QF③ 敗者 ┐'),
                  _flowLine('            ├→ 準決勝（敗者②）→ 勝→ 5位決定戦'),
                  _flowLine('QF④ 敗者 ┘                  └ 負→ 7位決定戦'),
                ])),
              ]),
            ]),
          ),

          pw.Spacer(),
          _footerLine(),
        ]);
      },
    ));
  }

  /// 4チームSEトーナメント — 上→下の自然な流れ
  void _add4TeamBracketPage(
    pw.Document pdf, pw.Font font, pw.Font fontBold,
    String tournamentName, String bracketName, List<Map<String, dynamic>> matches,
  ) {
    final semiMatches = matches.where((m) => m['round'] == 'semi').toList()
      ..sort((a, b) => (a['matchNumber'] as int? ?? 0).compareTo(b['matchNumber'] as int? ?? 0));
    final final1st = matches.where((m) => m['round'] == 'final_1st' || m['round'] == 'final').firstOrNull;
    final final3rd = matches.where((m) => m['round'] == 'final_3rd').firstOrNull;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      build: (context) {
        return pw.Column(children: [
          _buildTitleBanner('$bracketNameトーナメント'),
          pw.SizedBox(height: 16),

          // ━━━ 準決勝 ━━━
          _sectionHeader('準決勝'),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: semiMatches.isNotEmpty
                ? _matchBox(semiMatches[0], label: '準決勝①') : pw.SizedBox()),
            pw.SizedBox(width: 20),
            pw.Expanded(child: semiMatches.length > 1
                ? _matchBox(semiMatches[1], label: '準決勝②') : pw.SizedBox()),
          ]),
          pw.SizedBox(height: 6),
          _connectorDown2(),
          pw.SizedBox(height: 10),

          // ━━━ 順位決定戦 ━━━
          _sectionHeader('順位決定戦'),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: final3rd != null
                ? _matchBox(final3rd, label: '3位決定戦')
                : pw.SizedBox()),
            pw.SizedBox(width: 20),
            pw.Expanded(child: final1st != null
                ? _matchBox(final1st, label: '決勝（1-2位）', highlight: true)
                : pw.SizedBox()),
          ]),
          pw.SizedBox(height: 16),

          // フロー図
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F5F5),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _divider),
            ),
            child: pw.Column(children: [
              pw.Text('対戦フロー', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(height: 4),
              _flowLine('準決勝①の勝者 ┐'),
              _flowLine('                    ├→ 決勝（1-2位）'),
              _flowLine('準決勝②の勝者 ┘'),
              pw.SizedBox(height: 3),
              _flowLine('準決勝①の敗者 ┐'),
              _flowLine('                    ├→ 3位決定戦'),
              _flowLine('準決勝②の敗者 ┘'),
            ]),
          ),

          pw.Spacer(),
          _footerLine(),
        ]);
      },
    ));
  }

  /// 3チーム以下: シンプルリスト形式
  void _addSimpleBracketPage(
    pw.Document pdf, pw.Font font, pw.Font fontBold,
    String tournamentName, String bracketName, List<Map<String, dynamic>> matches,
  ) {
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      header: (context) => _pageHeader(tournamentName),
      footer: (context) => _pageFooter(context),
      build: (context) => [
        _buildTitleBanner('$bracketNameトーナメント'),
        pw.SizedBox(height: 16),
        ...matches.map((m) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: _matchBox(m, label: m['label'] as String? ?? ''),
          );
        }),
      ],
    ));
  }

  /// 旧名称（上/中/下）をフルネームに変換
  String _toFullLeagueName(String name) {
    const map = {
      '上': '上位リーグ', '中': '中位リーグ', '下': '下位リーグ',
      '中①': '中位①リーグ', '中②': '中位②リーグ',
    };
    return map[name] ?? name;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ブラケット用ウィジェット
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 試合ボックス
  pw.Widget _matchBox(Map<String, dynamic> m, {String? label, bool highlight = false, bool compact = false}) {
    final result = m['result'] as Map<String, dynamic>? ?? {};
    final status = m['status'] ?? 'pending';
    final isCompleted = status == 'completed';
    final winnerId = result['winner'] ?? '';
    final teamAName = (m['teamAName'] ?? '') as String;
    final teamBName = (m['teamBName'] ?? '') as String;
    final teamAId = (m['teamAId'] ?? '') as String;
    final teamBId = (m['teamBId'] ?? '') as String;
    final aWon = isCompleted && winnerId == teamAId && teamAId.isNotEmpty;
    final bWon = isCompleted && winnerId == teamBId && teamBId.isNotEmpty;
    final score = isCompleted
        ? '${result['setsA'] ?? 0} - ${result['setsB'] ?? 0}'
        : (status == 'waiting' ? '待機中' : 'vs');

    final borderColor = highlight ? _gold : (isCompleted ? _green : _divider);
    final vPad = compact ? 6.0 : 8.0;
    final fontSize = compact ? 7.0 : 9.0;
    final labelSize = compact ? 6.0 : 7.0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: highlight ? 1.5 : 0.8),
        borderRadius: pw.BorderRadius.circular(6),
        color: _white,
      ),
      child: pw.Column(children: [
        // ラベル
        if (label != null && label.isNotEmpty)
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: pw.BoxDecoration(
              color: highlight ? _goldLight : (isCompleted ? _greenLight : _navyLight),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(label, style: pw.TextStyle(
              fontSize: labelSize, fontWeight: pw.FontWeight.bold,
              color: highlight ? _gold : (isCompleted ? _green : _navy),
            ), textAlign: pw.TextAlign.center),
          ),
        // チームA
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: vPad, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: aWon ? PdfColor.fromInt(0xFFE8F5E9) : _white,
            border: const pw.Border(bottom: pw.BorderSide(color: _divider, width: 0.3)),
          ),
          child: pw.Row(children: [
            if (aWon) pw.Text('◎ ', style: pw.TextStyle(fontSize: fontSize, color: _green, fontWeight: pw.FontWeight.bold)),
            pw.Expanded(child: pw.Text(teamAName, style: pw.TextStyle(
              fontSize: fontSize, fontWeight: aWon ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: aWon ? _green : _textDark,
            ))),
            if (isCompleted) pw.Text('${result['setsA'] ?? 0}', style: pw.TextStyle(
              fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: _navy)),
          ]),
        ),
        // チームB
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: vPad, horizontal: 8),
          child: pw.Row(children: [
            if (bWon) pw.Text('◎ ', style: pw.TextStyle(fontSize: fontSize, color: _green, fontWeight: pw.FontWeight.bold)),
            pw.Expanded(child: pw.Text(teamBName, style: pw.TextStyle(
              fontSize: fontSize, fontWeight: bWon ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: bWon ? _green : _textDark,
            ))),
            if (isCompleted) pw.Text('${result['setsB'] ?? 0}', style: pw.TextStyle(
              fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: _navy)),
            if (!isCompleted) pw.Text(score, style: pw.TextStyle(fontSize: fontSize - 1, color: _textMedium)),
          ]),
        ),
      ]),
    );
  }

  /// 王冠アイコン
  pw.Widget _crownIcon() {
    return pw.Center(
      child: pw.Container(
        width: 36, height: 36,
        decoration: pw.BoxDecoration(
          color: _goldLight,
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: _gold, width: 1.5),
        ),
        child: pw.Center(child: pw.Text('👑', style: pw.TextStyle(fontSize: 16))),
      ),
    );
  }

  /// セクションヘッダー
  pw.Widget _sectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _navyLight,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy), textAlign: pw.TextAlign.center),
    );
  }

  /// フロー説明テキスト
  pw.Widget _flowLine(String text) {
    return pw.Text(text, style: pw.TextStyle(fontSize: 7, color: _textMedium));
  }

  /// 下方向コネクタ（4分岐 → 2分岐）
  pw.Widget _connectorDown4() {
    return pw.CustomPaint(
      size: const PdfPoint(0, 12),
      painter: (canvas, size) {
        final paint = PdfColor.fromInt(0xFFBDBDBD);
        canvas.setStrokeColor(paint);
        canvas.setLineWidth(0.6);
        // 下方向の矢印線
        final midX = size.x / 2;
        canvas.drawLine(midX, 0, midX, size.y);
        canvas.strokePath();
        // 横線
        canvas.drawLine(size.x * 0.15, size.y * 0.5, size.x * 0.85, size.y * 0.5);
        canvas.strokePath();
      },
    );
  }

  /// 下方向コネクタ（2分岐）
  pw.Widget _connectorDown2() {
    return pw.CustomPaint(
      size: const PdfPoint(0, 16),
      painter: (canvas, size) {
        final paint = PdfColor.fromInt(0xFFBDBDBD);
        final midX = size.x / 2;
        // 中央から左右に線
        canvas.drawLine(size.x * 0.25, 0, size.x * 0.75, 0);
        canvas.setStrokeColor(paint);
        canvas.setLineWidth(0.8);
        canvas.strokePath();
        // 左の縦線
        canvas.drawLine(size.x * 0.25, 0, size.x * 0.25, size.y);
        canvas.strokePath();
        // 右の縦線
        canvas.drawLine(size.x * 0.75, 0, size.x * 0.75, size.y);
        canvas.strokePath();
        // 中央の縦線（上へ）
        canvas.drawLine(midX, 0, midX, -4);
        canvas.strokePath();
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 共通ウィジェット
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// タイトルバナー（ネイビー帯）
  pw.Widget _buildTitleBanner(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _white),
      )),
    );
  }

  /// コートバッジ
  pw.Widget _courtBadge(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(label, style: pw.TextStyle(
        fontSize: 10, fontWeight: pw.FontWeight.bold, color: _white,
      )),
    );
  }

  /// フッターライン
  pw.Widget _footerLine() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _divider, width: 0.5)),
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Powered by Sofvo', style: pw.TextStyle(fontSize: 7, color: _textMedium)),
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

  /// チェックイン掲示用（大会名・QR画像・URL）の1枚PDF
  static Future<Uint8List> buildCheckInQrPosterPdf({
    required String tournamentName,
    required String checkInUrl,
    required Uint8List qrPngBytes,
  }) async {
    final font = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();
    final img = pw.MemoryImage(qrPngBytes);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (c) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('チェックイン',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _textDark)),
            pw.SizedBox(height: 10),
            pw.Text(tournamentName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 14, color: _textDark)),
            pw.SizedBox(height: 28),
            pw.Center(child: pw.Image(img, width: 200, height: 200)),
            pw.SizedBox(height: 20),
            pw.Text(
              'SofvoアプリでこのQRコードをスキャンしてください',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 11, color: _textMedium),
            ),
            pw.SizedBox(height: 10),
            pw.Text(checkInUrl,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8.5, color: _textDark)),
            pw.Spacer(),
            pw.Text('Powered by Sofvo', style: pw.TextStyle(fontSize: 8, color: _textMedium)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Print or share PDF
  static Future<void> printPdf(Uint8List bytes, String title) async {
    await Printing.layoutPdf(onLayout: (_) => bytes, name: title);
  }

  static Future<void> sharePdf(Uint8List bytes, String title) async {
    await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
  }
}
