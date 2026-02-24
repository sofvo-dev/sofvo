/// 試合生成アルゴリズム（純粋関数・テスト可能）
class MatchAlgorithm {
  /// チームをランダムにコートに割り振る
  static List<List<T>> assignRandom<T>(
      List<T> entries, int courtCount, int teamsPerCourt) {
    final shuffled = List<T>.from(entries)..shuffle();
    final actualCourts =
        (shuffled.length / teamsPerCourt).ceil().clamp(1, courtCount);
    final courts = List.generate(actualCourts, (_) => <T>[]);

    for (int i = 0; i < shuffled.length; i++) {
      courts[i % actualCourts].add(shuffled[i]);
    }

    return courts;
  }

  /// ラウンドロビン対戦表を生成
  /// 戻り値: [(teamAIdx, teamBIdx, mainRefIdx?, subRefIdx?)]
  static List<MatchPairing> generateRoundRobin(int teamCount) {
    final matches = <MatchPairing>[];
    final mainRefCount = <int, int>{};
    for (int i = 0; i < teamCount; i++) {
      mainRefCount[i] = 0;
    }

    for (int i = 0; i < teamCount; i++) {
      for (int j = i + 1; j < teamCount; j++) {
        final refs = <int>[];
        for (int k = 0; k < teamCount; k++) {
          if (k != i && k != j) refs.add(k);
        }

        int? mainRef;
        int? subRef;

        if (refs.length >= 2) {
          refs.sort((a, b) => mainRefCount[a]!.compareTo(mainRefCount[b]!));
          mainRef = refs[0];
          subRef = refs[1];
          mainRefCount[mainRef] = mainRefCount[mainRef]! + 1;
        } else if (refs.length == 1) {
          mainRef = refs[0];
          mainRefCount[mainRef] = mainRefCount[mainRef]! + 1;
        }

        matches.add(MatchPairing(
          teamAIdx: i,
          teamBIdx: j,
          mainRefIdx: mainRef,
          subRefIdx: subRef,
        ));
      }
    }
    return matches;
  }

  /// マッチポイント計算（2セットマッチ用 - 後方互換）
  static MatchPointResult calculateMatchPoints({
    required int setsA,
    required int setsB,
    required int totalPointsA,
    required int totalPointsB,
    int win20 = 10,
    int win11 = 7,
    int draw = 4,
    int lose11 = 2,
    int lose02 = 0,
  }) {
    return calculateMatchPointsByFormat(
      setFormat: 2,
      setsA: setsA, setsB: setsB,
      totalPointsA: totalPointsA, totalPointsB: totalPointsB,
      scoring: {'win20': win20, 'win11': win11, 'draw': draw, 'lose11': lose11, 'lose02': lose02},
    );
  }

  /// セット形式に応じたマッチポイント計算
  static MatchPointResult calculateMatchPointsByFormat({
    required int setFormat, // 1, 2, or 3
    required int setsA,
    required int setsB,
    required int totalPointsA,
    required int totalPointsB,
    required Map<String, dynamic> scoring,
  }) {
    int mpA, mpB;
    MatchOutcome outcomeA, outcomeB;

    if (setFormat == 1) {
      // 1セットマッチ: 勝ち or 負け
      final winPts = scoring['win'] ?? 3;
      final losePts = scoring['lose'] ?? 0;
      if (totalPointsA > totalPointsB) {
        mpA = winPts; mpB = losePts;
        outcomeA = MatchOutcome.win; outcomeB = MatchOutcome.loss;
      } else if (totalPointsB > totalPointsA) {
        mpA = losePts; mpB = winPts;
        outcomeA = MatchOutcome.loss; outcomeB = MatchOutcome.win;
      } else {
        mpA = (winPts / 2).round(); mpB = (winPts / 2).round();
        outcomeA = MatchOutcome.draw; outcomeB = MatchOutcome.draw;
      }
    } else if (setFormat == 3) {
      // 2セット先取（最大3セット）: 2-0, 2-1, 1-2, 0-2
      final win20 = scoring['win20'] ?? 10;
      final win21 = scoring['win21'] ?? 7;
      final lose12 = scoring['lose12'] ?? 2;
      final lose02 = scoring['lose02'] ?? 0;
      if (setsA == 2 && setsB == 0) {
        mpA = win20; mpB = lose02;
        outcomeA = MatchOutcome.win; outcomeB = MatchOutcome.loss;
      } else if (setsA == 0 && setsB == 2) {
        mpA = lose02; mpB = win20;
        outcomeA = MatchOutcome.loss; outcomeB = MatchOutcome.win;
      } else if (setsA == 2 && setsB == 1) {
        mpA = win21; mpB = lose12;
        outcomeA = MatchOutcome.win; outcomeB = MatchOutcome.loss;
      } else if (setsA == 1 && setsB == 2) {
        mpA = lose12; mpB = win21;
        outcomeA = MatchOutcome.loss; outcomeB = MatchOutcome.win;
      } else {
        mpA = 0; mpB = 0;
        outcomeA = MatchOutcome.draw; outcomeB = MatchOutcome.draw;
      }
    } else {
      // 2セットマッチ: 2-0, 1-1, 0-2
      final win20 = scoring['win20'] ?? 10;
      final win11 = scoring['win11'] ?? 7;
      final draw = scoring['draw'] ?? 4;
      final lose11 = scoring['lose11'] ?? 2;
      final lose02 = scoring['lose02'] ?? 0;
      if (setsA == 2 && setsB == 0) {
        mpA = win20; mpB = lose02;
        outcomeA = MatchOutcome.win; outcomeB = MatchOutcome.loss;
      } else if (setsA == 0 && setsB == 2) {
        mpA = lose02; mpB = win20;
        outcomeA = MatchOutcome.loss; outcomeB = MatchOutcome.win;
      } else {
        if (totalPointsA > totalPointsB) {
          mpA = win11; mpB = lose11;
          outcomeA = MatchOutcome.win; outcomeB = MatchOutcome.loss;
        } else if (totalPointsA < totalPointsB) {
          mpA = lose11; mpB = win11;
          outcomeA = MatchOutcome.loss; outcomeB = MatchOutcome.win;
        } else {
          mpA = draw; mpB = draw;
          outcomeA = MatchOutcome.draw; outcomeB = MatchOutcome.draw;
        }
      }
    }

    return MatchPointResult(
      pointsA: mpA,
      pointsB: mpB,
      outcomeA: outcomeA,
      outcomeB: outcomeB,
    );
  }
}

class MatchPairing {
  final int teamAIdx;
  final int teamBIdx;
  final int? mainRefIdx;
  final int? subRefIdx;

  const MatchPairing({
    required this.teamAIdx,
    required this.teamBIdx,
    this.mainRefIdx,
    this.subRefIdx,
  });
}

enum MatchOutcome { win, loss, draw }

class MatchPointResult {
  final int pointsA;
  final int pointsB;
  final MatchOutcome outcomeA;
  final MatchOutcome outcomeB;

  const MatchPointResult({
    required this.pointsA,
    required this.pointsB,
    required this.outcomeA,
    required this.outcomeB,
  });
}
