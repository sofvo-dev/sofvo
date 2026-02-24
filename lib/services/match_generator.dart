import 'package:cloud_firestore/cloud_firestore.dart';

class MatchGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate round-robin match table for preliminary round
  /// Returns list of generated match documents
  Future<List<Map<String, dynamic>>> generatePreliminary({
    required String tournamentId,
    required int roundNumber, // 1 or 2
  }) async {
    // 1. Get tournament data
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    if (!tournDoc.exists) throw Exception('Tournament not found');
    final tournData = tournDoc.data()!;
    final rules = tournData['rules'] as Map<String, dynamic>? ?? {};
    final management = rules['management'] as Map<String, dynamic>? ?? {};
    final teamsPerCourt = management['teamsPerCourt'] ?? 4;
    final courtCount = tournData['courts'] ?? 2;

    // 2. Get entries
    final entriesSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('entries').get();
    final entries = entriesSnap.docs.map((d) {
      final data = d.data();
      return {'entryId': d.id, 'teamId': data['teamId'], 'teamName': data['teamName'], ...data};
    }).toList();

    if (entries.isEmpty) throw Exception('No entries found');

    // 3. Assign teams to courts
    List<List<Map<String, dynamic>>> courts;
    if (roundNumber == 1) {
      courts = _assignRandom(entries, courtCount, teamsPerCourt);
    } else {
      courts = await _assignByRanking(tournamentId, entries, courtCount, teamsPerCourt);
    }

    // 4. Generate round-robin matches per court
    final allMatches = <Map<String, dynamic>>[];
    final roundRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').doc('round_$roundNumber');

    // Create round document
    await roundRef.set({
      'roundNumber': roundNumber,
      'status': 'pending',
      'courtCount': courts.length,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (int courtIdx = 0; courtIdx < courts.length; courtIdx++) {
      final courtTeams = courts[courtIdx];
      final courtId = 'court_${courtIdx + 1}';
      final matches = _generateRoundRobin(courtTeams, courtId, courtIdx + 1);

      // Save court standings structure
      final standingRef = roundRef.collection('standings').doc(courtId);
      await standingRef.set({'courtNumber': courtIdx + 1, 'teams': courtTeams.map((t) => t['teamId']).toList()});

      for (var team in courtTeams) {
        await standingRef.collection('teams').doc(team['teamId']).set({
          'teamId': team['teamId'],
          'teamName': team['teamName'],
          'matchPoints': 0,
          'pointDiff': 0,
          'totalPoints': 0,
          'wins': 0,
          'losses': 0,
          'draws': 0,
          'rank': 0,
        });
      }

      // Save matches
      int matchOrder = 1;
      for (var match in matches) {
        match['roundNumber'] = roundNumber;
        match['matchOrder'] = matchOrder++;
        match['status'] = 'pending';
        match['sets'] = [];
        match['result'] = {};
        match['confirmedByA'] = false;
        match['confirmedByB'] = false;
        final docRef = await roundRef.collection('matches').add(match);
        match['matchId'] = docRef.id;
        allMatches.add(match);
      }
    }

    // Update tournament status
    await _firestore.collection('tournaments').doc(tournamentId).update({
      'status': '開催中',
      'currentRound': roundNumber,
    });

    return allMatches;
  }

  /// Random assignment for round 1
  List<List<Map<String, dynamic>>> _assignRandom(
      List<Map<String, dynamic>> entries, int courtCount, int teamsPerCourt) {
    final shuffled = List<Map<String, dynamic>>.from(entries)..shuffle();
    final courts = <List<Map<String, dynamic>>>[];

    // Calculate actual courts needed
    final actualCourts = (shuffled.length / teamsPerCourt).ceil().clamp(1, courtCount);

    for (int i = 0; i < actualCourts; i++) {
      courts.add([]);
    }

    for (int i = 0; i < shuffled.length; i++) {
      courts[i % actualCourts].add(shuffled[i]);
    }

    return courts;
  }

  /// Rank-based assignment for round 2
  /// 同順位のチームを同じコートにまとめ、上位→下位のブラケットを形成する
  Future<List<List<Map<String, dynamic>>>> _assignByRanking(
      String tournamentId, List<Map<String, dynamic>> entries,
      int courtCount, int teamsPerCourt) async {
    // Get round 1 standings
    final round1Ref = _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').doc('round_1');
    final standingsSnap = await round1Ref.collection('standings').get();

    // Collect all team rankings (rank within their court)
    final teamRankings = <String, int>{};
    for (var courtDoc in standingsSnap.docs) {
      final teamsSnap = await courtDoc.reference.collection('teams')
          .orderBy('matchPoints', descending: true)
          .orderBy('pointDiff', descending: true)
          .orderBy('totalPoints', descending: true)
          .get();
      for (int i = 0; i < teamsSnap.docs.length; i++) {
        teamRankings[teamsSnap.docs[i].id] = i + 1; // 1st, 2nd, 3rd...
      }
    }

    // Group by rank
    final rankGroups = <int, List<Map<String, dynamic>>>{};
    for (var entry in entries) {
      final rank = teamRankings[entry['teamId']] ?? 99;
      rankGroups.putIfAbsent(rank, () => []);
      rankGroups[rank]!.add(entry);
    }

    // 同順位チームを同じコートにグループ化
    // 例: 2コート×4チーム → コートA: 1位+2位チーム、コートB: 3位+4位チーム
    final sortedRanks = rankGroups.keys.toList()..sort();
    final actualCourts = (entries.length / teamsPerCourt).ceil().clamp(1, courtCount);
    final courts = List.generate(actualCourts, (_) => <Map<String, dynamic>>[]);

    // 順位グループを順番にコートに詰めていく
    int courtIdx = 0;
    for (var rank in sortedRanks) {
      final group = rankGroups[rank]!..shuffle();
      // この順位グループ全体を現在のコートに入れる
      for (var team in group) {
        courts[courtIdx].add(team);
      }
      // コートがteamsPerCourt以上になったら次のコートへ
      if (courts[courtIdx].length >= teamsPerCourt && courtIdx < actualCourts - 1) {
        courtIdx++;
      }
    }

    return courts;
  }

  /// Generate round-robin matches for teams in a court
  List<Map<String, dynamic>> _generateRoundRobin(
      List<Map<String, dynamic>> teams, String courtId, int courtNumber) {
    final matches = <Map<String, dynamic>>[];
    // Track referee counts for fairness
    final mainRefCount = <int, int>{};
    final subRefCount = <int, int>{};
    for (int i = 0; i < teams.length; i++) {
      mainRefCount[i] = 0;
      subRefCount[i] = 0;
    }

    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        // Find 2 teams not playing
        final refs = <int>[];
        for (int k = 0; k < teams.length; k++) {
          if (k != i && k != j) refs.add(k);
        }

        String mainRefId = '';
        String mainRefName = '';
        String subRefId = '';
        String subRefName = '';

        if (refs.length >= 2) {
          // Sort by main ref count (ascending) to balance
          refs.sort((a, b) => mainRefCount[a]!.compareTo(mainRefCount[b]!));
          final mainIdx = refs[0];
          final subIdx = refs[1];
          mainRefId = teams[mainIdx]['teamId'] ?? '';
          mainRefName = teams[mainIdx]['teamName'] ?? '';
          subRefId = teams[subIdx]['teamId'] ?? '';
          subRefName = teams[subIdx]['teamName'] ?? '';
          mainRefCount[mainIdx] = mainRefCount[mainIdx]! + 1;
          subRefCount[subIdx] = subRefCount[subIdx]! + 1;
        } else if (refs.length == 1) {
          mainRefId = teams[refs[0]]['teamId'] ?? '';
          mainRefName = teams[refs[0]]['teamName'] ?? '';
          mainRefCount[refs[0]] = mainRefCount[refs[0]]! + 1;
        }

        matches.add({
          'courtId': courtId,
          'courtNumber': courtNumber,
          'teamAId': teams[i]['teamId'],
          'teamAName': teams[i]['teamName'],
          'teamBId': teams[j]['teamId'],
          'teamBName': teams[j]['teamName'],
          'refereeTeamId': mainRefId,
          'refereeTeamName': mainRefName,
          'subRefereeTeamId': subRefId,
          'subRefereeTeamName': subRefName,
        });
      }
    }
    return matches;
  }
  /// Resolve scoring config for a specific round
  /// Handles both per-round (round1/round2 sub-objects) and flat scoring formats
  Map<String, dynamic> _resolveRoundScoring(Map<String, dynamic> rules, int roundNumber) {
    final scoring = rules['scoring'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final rounds = preliminary['rounds'] ?? 1;

    // Check for per-round scoring
    if (rounds == 2) {
      final roundKey = 'round$roundNumber';
      final roundScoring = scoring[roundKey] as Map<String, dynamic>?;
      if (roundScoring != null) return roundScoring;
    }

    // Flat scoring (backwards compatible)
    return scoring;
  }

  /// Resolve preliminary config for a specific round
  Map<String, dynamic> _resolveRoundPreliminary(Map<String, dynamic> rules, int roundNumber) {
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final rounds = preliminary['rounds'] ?? 1;

    if (rounds == 2) {
      final roundKey = 'round$roundNumber';
      final roundPrelim = preliminary[roundKey] as Map<String, dynamic>?;
      if (roundPrelim != null) return roundPrelim;
    }

    // Flat format (backwards compatible)
    return preliminary;
  }

  /// Determine set format for a round (1=1セットマッチ, 2=2セットマッチ, 3=2セット先取)
  int _getSetFormat(Map<String, dynamic> rules, int roundNumber) {
    final roundPrelim = _resolveRoundPreliminary(rules, roundNumber);
    return roundPrelim['sets'] ?? 2;
  }

  Future<void> updateStandings({
    required String tournamentId,
    required int roundNumber,
    required String courtId,
  }) async {
    final roundRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').doc('round_$roundNumber');

    // Get tournament rules for scoring
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final rules = tournDoc.data()?['rules'] as Map<String, dynamic>? ?? {};
    final topScoring = rules['scoring'] as Map<String, dynamic>? ?? {};
    final useMatchPoints = topScoring['enabled'] ?? true;

    // Resolve scoring for this specific round
    final scoring = _resolveRoundScoring(rules, roundNumber);
    final setFormat = _getSetFormat(rules, roundNumber);

    // Get completed matches for this court
    final matchesSnap = await roundRef.collection('matches')
        .where('courtId', isEqualTo: courtId)
        .where('status', isEqualTo: 'completed')
        .get();

    // Accumulate stats per team
    final stats = <String, Map<String, dynamic>>{};

    for (var matchDoc in matchesSnap.docs) {
      final match = matchDoc.data();
      final result = match['result'] as Map<String, dynamic>? ?? {};
      final teamAId = match['teamAId'] as String;
      final teamBId = match['teamBId'] as String;
      final setsA = result['setsA'] ?? 0;
      final setsB = result['setsB'] ?? 0;
      final totalA = result['totalPointsA'] ?? 0;
      final totalB = result['totalPointsB'] ?? 0;

      stats.putIfAbsent(teamAId, () => _emptyStats(match['teamAName']));
      stats.putIfAbsent(teamBId, () => _emptyStats(match['teamBName']));

      if (useMatchPoints) {
        final mpResult = _calculateMatchPointsForFormat(
          setFormat: setFormat, setsA: setsA, setsB: setsB,
          totalA: totalA, totalB: totalB, scoring: scoring,
        );
        stats[teamAId]!['matchPoints'] += mpResult[0];
        stats[teamBId]!['matchPoints'] += mpResult[1];
        // Determine win/loss/draw
        if (mpResult[0] > mpResult[1]) {
          stats[teamAId]!['wins']++;
          stats[teamBId]!['losses']++;
        } else if (mpResult[1] > mpResult[0]) {
          stats[teamBId]!['wins']++;
          stats[teamAId]!['losses']++;
        } else {
          stats[teamAId]!['draws']++;
          stats[teamBId]!['draws']++;
        }
      } else {
        // Simple win/loss
        if (setsA > setsB) {
          stats[teamAId]!['wins']++;
          stats[teamBId]!['losses']++;
          stats[teamAId]!['matchPoints'] += 2;
        } else if (setsB > setsA) {
          stats[teamBId]!['wins']++;
          stats[teamAId]!['losses']++;
          stats[teamBId]!['matchPoints'] += 2;
        } else {
          // 1-1 or tie: use point diff
          if (totalA > totalB) {
            stats[teamAId]!['wins']++;
            stats[teamBId]!['losses']++;
            stats[teamAId]!['matchPoints'] += 2;
          } else if (totalB > totalA) {
            stats[teamBId]!['wins']++;
            stats[teamAId]!['losses']++;
            stats[teamBId]!['matchPoints'] += 2;
          } else {
            stats[teamAId]!['draws']++;
            stats[teamBId]!['draws']++;
            stats[teamAId]!['matchPoints'] += 1;
            stats[teamBId]!['matchPoints'] += 1;
          }
        }
      }

      stats[teamAId]!['totalPoints'] += totalA;
      stats[teamBId]!['totalPoints'] += totalB;
      stats[teamAId]!['pointDiff'] += (totalA - totalB);
      stats[teamBId]!['pointDiff'] += (totalB - totalA);
    }

    // Sort and assign ranks
    final sorted = stats.entries.toList()
      ..sort((a, b) {
        final mp = (b.value['matchPoints'] as int).compareTo(a.value['matchPoints'] as int);
        if (mp != 0) return mp;
        final pd = (b.value['pointDiff'] as int).compareTo(a.value['pointDiff'] as int);
        if (pd != 0) return pd;
        return (b.value['totalPoints'] as int).compareTo(a.value['totalPoints'] as int);
      });

    // Update standings in Firestore
    final standingRef = roundRef.collection('standings').doc(courtId);
    for (int i = 0; i < sorted.length; i++) {
      final teamId = sorted[i].key;
      final teamStats = sorted[i].value;
      teamStats['rank'] = i + 1;
      await standingRef.collection('teams').doc(teamId).update(teamStats);
    }
  }

  /// セット形式に応じたマッチポイント計算（[mpA, mpB]を返す）
  List<int> _calculateMatchPointsForFormat({
    required int setFormat,
    required int setsA,
    required int setsB,
    required int totalA,
    required int totalB,
    required Map<String, dynamic> scoring,
  }) {
    if (setFormat == 1) {
      final winPts = scoring['win'] ?? 3;
      final losePts = scoring['lose'] ?? 0;
      if (totalA > totalB) return [winPts, losePts];
      if (totalB > totalA) return [losePts, winPts];
      return [((winPts as int) ~/ 2), ((winPts as int) ~/ 2)];
    } else if (setFormat == 3) {
      final win20 = scoring['win20'] ?? 10;
      final win21 = scoring['win21'] ?? 7;
      final lose12 = scoring['lose12'] ?? 2;
      final lose02 = scoring['lose02'] ?? 0;
      if (setsA == 2 && setsB == 0) return [win20, lose02];
      if (setsA == 0 && setsB == 2) return [lose02, win20];
      if (setsA == 2 && setsB == 1) return [win21, lose12];
      if (setsA == 1 && setsB == 2) return [lose12, win21];
      return [0, 0];
    } else {
      // 2セットマッチ
      final win20 = scoring['win20'] ?? 10;
      final win11 = scoring['win11'] ?? 7;
      final draw = scoring['draw'] ?? 4;
      final lose11 = scoring['lose11'] ?? 2;
      final lose02 = scoring['lose02'] ?? 0;
      if (setsA == 2 && setsB == 0) return [win20, lose02];
      if (setsA == 0 && setsB == 2) return [lose02, win20];
      if (totalA > totalB) return [win11, lose11];
      if (totalA < totalB) return [lose11, win11];
      return [draw, draw];
    }
  }

  Map<String, dynamic> _emptyStats(String teamName) {
    return {
      'teamName': teamName,
      'matchPoints': 0,
      'pointDiff': 0,
      'totalPoints': 0,
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'rank': 0,
    };
  }

  /// Generate final brackets / round-robin groups (順位決定戦)
  Future<void> generateFinals({
    required String tournamentId,
  }) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final tournData = tournDoc.data()!;
    final rules = tournData['rules'] as Map<String, dynamic>? ?? {};
    final finalRules = rules['final'] as Map<String, dynamic>? ?? {};
    final type = finalRules['type'] ?? 'tournament';
    final format = finalRules['format'] ?? '順位別複数';

    // Get overall standings
    final sorted = await _getOverallSortedStandings(tournamentId);

    if (type == 'round_robin') {
      // 総当たり方式: split into tier groups and generate round-robin
      await _generateRoundRobinFinals(tournamentId, sorted, finalRules);
    } else if (format == '順位別複数') {
      await _generateTierBrackets(tournamentId, sorted, finalRules);
    } else {
      await _generateSingleBracket(tournamentId, sorted);
    }

    await _firestore.collection('tournaments').doc(tournamentId).update({'status': '順位決定中'});
  }

  /// Aggregate and sort all team stats across preliminary rounds
  Future<List<MapEntry<String, Map<String, dynamic>>>> _getOverallSortedStandings(String tournamentId) async {
    final roundsSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').get();
    final overallStats = <String, Map<String, dynamic>>{};

    for (var roundDoc in roundsSnap.docs) {
      final standingsSnap = await roundDoc.reference.collection('standings').get();
      for (var courtDoc in standingsSnap.docs) {
        final teamsSnap = await courtDoc.reference.collection('teams').get();
        for (var teamDoc in teamsSnap.docs) {
          final data = teamDoc.data();
          final teamId = teamDoc.id;
          if (!overallStats.containsKey(teamId)) {
            overallStats[teamId] = _emptyStats(data['teamName'] ?? '');
          }
          overallStats[teamId]!['matchPoints'] += (data['matchPoints'] ?? 0);
          overallStats[teamId]!['pointDiff'] += (data['pointDiff'] ?? 0);
          overallStats[teamId]!['totalPoints'] += (data['totalPoints'] ?? 0);
          overallStats[teamId]!['wins'] += (data['wins'] ?? 0);
          overallStats[teamId]!['losses'] += (data['losses'] ?? 0);
          overallStats[teamId]!['draws'] += (data['draws'] ?? 0);
        }
      }
    }

    return overallStats.entries.toList()
      ..sort((a, b) {
        final mp = (b.value['matchPoints'] as int).compareTo(a.value['matchPoints'] as int);
        if (mp != 0) return mp;
        final pd = (b.value['pointDiff'] as int).compareTo(a.value['pointDiff'] as int);
        if (pd != 0) return pd;
        return (b.value['totalPoints'] as int).compareTo(a.value['totalPoints'] as int);
      });
  }

  /// Generate round-robin finals (総当たり順位決定戦)
  Future<void> _generateRoundRobinFinals(
    String tournamentId,
    List<MapEntry<String, Map<String, dynamic>>> sorted,
    Map<String, dynamic> finalRules,
  ) async {
    final brackets = _splitIntoGroups(sorted, 4);
    final bracketNames = ['上位', '中上位', '中位', '中下位', '下位', 'エンジョイ'];

    for (int b = 0; b < brackets.length; b++) {
      final bracket = brackets[b];
      final bracketName = b < bracketNames.length ? bracketNames[b] : '第${b + 1}グループ';
      final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
          .collection('brackets').doc('bracket_${b + 1}');

      await bracketRef.set({
        'bracketNumber': b + 1,
        'bracketName': bracketName,
        'teamCount': bracket.length,
        'type': 'round_robin',
        'status': 'pending',
      });

      // Generate round-robin matches
      int matchNum = 1;
      for (int i = 0; i < bracket.length; i++) {
        for (int j = i + 1; j < bracket.length; j++) {
          await bracketRef.collection('matches').add({
            'round': 'round-robin', 'matchNumber': matchNum++,
            'teamAId': bracket[i].key, 'teamAName': bracket[i].value['teamName'],
            'teamBId': bracket[j].key, 'teamBName': bracket[j].value['teamName'],
            'status': 'pending', 'sets': [], 'result': {},
          });
        }
      }

      // Initialize standings for this bracket
      for (var team in bracket) {
        await bracketRef.collection('standings').doc(team.key).set({
          'teamId': team.key,
          'teamName': team.value['teamName'],
          'matchPoints': 0, 'pointDiff': 0, 'totalPoints': 0,
          'wins': 0, 'losses': 0, 'draws': 0, 'rank': 0,
        });
      }
    }
  }

  /// Generate tier-based tournament brackets (順位別トーナメント)
  Future<void> _generateTierBrackets(
    String tournamentId,
    List<MapEntry<String, Map<String, dynamic>>> sorted,
    Map<String, dynamic> finalRules,
  ) async {
    final brackets = _splitIntoGroups(sorted, 4);
    final bracketNames = ['上位', '中上位', '中位', '中下位', '下位', 'エンジョイ'];

    for (int b = 0; b < brackets.length; b++) {
      final bracket = brackets[b];
      final bracketName = b < bracketNames.length ? bracketNames[b] : '第${b + 1}ブラケット';
      final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
          .collection('brackets').doc('bracket_${b + 1}');

      await bracketRef.set({
        'bracketNumber': b + 1,
        'bracketName': bracketName,
        'teamCount': bracket.length,
        'type': 'tournament',
        'status': 'pending',
      });

      if (bracket.length >= 4) {
        // Semi-finals: 1st vs 4th, 2nd vs 3rd
        await bracketRef.collection('matches').add({
          'round': 'semi', 'matchNumber': 1,
          'teamAId': bracket[0].key, 'teamAName': bracket[0].value['teamName'],
          'teamBId': bracket[3].key, 'teamBName': bracket[3].value['teamName'],
          'status': 'pending', 'sets': [], 'result': {},
        });
        await bracketRef.collection('matches').add({
          'round': 'semi', 'matchNumber': 2,
          'teamAId': bracket[1].key, 'teamAName': bracket[1].value['teamName'],
          'teamBId': bracket[2].key, 'teamBName': bracket[2].value['teamName'],
          'status': 'pending', 'sets': [], 'result': {},
        });
        // Final placeholder
        await bracketRef.collection('matches').add({
          'round': 'final', 'matchNumber': 3,
          'teamAId': '', 'teamAName': '準決勝①勝者',
          'teamBId': '', 'teamBName': '準決勝②勝者',
          'status': 'waiting', 'sets': [], 'result': {},
        });
      } else if (bracket.length == 3) {
        // Round-robin for 3 teams
        int matchNum = 1;
        for (int i = 0; i < bracket.length; i++) {
          for (int j = i + 1; j < bracket.length; j++) {
            await bracketRef.collection('matches').add({
              'round': 'round-robin', 'matchNumber': matchNum++,
              'teamAId': bracket[i].key, 'teamAName': bracket[i].value['teamName'],
              'teamBId': bracket[j].key, 'teamBName': bracket[j].value['teamName'],
              'status': 'pending', 'sets': [], 'result': {},
            });
          }
        }
      } else if (bracket.length == 2) {
        await bracketRef.collection('matches').add({
          'round': 'final', 'matchNumber': 1,
          'teamAId': bracket[0].key, 'teamAName': bracket[0].value['teamName'],
          'teamBId': bracket[1].key, 'teamBName': bracket[1].value['teamName'],
          'status': 'pending', 'sets': [], 'result': {},
        });
      }
    }
  }

  /// Generate single elimination bracket for all teams
  Future<void> _generateSingleBracket(
    String tournamentId,
    List<MapEntry<String, Map<String, dynamic>>> sorted,
  ) async {
    final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').doc('bracket_main');
    await bracketRef.set({
      'bracketNumber': 1, 'bracketName': '順位決定戦',
      'teamCount': sorted.length, 'type': 'tournament', 'status': 'pending',
    });
    for (int i = 0; i < sorted.length ~/ 2; i++) {
      final a = sorted[i];
      final b = sorted[sorted.length - 1 - i];
      await bracketRef.collection('matches').add({
        'round': 'round1', 'matchNumber': i + 1,
        'teamAId': a.key, 'teamAName': a.value['teamName'],
        'teamBId': b.key, 'teamBName': b.value['teamName'],
        'status': 'pending', 'sets': [], 'result': {},
      });
    }
  }

  /// Split sorted teams into groups of N
  List<List<MapEntry<String, Map<String, dynamic>>>> _splitIntoGroups(
    List<MapEntry<String, Map<String, dynamic>>> sorted, int groupSize) {
    final groups = <List<MapEntry<String, Map<String, dynamic>>>>[];
    for (int i = 0; i < sorted.length; i += groupSize) {
      final end = (i + groupSize).clamp(0, sorted.length);
      groups.add(sorted.sublist(i, end));
    }
    return groups;
  }

  /// After a bracket semi-final is completed, update final match
  Future<void> updateBracketProgression({
    required String tournamentId,
    required String bracketId,
  }) async {
    final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').doc(bracketId);
    final matchesSnap = await bracketRef.collection('matches').orderBy('matchNumber').get();

    final semiMatches = matchesSnap.docs.where((d) => (d.data())['round'] == 'semi').toList();
    final finalMatch = matchesSnap.docs.where((d) => (d.data())['round'] == 'final').firstOrNull;

    if (semiMatches.length < 2) return;

    final semi1 = semiMatches[0].data();
    final semi2 = semiMatches[1].data();

    if (semi1['status'] != 'completed' || semi2['status'] != 'completed') return;

    final result1 = semi1['result'] as Map<String, dynamic>? ?? {};
    final result2 = semi2['result'] as Map<String, dynamic>? ?? {};

    final winner1Id = result1['winner'] ?? '';
    final winner1Name = winner1Id == semi1['teamAId'] ? semi1['teamAName'] : semi1['teamBName'];

    final winner2Id = result2['winner'] ?? '';
    final winner2Name = winner2Id == semi2['teamAId'] ? semi2['teamAName'] : semi2['teamBName'];

    if (finalMatch != null) {
      await finalMatch.reference.update({
        'teamAId': winner1Id, 'teamAName': winner1Name,
        'teamBId': winner2Id, 'teamBName': winner2Name,
        'status': 'pending',
      });
    }
  }

  /// Update standings for round-robin bracket (順位決定戦 総当たり)
  Future<void> updateBracketStandings({
    required String tournamentId,
    required String bracketId,
  }) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final rules = tournDoc.data()?['rules'] as Map<String, dynamic>? ?? {};
    final finalRules = rules['final'] as Map<String, dynamic>? ?? {};
    final setFormat = finalRules['sets'] ?? 3;
    final scoringMap = finalRules['scoring'] as Map<String, dynamic>? ?? {};
    final useMatchPoints = scoringMap.isNotEmpty;

    final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').doc(bracketId);
    final matchesSnap = await bracketRef.collection('matches')
        .where('status', isEqualTo: 'completed').get();

    final stats = <String, Map<String, dynamic>>{};

    for (var matchDoc in matchesSnap.docs) {
      final match = matchDoc.data();
      final result = match['result'] as Map<String, dynamic>? ?? {};
      final teamAId = match['teamAId'] as String;
      final teamBId = match['teamBId'] as String;
      final setsA = result['setsA'] ?? 0;
      final setsB = result['setsB'] ?? 0;
      final totalA = result['totalPointsA'] ?? 0;
      final totalB = result['totalPointsB'] ?? 0;

      stats.putIfAbsent(teamAId, () => _emptyStats(match['teamAName']));
      stats.putIfAbsent(teamBId, () => _emptyStats(match['teamBName']));

      if (useMatchPoints) {
        final mpResult = _calculateMatchPointsForFormat(
          setFormat: setFormat, setsA: setsA, setsB: setsB,
          totalA: totalA, totalB: totalB, scoring: scoringMap,
        );
        stats[teamAId]!['matchPoints'] += mpResult[0];
        stats[teamBId]!['matchPoints'] += mpResult[1];
        if (mpResult[0] > mpResult[1]) {
          stats[teamAId]!['wins']++; stats[teamBId]!['losses']++;
        } else if (mpResult[1] > mpResult[0]) {
          stats[teamBId]!['wins']++; stats[teamAId]!['losses']++;
        } else {
          stats[teamAId]!['draws']++; stats[teamBId]!['draws']++;
        }
      } else {
        if (setsA > setsB) {
          stats[teamAId]!['wins']++; stats[teamBId]!['losses']++;
          stats[teamAId]!['matchPoints'] += 2;
        } else if (setsB > setsA) {
          stats[teamBId]!['wins']++; stats[teamAId]!['losses']++;
          stats[teamBId]!['matchPoints'] += 2;
        } else {
          stats[teamAId]!['draws']++; stats[teamBId]!['draws']++;
          stats[teamAId]!['matchPoints'] += 1; stats[teamBId]!['matchPoints'] += 1;
        }
      }

      stats[teamAId]!['totalPoints'] += totalA;
      stats[teamBId]!['totalPoints'] += totalB;
      stats[teamAId]!['pointDiff'] += (totalA - totalB);
      stats[teamBId]!['pointDiff'] += (totalB - totalA);
    }

    // Sort and assign ranks
    final sorted = stats.entries.toList()
      ..sort((a, b) {
        final mp = (b.value['matchPoints'] as int).compareTo(a.value['matchPoints'] as int);
        if (mp != 0) return mp;
        final pd = (b.value['pointDiff'] as int).compareTo(a.value['pointDiff'] as int);
        if (pd != 0) return pd;
        return (b.value['totalPoints'] as int).compareTo(a.value['totalPoints'] as int);
      });

    for (int i = 0; i < sorted.length; i++) {
      final teamId = sorted[i].key;
      final teamStats = sorted[i].value;
      teamStats['rank'] = i + 1;
      await bracketRef.collection('standings').doc(teamId).set(teamStats);
    }
  }

}
