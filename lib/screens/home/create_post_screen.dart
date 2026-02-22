import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../services/media_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String? badgeName;
  final int? badgeIconCodePoint;
  final int? badgeColorValue;
  final String? tournamentId;
  final String? tournamentName;

  const CreatePostScreen({
    super.key,
    this.badgeName,
    this.badgeIconCodePoint,
    this.badgeColorValue,
    this.tournamentId,
    this.tournamentName,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  final List<Uint8List> _imageBytes = [];
  final List<String> _imageNames = [];
  bool _isLoading = false;

  bool get _hasBadge => widget.badgeName != null;
  bool get _hasTournament => widget.tournamentName != null;

  @override
  void initState() {
    super.initState();
    if (_hasBadge) {
      _textController.text = '「${widget.badgeName}」バッジを獲得しました！';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_imageBytes.length >= 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('無料プランでは画像は最大2枚までです'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: MediaService.imageQuality,
        maxWidth: MediaService.imageMaxWidth.toDouble(),
        maxHeight: MediaService.imageMaxHeight.toDouble(),
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!MediaService.validateFileSize(
          bytes.length, maxMB: MediaService.maxImageSizeMB)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '画像サイズが${MediaService.maxImageSizeMB}MBを超えています'),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
        return;
      }

      setState(() {
        _imageBytes.add(bytes);
        _imageNames.add(image.name);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の選択に失敗しました: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageBytes.removeAt(index);
      _imageNames.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _imageBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('テキストまたは画像を追加してください'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ログインしてください');

      // ユーザー情報取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      String safeString(dynamic value) {
        if (value is String) return value;
        if (value is Map) return value.values.join(' ');
        return value?.toString() ?? '';
      }

      final nickname = safeString(userData['nickname']).isEmpty
          ? '名無し'
          : safeString(userData['nickname']);

      // 画像をFirebase Storageに並列アップロード
      final uploadFutures = <Future<String>>[];
      for (int i = 0; i < _imageBytes.length; i++) {
        final fileName = MediaService.generateFileName(_imageNames[i]);
        uploadFutures.add(MediaService.uploadImage(
          bytes: _imageBytes[i],
          storagePath: 'post_images/${user.uid}',
          fileName: fileName,
        ));
      }
      final imageUrls = await Future.wait(uploadFutures);

      // 投稿をFirestoreに保存
      final postData = <String, dynamic>{
        'userId': user.uid,
        'userNickname': nickname,
        'userAvatarUrl': safeString(userData['avatarUrl']),
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

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('投稿に失敗しました: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
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
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
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
    final canPost =
        _textController.text.trim().isNotEmpty || _imageBytes.isNotEmpty;

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
            child: ElevatedButton(
              onPressed: _isLoading || !canPost ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('投稿する'),
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
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          minLines: 5,
                          maxLength: 500,
                          style:
                              const TextStyle(fontSize: 16, height: 1.5),
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
                          onChanged: (_) => setState(() {}),
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
                        return Stack(
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
                        _imageBytes.length >= 2 ? null : _pickImages,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _imageBytes.length >= 2
                            ? Colors.grey[100]
                            : AppTheme.primaryColor
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: _imageBytes.length >= 2
                                ? AppTheme.textHint
                                : AppTheme.primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _imageBytes.isEmpty
                                ? '画像を追加'
                                : '${_imageBytes.length}/2枚',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _imageBytes.length >= 2
                                  ? AppTheme.textHint
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_textController.text.length} / 500',
                    style: TextStyle(
                      fontSize: 13,
                      color: _textController.text.length > 450
                          ? AppTheme.warning
                          : AppTheme.textHint,
                    ),
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
