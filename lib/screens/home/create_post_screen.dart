import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../services/media_service.dart';
import '../../services/content_filter_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String? badgeName;
  final int? badgeIconCodePoint;
  final int? badgeColorValue;
  final String? tournamentId;
  final String? tournamentName;
  final String? initialText;

  const CreatePostScreen({
    super.key,
    this.badgeName,
    this.badgeIconCodePoint,
    this.badgeColorValue,
    this.tournamentId,
    this.tournamentName,
    this.initialText,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  final List<Uint8List> _imageBytes = [];
  final List<String> _imageNames = [];
  bool _isLoading = false;
  double _uploadProgress = 0;
  String _avatarUrl = '';
  String _nickname = '';

  bool get _hasBadge => widget.badgeName != null;
  bool get _hasTournament => widget.tournamentName != null;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    if (widget.initialText != null) {
      _textController.text = widget.initialText!;
    } else if (_hasBadge) {
      _textController.text = '「${widget.badgeName}」バッジを獲得しました！';
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        final raw = data['avatarUrl'];
        _avatarUrl = (raw is String) ? raw : '';
        final nick = data['nickname'];
        _nickname = (nick is String && nick.isNotEmpty) ? nick : '名無し';
      });
    } catch (_) {
      // Firestore読み込み失敗時はプレースホルダーのまま
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _imageBytes.length;
    if (remaining <= 0) {
      _showSnackBar('画像は最大5枚までです');
      return;
    }

    try {
      final images = await _picker.pickMultiImage(
        imageQuality: MediaService.imageQuality,
        maxWidth: MediaService.imageMaxWidth.toDouble(),
        maxHeight: MediaService.imageMaxHeight.toDouble(),
      );
      if (images.isEmpty || !mounted) return;

      final selected = images.take(remaining).toList();
      var oversized = false;
      var added = false;

      for (final image in selected) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;

        if (!MediaService.validateFileSize(
            bytes.length, maxMB: MediaService.maxImageSizeMB)) {
          oversized = true;
          continue;
        }

        _imageBytes.add(bytes);
        _imageNames.add(image.name);
        added = true;
      }

      if (oversized) {
        _showSnackBar('${MediaService.maxImageSizeMB}MBを超える画像はスキップしました');
      }
      if (images.length > remaining) {
        _showSnackBar('画像は最大5枚までです');
      }

      if (added) setState(() {});
    } catch (e) {
      _showSnackBar('画像の選択に失敗しました: $e', isError: true);
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _imageBytes.length) return;
    setState(() {
      _imageBytes.removeAt(index);
      _imageNames.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _imageBytes.isEmpty) {
      _showSnackBar('テキストまたは画像を追加してください');
      return;
    }

    if (ContentFilterService.containsProhibitedContent(text)) {
      _showSnackBar('不適切な表現が含まれています。内容を修正してください。', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _uploadProgress = 0;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ログインしてください');

      // Authトークンを強制リフレッシュ（expired token対策）
      await user.getIdToken(true);

      // 画像をFirebase Storageに順次アップロード（進捗表示のため）
      final imageUrls = <String>[];
      for (int i = 0; i < _imageBytes.length; i++) {
        final fileName = MediaService.generateFileName(_imageNames[i]);
        final url = await MediaService.uploadImage(
          bytes: _imageBytes[i],
          storagePath: 'post_images/${user.uid}',
          fileName: fileName,
        );
        if (!mounted) return;
        imageUrls.add(url);
        setState(() {
          _uploadProgress = (i + 1) / _imageBytes.length;
        });
      }

      // 投稿をFirestoreに保存（initStateで取得済みのユーザー情報を再利用）
      final postData = <String, dynamic>{
        'userId': user.uid,
        'userNickname': _nickname,
        'userAvatarUrl': _avatarUrl,
        'text': text,
        'images': imageUrls,
        'likesCount': 0,
        'commentsCount': 0,
        'autoGenerated': false,
        'tournamentId': widget.tournamentId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_hasBadge) {
        postData['badgeName'] = widget.badgeName;
        postData['badgeIconCodePoint'] = widget.badgeIconCodePoint;
        postData['badgeColorValue'] = widget.badgeColorValue;
      }

      await FirebaseFirestore.instance.collection('posts').add(postData);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('投稿に失敗しました: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _badgeIconMap = <String, IconData>{
    '初参加': Icons.flag_rounded,
    '5大会参加': Icons.emoji_events_rounded,
    '10大会参加': Icons.emoji_events_rounded,
    '20大会参加': Icons.emoji_events_rounded,
    '初優勝': Icons.military_tech_rounded,
    '3回優勝': Icons.military_tech_rounded,
    '5回優勝': Icons.military_tech_rounded,
    '100Pt達成': Icons.star_rounded,
    '500Pt達成': Icons.star_rounded,
    '1000Pt達成': Icons.diamond_rounded,
    'ガジェット5個': Icons.devices_other_rounded,
    'フォロワー10': Icons.people_rounded,
    'フォロワー50': Icons.people_rounded,
    '投稿10件': Icons.article_rounded,
  };

  Widget _buildBadgePreview() {
    final color = Color(widget.badgeColorValue ?? 0xFF4CAF50);
    final icon = _badgeIconMap[widget.badgeName] ?? Icons.emoji_events_rounded;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 2.5),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.badgeName ?? '',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'バッジ獲得！',
                  style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          Icon(Icons.verified, color: color, size: 28),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('投稿を作成'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, child) {
                final canPost =
                    value.text.trim().isNotEmpty || _imageBytes.isNotEmpty;
                return ElevatedButton(
                  onPressed: _isLoading || !canPost ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            if (_imageBytes.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                            ],
                          ],
                        )
                      : const Text('投稿する'),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _avatarUrl.isNotEmpty
                          ? CircleAvatar(
                              radius: 22,
                              backgroundImage:
                                  CachedNetworkImageProvider(_avatarUrl),
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                            )
                          : CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                              child: Text(
                                _nickname.isNotEmpty ? _nickname[0] : '?',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          minLines: 5,
                          maxLength: 500,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          decoration: InputDecoration(
                            hintText: _hasTournament
                                ? '大会の感想を書いてみましょう！\n楽しかったこと、印象に残った試合など'
                                : '今日の大会はどうでしたか？\nチームメンバー募集中？\n近況を投稿してみましょう！',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: AppTheme.textHint,
                              height: 1.5,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            filled: true,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ── 大会感想ラベル ──
                  if (_hasTournament) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.emoji_events, size: 18, color: AppTheme.accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.tournamentName!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('の感想', style: TextStyle(fontSize: 13, color: AppTheme.accentColor)),
                        ],
                      ),
                    ),
                  ],
                  // ── バッジプレビュー ──
                  if (_hasBadge) ...[
                    const SizedBox(height: 16),
                    _buildBadgePreview(),
                  ],
                  // ── 画像プレビュー ──
                  if (_imageBytes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _imageBytes.length,
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _imageBytes[index],
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── ボトムツールバー ──
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap:
                        _imageBytes.length >= 5 ? null : _pickImages,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _imageBytes.length >= 5
                            ? Colors.grey[100]
                            : AppTheme.primaryColor
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: _imageBytes.length >= 5
                                ? AppTheme.textHint
                                : AppTheme.primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _imageBytes.isEmpty
                                ? '画像を追加'
                                : '${_imageBytes.length}/5枚',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _imageBytes.length >= 5
                                  ? AppTheme.textHint
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textController,
                    builder: (context, value, child) {
                      return Text(
                        '${value.text.length} / 500',
                        style: TextStyle(
                          fontSize: 13,
                          color: value.text.length > 450
                              ? AppTheme.warning
                              : AppTheme.textHint,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
