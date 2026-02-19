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

  /// マッチポイント計算
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
    int mpA, mpB;
    MatchOutcome outcomeA, outcomeB;

    if (setsA == 2 && setsB == 0) {
      mpA = win20;
      mpB = lose02;
      outcomeA = MatchOutcome.win;
      outcomeB = MatchOutcome.loss;
    } else if (setsA == 0 && setsB == 2) {
      mpA = lose02;
      mpB = win20;
      outcomeA = MatchOutcome.loss;
      outcomeB = MatchOutcome.win;
    } else {
      if (totalPointsA > totalPointsB) {
        mpA = win11;
        mpB = lose11;
        outcomeA = MatchOutcome.win;
        outcomeB = MatchOutcome.loss;
      } else if (totalPointsA < totalPointsB) {
        mpA = lose11;
        mpB = win11;
        outcomeA = MatchOutcome.loss;
        outcomeB = MatchOutcome.win;
      } else {
        mpA = draw;
        mpB = draw;
        outcomeA = MatchOutcome.draw;
        outcomeB = MatchOutcome.draw;
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
