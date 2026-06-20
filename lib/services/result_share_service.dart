import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_theme.dart';
import 'save_image_bytes.dart';
import 'widget_capture.dart';

// ====== 配色・サイズ定数 ======
const double _kCardW = 1080;
const double _kCardH = 1350; // 4:5（Instagram カルーセル推奨）
const Color _kLogoNavy = Color(0xFF2C3E5A);
const Color _kLogoGold = Color(0xFFC4A55A);
const Color _kGoldDeep = Color(0xFFA98B3F);
const Color _kHair = Color(0xFFEEF1F5);

// ====== データモデル ======

class ShareRankingRow {
  final int rank;
  final String teamName;
  final String? note; // 優勝 / 準優勝 / 3位 など（任意）
  const ShareRankingRow({required this.rank, required this.teamName, this.note});
}

class ShareRankingData {
  final String tournamentTitle;
  final String? subtitle; // 日付・会場・全Nチーム など
  final List<ShareRankingRow> rows;
  const ShareRankingData({
    required this.tournamentTitle,
    this.subtitle,
    required this.rows,
  });
}

class ShareMatch {
  final String stageLabel; // 予選 1試合目 / 決勝 など
  final int resultKind; // 1=勝, -1=負, 0=分
  final String myName;
  final String oppName;
  final List<(int, int)> sets; // (自分, 相手)
  final int mySets;
  final int oppSets;
  const ShareMatch({
    required this.stageLabel,
    required this.resultKind,
    required this.myName,
    required this.oppName,
    required this.sets,
    required this.mySets,
    required this.oppSets,
  });
}

class ShareTeamResultData {
  final String teamName;
  final String tournamentTitle;
  final String? subtitle;
  final int? rank;
  final String placeLabel; // 優勝 / 準優勝 / 第3位 / N位
  final String winLoss; // 例 4勝1敗
  final String setWinLoss; // 例 8-4
  final String pointDiff; // 例 +12
  final List<ShareMatch> matches;
  const ShareTeamResultData({
    required this.teamName,
    required this.tournamentTitle,
    this.subtitle,
    this.rank,
    required this.placeLabel,
    required this.winLoss,
    required this.setWinLoss,
    required this.pointDiff,
    required this.matches,
  });
}

// ====== 公開API ======

class ResultShareService {
  /// 大会の順位表を画像で保存（チーム数が多ければ自動で複数枚＋最後にSofvo紹介）。
  static Future<void> saveRanking(BuildContext context, ShareRankingData data) async {
    if (data.rows.isEmpty) {
      _snack(context, '順位がまだ確定していません');
      return;
    }
    final pages = <Widget>[];
    // 1枚目は大きいヘッダーがあるので少なめ(5)にしてゆったり見せ、以降は 9 で分割
    //（行は伸縮するので切れない）
    final chunks = _chunkRanking(data.rows, first: 5, rest: 9);
    for (var i = 0; i < chunks.length; i++) {
      pages.add(_RankingPage(
        data: data,
        rows: chunks[i],
        isFirst: i == 0,
        pageIndex: i + 1,
        pageCount: chunks.length,
      ));
    }
    pages.add(const _SofvoIntroCard());
    await _generateAndSave(context, pages, stem: 'sofvo_ranking');
  }

  /// 自分のチームの対戦結果を画像で保存（タイプを選択）。
  static Future<void> saveTeamResult(BuildContext context, ShareTeamResultData data) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('画像で保存',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: AppTheme.accentColor),
              title: const Text('最終順位だけ（1枚）'),
              subtitle: const Text('順位・通算成績だけのシンプル版'),
              onTap: () => Navigator.pop(ctx, 'simple'),
            ),
            ListTile(
              leading: const Icon(Icons.table_rows, color: AppTheme.primaryColor),
              title: const Text('全試合の詳細'),
              subtitle: const Text('各試合のセットスコア入り（自動で複数枚）'),
              onTap: () => Navigator.pop(ctx, 'detail'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (!context.mounted) return;

    final pages = <Widget>[];
    if (choice == 'simple') {
      pages.add(_TeamResultOnlyCard(data: data));
    } else {
      final chunks = _chunkMatches(data.matches, first: 3, rest: 4);
      if (chunks.isEmpty) {
        pages.add(_TeamResultDetailPage(
          data: data, matches: const [], isFirst: true, pageIndex: 1, pageCount: 1));
      }
      for (var i = 0; i < chunks.length; i++) {
        pages.add(_TeamResultDetailPage(
          data: data,
          matches: chunks[i],
          isFirst: i == 0,
          pageIndex: i + 1,
          pageCount: chunks.length,
        ));
      }
    }
    pages.add(const _SofvoIntroCard());
    await _generateAndSave(context, pages, stem: 'sofvo_team_result');
  }

  // ====== 内部処理 ======

  static Future<void> _generateAndSave(
    BuildContext context,
    List<Widget> pages, {
    required String stem,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
    try {
      // 画像保存用フォント（アプリ全体と同じ Noto Sans JP）をキャプチャ前に
      // 確実にロードしておく。Google Fonts は非同期取得のため、待たずに
      // キャプチャするとシステムフォントにフォールバックして「見た目が違う」
      // 画像になってしまう。
      await _ensureShareFontLoaded();
      var saved = 0;
      for (var i = 0; i < pages.length; i++) {
        if (!context.mounted) break;
        final png = await captureWidgetToPng(
          context,
          // 各 TextStyle は fontFamily を指定していないため、DefaultTextStyle で
          // Noto Sans JP を継承させてアプリ内の表示とフォントを揃える。
          child: DefaultTextStyle(
            style: GoogleFonts.notoSansJp(
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
            child: pages[i],
          ),
          size: const Size(_kCardW, _kCardH),
        );
        await saveImageBytes(png, filename: '${stem}_${i + 1}.png');
        saved++;
      }
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        _snack(context, '$saved枚を写真に保存しました');
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        _snack(context, '画像の保存に失敗しました: $e');
      }
    }
  }

  static List<List<ShareRankingRow>> _chunkRanking(
      List<ShareRankingRow> rows, {required int first, required int rest}) {
    final out = <List<ShareRankingRow>>[];
    var idx = 0;
    while (idx < rows.length) {
      final size = out.isEmpty ? first : rest;
      out.add(rows.sublist(idx, (idx + size).clamp(0, rows.length)));
      idx += size;
    }
    return out;
  }

  static List<List<ShareMatch>> _chunkMatches(
      List<ShareMatch> rows, {required int first, required int rest}) {
    final out = <List<ShareMatch>>[];
    var idx = 0;
    while (idx < rows.length) {
      final size = out.isEmpty ? first : rest;
      out.add(rows.sublist(idx, (idx + size).clamp(0, rows.length)));
      idx += size;
    }
    return out;
  }

  /// 画像保存に使う Noto Sans JP をロード完了まで待つ。
  /// `GoogleFonts.pendingFonts` は対象フォントのダウンロード/登録が
  /// 終わるまで完了しない Future を返す。失敗しても画像保存自体は
  /// 続行する（システムフォントにフォールバック）。
  static Future<void> _ensureShareFontLoaded() async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.notoSansJp(),
        GoogleFonts.notoSansJp(fontWeight: FontWeight.w500),
        GoogleFonts.notoSansJp(fontWeight: FontWeight.bold),
        GoogleFonts.notoSansJp(fontWeight: FontWeight.w800),
        GoogleFonts.notoSansJp(fontWeight: FontWeight.w900),
      ]);
    } catch (_) {
      // フォント取得に失敗しても保存処理は継続する
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

// ====== 共通パーツ ======

class _SofvoLogo extends StatelessWidget {
  final double size;
  const _SofvoLogo({this.size = 40});
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: const [
        TextSpan(text: 'Sof', style: TextStyle(color: _kLogoNavy)),
        TextSpan(text: 'vo', style: TextStyle(color: _kLogoGold)),
      ]),
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.0,
      ),
    );
  }
}

Widget _goldTopBar() => Container(
      height: 18,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accentColor, _kLogoGold]),
      ),
    );

Widget _pageBadge(int index, int count) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$index / $count',
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
    );

// ====== A: 順位表ページ ======

class _RankingPage extends StatelessWidget {
  final ShareRankingData data;
  final List<ShareRankingRow> rows;
  final bool isFirst;
  final int pageIndex;
  final int pageCount;
  const _RankingPage({
    required this.data,
    required this.rows,
    required this.isFirst,
    required this.pageIndex,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _goldTopBar(),
          if (isFirst)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 44, 56, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOFVO TOURNAMENT',
                      style: TextStyle(
                          fontSize: 26,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          color: _kGoldDeep)),
                  const SizedBox(height: 10),
                  Text(data.tournamentTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 56,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor)),
                  if (data.subtitle != null) ...[
                    const SizedBox(height: 12),
                    Text(data.subtitle!,
                        style: const TextStyle(
                            fontSize: 28, color: AppTheme.textSecondary)),
                  ],
                  const SizedBox(height: 22),
                  Row(children: [
                    const Icon(Icons.emoji_events,
                        size: 34, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    const Text('RESULT',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppTheme.primaryColor)),
                    const Spacer(),
                    if (pageCount > 1) _pageBadge(pageIndex, pageCount),
                  ]),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 44, 56, 12),
              child: Row(children: [
                Expanded(
                  child: Text(data.tournamentTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor)),
                ),
                const SizedBox(width: 12),
                if (pageCount > 1) _pageBadge(pageIndex, pageCount),
              ]),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  for (final r in rows) Expanded(child: _row(r)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(ShareRankingRow r) {
    final medalColor = r.rank == 1
        ? const Color(0xFFE0A526)
        : r.rank == 2
            ? const Color(0xFF9AA7AD)
            : r.rank == 3
                ? const Color(0xFFB97A3D)
                : null;
    return Container(
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: Color(0xFFF2F4F7))),
        gradient: r.rank <= 3
            ? LinearGradient(colors: [
                AppTheme.accentColor.withValues(alpha: 0.16),
                Colors.transparent,
              ])
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        SizedBox(
          width: 56,
          child: medalColor != null
              ? Icon(Icons.emoji_events, size: 40, color: medalColor)
              : const SizedBox.shrink(),
        ),
        SizedBox(
          width: 96,
          child: Text('${r.rank}位',
              style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor)),
        ),
        Expanded(
          child: Text(r.teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w500)),
        ),
        if (r.note != null)
          Text(r.note!,
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.bold, color: _kGoldDeep)),
      ]),
    );
  }
}

// ====== B-1: 最終順位だけカード ======

class _TeamResultOnlyCard extends StatelessWidget {
  final ShareTeamResultData data;
  const _TeamResultOnlyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _goldTopBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('SOFVO ・ RESULT',
                      style: TextStyle(
                          fontSize: 28,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          color: _kGoldDeep)),
                  const SizedBox(height: 28),
                  Icon(Icons.emoji_events,
                      size: 160,
                      color: data.rank == 2
                          ? const Color(0xFF9AA7AD)
                          : data.rank == 3
                              ? const Color(0xFFB97A3D)
                              : AppTheme.accentColor),
                  const SizedBox(height: 16),
                  Text(data.placeLabel,
                      style: const TextStyle(
                          fontSize: 96,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 14),
                  Text(data.teamName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 16),
                  Text(
                    [data.tournamentTitle, if (data.subtitle != null) data.subtitle!]
                        .join('\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28, height: 1.4, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 44),
                  _summaryRow(data),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _SofvoLogo(size: 34),
                const Text(' ・ sofvo.com',
                    style: TextStyle(
                        fontSize: 28, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _summaryRow(ShareTeamResultData data) {
  Widget cell(String v, String k) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(children: [
            Text(v,
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor)),
            const SizedBox(height: 6),
            Text(k,
                style: const TextStyle(
                    fontSize: 24, color: AppTheme.textSecondary)),
          ]),
        ),
      );
  Widget divider() => Container(width: 1, height: 72, color: _kHair);
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _kHair),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ],
    ),
    child: Row(children: [
      cell(data.winLoss, '通算成績'),
      divider(),
      cell(data.setWinLoss, 'セット勝敗'),
      divider(),
      cell(data.pointDiff, '得失点'),
    ]),
  );
}

// ====== B-2: 全試合の詳細ページ ======

class _TeamResultDetailPage extends StatelessWidget {
  final ShareTeamResultData data;
  final List<ShareMatch> matches;
  final bool isFirst;
  final int pageIndex;
  final int pageCount;
  const _TeamResultDetailPage({
    required this.data,
    required this.matches,
    required this.isFirst,
    required this.pageIndex,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _goldTopBar(),
          if (isFirst) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 36, 48, 8),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor)),
                      const SizedBox(height: 6),
                      Text(
                        '${data.placeLabel} ・ ${data.tournamentTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 26, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (pageCount > 1) _pageBadge(pageIndex, pageCount),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 8, 48, 8),
              child: _summaryRow(data),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 36, 48, 8),
              child: Row(children: [
                Expanded(
                  child: Text('${data.teamName} ・ 対戦結果',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor)),
                ),
                if (pageCount > 1) _pageBadge(pageIndex, pageCount),
              ]),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 8, 48, 24),
              child: Column(
                children: [
                  for (final m in matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _matchCard(m),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchCard(ShareMatch m) {
    final resultColor = m.resultKind > 0
        ? AppTheme.success
        : m.resultKind < 0
            ? AppTheme.error
            : Colors.grey;
    final resultLabel = m.resultKind > 0
        ? '勝利'
        : m.resultKind < 0
            ? '敗北'
            : '引き分け';
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _kHair),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(m.stageLabel,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(resultLabel,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: resultColor)),
            ),
          ]),
          const SizedBox(height: 14),
          _scoreRow('チーム', [for (var i = 0; i < m.sets.length; i++) 'S${i + 1}'],
              '合計',
              isHeader: true),
          _scoreRow(
            m.myName,
            [for (final s in m.sets) '${s.$1}'],
            '${m.mySets}',
            highlightSets: [for (final s in m.sets) s.$1 > s.$2],
            own: true,
          ),
          _scoreRow(
            m.oppName,
            [for (final s in m.sets) '${s.$2}'],
            '${m.oppSets}',
            highlightSets: [for (final s in m.sets) s.$2 > s.$1],
          ),
        ],
      ),
    );
  }

  Widget _scoreRow(String name, List<String> sets, String total,
      {bool isHeader = false, List<bool>? highlightSets, bool own = false}) {
    final baseStyle = isHeader
        ? const TextStyle(fontSize: 22, color: AppTheme.textSecondary)
        : TextStyle(
            fontSize: 28,
            fontWeight: own ? FontWeight.w900 : FontWeight.w500,
            color: own ? AppTheme.primaryColor : AppTheme.textPrimary,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle),
        ),
        for (var i = 0; i < sets.length; i++)
          SizedBox(
            width: 90,
            child: Text(
              sets[i],
              textAlign: TextAlign.center,
              style: isHeader
                  ? baseStyle
                  : baseStyle.copyWith(
                      color: (highlightSets != null && highlightSets[i])
                          ? AppTheme.success
                          : baseStyle.color),
            ),
          ),
        SizedBox(
          width: 96,
          child: Text(total,
              textAlign: TextAlign.center,
              style: isHeader
                  ? baseStyle
                  : baseStyle.copyWith(
                      fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
        ),
      ]),
    );
  }
}

// ====== 最後のページ: Sofvo紹介 ======

class _SofvoIntroCard extends StatelessWidget {
  const _SofvoIntroCard();

  @override
  Widget build(BuildContext context) {
    Widget feat(IconData icon, String title, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 44, color: AppTheme.accentColor),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor)),
                    const SizedBox(height: 4),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 26, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFFBF8F0)],
        ),
      ),
      child: Column(
        children: [
          _goldTopBar(),
          const SizedBox(height: 60),
          const _SofvoLogo(size: 110),
          const SizedBox(height: 14),
          const Text('ソフトバレーの大会を、もっと簡単に。',
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: _kGoldDeep)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 96),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  feat(Icons.search, '大会をさがす・エントリー', '近くの大会をアプリから申し込み'),
                  feat(Icons.assignment, '対戦表・順位を自動作成', 'スコア入力でリアルタイム集計'),
                  feat(Icons.emoji_events, '結果をシェア', 'この画像もアプリでワンタップ生成'),
                  feat(Icons.groups, 'チーム・仲間とつながる', 'フォローで大会情報をキャッチ'),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 48),
            child: Text('sofvo.com',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}
