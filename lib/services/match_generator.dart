import 'package:cloud_firestore/cloud_firestore.dart';

class MatchGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate round-robin match table for preliminary round
  /// Returns list of generated match documents
  Future<List<Map<String, dynamic>>> generatePreliminary({
    required String tournamentId,
    required int roundNumber, // 1 or 2
    String assignmentMode = 'snake', // 'snake' or 'random' (round 2 only)
  }) async {
    final preview = await previewPreliminary(tournamentId: tournamentId, roundNumber: roundNumber, assignmentMode: assignmentMode);
    return savePreliminaryPreview(tournamentId: tournamentId, roundNumber: roundNumber, preview: preview);
  }

  /// Preview preliminary round without saving to Firestore.
  /// Returns { 'courts': List<List<Map>>, 'matches': List<Map> }
  Future<Map<String, dynamic>> previewPreliminary({
    required String tournamentId,
    required int roundNumber,
    String assignmentMode = 'snake',
  }) async {
    // 予選2以降の場合、前ラウンドが全て完了しているかチェック
    if (roundNumber >= 2) {
      await _validateRoundComplete(tournamentId, roundNumber - 1);
    }

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
    if (roundNumber >= 2 && assignmentMode == 'random') {
      courts = await _assignRandomAvoidDuplicates(tournamentId, entries, courtCount, teamsPerCourt);
    } else if (roundNumber == 1) {
      courts = _assignRandom(entries, courtCount, teamsPerCourt);
    } else {
      courts = await _assignSnakeDraft(tournamentId, entries, courtCount, teamsPerCourt);
    }

    // 4. Generate round-robin matches per court (in memory only)
    final allMatches = <Map<String, dynamic>>[];
    for (int courtIdx = 0; courtIdx < courts.length; courtIdx++) {
      final courtTeams = courts[courtIdx];
      final courtId = 'court_${courtIdx + 1}';
      final matches = _generateRoundRobin(courtTeams, courtId, courtIdx + 1);

      int matchOrder = 1;
      for (var match in matches) {
        match['roundNumber'] = roundNumber;
        match['matchOrder'] = matchOrder++;
        match['status'] = 'pending';
        match['sets'] = [];
        match['result'] = {};
        match['confirmedByA'] = false;
        match['confirmedByB'] = false;
        allMatches.add(match);
      }
    }

    return {'courts': courts, 'matches': allMatches};
  }

  /// Save a previously-previewed preliminary round to Firestore.
  Future<List<Map<String, dynamic>>> savePreliminaryPreview({
    required String tournamentId,
    required int roundNumber,
    required Map<String, dynamic> preview,
  }) async {
    final courts = (preview['courts'] as List).cast<List<Map<String, dynamic>>>();
    final allMatches = (preview['matches'] as List).cast<Map<String, dynamic>>();

    final roundRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').doc('round_$roundNumber');

    // Delete existing matches and standings before regenerating
    await _clearRoundData(roundRef);

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
    }

    // Save matches
    final savedMatches = <Map<String, dynamic>>[];
    for (var match in allMatches) {
      final docRef = await roundRef.collection('matches').add(match);
      match['matchId'] = docRef.id;
      savedMatches.add(match);
    }

    // Update tournament status
    await _firestore.collection('tournaments').doc(tournamentId).update({
      'status': '開催中',
      'currentRound': roundNumber,
    });

    return savedMatches;
  }

  /// Import pre-defined match table (対戦表CSVインポート)
  /// [matchRows] is a list of maps with keys: court, matchOrder, teamA, teamB, referee, subReferee
  Future<List<Map<String, dynamic>>> importMatchTable({
    required String tournamentId,
    required int roundNumber,
    required List<Map<String, String>> matchRows,
  }) async {
    // 1. Get entries to map teamName → teamId
    final entriesSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('entries').get();
    final nameToId = <String, String>{};
    final nameToEntry = <String, Map<String, dynamic>>{};
    for (var d in entriesSnap.docs) {
      final data = d.data();
      final name = (data['teamName'] as String? ?? '').trim();
      nameToId[name] = data['teamId'] ?? d.id;
      nameToEntry[name] = {'entryId': d.id, 'teamId': data['teamId'] ?? d.id, 'teamName': name, ...data};
    }

    // 2. Group matchRows by court
    final courtGroups = <String, List<Map<String, String>>>{};
    for (var row in matchRows) {
      final court = row['court'] ?? 'A';
      courtGroups.putIfAbsent(court, () => []);
      courtGroups[court]!.add(row);
    }

    // Sort courts alphabetically
    final sortedCourts = courtGroups.keys.toList()..sort();

    // 3. Create round document
    final roundRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').doc('round_$roundNumber');

    // Delete existing matches and standings before importing
    await _clearRoundData(roundRef);

    await roundRef.set({
      'roundNumber': roundNumber,
      'status': 'pending',
      'courtCount': sortedCourts.length,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final allMatches = <Map<String, dynamic>>[];

    for (int courtIdx = 0; courtIdx < sortedCourts.length; courtIdx++) {
      final courtLetter = sortedCourts[courtIdx];
      final courtId = 'court_${courtIdx + 1}';
      final courtNumber = courtIdx + 1;
      final rows = courtGroups[courtLetter]!;

      // Sort by matchOrder
      rows.sort((a, b) => (int.tryParse(a['matchOrder'] ?? '0') ?? 0)
          .compareTo(int.tryParse(b['matchOrder'] ?? '0') ?? 0));

      // Collect unique teams in this court
      final courtTeamNames = <String>{};
      for (var r in rows) {
        courtTeamNames.add(r['teamA'] ?? '');
        courtTeamNames.add(r['teamB'] ?? '');
      }
      courtTeamNames.remove('');

      // Create standings
      final standingRef = roundRef.collection('standings').doc(courtId);
      final teamIds = courtTeamNames.map((n) => nameToId[n] ?? n).toList();
      await standingRef.set({'courtNumber': courtNumber, 'teams': teamIds});

      for (var teamName in courtTeamNames) {
        final tid = nameToId[teamName] ?? teamName;
        await standingRef.collection('teams').doc(tid).set({
          'teamId': tid,
          'teamName': teamName,
          'matchPoints': 0,
          'pointDiff': 0,
          'totalPoints': 0,
          'wins': 0,
          'losses': 0,
          'draws': 0,
          'rank': 0,
        });
      }

      // Create matches
      int matchOrder = 1;
      for (var row in rows) {
        final teamAName = row['teamA'] ?? '';
        final teamBName = row['teamB'] ?? '';
        final refName = row['referee'] ?? '';
        final subRefName = row['subReferee'] ?? '';

        final match = <String, dynamic>{
          'courtId': courtId,
          'courtNumber': courtNumber,
          'teamAId': nameToId[teamAName] ?? teamAName,
          'teamAName': teamAName,
          'teamBId': nameToId[teamBName] ?? teamBName,
          'teamBName': teamBName,
          'refereeTeamId': nameToId[refName] ?? '',
          'refereeTeamName': refName,
          'subRefereeTeamId': nameToId[subRefName] ?? '',
          'subRefereeTeamName': subRefName,
          'roundNumber': roundNumber,
          'matchOrder': matchOrder++,
          'status': 'pending',
          'sets': [],
          'result': {},
          'confirmedByA': false,
          'confirmedByB': false,
        };

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
    final safeTpc = teamsPerCourt > 0 ? teamsPerCourt : 1;
    final actualCourts = (shuffled.length / safeTpc).ceil().clamp(1, courtCount);

    for (int i = 0; i < actualCourts; i++) {
      courts.add([]);
    }

    for (int i = 0; i < shuffled.length; i++) {
      courts[i % actualCourts].add(shuffled[i]);
    }

    return courts;
  }

  /// Random assignment for round 2 avoiding round 1 same-court teammates
  /// 予選1で同じコートだったチームをなるべく別コートに配置
  Future<List<List<Map<String, dynamic>>>> _assignRandomAvoidDuplicates(
      String tournamentId, List<Map<String, dynamic>> entries,
      int courtCount, int teamsPerCourt) async {
    // Get round 1 court groupings
    final round1Ref = _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').doc('round_1');
    final standingsSnap = await round1Ref.collection('standings').get();

    // Build a map: teamId -> set of teamIds that were on the same court in round 1
    final sameCourtMap = <String, Set<String>>{};
    for (var courtDoc in standingsSnap.docs) {
      final teams = List<String>.from(courtDoc.data()['teams'] ?? []);
      for (var tid in teams) {
        sameCourtMap.putIfAbsent(tid, () => {});
        sameCourtMap[tid]!.addAll(teams.where((t) => t != tid));
      }
    }

    final safeTpc = teamsPerCourt > 0 ? teamsPerCourt : 1;
    final actualCourts = (entries.length / safeTpc).ceil().clamp(1, courtCount);
    final courts = List.generate(actualCourts, (_) => <Map<String, dynamic>>[]);

    // Shuffle entries for randomness, then greedily place avoiding duplicates
    final remaining = List<Map<String, dynamic>>.from(entries)..shuffle();

    for (var entry in remaining) {
      final teamId = entry['teamId'] as String;
      final prevTeammates = sameCourtMap[teamId] ?? <String>{};

      // Score each court: count how many round 1 same-court members are already there
      int bestCourt = 0;
      int bestOverlap = 999;
      for (int c = 0; c < actualCourts; c++) {
        if (courts[c].length >= safeTpc) continue; // court full
        final overlap = courts[c].where((t) => prevTeammates.contains(t['teamId'])).length;
        if (overlap < bestOverlap) {
          bestOverlap = overlap;
          bestCourt = c;
        }
      }
      courts[bestCourt].add(entry);
    }

    return courts;
  }

  /// Snake draft assignment for round 2 (実力均等配置)
  /// 予選1の総合順位で蛇行配置し、各コートの実力を均等にする
  /// 例: 8チーム2コート → A: 1,4,5,8位 / B: 2,3,6,7位
  Future<List<List<Map<String, dynamic>>>> _assignSnakeDraft(
      String tournamentId, List<Map<String, dynamic>> entries,
      int courtCount, int teamsPerCourt) async {
    // Get overall sorted standings from round 1
    final sorted = await _getOverallSortedStandings(tournamentId);
    final teamIdOrder = sorted.map((e) => e.key).toList();

    // Sort entries by overall ranking
    final entryMap = <String, Map<String, dynamic>>{};
    for (var e in entries) {
      entryMap[e['teamId']] = e;
    }
    final rankedEntries = <Map<String, dynamic>>[];
    for (var teamId in teamIdOrder) {
      if (entryMap.containsKey(teamId)) {
        rankedEntries.add(entryMap.remove(teamId)!);
      }
    }
    // Append any remaining entries not found in standings
    rankedEntries.addAll(entryMap.values);

    // Snake draft: 1→2→3→3→2→1→1→2→3...
    final actualCourts = (entries.length / teamsPerCourt).ceil().clamp(1, courtCount);
    final courts = List.generate(actualCourts, (_) => <Map<String, dynamic>>[]);

    bool forward = true;
    int courtIdx = 0;
    for (var entry in rankedEntries) {
      courts[courtIdx].add(entry);
      if (forward) {
        if (courtIdx >= actualCourts - 1) {
          forward = false; // reverse direction
        } else {
          courtIdx++;
        }
      } else {
        if (courtIdx <= 0) {
          forward = true; // reverse direction
        } else {
          courtIdx--;
        }
      }
    }

    return courts;
  }

  /// Delete existing matches and standings sub-collections under a round
  Future<void> _clearRoundData(DocumentReference roundRef) async {
    // Delete matches
    final matchSnap = await roundRef.collection('matches').get();
    if (matchSnap.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (var doc in matchSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Delete standings and their sub-collections
    final standSnap = await roundRef.collection('standings').get();
    for (var standDoc in standSnap.docs) {
      final teamSnap = await standDoc.reference.collection('teams').get();
      if (teamSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in teamSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      await standDoc.reference.delete();
    }
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

  /// Generate final tournament brackets (順位決定戦)
  /// Throws if any preliminary round has incomplete matches.
  Future<void> generateFinals({
    required String tournamentId,
  }) async {
    final preview = await previewFinals(tournamentId: tournamentId);
    await saveFinalsPreview(tournamentId: tournamentId, preview: preview);
  }

  /// Preview finals bracket without saving to Firestore.
  /// Returns { 'sorted': overall standings, 'brackets': bracket data with matches }
  Future<Map<String, dynamic>> previewFinals({
    required String tournamentId,
  }) async {
    await _validatePreliminaryComplete(tournamentId);

    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final tournData = tournDoc.data()!;
    final rules = tournData['rules'] as Map<String, dynamic>? ?? {};
    final finalRules = rules['final'] as Map<String, dynamic>? ?? {};
    final format = finalRules['format'] ?? '順位別複数';

    final sorted = await _getOverallSortedStandings(tournamentId);

    final brackets = <Map<String, dynamic>>[];

    if (format == '順位別複数') {
      final leagueCount = (finalRules['tierCount'] as int? ?? 3).clamp(1, sorted.length);
      final teamsPerLeague = (sorted.length / leagueCount).ceil();
      final leagues = _splitIntoGroups(sorted, teamsPerLeague);
      final leagueNames = _getLeagueNames(leagues.length);

      for (int b = 0; b < leagues.length; b++) {
        final league = leagues[b];
        final leagueName = b < leagueNames.length ? leagueNames[b] : '第${b + 1}';
        final rankStart = b * teamsPerLeague + 1;
        final rankEnd = (rankStart + league.length - 1).clamp(rankStart, sorted.length);

        brackets.add({
          'bracketName': leagueName,
          'rankRange': '$rankStart〜$rankEnd位',
          'teams': league.map((e) => {'teamId': e.key, 'teamName': e.value['teamName']}).toList(),
          'teamCount': league.length,
        });
      }
    } else {
      brackets.add({
        'bracketName': '順位決定戦',
        'rankRange': '全チーム',
        'teams': sorted.map((e) => {'teamId': e.key, 'teamName': e.value['teamName']}).toList(),
        'teamCount': sorted.length,
      });
    }

    return {
      'sorted': sorted,
      'brackets': brackets,
      'format': format,
      'finalRules': finalRules,
    };
  }

  /// Save a previously-previewed finals bracket to Firestore.
  Future<void> saveFinalsPreview({
    required String tournamentId,
    required Map<String, dynamic> preview,
  }) async {
    final sorted = preview['sorted'] as List<MapEntry<String, Map<String, dynamic>>>;
    final format = preview['format'] as String;
    final finalRules = preview['finalRules'] as Map<String, dynamic>;

    if (format == '順位別複数') {
      await _generateTierBrackets(tournamentId, sorted, finalRules);
    } else {
      await _generateSingleBracket(tournamentId, sorted);
    }

    await _firestore.collection('tournaments').doc(tournamentId).update({'status': '順位決定中'});
  }

  /// 指定ラウンドの試合が全て完了しているか検証
  Future<void> _validateRoundComplete(String tournamentId, int roundNumber) async {
    final roundRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').doc('round_$roundNumber');
    final roundDoc = await roundRef.get();

    if (!roundDoc.exists) {
      throw Exception('予選${roundNumber}がまだ生成されていません。');
    }

    final matchesSnap = await roundRef.collection('matches').get();
    if (matchesSnap.docs.isEmpty) {
      throw Exception('予選${roundNumber}に試合がありません。');
    }

    final pendingMatches = matchesSnap.docs.where((d) {
      final status = (d.data())['status'] as String? ?? '';
      return status != 'completed';
    }).toList();

    if (pendingMatches.isNotEmpty) {
      throw Exception(
        '予選${roundNumber}にまだ未完了の試合が${pendingMatches.length}件あります。'
        '全試合を完了してから次に進んでください。'
      );
    }
  }

  /// 全予選ラウンドの試合が完了しているか検証
  Future<void> _validatePreliminaryComplete(String tournamentId) async {
    final roundsSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('rounds').get();

    if (roundsSnap.docs.isEmpty) {
      throw Exception('予選が生成されていません。先に予選を作成してください。');
    }

    for (var roundDoc in roundsSnap.docs) {
      final roundNum = (roundDoc.data())['roundNumber'] as int? ?? 1;
      await _validateRoundComplete(tournamentId, roundNum);
    }
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

  /// Generate tier-based tournament brackets (順位別トーナメント)
  /// 予選順位で自動的にリーグ分け → 各リーグでSEトーナメント（全順位決定）
  Future<void> _generateTierBrackets(
    String tournamentId,
    List<MapEntry<String, Map<String, dynamic>>> sorted,
    Map<String, dynamic> finalRules,
  ) async {
    // ルール設定の区分数（tierCount）を使用
    final leagueCount = (finalRules['tierCount'] as int? ?? 3).clamp(1, sorted.length);
    final teamsPerLeague = (sorted.length / leagueCount).ceil();
    final leagues = _splitIntoGroups(sorted, teamsPerLeague);

    // リーグ数に応じた名前を動的に決定
    final leagueNames = _getLeagueNames(leagues.length);

    for (int b = 0; b < leagues.length; b++) {
      final league = leagues[b];
      final leagueName = b < leagueNames.length ? leagueNames[b] : '第${b + 1}';
      final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
          .collection('brackets').doc('bracket_${b + 1}');

      // リーグの順位範囲を計算（例: 上 → 1〜8位）
      final rankStart = b * teamsPerLeague + 1;
      final rankEnd = (rankStart + league.length - 1).clamp(rankStart, sorted.length);

      await bracketRef.set({
        'bracketNumber': b + 1,
        'bracketName': leagueName,
        'teamCount': league.length,
        'rankRange': '$rankStart〜$rankEnd位',
        'type': 'tournament',
        'status': 'pending',
      });

      if (league.length >= 8) {
        // 8チーム以上: SE全順位決定トーナメント
        await _generate8TeamSE(bracketRef, league);
      } else if (league.length >= 4) {
        // 4〜7チーム: 4チームSE（準決勝→決勝+3位決定戦）
        await _generate4TeamSE(bracketRef, league);
      } else if (league.length == 3) {
        // 3チーム: 総当たり
        int matchNum = 1;
        for (int i = 0; i < league.length; i++) {
          for (int j = i + 1; j < league.length; j++) {
            await bracketRef.collection('matches').add({
              'round': 'round-robin', 'matchNumber': matchNum++,
              'teamAId': league[i].key, 'teamAName': league[i].value['teamName'],
              'teamBId': league[j].key, 'teamBName': league[j].value['teamName'],
              'status': 'pending', 'sets': [], 'result': {},
            });
          }
        }
      } else if (league.length == 2) {
        await bracketRef.collection('matches').add({
          'round': 'final', 'matchNumber': 1,
          'teamAId': league[0].key, 'teamAName': league[0].value['teamName'],
          'teamBId': league[1].key, 'teamBName': league[1].value['teamName'],
          'status': 'pending', 'sets': [], 'result': {},
        });
      }
    }
  }

  /// 8チームSE全順位決定トーナメント
  /// QF(4試合) → SF勝者(2) + SF敗者(2) → 決勝+3位+5位+7位決定戦(4)
  Future<void> _generate8TeamSE(
    DocumentReference bracketRef,
    List<MapEntry<String, Map<String, dynamic>>> teams,
  ) async {
    // QF: 1v8, 4v5, 2v7, 3v6（シード配置）
    final qfPairs = [
      [0, 7], // 1位 vs 8位
      [3, 4], // 4位 vs 5位
      [1, 6], // 2位 vs 7位
      [2, 5], // 3位 vs 6位
    ];
    for (int i = 0; i < qfPairs.length; i++) {
      final a = qfPairs[i][0] < teams.length ? teams[qfPairs[i][0]] : null;
      final b = qfPairs[i][1] < teams.length ? teams[qfPairs[i][1]] : null;
      if (a != null && b != null) {
        await bracketRef.collection('matches').add({
          'round': 'qf', 'matchNumber': i + 1,
          'teamAId': a.key, 'teamAName': a.value['teamName'],
          'teamBId': b.key, 'teamBName': b.value['teamName'],
          'status': 'pending', 'sets': [], 'result': {},
        });
      }
    }
    // SF勝者: QF①勝者 vs QF②勝者, QF③勝者 vs QF④勝者
    await bracketRef.collection('matches').add({
      'round': 'sf_winner', 'matchNumber': 5,
      'teamAId': '', 'teamAName': 'QF①勝者',
      'teamBId': '', 'teamBName': 'QF②勝者',
      'status': 'waiting', 'sets': [], 'result': {},
    });
    await bracketRef.collection('matches').add({
      'round': 'sf_winner', 'matchNumber': 6,
      'teamAId': '', 'teamAName': 'QF③勝者',
      'teamBId': '', 'teamBName': 'QF④勝者',
      'status': 'waiting', 'sets': [], 'result': {},
    });
    // SF敗者: QF①敗者 vs QF②敗者, QF③敗者 vs QF④敗者
    await bracketRef.collection('matches').add({
      'round': 'sf_loser', 'matchNumber': 7,
      'teamAId': '', 'teamAName': 'QF①敗者',
      'teamBId': '', 'teamBName': 'QF②敗者',
      'status': 'waiting', 'sets': [], 'result': {},
    });
    await bracketRef.collection('matches').add({
      'round': 'sf_loser', 'matchNumber': 8,
      'teamAId': '', 'teamAName': 'QF③敗者',
      'teamBId': '', 'teamBName': 'QF④敗者',
      'status': 'waiting', 'sets': [], 'result': {},
    });
    // 決勝(1-2位), 3位決定戦, 5位決定戦, 7位決定戦
    for (final entry in [
      {'round': 'final_1st', 'num': 9, 'a': 'SF勝者①勝者', 'b': 'SF勝者②勝者', 'label': '決勝（1-2位）'},
      {'round': 'final_3rd', 'num': 10, 'a': 'SF勝者①敗者', 'b': 'SF勝者②敗者', 'label': '3位決定戦'},
      {'round': 'final_5th', 'num': 11, 'a': 'SF敗者①勝者', 'b': 'SF敗者②勝者', 'label': '5位決定戦'},
      {'round': 'final_7th', 'num': 12, 'a': 'SF敗者①敗者', 'b': 'SF敗者②敗者', 'label': '7位決定戦'},
    ]) {
      await bracketRef.collection('matches').add({
        'round': entry['round'], 'matchNumber': entry['num'],
        'teamAId': '', 'teamAName': entry['a'],
        'teamBId': '', 'teamBName': entry['b'],
        'label': entry['label'],
        'status': 'waiting', 'sets': [], 'result': {},
      });
    }
  }

  /// 4チームSE（準決勝→決勝+3位決定戦）
  Future<void> _generate4TeamSE(
    DocumentReference bracketRef,
    List<MapEntry<String, Map<String, dynamic>>> teams,
  ) async {
    // SF: 1vs4, 2vs3
    await bracketRef.collection('matches').add({
      'round': 'semi', 'matchNumber': 1,
      'teamAId': teams[0].key, 'teamAName': teams[0].value['teamName'],
      'teamBId': teams.length > 3 ? teams[3].key : '', 'teamBName': teams.length > 3 ? teams[3].value['teamName'] : '',
      'status': 'pending', 'sets': [], 'result': {},
    });
    await bracketRef.collection('matches').add({
      'round': 'semi', 'matchNumber': 2,
      'teamAId': teams[1].key, 'teamAName': teams[1].value['teamName'],
      'teamBId': teams.length > 2 ? teams[2].key : '', 'teamBName': teams.length > 2 ? teams[2].value['teamName'] : '',
      'status': 'pending', 'sets': [], 'result': {},
    });
    // 決勝 + 3位決定戦
    await bracketRef.collection('matches').add({
      'round': 'final_1st', 'matchNumber': 3,
      'teamAId': '', 'teamAName': 'SF①勝者',
      'teamBId': '', 'teamBName': 'SF②勝者',
      'label': '決勝（1-2位）',
      'status': 'waiting', 'sets': [], 'result': {},
    });
    await bracketRef.collection('matches').add({
      'round': 'final_3rd', 'matchNumber': 4,
      'teamAId': '', 'teamAName': 'SF①敗者',
      'teamBId': '', 'teamBName': 'SF②敗者',
      'label': '3位決定戦',
      'status': 'waiting', 'sets': [], 'result': {},
    });
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

  /// After a bracket match is completed, update next round matches
  /// Handles: QF→SF(winner/loser), SF→Finals, Semi→Finals(4-team)
  Future<void> updateBracketProgression({
    required String tournamentId,
    required String bracketId,
  }) async {
    final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').doc(bracketId);
    final matchesSnap = await bracketRef.collection('matches').orderBy('matchNumber').get();

    // Group matches by round
    final byRound = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in matchesSnap.docs) {
      final round = (doc.data() as Map<String, dynamic>)['round'] as String? ?? '';
      byRound.putIfAbsent(round, () => []);
      byRound[round]!.add(doc);
    }

    // Sort each round's matches by matchNumber
    for (var list in byRound.values) {
      list.sort((a, b) => ((a.data() as Map<String, dynamic>)['matchNumber'] as int)
          .compareTo((b.data() as Map<String, dynamic>)['matchNumber'] as int));
    }

    // Helper: skip update if the target match is already completed
    bool _isCompleted(QueryDocumentSnapshot doc) =>
        (doc.data() as Map<String, dynamic>)['status'] == 'completed';

    // 8-team: QF → SF winner + SF loser
    if (byRound.containsKey('qf')) {
      final qf = byRound['qf']!;
      final allDone = qf.every((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed');
      if (allDone && qf.length >= 4) {
        final q1 = qf[0].data() as Map<String, dynamic>;
        final q2 = qf[1].data() as Map<String, dynamic>;
        final q3 = qf[2].data() as Map<String, dynamic>;
        final q4 = qf[3].data() as Map<String, dynamic>;

        final sfW = byRound['sf_winner'] ?? [];
        if (sfW.length >= 2) {
          if (!_isCompleted(sfW[0])) {
            await sfW[0].reference.update({
              'teamAId': _winnerId(q1), 'teamAName': _winnerName(q1),
              'teamBId': _winnerId(q2), 'teamBName': _winnerName(q2),
              'status': 'pending',
            });
          }
          if (!_isCompleted(sfW[1])) {
            await sfW[1].reference.update({
              'teamAId': _winnerId(q3), 'teamAName': _winnerName(q3),
              'teamBId': _winnerId(q4), 'teamBName': _winnerName(q4),
              'status': 'pending',
            });
          }
        }

        final sfL = byRound['sf_loser'] ?? [];
        if (sfL.length >= 2) {
          if (!_isCompleted(sfL[0])) {
            await sfL[0].reference.update({
              'teamAId': _loserId(q1), 'teamAName': _loserName(q1),
              'teamBId': _loserId(q2), 'teamBName': _loserName(q2),
              'status': 'pending',
            });
          }
          if (!_isCompleted(sfL[1])) {
            await sfL[1].reference.update({
              'teamAId': _loserId(q3), 'teamAName': _loserName(q3),
              'teamBId': _loserId(q4), 'teamBName': _loserName(q4),
              'status': 'pending',
            });
          }
        }
      }
    }

    // SF winner → Final 1st + 3rd
    if (byRound.containsKey('sf_winner')) {
      final sfW = byRound['sf_winner']!;
      final allDone = sfW.every((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed');
      if (allDone && sfW.length >= 2) {
        final sw1 = sfW[0].data() as Map<String, dynamic>;
        final sw2 = sfW[1].data() as Map<String, dynamic>;

        final f1st = byRound['final_1st']?.firstOrNull;
        if (f1st != null && !_isCompleted(f1st)) {
          await f1st.reference.update({
            'teamAId': _winnerId(sw1), 'teamAName': _winnerName(sw1),
            'teamBId': _winnerId(sw2), 'teamBName': _winnerName(sw2),
            'status': 'pending',
          });
        }
        final f3rd = byRound['final_3rd']?.firstOrNull;
        if (f3rd != null && !_isCompleted(f3rd)) {
          await f3rd.reference.update({
            'teamAId': _loserId(sw1), 'teamAName': _loserName(sw1),
            'teamBId': _loserId(sw2), 'teamBName': _loserName(sw2),
            'status': 'pending',
          });
        }
      }
    }

    // SF loser → Final 5th + 7th
    if (byRound.containsKey('sf_loser')) {
      final sfL = byRound['sf_loser']!;
      final allDone = sfL.every((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed');
      if (allDone && sfL.length >= 2) {
        final sl1 = sfL[0].data() as Map<String, dynamic>;
        final sl2 = sfL[1].data() as Map<String, dynamic>;

        final f5th = byRound['final_5th']?.firstOrNull;
        if (f5th != null && !_isCompleted(f5th)) {
          await f5th.reference.update({
            'teamAId': _winnerId(sl1), 'teamAName': _winnerName(sl1),
            'teamBId': _winnerId(sl2), 'teamBName': _winnerName(sl2),
            'status': 'pending',
          });
        }
        final f7th = byRound['final_7th']?.firstOrNull;
        if (f7th != null && !_isCompleted(f7th)) {
          await f7th.reference.update({
            'teamAId': _loserId(sl1), 'teamAName': _loserName(sl1),
            'teamBId': _loserId(sl2), 'teamBName': _loserName(sl2),
            'status': 'pending',
          });
        }
      }
    }

    // 4-team: semi → final_1st + final_3rd
    if (byRound.containsKey('semi')) {
      final semi = byRound['semi']!;
      final allDone = semi.every((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed');
      if (allDone && semi.length >= 2) {
        final s1 = semi[0].data() as Map<String, dynamic>;
        final s2 = semi[1].data() as Map<String, dynamic>;

        final f1st = byRound['final_1st']?.firstOrNull;
        if (f1st != null && !_isCompleted(f1st)) {
          await f1st.reference.update({
            'teamAId': _winnerId(s1), 'teamAName': _winnerName(s1),
            'teamBId': _winnerId(s2), 'teamBName': _winnerName(s2),
            'status': 'pending',
          });
        }
        final f3rd = byRound['final_3rd']?.firstOrNull;
        if (f3rd != null && !_isCompleted(f3rd)) {
          await f3rd.reference.update({
            'teamAId': _loserId(s1), 'teamAName': _loserName(s1),
            'teamBId': _loserId(s2), 'teamBName': _loserName(s2),
            'status': 'pending',
          });
        }
      }
    }
  }

  /// リーグ数に応じたリーグ名を返す
  /// 2 → [上, 下]
  /// 3 → [上, 中, 下]
  /// 4 → [上, 中上, 中下, 下]
  /// 5 → [上, 中上, 中, 中下, 下]
  /// 6+ → [上, 中上, 中, 中下, 下, エンジョイ, ...]
  List<String> _getLeagueNames(int count) {
    switch (count) {
      case 1:
        return ['リーグ'];
      case 2:
        return ['上位リーグ', '下位リーグ'];
      case 3:
        return ['上位リーグ', '中位リーグ', '下位リーグ'];
      case 4:
        return ['上位リーグ', '中上位リーグ', '中下位リーグ', '下位リーグ'];
      case 5:
        return ['上位リーグ', '中上位リーグ', '中位リーグ', '中下位リーグ', '下位リーグ'];
      case 6:
        return ['上位リーグ', '中上位リーグ', '中位リーグ', '中下位リーグ', '下位リーグ', 'エンジョイ'];
      default:
        final names = ['上位リーグ', '中上位リーグ', '中位リーグ', '中下位リーグ', '下位リーグ'];
        for (int i = 5; i < count; i++) {
          names.add('第${i + 1}リーグ');
        }
        return names;
    }
  }

  // Helper: extract winner/loser ID and name from completed match
  String _winnerId(Map<String, dynamic> m) =>
      (m['result'] as Map<String, dynamic>? ?? {})['winner'] ?? '';
  String _winnerName(Map<String, dynamic> m) {
    final wId = _winnerId(m);
    return wId == m['teamAId'] ? (m['teamAName'] ?? '') : (m['teamBName'] ?? '');
  }
  String _loserId(Map<String, dynamic> m) {
    final wId = _winnerId(m);
    return wId == m['teamAId'] ? (m['teamBId'] ?? '') : (m['teamAId'] ?? '');
  }
  String _loserName(Map<String, dynamic> m) {
    final wId = _winnerId(m);
    return wId == m['teamAId'] ? (m['teamBName'] ?? '') : (m['teamAName'] ?? '');
  }

}
