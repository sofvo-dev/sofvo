// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: uri_does_not_exist
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

int _iframeCounter = 0;

/// Web環境ではボトムシート内にiframeで表示
void showUrlBottomSheet(BuildContext context, String title, String url) {
  final viewType = 'url-iframe-${_iframeCounter++}';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    },
  );

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
          // ── iframe コンテンツ ──
          Expanded(
            child: HtmlElementView(viewType: viewType),
          ),
        ],
      ),
    ),
  );
}
