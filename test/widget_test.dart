import 'package:flutter_test/flutter_test.dart';
import 'package:sofvo/utils/match_algorithm.dart';
import 'package:sofvo/config/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  group('MatchAlgorithm - ラウンドロビン生成', () {
    test('4チームで6試合生成される', () {
      final matches = MatchAlgorithm.generateRoundRobin(4);
      // 4C2 = 6
      expect(matches.length, 6);
    });

    test('3チームで3試合生成される', () {
      final matches = MatchAlgorithm.generateRoundRobin(3);
      // 3C2 = 3
      expect(matches.length, 3);
    });

    test('5チームで10試合生成される', () {
      final matches = MatchAlgorithm.generateRoundRobin(5);
      // 5C2 = 10
      expect(matches.length, 10);
    });

    test('2チームで1試合生成される', () {
      final matches = MatchAlgorithm.generateRoundRobin(2);
      expect(matches.length, 1);
      expect(matches[0].teamAIdx, 0);
      expect(matches[0].teamBIdx, 1);
    });

    test('全チームが少なくとも1回は試合する', () {
      final matches = MatchAlgorithm.generateRoundRobin(4);
      final teamsInMatches = <int>{};
      for (final m in matches) {
        teamsInMatches.add(m.teamAIdx);
        teamsInMatches.add(m.teamBIdx);
      }
      expect(teamsInMatches, {0, 1, 2, 3});
    });

    test('4チーム以上の場合、全試合に主審と副審が割り当てられる', () {
      final matches = MatchAlgorithm.generateRoundRobin(4);
      for (final m in matches) {
        expect(m.mainRefIdx, isNotNull);
        expect(m.subRefIdx, isNotNull);
        // 審判は対戦チームと異なる
        expect(m.mainRefIdx, isNot(m.teamAIdx));
        expect(m.mainRefIdx, isNot(m.teamBIdx));
        expect(m.subRefIdx, isNot(m.teamAIdx));
        expect(m.subRefIdx, isNot(m.teamBIdx));
      }
    });

    test('同じチーム同士の対戦がない', () {
      final matches = MatchAlgorithm.generateRoundRobin(5);
      for (final m in matches) {
        expect(m.teamAIdx, isNot(m.teamBIdx));
      }
    });

    test('重複した対戦がない', () {
      final matches = MatchAlgorithm.generateRoundRobin(5);
      final pairs = <String>{};
      for (final m in matches) {
        final key = '${m.teamAIdx}-${m.teamBIdx}';
        expect(pairs.contains(key), false, reason: '重複対戦: $key');
        pairs.add(key);
      }
    });
  });

  group('MatchAlgorithm - コート割り振り', () {
    test('8チーム・2コートに均等に分配される', () {
      final teams = List.generate(8, (i) => 'Team$i');
      final courts = MatchAlgorithm.assignRandom(teams, 2, 4);
      expect(courts.length, 2);
      expect(courts[0].length, 4);
      expect(courts[1].length, 4);
    });

    test('7チーム・2コートに分配される（不均等OK）', () {
      final teams = List.generate(7, (i) => 'Team$i');
      final courts = MatchAlgorithm.assignRandom(teams, 2, 4);
      expect(courts.length, 2);
      final total = courts[0].length + courts[1].length;
      expect(total, 7);
    });

    test('全チームがどこかのコートに配置される', () {
      final teams = List.generate(10, (i) => 'Team$i');
      final courts = MatchAlgorithm.assignRandom(teams, 3, 4);
      final allTeams = courts.expand((c) => c).toSet();
      expect(allTeams.length, 10);
    });

    test('1チームの場合も正常に動作する', () {
      final teams = ['TeamA'];
      final courts = MatchAlgorithm.assignRandom(teams, 2, 4);
      expect(courts.length, 1);
      expect(courts[0].length, 1);
    });
  });

  group('MatchAlgorithm - マッチポイント計算', () {
    test('2-0ストレート勝ち → win20ポイント', () {
      final result = MatchAlgorithm.calculateMatchPoints(
        setsA: 2, setsB: 0,
        totalPointsA: 42, totalPointsB: 30,
      );
      expect(result.pointsA, 10);
      expect(result.pointsB, 0);
      expect(result.outcomeA, MatchOutcome.win);
      expect(result.outcomeB, MatchOutcome.loss);
    });

    test('0-2ストレート負け → lose02ポイント', () {
      final result = MatchAlgorithm.calculateMatchPoints(
        setsA: 0, setsB: 2,
        totalPointsA: 30, totalPointsB: 42,
      );
      expect(result.pointsA, 0);
      expect(result.pointsB, 10);
      expect(result.outcomeA, MatchOutcome.loss);
      expect(result.outcomeB, MatchOutcome.win);
    });

    test('1-1で得点差あり → win11/lose11', () {
      final result = MatchAlgorithm.calculateMatchPoints(
        setsA: 1, setsB: 1,
        totalPointsA: 45, totalPointsB: 40,
      );
      expect(result.pointsA, 7);
      expect(result.pointsB, 2);
      expect(result.outcomeA, MatchOutcome.win);
      expect(result.outcomeB, MatchOutcome.loss);
    });

    test('1-1で得点同点 → draw', () {
      final result = MatchAlgorithm.calculateMatchPoints(
        setsA: 1, setsB: 1,
        totalPointsA: 40, totalPointsB: 40,
      );
      expect(result.pointsA, 4);
      expect(result.pointsB, 4);
      expect(result.outcomeA, MatchOutcome.draw);
      expect(result.outcomeB, MatchOutcome.draw);
    });

    test('カスタムポイントで計算できる', () {
      final result = MatchAlgorithm.calculateMatchPoints(
        setsA: 2, setsB: 0,
        totalPointsA: 42, totalPointsB: 30,
        win20: 15, lose02: 1,
      );
      expect(result.pointsA, 15);
      expect(result.pointsB, 1);
    });
  });

  group('AppTheme - テーマ設定', () {
    test('ライトテーマが正しいカラーを持つ', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, AppTheme.primaryColor);
      expect(theme.useMaterial3, true);
    });

    test('プライマリカラーがネイビー', () {
      expect(AppTheme.primaryColor, const Color(0xFF1B3A5C));
    });

    test('アクセントカラーがゴールド', () {
      expect(AppTheme.accentColor, const Color(0xFFC4A962));
    });

  });
}
