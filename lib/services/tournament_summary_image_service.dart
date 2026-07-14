import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_theme.dart';
import 'tournament_summary_data.dart';
import 'widget_capture.dart';

/// 大会要項の画像版（PDF版と同じ ◆見出し＋箇条書きレイアウト）を生成する。
class TournamentSummaryImageService {
  static Future<Uint8List> renderPng(BuildContext context, TournamentSummaryData data) async {
    await _ensureFontLoaded();
    if (!context.mounted) throw StateError('画面が閉じられました');
    return captureWidgetToPngAutoHeight(
      context,
      child: DefaultTextStyle(
        style: GoogleFonts.notoSansJp(color: AppTheme.textPrimary, height: 1.3),
        child: TournamentSummaryDocument(data: data),
      ),
      width: 1240,
      pixelRatio: 1.5,
    );
  }

  static Future<void> _ensureFontLoaded() async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.notoSansJp(),
        GoogleFonts.notoSansJp(fontWeight: FontWeight.bold),
      ]);
    } catch (_) {
      // フォント取得に失敗しても画像化は継続する
    }
  }
}

/// 要項ドキュメント本体（プレビュー画面にもそのまま表示できる）
class TournamentSummaryDocument extends StatelessWidget {
  final TournamentSummaryData data;
  const TournamentSummaryDocument({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text('大会要項',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, letterSpacing: 3, color: AppTheme.textSecondary)),
        const SizedBox(height: 30),

        _section('日程', [Text(data.date, style: _body())]),
        _section('会場', [
          Text(data.venueName, style: _body()),
          if (data.venueAddress.isNotEmpty || data.venuePhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text([
                if (data.venueAddress.isNotEmpty) '住所: ${data.venueAddress}',
                if (data.venuePhone.isNotEmpty) 'TEL: ${data.venuePhone}',
              ].join('　'), style: _body(size: 13, color: AppTheme.textSecondary)),
            ),
          if (data.parking > 0)
            Text('駐車場: ${data.parking}台', style: _body(size: 13, color: AppTheme.textSecondary)),
        ]),
        _section('時間', [
          for (final s in data.schedule)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${s.$1}　・・・・　${s.$2}', style: _body()),
            ),
        ]),
        _section('大会概要', [
          Wrap(spacing: 28, runSpacing: 6, children: [
            Text('参加チーム数　${data.teamCountText}', style: _body()),
            Text('参加費　${data.feeText}', style: _body()),
            Text('コート数　${data.courtText}', style: _body()),
            Text('種別　${data.typeText}', style: _body()),
          ]),
        ]),
        _section('対戦方法', [
          for (final l in data.matchFormatLines)
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l, style: _body())),
        ]),
        if (data.noticeLines.isNotEmpty)
          _section('連絡事項', [
            for (final l in data.noticeLines)
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('・$l', style: _body())),
          ]),

        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFE0E0E0)),
        const SizedBox(height: 10),
        Text('Powered by Sofvo', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]),
    );
  }

  TextStyle _body({double size = 14, Color color = AppTheme.textPrimary}) =>
      TextStyle(fontSize: size, color: color);

  Widget _section(String label, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 116,
          child: Text('◆$label',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ]),
    );
  }
}
