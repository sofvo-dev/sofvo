import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_theme.dart';

/// URLのHTMLコンテンツをボトムシートで表示する
void showUrlBottomSheet(BuildContext context, String title, String url) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.85,
      child: Column(
        children: [
          // ── ドラッグハンドル ──
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── タイトルバー ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── コンテンツ ──
          Expanded(
            child: _HtmlContentView(url: url),
          ),
        ],
      ),
    ),
  );
}

class _HtmlContentView extends StatefulWidget {
  final String url;
  const _HtmlContentView({required this.url});

  @override
  State<_HtmlContentView> createState() => _HtmlContentViewState();
}

class _HtmlContentViewState extends State<_HtmlContentView> {
  List<_ContentBlock>? _blocks;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAndParse();
  }

  Future<void> _fetchAndParse() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        final blocks = _parseHtmlToBlocks(response.body);
        if (mounted) setState(() => _blocks = blocks);
      } else {
        if (mounted) setState(() => _error = '読み込みに失敗しました');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '読み込みに失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    if (_blocks == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _blocks!.length,
      itemBuilder: (context, index) {
        final block = _blocks![index];
        switch (block.type) {
          case _BlockType.h1:
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                block.text,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            );
          case _BlockType.h2:
            return Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.accentColor, width: 2),
                  ),
                ),
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  block.text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            );
          case _BlockType.h3:
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          case _BlockType.paragraph:
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                block.text,
                style: const TextStyle(fontSize: 13, height: 1.8),
              ),
            );
          case _BlockType.warning:
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                border: const Border(
                  left: BorderSide(color: Color(0xFFE65100), width: 4),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            );
          case _BlockType.listItem:
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('・ ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      block.text,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            );
          case _BlockType.numberedItem:
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${block.number}.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      block.text,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            );
          case _BlockType.updated:
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                block.text,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textHint,
                ),
              ),
            );
        }
      },
    );
  }
}

enum _BlockType { h1, h2, h3, paragraph, warning, listItem, numberedItem, updated }

class _ContentBlock {
  final _BlockType type;
  final String text;
  final int number;
  _ContentBlock(this.type, this.text, {this.number = 0});
}

/// HTMLの<main>タグ内のコンテンツをパースしてブロックのリストに変換
List<_ContentBlock> _parseHtmlToBlocks(String html) {
  final blocks = <_ContentBlock>[];

  // <main>タグ内のコンテンツのみ抽出
  final mainMatch = RegExp(r'<main[^>]*>([\s\S]*?)</main>').firstMatch(html);
  if (mainMatch == null) return blocks;
  final mainContent = mainMatch.group(1)!;

  // HTMLタグを順番に処理
  final tagPattern = RegExp(
    r'<(h1|h2|h3|p|li|td|th)[^>]*>([\s\S]*?)</\1>',
    caseSensitive: false,
  );

  int olCounter = 0;
  bool inOl = false;

  // ol/ul の開始・終了を追跡
  final elementPattern = RegExp(
    r'<(/?)(\w+)[^>]*>|([^<]+)',
    caseSensitive: false,
  );

  // より単純なアプローチ: 行ごとに処理
  final lines = mainContent.split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.contains('<ol')) {
      inOl = true;
      olCounter = 0;
      continue;
    }
    if (trimmed.contains('</ol>')) {
      inOl = false;
      continue;
    }
    if (trimmed.contains('<ul')) continue;
    if (trimmed.contains('</ul>')) continue;
    if (trimmed.contains('<table')) continue;
    if (trimmed.contains('</table>')) continue;
    if (trimmed.contains('<tr>') || trimmed.contains('</tr>')) continue;

    // 警告ボックス（style付きp）
    if (trimmed.contains('background: #FFF3E0') || trimmed.contains('ゼロトレランス')) {
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) {
        blocks.add(_ContentBlock(_BlockType.warning, text));
      }
      continue;
    }

    if (trimmed.startsWith('<h1')) {
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) blocks.add(_ContentBlock(_BlockType.h1, text));
    } else if (trimmed.startsWith('<h2')) {
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) blocks.add(_ContentBlock(_BlockType.h2, text));
    } else if (trimmed.startsWith('<h3')) {
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) blocks.add(_ContentBlock(_BlockType.h3, text));
    } else if (trimmed.contains('class="updated"')) {
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) blocks.add(_ContentBlock(_BlockType.updated, text));
    } else if (trimmed.startsWith('<p')) {
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) blocks.add(_ContentBlock(_BlockType.paragraph, text));
    } else if (trimmed.startsWith('<li')) {
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) {
        if (inOl) {
          olCounter++;
          blocks.add(_ContentBlock(_BlockType.numberedItem, text, number: olCounter));
        } else {
          blocks.add(_ContentBlock(_BlockType.listItem, text));
        }
      }
    } else if (trimmed.startsWith('<th') || trimmed.startsWith('<td')) {
      // テーブルのセルはパラグラフとして表示
      final text = _stripHtmlTags(trimmed);
      if (text.isNotEmpty) {
        blocks.add(_ContentBlock(_BlockType.paragraph, text));
      }
    }
  }

  return blocks;
}

/// HTMLタグを除去してプレーンテキストにする
String _stripHtmlTags(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&copy;', '\u00A9')
      .replaceAll('&nbsp;', ' ')
      .trim();
}
