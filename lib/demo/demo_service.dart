// ログイン不要の体験デモ（Instagram 等からの導線用）。
//
// 仕組み:
//   1. /demo パス（または ?demo=1）で起動を検知
//   2. 匿名サインイン → デモ用ユーザードキュメントを作成（プロフィール設定をスキップ）
//   3. 使い捨ての「デモ大会」を seed（チーム12・status 開催中・主催者=匿名uid）
//   4. その大会詳細へ自動遷移 → 本物の「対戦表自動生成・得点入力・順位表」を体験
//
// デモ大会・デモユーザーは isDemo:true で隔離し、Cloud Functions の
// cleanupDemoData が定期的に削除する。キャッシュ（匿名セッション）が消えれば
// 入力内容にはアクセスできなくなる。
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import '../services/match_generator.dart';

class DemoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 今回の起動がデモ起動かどうか（Web のみ）。
  static bool isDemoLaunch = false;

  /// 起動中のデモ大会 ID（startDemo 完了後に設定）。
  static String? demoTournamentId;

  static const List<String> _teamNames = [
    'はやぶさ', 'スパイカーズ', 'なでしこ', 'アタッカーズ',
    'ブロッカーズ', 'サンライズ', 'フェニックス', 'おひさま',
    'チームK', 'ファイターズ', 'ラリーズ', 'みなとクラブ',
  ];

  /// デモ大会のルール（最小構成）。決勝トーナメントは無効にして
  /// 予選リーグ → 総合順位 の体験に集中させる。
  static Map<String, dynamic> _demoRules() => {
        'preliminary': {
          'rounds': 1,
          'sets': 1, // デモは手入力の手間を抑えるため1セット制
          'deuce': false,
          'deuceCap': 17,
          'points': 15,
        },
        'final': {
          'enabled': false,
          'sets': 3,
          'deuce': true,
          'deuceCap': 17,
          'format': '順位決定戦',
          'tierCount': 3,
        },
        'scoring': {
          'enabled': true,
          'win20': 10,
          'win11': 7,
          'draw': 4,
          'lose11': 2,
          'lose02': 0,
        },
        'other': {
          'uniformRequired': false,
          'snsVideoAllowed': true,
          'lunchBreak': 'なし',
        },
        'management': {
          'teamsPerCourt': 4,
        },
      };

  /// URL からデモ起動を判定（Web のみ）。
  static void detectFromUri(Uri uri) {
    if (!kIsWeb) return;
    final isDemoPath = uri.pathSegments.contains('demo');
    final demoQuery = uri.queryParameters['demo'];
    final isDemoQuery = demoQuery == '1' || demoQuery == 'true';
    isDemoLaunch = isDemoPath || isDemoQuery;
  }

  /// 匿名サインイン → デモユーザー作成 → デモ大会 seed。大会 ID を返す。
  static Future<String> startDemo() async {
    // 1. 匿名サインイン
    //    デモは必ず「使い捨ての匿名セッション」で動かす。
    //    本物のユーザーがログイン中のまま進めると、その人の users ドキュメントに
    //    isDemo:true / nickname:'ゲスト' が書き込まれ、cleanupDemoData によって
    //    本物のアカウントごと削除されてしまうため、匿名ユーザー以外は一旦サインアウトする。
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) {
      if (user != null && !user.isAnonymous) {
        await FirebaseAuth.instance.signOut();
      }
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    final uid = user!.uid;

    // 2. デモユーザードキュメント（profileCompleted:true でプロフィール設定をスキップ）
    await _firestore.collection('users').doc(uid).set({
      'nickname': 'ゲスト',
      'profileCompleted': true,
      'isDemo': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. デモ大会を seed
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tournamentData = <String, dynamic>{
      'title': '【体験】Sofvoデモ大会',
      'name': '【体験】Sofvoデモ大会',
      'date': dateStr,
      'location': 'Sofvo体育館',
      'venueId': '',
      'venueAddress': '',
      'courts': 3,
      'maxTeams': 12,
      'currentTeams': 0, // onEntryCreated トリガーで 12 まで加算される
      'entryFee': 0,
      'type': '混合',
      'deadline': dateStr,
      'description':
          'ログイン不要の体験用デモ大会です。\n「対戦表」タブから対戦表を自動生成し、試合をタップして得点を入力すると「順位表」に反映されます。\n入力した内容は自動的に削除されます。',
      'area': '',
      'status': '開催中', // 対戦表/順位表タブ表示・得点入力可能・generate ボタン表示の条件
      'organizerId': uid,
      'organizerName': 'デモ主催',
      'matchStartTime': '09:00',
      'entryTeamIds': [],
      'rules': _demoRules(),
      'createdAt': FieldValue.serverTimestamp(),
      'isCertified': false,
      'isDemo': true,
    };
    final docRef =
        await _firestore.collection('tournaments').add(tournamentData);
    final tid = docRef.id;

    // 4. エントリー12チームを seed
    //    先頭チームはデモユーザー自身のチームにする。これにより大会詳細の
    //    対戦表/順位表の初期表示（自分のコート=MY）が空にならず、生成結果が
    //    すぐ見える。さらに「自分のチーム」を追える自然なデモになる。
    for (int i = 0; i < _teamNames.length; i++) {
      final name = _teamNames[i];
      final isMyTeam = i == 0;
      final entryRef =
          _firestore.collection('tournaments').doc(tid).collection('entries').doc();
      await entryRef.set({
        'teamId': entryRef.id,
        'teamName': name,
        'leaderName': isMyTeam ? 'あなた' : '${name}キャプテン',
        'memberCount': 4,
        'memberNames': <String, String>{},
        'enteredBy': isMyTeam ? uid : '',
        if (isMyTeam) 'leaderUid': uid,
        if (isMyTeam) 'memberUids': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    demoTournamentId = tid;
    debugPrint('[Demo] started demo tournament: $tid');
    return tid;
  }

  /// 残っている試合をランダムなスコアで自動入力し、順位表まで一気に完成させる。
  /// 「全セット手入力」の手間を省くためのデモ専用機能。
  /// 対戦表が未生成なら予選1を生成してから埋める。
  static Future<void> autoFillScores() async {
    final tid = demoTournamentId;
    if (tid == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final rnd = Random();

    // ルールから1試合のセット数・1セットの点数を取得（デモは preliminary.sets=1）
    final tournDoc =
        await _firestore.collection('tournaments').doc(tid).get();
    final rules = (tournDoc.data()?['rules'] as Map<String, dynamic>?) ?? {};
    final prelim = (rules['preliminary'] as Map<String, dynamic>?) ?? {};
    final setsPerMatch = (prelim['sets'] as int?) ?? 1;
    final winPoint = (prelim['points'] as int?) ?? 15;

    // 対戦表が無ければ予選1を生成
    final roundsSnap0 =
        await _firestore.collection('tournaments').doc(tid).collection('rounds').get();
    if (roundsSnap0.docs.isEmpty) {
      await MatchGenerator()
          .generatePreliminary(tournamentId: tid, roundNumber: 1);
    }

    final rounds =
        await _firestore.collection('tournaments').doc(tid).collection('rounds').get();
    for (final roundDoc in rounds.docs) {
      final roundNum = (roundDoc.data()['roundNumber'] ?? 1) as int;
      final matchesSnap = await roundDoc.reference.collection('matches').get();
      final courtIds = <String>{};

      for (final matchDoc in matchesSnap.docs) {
        final data = matchDoc.data();
        final courtId = (data['courtId'] ?? 'court_1').toString();
        courtIds.add(courtId);
        if (data['status'] == 'completed') continue;

        // ルールのセット数ぶん、ランダムな結果を生成
        final setsData = <Map<String, int>>[];
        int setsA = 0, setsB = 0, totalA = 0, totalB = 0;
        for (int s = 0; s < setsPerMatch; s++) {
          final aWins = rnd.nextBool();
          final win = winPoint;
          final lose = (winPoint - 7) + rnd.nextInt(6); // 接戦寄りのスコア
          final a = aWins ? win : lose;
          final b = aWins ? lose : win;
          setsData.add({'a': a, 'b': b});
          totalA += a;
          totalB += b;
          if (a > b) {
            setsA++;
          } else {
            setsB++;
          }
        }
        final winnerId = setsA > setsB
            ? data['teamAId']
            : (setsB > setsA
                ? data['teamBId']
                : (totalA >= totalB ? data['teamAId'] : data['teamBId']));

        await matchDoc.reference.update({
          'sets': setsData,
          'result': {
            'setsA': setsA,
            'setsB': setsB,
            'totalPointsA': totalA,
            'totalPointsB': totalB,
            'winner': winnerId,
          },
          'status': 'completed',
          'outcome': 'normal',
          'refereeConfirmed': true,
          'confirmedByA': true,
          'confirmedByB': true,
          'completedAt': FieldValue.serverTimestamp(),
          'lastEditedBy': uid,
          'lastEditedAt': FieldValue.serverTimestamp(),
          'confirmedBy': uid,
          'editCount': 0,
        });
      }

      // コートごとに順位を再計算（得点入力画面と同じ処理）
      for (final courtId in courtIds) {
        await MatchGenerator().updateStandings(
          tournamentId: tid,
          roundNumber: roundNum,
          courtId: courtId,
        );
      }
      await roundDoc.reference
          .update({'completedAt': FieldValue.serverTimestamp()});
    }

    await _firestore
        .collection('tournaments')
        .doc(tid)
        .update({'status': '予選1完了'});
    debugPrint('[Demo] auto-filled scores for $tid');
  }
}
