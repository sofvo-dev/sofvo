import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'post_video_player.dart';

/// タイムライン投稿の画像・動画を Instagram 風の全幅スワイプで表示する。
/// 「比率そのまま（切り取らない）」: フレームの縦横比を最初のメディアに合わせ、
/// 各メディアは contain で全体を表示する（1投稿内が同じ比率なら余白なくピッタリ収まる）。
class PostMediaCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> media; // [{type: 'image'|'video', url}]
  const PostMediaCarousel({super.key, required this.media});

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  final PageController _pageController = PageController();
  int _page = 0;
  double? _aspect; // 幅/高さ。最初のメディアの実比率で確定
  bool _firstIsVideo = false;

  @override
  void initState() {
    super.initState();
    _firstIsVideo = widget.media.isNotEmpty && widget.media.first['type'] == 'video';
    if (!_firstIsVideo) _resolveImageAspect();
  }

  void _setAspect(double ar) {
    if (!mounted || ar <= 0) return;
    // 極端な比率だけレイアウト崩れ防止に緩く制限（通常の縦長/横長は素通し）
    final double clamped = ar.clamp(0.42, 2.5).toDouble();
    if (_aspect == null || (_aspect! - clamped).abs() > 0.001) {
      setState(() => _aspect = clamped);
    }
  }

  void _resolveImageAspect() {
    final url = (widget.media.first['url'] ?? '').toString();
    if (url.isEmpty) return;
    final stream = CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0) _setAspect(w / h);
      stream.removeListener(listener);
    }, onError: (_, __) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullImage(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    // 確定前の暫定比率（動画なら縦長9:16、画像なら縦長4:5）。確定後に差し替わる
    final aspect = _aspect ?? (_firstIsVideo ? (9 / 16) : 0.8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: media.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final m = media[i];
                final url = (m['url'] ?? '').toString();
                if (m['type'] == 'video') {
                  return PostVideoPlayer(
                    url: url,
                    width: double.infinity,
                    height: double.infinity,
                    // 先頭が動画のときは実比率でフレームを合わせる
                    onAspectReady: (i == 0 && _firstIsVideo) ? _setAspect : null,
                  );
                }
                return GestureDetector(
                  onTap: () => _openFullImage(url),
                  child: Container(
                    color: Colors.white,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain, // 比率そのまま（切り取らない）
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) => Container(color: Colors.grey[100]),
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.grey[100], child: const Icon(Icons.broken_image_outlined, color: Colors.grey)),
                    ),
                  ),
                );
              },
            ),
            // 枚数カウンタ（複数のみ）
            if (media.length > 1)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_page + 1}/${media.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            // ドットインジケータ（複数のみ）
            if (media.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    media.length,
                    (i) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? Colors.white : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
