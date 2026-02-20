import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../profile/user_profile_screen.dart';
import 'group_chat_settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final String chatType;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.chatType,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _picker = ImagePicker();
  bool _isSending = false;
  Map<String, dynamic> _lastReadMap = {};
  List<String> _memberIds = [];
  String _groupIconUrl = '';

  late final Stream<QuerySnapshot> _messagesStream;
  StreamSubscription<DocumentSnapshot>? _chatDocSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markAsRead();
    _loadChatMeta();

    // メッセージストリームを一度だけ生成（再生成による無限ローディングを防止）
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();

    // チャットドキュメントの変更をリスナーで監視（StreamBuilder外で処理）
    _chatDocSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((chatSnap) {
      if (chatSnap.exists && mounted) {
        final chatData = chatSnap.data() ?? {};
        setState(() {
          _lastReadMap = (chatData['lastRead'] as Map<String, dynamic>?) ?? {};
          _memberIds = List<String>.from(chatData['members'] ?? _memberIds);
          _groupIconUrl = (chatData['iconUrl'] as String?) ?? _groupIconUrl;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatDocSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markAsRead();
  }

  void _markAsRead() {
    if (_currentUser == null) return;
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastRead.${_currentUser!.uid}': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _loadChatMeta() async {
    final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    final data = doc.data() ?? {};
    if (mounted) {
      setState(() {
        _memberIds = List<String>.from(data['members'] ?? []);
        _groupIconUrl = (data['iconUrl'] as String?) ?? '';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    _messageController.clear();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    final senderName =
        (userDoc.data()?['nickname'] as String?) ?? '自分';

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': _currentUser!.uid,
      'senderName': senderName,
      'type': 'text',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    if (_currentUser == null) return;

    try {
      final picked =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;

      setState(() => _isSending = true);

      final bytes = await picked.readAsBytes();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.chatId)
          .child(fileName);

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      final senderName =
          (userDoc.data()?['nickname'] as String?) ?? '自分';

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': _currentUser!.uid,
        'senderName': senderName,
        'type': 'image',
        'text': '',
        'mediaUrl': downloadUrl,
        'fileName': picked.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': '📷 画像',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('画像の送信に失敗しました: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendFile() async {
    if (_currentUser == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isSending = true);

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_files')
          .child(widget.chatId)
          .child(fileName);

      String contentType = 'application/octet-stream';
      final ext = file.extension?.toLowerCase() ?? '';
      if (ext == 'pdf') contentType = 'application/pdf';
      else if (ext == 'doc') contentType = 'application/msword';
      else if (ext == 'docx') contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      else if (ext == 'xls') contentType = 'application/vnd.ms-excel';
      else if (ext == 'xlsx') contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      else if (ext == 'ppt') contentType = 'application/vnd.ms-powerpoint';
      else if (ext == 'pptx') contentType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      else if (ext == 'txt') contentType = 'text/plain';
      else if (ext == 'zip') contentType = 'application/zip';

      await ref.putData(file.bytes!, SettableMetadata(contentType: contentType));
      final downloadUrl = await ref.getDownloadURL();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      final senderName =
          (userDoc.data()?['nickname'] as String?) ?? '自分';

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': _currentUser!.uid,
        'senderName': senderName,
        'type': 'file',
        'text': '',
        'mediaUrl': downloadUrl,
        'fileName': file.name,
        'fileExtension': ext,
        'fileSize': file.size,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': '📎 ${file.name}',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ファイルの送信に失敗しました: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image, color: Colors.blue),
              ),
              title: const Text('画像を送信'),
              subtitle: const Text('写真ライブラリから選択'),
              onTap: () {
                Navigator.pop(ctx);
                _sendImage();
              },
            ),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.attach_file, color: Colors.orange),
              ),
              title: const Text('ファイルを送信'),
              subtitle: const Text('PDF、Word、Excel など'),
              onTap: () {
                Navigator.pop(ctx);
                _sendFile();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.chatTitle.isNotEmpty ? widget.chatTitle[0] : '?';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: GestureDetector(
          onTap: widget.chatType == 'group' ? () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => GroupChatSettingsScreen(
                chatId: widget.chatId,
                chatName: widget.chatTitle,
              ),
            ));
          } : null,
          child: Row(
            children: [
              _groupIconUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(_groupIconUrl),
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                    ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(widget.chatTitle,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text('メッセージを送ってみましょう！',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUser?.uid;
                    return _buildMessageBubble(data, isMe, messageId: doc.id);
                  },
                );
              },
            ),
          ),
          if (_isSending)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor)),
                  const SizedBox(width: 8),
                  Text('送信中...',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        color: AppTheme.textSecondary),
                    onPressed: _isSending ? null : _showAttachMenu,
                  ),
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(fontSize: 15),
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'メッセージを入力',
                          hintStyle:
                              TextStyle(color: AppTheme.textHint),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isSending
                            ? Colors.grey
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 20),
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

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, {String? messageId}) {
    final type = (data['type'] as String?) ?? 'text';
    final text = (data['text'] as String?) ?? '';
    final senderName = (data['senderName'] as String?) ?? '';
    final mediaUrl = (data['mediaUrl'] as String?) ?? '';
    final fileName = (data['fileName'] as String?) ?? '';
    final fileExtension = (data['fileExtension'] as String?) ?? '';
    final fileSize = data['fileSize'] as int?;
    final createdAt = data['createdAt'] as Timestamp?;
    final timeText = _formatMessageTime(createdAt);
    final isDeleted = data['deleted'] == true;

    if (isDeleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.block, size: 14, color: AppTheme.textHint),
              const SizedBox(width: 6),
              Text('メッセージが削除されました',
                  style: TextStyle(fontSize: 13, color: AppTheme.textHint, fontStyle: FontStyle.italic)),
            ]),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: isMe && messageId != null ? () => _showDeleteMessageDialog(messageId) : null,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && widget.chatType != 'dm')
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: GestureDetector(
                onTap: () {
                  final senderId = data['senderId'] as String?;
                  if (senderId != null && senderId.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: senderId),
                    ));
                  }
                },
                child: Text(senderName,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                GestureDetector(
                  onTap: () {
                    final senderId = data['senderId'] as String?;
                    if (senderId != null && senderId.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: senderId),
                      ));
                    }
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: Text(
                      senderName.isNotEmpty ? senderName[0] : '?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildReadReceipt(createdAt),
                      Text(timeText, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ),
              Flexible(
                child: _buildMessageContent(type, text, mediaUrl, fileName, fileExtension, fileSize, isMe),
              ),
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 2),
                  child: Text(timeText,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  void _showDeleteMessageDialog(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('メッセージを削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('このメッセージを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('chats').doc(widget.chatId)
                  .collection('messages').doc(messageId)
                  .update({'deleted': true, 'text': '', 'mediaUrl': ''});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String type, String text, String mediaUrl, String fileName, String fileExtension, int? fileSize, bool isMe) {
    if (type == 'image' && mediaUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () => _showFullImage(mediaUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            mediaUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor)),
              );
            },
          ),
        ),
      );
    }

    if (type == 'file' && mediaUrl.isNotEmpty) {
      final color = _getFileColor(fileExtension);
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(mediaUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: isMe ? null : Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getFileIcon(fileExtension), color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fileExtension.toUpperCase()} ${_formatFileSize(fileSize)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.download_rounded,
                size: 20,
                color: isMe ? Colors.white70 : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        border: isMe ? null : Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.white : AppTheme.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }

  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (widget.chatType == 'dm') ...[
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('プロフィールを見る'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (widget.otherUserId != null && widget.otherUserId!.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: widget.otherUserId!),
                    ));
                  }
                },
              ),
            ],
            if (widget.chatType == 'group') ...[
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('グループ設定'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => GroupChatSettingsScreen(
                      chatId: widget.chatId,
                      chatName: widget.chatTitle,
                    ),
                  ));
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('通知をオフにする'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('このチャットの通知をオフにしました')),
                );
              },
            ),
            if (widget.chatType == 'dm')
              ListTile(
                leading:
                    const Icon(Icons.block, color: AppTheme.error),
                title: const Text('ブロック',
                    style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBlockUser();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmBlockUser() {
    if (_currentUser == null || widget.otherUserId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ブロックしますか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('ブロックすると相手の投稿やメッセージが表示されなくなります。設定からいつでも解除できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('blockedUsers')
                  .doc(widget.otherUserId!)
                  .set({'blockedAt': FieldValue.serverTimestamp()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ユーザーをブロックしました'), backgroundColor: AppTheme.success),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('ブロック'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadReceipt(Timestamp? messageTime) {
    if (messageTime == null || _currentUser == null) return const SizedBox();

    final msgDate = messageTime.toDate();
    final otherMembers = _memberIds.where((id) => id != _currentUser!.uid).toList();
    if (otherMembers.isEmpty) return const SizedBox();

    int readCount = 0;
    for (final memberId in otherMembers) {
      final lastRead = _lastReadMap[memberId];
      if (lastRead is Timestamp && lastRead.toDate().isAfter(msgDate)) {
        readCount++;
      }
    }

    if (readCount == 0) return const SizedBox();

    if (widget.chatType == 'dm') {
      return const Text('既読', style: TextStyle(fontSize: 10, color: AppTheme.primaryColor));
    } else {
      return Text('既読 $readCount', style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor));
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
