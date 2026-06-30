import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 招待コードの発行・引き換えを担う共通サービス。
///
/// 友達紹介（マイページ）・チーム招待（チーム管理）・大会招待（エントリー）を
/// すべて 1 つの `invites/{CODE}` 基盤で扱う。引き換え（相互フォロー・チーム参加）は
/// クライアントから相手側コレクションへ書けないため、`redeemInvite` Cloud Function が
/// admin 権限で確定する。クリップボードや Install Referrer のような「見えない」経路に
/// 頼らず、コードを目に見える形で運んで登録後に確実に成立させるのが狙い。
class InviteService {
  InviteService._();

  static final _firestore = FirebaseFirestore.instance;

  /// コードに使う文字（紛らわしい 0/O/1/I/L を除外）
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// 招待リンクのベース URL
  static String urlForCode(String code) => 'https://sofvo.com/invite?code=$code';

  static String _randomCode([int length = 6]) {
    final rnd = Random.secure();
    return List.generate(length, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
  }

  /// 招待コードを発行して `invites/{CODE}` を作成する。
  ///
  /// [teamId] を渡すと引き換え時にそのチームへ自動参加、[tournamentId] を渡すと
  /// 引き換え後にその大会へ誘導できる（いずれも任意）。
  /// 戻り値は発行されたコード。失敗時は例外を投げる。
  static Future<String> createInvite({
    String? teamId,
    String? tournamentId,
    Duration validFor = const Duration(days: 30),
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('ログインが必要です');
    }

    final expiresAt = Timestamp.fromDate(DateTime.now().add(validFor));

    // コード衝突に備えて数回リトライ
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode();
      final ref = _firestore.collection('invites').doc(code);
      try {
        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) {
            throw _CodeCollision();
          }
          tx.set(ref, {
            'referrerUid': uid,
            if (teamId != null) 'teamId': teamId,
            if (tournamentId != null) 'tournamentId': tournamentId,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': expiresAt,
          });
        });
        return code;
      } on _CodeCollision {
        continue;
      }
    }
    throw StateError('招待コードの発行に失敗しました。もう一度お試しください。');
  }

  /// 招待コードを引き換える（相互フォロー＋必要ならチーム参加）。
  /// 戻り値は `redeemInvite` Cloud Function の結果
  /// （referrerName / teamId / teamName / tournamentId / followed / joinedTeam）。
  static Future<Map<String, dynamic>> redeemInvite(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw StateError('招待コードを入力してください');
    }
    final callable = FirebaseFunctions.instance.httpsCallable('redeemInvite');
    final res = await callable.call({'code': normalized});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// LINE などで共有するときのデフォルト本文を組み立てる。
  static String shareText({
    required String code,
    String? teamName,
    String? tournamentName,
  }) {
    final url = urlForCode(code);
    final buffer = StringBuffer();
    if (tournamentName != null && tournamentName.isNotEmpty) {
      buffer.writeln('「$tournamentName」に一緒に出ませんか？');
    } else if (teamName != null && teamName.isNotEmpty) {
      buffer.writeln('チーム「$teamName」に招待します！');
    } else {
      buffer.writeln('ソフトバレーボールアプリ「Sofvo」に招待します！');
    }
    buffer.writeln('① 下のリンクからアプリをダウンロード');
    buffer.writeln(url);
    buffer.writeln('② 登録時に招待コードを入力');
    buffer.writeln('招待コード: $code');
    return buffer.toString();
  }
}

class _CodeCollision implements Exception {}
