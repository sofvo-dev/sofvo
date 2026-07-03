import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../config/app_theme.dart';

/// タイムライン投稿内のインライン動画プレビュー。
/// 最初のフレームをサムネイル代わりに表示し、タップでフルスクリーン再生する。
/// （フィード内で多数の動画を自動再生しないことでスクロール負荷・音声の暴発を防ぐ）
class PostVideoPlayer extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  /// 動画の初期化完了時に実際の縦横比(幅/高さ)を通知する（カルーセルの枠決定用）
  final ValueChanged<double>? onAspectReady;

  const PostVideoPlayer({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.onAspectReady,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  Future<void> _initPreview() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = controller;
      await controller.initialize();
      await controller.setVolume(0); // プレビューは無音（最初のフレームのみ）
      if (!mounted) {
        controller.dispose();
        return;
      }
      final ar = controller.value.aspectRatio;
      if (ar > 0) widget.onAspectReady?.call(ar);
      setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(url: widget.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;

    Widget preview;
    if (_initialized && _controller != null) {
      // 比率そのまま（切り取らない）: contain でフレーム内に収める
      preview = FittedBox(
        fit: BoxFit.contain,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      );
    } else if (_failed) {
      preview = const Center(
        child: Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 32),
      );
    } else {
      preview = const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      );
    }

    return GestureDetector(
      onTap: _failed ? null : _openFullscreen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w == double.infinity ? 12 : 10),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black, child: preview),
              // 再生ボタン
              if (!_failed)
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  ),
                ),
              // 動画バッジ
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 3),
                      Text('動画', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// フルスクリーンの動画再生ページ（Chewieで再生・シーク・フルスクリーン対応）
class _FullscreenVideoPage extends StatefulWidget {
  final String url;
  const _FullscreenVideoPage({required this.url});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _videoController = videoController;
      await videoController.initialize();
      if (!mounted) {
        videoController.dispose();
        return;
      }
      _chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        aspectRatio: videoController.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
          handleColor: AppTheme.primaryColor,
        ),
      );
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _failed
            ? const Text('動画を再生できませんでした', style: TextStyle(color: Colors.white70))
            : (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white70),
      ),
    );
  }
}
