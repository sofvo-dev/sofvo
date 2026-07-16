import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'tournament_summary_data.dart';

class PdfGenerator {
  // ━━━ カラーパレット ━━━
  static const _navy = PdfColor.fromInt(0xFF1B3A5C);
  static const _textDark = PdfColor.fromInt(0xFF212121);
  static const _textMedium = PdfColor.fromInt(0xFF616161);
  static const _divider = PdfColor.fromInt(0xFFE0E0E0);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 大会要項PDF（◆見出し＋箇条書きの正式な要項フォーマット）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<Uint8List> generateTournamentSummary(String tournamentId) async {
    final data = await TournamentSummaryData.build(tournamentId);
    return generateTournamentSummaryFromData(data);
  }

  /// 既に取得済みの [TournamentSummaryData] からPDFを生成する
  /// （画像プレビューと同じデータを使い回して二重取得を避けるための版）。
  Future<Uint8List> generateTournamentSummaryFromData(TournamentSummaryData data) async {
    final font = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox(height: 0, width: 0)
          : _pageHeader(data.title),
      footer: (context) => _pageFooter(context),
      build: (context) => [
        pw.Center(child: pw.Text(data.title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _textDark))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('大会要項',
            style: pw.TextStyle(fontSize: 9, color: _textMedium, letterSpacing: 2))),
        pw.SizedBox(height: 22),

        _reqSection('日程', [pw.Text(data.date, style: _bodyStyle())]),
        _reqSection('会場', [
          pw.Text(data.venueName, style: _bodyStyle()),
          if (data.venueAddress.isNotEmpty || data.venuePhone.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text([
                if (data.venueAddress.isNotEmpty) '住所: ${data.venueAddress}',
                if (data.venuePhone.isNotEmpty) 'TEL: ${data.venuePhone}',
              ].join('　'), style: _bodyStyle(size: 9, color: _textMedium)),
            ),
          if (data.parking > 0)
            pw.Text('駐車場: ${data.parking}台', style: _bodyStyle(size: 9, color: _textMedium)),
        ]),
        _reqSection('時間', data.schedule.map((s) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Text('${s.$1}　・・・・　${s.$2}', style: _bodyStyle()),
        )).toList()),
        _reqSection('大会概要', [
          pw.Wrap(spacing: 22, runSpacing: 4, children: [
            pw.Text('参加チーム数　${data.teamCountText}', style: _bodyStyle()),
            pw.Text('参加費　${data.feeText}', style: _bodyStyle()),
            pw.Text('コート数　${data.courtText}', style: _bodyStyle()),
            pw.Text('種別　${data.typeText}', style: _bodyStyle()),
          ]),
        ]),
        _reqSection('対戦方法', data.matchFormatLines.map((l) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Text(l, style: _bodyStyle()),
        )).toList()),
        if (data.noticeLines.isNotEmpty)
          _reqSection('連絡事項', data.noticeLines.map((l) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text('・$l', style: _bodyStyle()),
          )).toList()),
      ],
    ));
    return pdf.save();
  }

  // ── 要項フォーマット用ヘルパー ──

  /// ◆見出し + インデントされた本文（サンプル要項と同じ構成）
  pw.Widget _reqSection(String label, List<pw.Widget> children) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 92, child: pw.Text('◆$label',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy))),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children)),
      ]),
    );
  }

  pw.TextStyle _bodyStyle({double size = 10, PdfColor color = _textDark}) =>
      pw.TextStyle(fontSize: size, color: color);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 共通ウィジェット
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
