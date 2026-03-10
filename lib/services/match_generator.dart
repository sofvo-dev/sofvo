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

        // Parse scores from CSV (set1A, set1B, set2A, set2B, set3A, set3B)
        final sets = <Map<String, int>>[];
        for (int s = 1; s <= 3; s++) {
          final a = int.tryParse(row['set${s}A'] ?? '');
          final b = int.tryParse(row['set${s}B'] ?? '');
          if (a != null && b != null) {
            sets.add({'a': a, 'b': b});
          }
        }
        final hasScore = sets.isNotEmpty;

        // Calculate result if scores exist
        Map<String, dynamic> result = {};
        String status = 'pending';
        if (hasScore) {
          int setsA = 0, setsB = 0, totalA = 0, totalB = 0;
          for (var set in sets) {
            totalA += set['a']!;
            totalB += set['b']!;
            if (set['a']! > set['b']!) setsA++;
            else if (set['b']! > set['a']!) setsB++;
          }
          final teamAId = nameToId[teamAName] ?? teamAName;
          final teamBId = nameToId[teamBName] ?? teamBName;
          final winner = setsA > setsB ? teamAId : (setsB > setsA ? teamBId : (totalA > totalB ? teamAId : (totalB > totalA ? teamBId : '引き分け')));
          result = {
            'setsA': setsA, 'setsB': setsB,
            'totalPointsA': totalA, 'totalPointsB': totalB,
            'winner': winner,
          };
          status = 'completed';
        }

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
          'status': status,
          'sets': sets,
          'result': result,
          'confirmedByA': hasScore,
          'confirmedByB': hasScore,
        };

        if (hasScore) {
          match['refereeConfirmed'] = true;
        }

        final docRef = await roundRef.collection('matches').add(match);
        match['matchId'] = docRef.id;
        allMatches.add(match);
      }
    }

    // Update standings for courts that have scored matches
    final courtsWithScores = <String>{};
    for (var match in allMatches) {
      if (match['status'] == 'completed') {
        courtsWithScores.add(match['courtId'] as String);
      }
    }
    for (var cid in courtsWithScores) {
      await updateStandings(tournamentId: tournamentId, roundNumber: roundNumber, courtId: cid);
    }

    // Update tournament status
    final allCompleted = allMatches.every((m) => m['status'] == 'completed');
    await _firestore.collection('tournaments').doc(tournamentId).update({
      'status': allCompleted ? '予選${roundNumber}完了' : '開催中',
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

      // 同順位チームの検出（境界をまたぐ同スコアチーム）
      final tiedTeamIds = <String>{};
      int idx = 0;
      for (int b = 0; b < leagues.length - 1; b++) {
        idx += leagues[b].length;
        if (idx > 0 && idx < sorted.length) {
          final prev = sorted[idx - 1].value;
          final curr = sorted[idx].value;
          if ((prev['matchPoints'] as int) == (curr['matchPoints'] as int) &&
              (prev['pointDiff'] as int) == (curr['pointDiff'] as int) &&
              (prev['totalPoints'] as int) == (curr['totalPoints'] as int)) {
            // この境界前後で同スコアのチームを全て収集
            final mp = prev['matchPoints'] as int;
            final pd = prev['pointDiff'] as int;
            final tp = prev['totalPoints'] as int;
            for (final e in sorted) {
              if ((e.value['matchPoints'] as int) == mp &&
                  (e.value['pointDiff'] as int) == pd &&
                  (e.value['totalPoints'] as int) == tp) {
                tiedTeamIds.add(e.key);
              }
            }
          }
        }
      }

      for (int b = 0; b < leagues.length; b++) {
        final league = leagues[b];
        final leagueName = b < leagueNames.length ? leagueNames[b] : '第${b + 1}';
        final rankStart = b * teamsPerLeague + 1;
        final rankEnd = (rankStart + league.length - 1).clamp(rankStart, sorted.length);

        brackets.add({
          'bracketName': leagueName,
          'rankRange': '$rankStart〜$rankEnd位',
          'teams': league.map((e) {
            return {
              'teamId': e.key,
              'teamName': e.value['teamName'],
              'isTied': tiedTeamIds.contains(e.key),
              'matchPoints': e.value['matchPoints'],
              'pointDiff': e.value['pointDiff'],
              'totalPoints': e.value['totalPoints'],
            };
          }).toList(),
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
    final brackets = preview['brackets'] as List<Map<String, dynamic>>?;

    if (format == '順位別複数') {
      // ユーザーが調整したbrackets情報がある場合、そこからsortedを再構築
      if (brackets != null && brackets.isNotEmpty) {
        final adjustedSorted = <MapEntry<String, Map<String, dynamic>>>[];
        for (final bracket in brackets) {
          final teams = (bracket['teams'] as List).cast<Map<String, dynamic>>();
          for (final team in teams) {
            final teamId = team['teamId'] as String;
            final original = sorted.firstWhere((e) => e.key == teamId,
                orElse: () => MapEntry(teamId, {'teamName': team['teamName'] ?? ''}));
            adjustedSorted.add(original);
          }
        }
        await _generateTierBrackets(tournamentId, adjustedSorted, finalRules);
      } else {
        await _generateTierBrackets(tournamentId, sorted, finalRules);
      }
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
    // Get total court count for distribution
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final totalCourts = (tournDoc.data()?['courts'] ?? 2) as int;

    // ルール設定の区分数（tierCount）を使用
    final leagueCount = (finalRules['tierCount'] as int? ?? 3).clamp(1, sorted.length);
    final teamsPerLeague = (sorted.length / leagueCount).ceil();
    final leagues = _splitIntoGroups(sorted, teamsPerLeague);

    // リーグ数に応じた名前を動的に決定
    final leagueNames = _getLeagueNames(leagues.length);

    // コートをリーグに均等配分（例: 6コート / 3リーグ = 各2コート）
    final courtsPerLeague = <int, List<int>>{}; // leagueIdx -> [courtNumber, ...]
    int courtIdx = 1;
    for (int b = 0; b < leagues.length; b++) {
      final courtCount = (totalCourts / leagues.length).ceil().clamp(1, totalCourts);
      courtsPerLeague[b] = [];
      for (int c = 0; c < courtCount && courtIdx <= totalCourts; c++) {
        courtsPerLeague[b]!.add(courtIdx++);
      }
      // 少なくとも1コートは保証
      if (courtsPerLeague[b]!.isEmpty) {
        courtsPerLeague[b]!.add(b + 1);
      }
    }

    for (int b = 0; b < leagues.length; b++) {
      final league = leagues[b];
      final leagueName = b < leagueNames.length ? leagueNames[b] : '第${b + 1}';
      final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
          .collection('brackets').doc('bracket_${b + 1}');

      // リーグの順位範囲を計算（例: 上 → 1〜8位）
      final rankStart = b * teamsPerLeague + 1;
      final rankEnd = (rankStart + league.length - 1).clamp(rankStart, sorted.length);
      final leagueCourts = courtsPerLeague[b] ?? [b + 1];

      await bracketRef.set({
        'bracketNumber': b + 1,
        'bracketName': leagueName,
        'teamCount': league.length,
        'rankRange': '$rankStart〜$rankEnd位',
        'type': 'tournament',
        'status': 'pending',
        'courts': leagueCourts,
        'teamIds': league.map((e) => e.key).toList(),
      });

      // リーグ内の全チームIDリスト（審判割り当て用）
      final leagueTeams = league.map((e) => {'teamId': e.key, 'teamName': e.value['teamName'] as String}).toList();

      if (league.length >= 8) {
        await _generate8TeamSE(bracketRef, league, leagueCourts, leagueTeams);
      } else if (league.length >= 5) {
        await _generate5to7TeamSE(bracketRef, league, leagueCourts, leagueTeams);
      } else if (league.length == 4) {
        await _generate4TeamSE(bracketRef, league, leagueCourts, leagueTeams);
      } else if (league.length == 3) {
        // 3チーム: 1位シード付きトーナメント
        // 第1試合（準決勝）: 2位 vs 3位、1位が審判
        // 第2試合（決勝）: 1位 vs 第1試合の勝者、敗者が審判
        await _generate3TeamSE(bracketRef, league, leagueCourts, leagueTeams);
      } else if (league.length == 2) {
        final courtNum = leagueCourts.first;
        await bracketRef.collection('matches').add({
          'round': 'final', 'matchNumber': 1,
          'teamAId': league[0].key, 'teamAName': league[0].value['teamName'],
          'teamBId': league[1].key, 'teamBName': league[1].value['teamName'],
          'refereeTeamId': '', 'refereeTeamName': '',
          'subRefereeTeamId': '', 'subRefereeTeamName': '',
          'courtNumber': courtNum,
          'courtId': 'court_$courtNum',
          'status': 'pending', 'sets': [], 'result': {},
        });
      }
    }
  }

  /// 8チームSE全順位決定トーナメント
  /// QF(4試合) → SF勝者(2) + SF敗者(2) → 決勝+3位+5位+7位決定戦(4)
  /// 3チーム: 1位シード付きトーナメント
  /// 第1試合（準決勝）: 2位 vs 3位、1位が審判
  /// 第2試合（決勝）: 1位 vs 第1試合の勝者、敗者が審判
  Future<void> _generate3TeamSE(
    DocumentReference bracketRef,
    List<MapEntry<String, Map<String, dynamic>>> teams,
    List<int> leagueCourts,
    List<Map<String, String>> leagueTeams,
  ) async {
    final courtNum = leagueCourts.first;

    // teams[0] = 1位（シード）, teams[1] = 2位, teams[2] = 3位

    // 第1試合（準決勝）: 2位 vs 3位、審判は1位
    await bracketRef.collection('matches').add({
      'round': 'semi', 'matchNumber': 1,
      'teamAId': teams[1].key, 'teamAName': teams[1].value['teamName'],
      'teamBId': teams[2].key, 'teamBName': teams[2].value['teamName'],
      'refereeTeamId': teams[0].key, 'refereeTeamName': teams[0].value['teamName'],
      'subRefereeTeamId': '', 'subRefereeTeamName': '',
      'courtNumber': courtNum, 'courtId': 'court_$courtNum',
      'status': 'pending', 'sets': [], 'result': {},
    });

    // 第2試合（決勝）: 1位 vs 第1試合の勝者、審判は第1試合の敗者
    await bracketRef.collection('matches').add({
      'round': 'final_1st', 'matchNumber': 2,
      'teamAId': teams[0].key, 'teamAName': teams[0].value['teamName'],
      'teamBId': '', 'teamBName': '第1試合 勝者',
      'label': '決勝',
      'refereeTeamId': '', 'refereeTeamName': '第1試合 敗者',
      'subRefereeTeamId': '', 'subRefereeTeamName': '',
      'courtNumber': courtNum, 'courtId': 'court_$courtNum',
      'status': 'waiting', 'sets': [], 'result': {},
    });
  }

  Future<void> _generate8TeamSE(
    DocumentReference bracketRef,
    List<MapEntry<String, Map<String, dynamic>>> teams,
    List<int> leagueCourts,
    List<Map<String, String>> leagueTeams,
  ) async {
    // 審判カウント（同リーグ内で平等に）
    final mainRefCount = <String, int>{};
    final subRefCount = <String, int>{};
    for (var t in leagueTeams) { mainRefCount[t['teamId']!] = 0; subRefCount[t['teamId']!] = 0; }

    Map<String, String> _pickRefs(Set<String> playingIds, int teamCount) {
      final available = leagueTeams.where((t) => !playingIds.contains(t['teamId'])).toList();
      available.sort((a, b) => (mainRefCount[a['teamId']]!).compareTo(mainRefCount[b['teamId']]!));
      final mainRef = available.isNotEmpty ? available.first : null;
      if (mainRef != null) mainRefCount[mainRef['teamId']!] = (mainRefCount[mainRef['teamId']!] ?? 0) + 1;

      String subRefId = '', subRefName = '';
      if (teamCount >= 4 && available.length >= 2) {
        final subCandidates = available.where((t) => t['teamId'] != mainRef?['teamId']).toList();
        subCandidates.sort((a, b) => (subRefCount[a['teamId']]!).compareTo(subRefCount[b['teamId']]!));
        if (subCandidates.isNotEmpty) {
          subRefId = subCandidates.first['teamId']!;
          subRefName = subCandidates.first['teamName']!;
          subRefCount[subRefId] = (subRefCount[subRefId] ?? 0) + 1;
        }
      }

      return {
        'refereeTeamId': mainRef?['teamId'] ?? '',
        'refereeTeamName': mainRef?['teamName'] ?? '',
        'subRefereeTeamId': subRefId,
        'subRefereeTeamName': subRefName,
      };
    }

    int matchIdx = 0;
    final slotReferees = <int, Set<String>>{};

    // QF: 1v8, 2v7, 4v5, 3v6（シード配置）
    // コート割り当て: A(1v8), B(2v7), A(4v5), B(3v6)
    // SFはクロスコート: A第1勝者 vs B第1勝者, A第2勝者 vs B第2勝者
    final qfPairs = [
      [0, 7], // 1位 vs 8位（コート1）
      [1, 6], // 2位 vs 7位（コート2）
      [3, 4], // 4位 vs 5位（コート1）
      [2, 5], // 3位 vs 6位（コート2）
    ];

    // 同時進行試合をコート数でグループ化して、同時に出場するチームを把握
    final courtCount = leagueCourts.length;
    // QFの有効ペアを先に構築
    final qfValidPairs = <List<MapEntry<String, Map<String, dynamic>>>>[];
    for (final pair in qfPairs) {
      final a = pair[0] < teams.length ? teams[pair[0]] : null;
      final b = pair[1] < teams.length ? teams[pair[1]] : null;
      if (a != null && b != null) qfValidPairs.add([a, b]);
    }

    // 同時進行する試合グループ（コート数分ずつ同時進行）
    for (int i = 0; i < qfValidPairs.length; i++) {
      final a = qfValidPairs[i][0];
      final b = qfValidPairs[i][1];

      // 同時進行する試合の全出場チーム＋既に割り当てられた審判を収集
      final concurrentSlot = matchIdx ~/ courtCount;
      final busyIds = <String>{a.key, b.key};
      for (int j = 0; j < qfValidPairs.length; j++) {
        if (j != i && (j ~/ courtCount) == concurrentSlot) {
          busyIds.add(qfValidPairs[j][0].key);
          busyIds.add(qfValidPairs[j][1].key);
        }
      }
      busyIds.addAll(slotReferees[concurrentSlot] ?? {});

      final refs = _pickRefs(busyIds, leagueTeams.length);
      // 割り当てた審判をスロットに記録
      if (refs['refereeTeamId']!.isNotEmpty) slotReferees.putIfAbsent(concurrentSlot, () => {}).add(refs['refereeTeamId']!);
      if (refs['subRefereeTeamId']!.isNotEmpty) slotReferees.putIfAbsent(concurrentSlot, () => {}).add(refs['subRefereeTeamId']!);
      final courtNum = leagueCourts[matchIdx % courtCount];
      matchIdx++;
      await bracketRef.collection('matches').add({
        'round': 'qf', 'matchNumber': i + 1,
        'teamAId': a.key, 'teamAName': a.value['teamName'],
        'teamBId': b.key, 'teamBName': b.value['teamName'],
        ...refs,
        'courtNumber': courtNum, 'courtId': 'court_$courtNum',
        'status': 'pending', 'sets': [], 'result': {},
      });
    }

    // SF以降はチーム未定のため審判は空、コートは割り当て
    // クロスコートSF: A第1勝者 vs B第1勝者(Aコート), A第1敗者 vs B第1敗者(Bコート)
    // 勝者側→Aコート, 敗者側→Bコート を交互に配置
    for (final entry in [
      {'round': 'sf_winner', 'num': 5, 'a': '第1試合 勝者', 'b': '第2試合 勝者'},
      {'round': 'sf_loser', 'num': 6, 'a': '第1試合 敗者', 'b': '第2試合 敗者'},
      {'round': 'sf_winner', 'num': 7, 'a': '第3試合 勝者', 'b': '第4試合 勝者'},
      {'round': 'sf_loser', 'num': 8, 'a': '第3試合 敗者', 'b': '第4試合 敗者'},
    ]) {
      final courtNum = leagueCourts[matchIdx % leagueCourts.length];
      matchIdx++;
      await bracketRef.collection('matches').add({
        'round': entry['round'], 'matchNumber': entry['num'],
        'teamAId': '', 'teamAName': entry['a'],
        'teamBId': '', 'teamBName': entry['b'],
        'refereeTeamId': '', 'refereeTeamName': '',
        'subRefereeTeamId': '', 'subRefereeTeamName': '',
        'courtNumber': courtNum, 'courtId': 'court_$courtNum',
        'status': 'waiting', 'sets': [], 'result': {},
      });
    }

    // 決勝系: Aコート=勝者側(3位決定・決勝), Bコート=敗者側(7位決定・5位決定)
    for (final entry in [
      {'round': 'final_3rd', 'num': 9, 'a': '第5試合 敗者', 'b': '第7試合 敗者', 'label': '3位決定戦'},
      {'round': 'final_7th', 'num': 10, 'a': '第6試合 敗者', 'b': '第8試合 敗者', 'label': '7位決定戦'},
      {'round': 'final_1st', 'num': 11, 'a': '第5試合 勝者', 'b': '第7試合 勝者', 'label': '決勝（1-2位）'},
      {'round': 'final_5th', 'num': 12, 'a': '第6試合 勝者', 'b': '第8試合 勝者', 'label': '5位決定戦'},
    ]) {
      final courtNum = leagueCourts[matchIdx % leagueCourts.length];
      matchIdx++;
      await bracketRef.collection('matches').add({
        'round': entry['round'], 'matchNumber': entry['num'],
        'teamAId': '', 'teamAName': entry['a'],
        'teamBId': '', 'teamBName': entry['b'],
        'label': entry['label'],
        'refereeTeamId': '', 'refereeTeamName': '',
        'subRefereeTeamId': '', 'subRefereeTeamName': '',
        'courtNumber': courtNum, 'courtId': 'court_$courtNum',
        'status': 'waiting', 'sets': [], 'result': {},
      });
    }
  }

  /// 5〜7チームSE全順位決定トーナメント（BYE付き8チームブラケット）
  /// 8チームブラケットの空きスロットにBYEを入れ、上位シードを自動進出させる
  /// QF → SF(勝者) + 5位決定戦(敗者) → 決勝 + 3位決定戦
  Future<void> _generate5to7TeamSE(
    DocumentReference bracketRef,
    List<MapEntry<String, Map<String, dynamic>>> teams,
    List<int> leagueCourts,
    List<Map<String, String>> leagueTeams,
  ) async {
    final n = teams.length; // 5, 6, or 7
    final mainRefCount = <String, int>{};
    final subRefCount = <String, int>{};
    for (var t in leagueTeams) { mainRefCount[t['teamId']!] = 0; subRefCount[t['teamId']!] = 0; }

    Map<String, String> _pickRefs(Set<String> busyIds) {
      final available = leagueTeams.where((t) => !busyIds.contains(t['teamId'])).toList();
      available.sort((a, b) => (mainRefCount[a['teamId']]!).compareTo(mainRefCount[b['teamId']]!));
      final mainRef = available.isNotEmpty ? available.first : null;
      if (mainRef != null) mainRefCount[mainRef['teamId']!] = (mainRefCount[mainRef['teamId']!] ?? 0) + 1;
      String subRefId = '', subRefName = '';
      if (available.length >= 2) {
        final subCandidates = available.where((t) => t['teamId'] != mainRef?['teamId']).toList();
        subCandidates.sort((a, b) => (subRefCount[a['teamId']]!).compareTo(subRefCount[b['teamId']]!));
        if (subCandidates.isNotEmpty) {
          subRefId = subCandidates.first['teamId']!;
          subRefName = subCandidates.first['teamName']!;
          subRefCount[subRefId] = (subRefCount[subRefId] ?? 0) + 1;
        }
      }
      return {
        'refereeTeamId': mainRef?['teamId'] ?? '', 'refereeTeamName': mainRef?['teamName'] ?? '',
        'subRefereeTeamId': subRefId, 'subRefereeTeamName': subRefName,
      };
    }

    int matchIdx = 0;
    final courtCount = leagueCourts.length;

    // 8チームブラケットのQFペア（シード配置）
    // クロスコート: A(1v8), B(2v7), A(4v5), B(3v6)
    // SFはクロスコート: A第1勝者 vs B第1勝者, A第2勝者 vs B第2勝者
    // チーム不在のスロット = BYE（上位シードが自動進出）
    final qfSeeds = [
      [0, 7], // QF1: 1位 vs 8位 → n<8なら1位BYE（コート1）
      [1, 6], // QF2: 2位 vs 7位 → n<7なら2位BYE（コート2）
      [3, 4], // QF3: 4位 vs 5位（コート1）
      [2, 5], // QF4: 3位 vs 6位 → n<6なら3位BYE（コート2）
    ];

    // BYE判定: 対戦相手がいないペア → 上位シードが自動進出
    // 実際の試合が必要なペアのみ生成
    final qfResults = <int, Map<String, String>>{}; // qfIndex → {winnerId, winnerName, loserId, loserName}

    for (int qi = 0; qi < 4; qi++) {
      final aIdx = qfSeeds[qi][0];
      final bIdx = qfSeeds[qi][1];

      if (bIdx >= n) {
        // BYE: 上位シードが自動進出
        qfResults[qi] = {
          'winnerId': teams[aIdx].key,
          'winnerName': teams[aIdx].value['teamName'] as String,
          'loserId': '', 'loserName': '',
        };
      } else {
        // 実際の試合を生成
        final busyIds = <String>{teams[aIdx].key, teams[bIdx].key};
        final refs = _pickRefs(busyIds);
        final courtNum = leagueCourts[matchIdx % courtCount];
        matchIdx++;

        await bracketRef.collection('matches').add({
          'round': 'qf', 'matchNumber': matchIdx,
          'teamAId': teams[aIdx].key, 'teamAName': teams[aIdx].value['teamName'],
          'teamBId': teams[bIdx].key, 'teamBName': teams[bIdx].value['teamName'],
          ...refs,
          'courtNumber': courtNum, 'courtId': 'court_$courtNum',
          'status': 'pending', 'sets': [], 'result': {},
          'qfIndex': qi, // QFスロット番号（BYE進出のSF自動更新用）
        });
      }
    }

    // SF勝者側: クロスコート QF1勝者(A) vs QF2勝者(B)、QF3勝者(A) vs QF4勝者(B)
    final sfPairs = [[0, 1], [2, 3]]; // qfResultのインデックス（クロスコート）
    for (int si = 0; si < sfPairs.length; si++) {
      final qiA = sfPairs[si][0];
      final qiB = sfPairs[si][1];

      // BYEチームはSFに直接配置
      final aIsBye = qfResults.containsKey(qiA);
      final bIsBye = qfResults.containsKey(qiB);

      final courtNum = leagueCourts[matchIdx % courtCount];
      matchIdx++;

      String teamAId = '', teamAName = '', teamBId = '', teamBName = '';
      String status = 'waiting';
      Map<String, String> refs = {'refereeTeamId': '', 'refereeTeamName': '', 'subRefereeTeamId': '', 'subRefereeTeamName': ''};

      if (aIsBye && bIsBye) {
        // 両方BYE → 両チーム確定
        teamAId = qfResults[qiA]!['winnerId']!;
        teamAName = qfResults[qiA]!['winnerName']!;
        teamBId = qfResults[qiB]!['winnerId']!;
        teamBName = qfResults[qiB]!['winnerName']!;
        status = 'pending';
        refs = _pickRefs({teamAId, teamBId});
      } else if (aIsBye) {
        teamAId = qfResults[qiA]!['winnerId']!;
        teamAName = qfResults[qiA]!['winnerName']!;
        teamBName = 'QF${qiB + 1}勝者';
        status = 'waiting';
      } else if (bIsBye) {
        teamAName = 'QF${qiA + 1}勝者';
        teamBId = qfResults[qiB]!['winnerId']!;
        teamBName = qfResults[qiB]!['winnerName']!;
        status = 'waiting';
      } else {
        teamAName = 'QF${qiA + 1}勝者';
        teamBName = 'QF${qiB + 1}勝者';
        status = 'waiting';
      }

      await bracketRef.collection('matches').add({
        'round': 'sf_winner', 'matchNumber': matchIdx,
        'teamAId': teamAId, 'teamAName': teamAName,
        'teamBId': teamBId, 'teamBName': teamBName,
        ...refs,
        'courtNumber': courtNum, 'courtId': 'court_$courtNum',
        'status': status, 'sets': [], 'result': {},
        'sfIndex': si, // SF番号
      });
    }

    // 敗者側: QFの敗者同士で下位順位を決定
    // BYEの敗者はいないので、実際に試合があったQFの敗者のみ
    final qfMatchIndices = <int>[]; // 実試合があるQFインデックス
    for (int qi = 0; qi < 4; qi++) {
      if (!qfResults.containsKey(qi)) qfMatchIndices.add(qi);
    }

    // 敗者の試合数に応じて生成
    if (qfMatchIndices.length >= 2) {
      // 2試合以上の敗者 → 敗者戦を生成
      // 6チーム: QF2敗者 vs QF4敗者 → 5位決定戦
      // 7チーム: QF2敗者 vs QF3敗者 + QF4敗者 → 複数試合
      if (qfMatchIndices.length == 2) {
        // 5位決定戦（6チーム: 2試合の敗者）
        final courtNum = leagueCourts[matchIdx % courtCount];
        matchIdx++;
        await bracketRef.collection('matches').add({
          'round': 'final_5th', 'matchNumber': matchIdx,
          'teamAId': '', 'teamAName': 'QF${qfMatchIndices[0] + 1}敗者',
          'teamBId': '', 'teamBName': 'QF${qfMatchIndices[1] + 1}敗者',
          'refereeTeamId': '', 'refereeTeamName': '',
          'subRefereeTeamId': '', 'subRefereeTeamName': '',
          'courtNumber': courtNum, 'courtId': 'court_$courtNum',
          'status': 'waiting', 'sets': [], 'result': {},
        });
      } else if (qfMatchIndices.length == 3) {
        // 7チーム: 3試合の敗者 → sf_loser(2試合) + 7位決定戦
        // sf_loser1: QF2敗者 vs QF4敗者
        final courtNum1 = leagueCourts[matchIdx % courtCount];
        matchIdx++;
        await bracketRef.collection('matches').add({
          'round': 'sf_loser', 'matchNumber': matchIdx,
          'teamAId': '', 'teamAName': 'QF${qfMatchIndices[0] + 1}敗者',
          'teamBId': '', 'teamBName': 'QF${qfMatchIndices[2] + 1}敗者',
          'refereeTeamId': '', 'refereeTeamName': '',
          'subRefereeTeamId': '', 'subRefereeTeamName': '',
          'courtNumber': courtNum1, 'courtId': 'court_$courtNum1',
          'status': 'waiting', 'sets': [], 'result': {},
        });
        // 5位決定戦: QF3敗者 vs sf_loser勝者
        final courtNum2 = leagueCourts[matchIdx % courtCount];
        matchIdx++;
        await bracketRef.collection('matches').add({
          'round': 'final_5th', 'matchNumber': matchIdx,
          'teamAId': '', 'teamAName': 'QF${qfMatchIndices[1] + 1}敗者',
          'teamBId': '', 'teamBName': '敗者戦 勝者',
          'refereeTeamId': '', 'refereeTeamName': '',
          'subRefereeTeamId': '', 'subRefereeTeamName': '',
          'courtNumber': courtNum2, 'courtId': 'court_$courtNum2',
          'status': 'waiting', 'sets': [], 'result': {},
        });
        // 7位決定戦: sf_loser敗者 = 7位（自動確定、試合不要）
      }
    }
    // 5チームの場合: QF敗者は1チームのみ → 自動的に最下位（試合不要）

    // 3位決定戦 + 決勝
    for (final entry in [
      {'round': 'final_3rd', 'a': 'SF1敗者', 'b': 'SF2敗者', 'label': '3位決定戦'},
      {'round': 'final_1st', 'a': 'SF1勝者', 'b': 'SF2勝者', 'label': '決勝（1-2位）'},
    ]) {
      final courtNum = leagueCourts[matchIdx % leagueCourts.length];
      matchIdx++;
      await bracketRef.collection('matches').add({
        'round': entry['round'], 'matchNumber': matchIdx,
        'teamAId': '', 'teamAName': entry['a'],
        'teamBId': '', 'teamBName': entry['b'],
        'label': entry['label'],
        'refereeTeamId': '', 'refereeTeamName': '',
        'subRefereeTeamId': '', 'subRefereeTeamName': '',
        'courtNumber': courtNum, 'courtId': 'court_$courtNum',
        'status': 'waiting', 'sets': [], 'result': {},
      });
    }
  }

  Future<void> _generate4TeamSE(
    DocumentReference bracketRef,
    List<MapEntry<String, Map<String, dynamic>>> teams,
    List<int> leagueCourts,
    List<Map<String, String>> leagueTeams,
  ) async {
    final mainRefCount = <String, int>{};
    final subRefCount = <String, int>{};
    for (var t in leagueTeams) { mainRefCount[t['teamId']!] = 0; subRefCount[t['teamId']!] = 0; }

    int matchIdx = 0;
    final courtCount = leagueCourts.length;
    final slotReferees = <int, Set<String>>{};

    // SF: 1vs4, 2vs3
    final sfPairs = [[0, 3], [1, 2]];
    for (int i = 0; i < sfPairs.length; i++) {
      final aIdx = sfPairs[i][0];
      final bIdx = sfPairs[i][1];
      final aId = teams[aIdx].key;
      final bId = bIdx < teams.length ? teams[bIdx].key : '';
      final aName = teams[aIdx].value['teamName'] ?? '';
      final bName = bIdx < teams.length ? teams[bIdx].value['teamName'] ?? '' : '';

      // 同時進行する試合の全出場チーム＋既に割り当てられた審判を収集
      final concurrentSlot = matchIdx ~/ courtCount;
      final busyIds = <String>{aId, bId};
      for (int j = 0; j < sfPairs.length; j++) {
        if (j != i && (j ~/ courtCount) == concurrentSlot) {
          busyIds.add(teams[sfPairs[j][0]].key);
          if (sfPairs[j][1] < teams.length) busyIds.add(teams[sfPairs[j][1]].key);
        }
      }
      busyIds.addAll(slotReferees[concurrentSlot] ?? {});

      // 審判割り当て（同時進行チーム＋既割当審判を除外）
      final available = leagueTeams.where((t) => !busyIds.contains(t['teamId'])).toList();
      available.sort((a, b) => (mainRefCount[a['teamId']]!).compareTo(mainRefCount[b['teamId']]!));
      final mainRef = available.isNotEmpty ? available.first : null;
      if (mainRef != null) {
        mainRefCount[mainRef['teamId']!] = (mainRefCount[mainRef['teamId']!] ?? 0) + 1;
        slotReferees.putIfAbsent(concurrentSlot, () => {}).add(mainRef['teamId']!);
      }

      String subRefId = '', subRefName = '';
      if (leagueTeams.length >= 4 && available.length >= 2) {
        final subCandidates = available.where((t) => t['teamId'] != mainRef?['teamId']).toList();
        subCandidates.sort((a, b) => (subRefCount[a['teamId']]!).compareTo(subRefCount[b['teamId']]!));
        if (subCandidates.isNotEmpty) {
          subRefId = subCandidates.first['teamId']!;
          subRefName = subCandidates.first['teamName']!;
          subRefCount[subRefId] = (subRefCount[subRefId] ?? 0) + 1;
          slotReferees.putIfAbsent(concurrentSlot, () => {}).add(subRefId);
        }
      }

      final courtNum = leagueCourts[matchIdx % courtCount];
      matchIdx++;
      await bracketRef.collection('matches').add({
        'round': 'semi', 'matchNumber': matchIdx,
        'teamAId': aId, 'teamAName': aName,
        'teamBId': bId, 'teamBName': bName,
        'refereeTeamId': mainRef?['teamId'] ?? '', 'refereeTeamName': mainRef?['teamName'] ?? '',
        'subRefereeTeamId': subRefId, 'subRefereeTeamName': subRefName,
        'courtNumber': courtNum, 'courtId': 'court_$courtNum',
        'status': 'pending', 'sets': [], 'result': {},
      });
    }

    // 3位決定戦 → 決勝（決勝が最後）
    for (final entry in [
      {'round': 'final_3rd', 'a': '第1試合 敗者', 'b': '第2試合 敗者', 'label': '3位決定戦'},
      {'round': 'final_1st', 'a': '第1試合 勝者', 'b': '第2試合 勝者', 'label': '決勝（1-2位）'},
    ]) {
      final courtNum = leagueCourts[matchIdx % leagueCourts.length];
      matchIdx++;
      await bracketRef.collection('matches').add({
        'round': entry['round'], 'matchNumber': matchIdx,
        'teamAId': '', 'teamAName': entry['a'],
        'teamBId': '', 'teamBName': entry['b'],
        'label': entry['label'],
        'refereeTeamId': '', 'refereeTeamName': '',
        'subRefereeTeamId': '', 'subRefereeTeamName': '',
        'courtNumber': courtNum, 'courtId': 'court_$courtNum',
        'status': 'waiting', 'sets': [], 'result': {},
      });
    }
  }

  /// Generate single elimination bracket for all teams
  /// 全チーム1ブラケットでSEトーナメントを生成（チーム数に応じた適切な構造を使用）
  Future<void> _generateSingleBracket(
    String tournamentId,
    List<MapEntry<String, Map<String, dynamic>>> sorted,
  ) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final totalCourts = (tournDoc.data()?['courts'] ?? 2) as int;

    final bracketRef = _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').doc('bracket_main');
    final allCourts = List.generate(totalCourts, (i) => i + 1);
    await bracketRef.set({
      'bracketNumber': 1, 'bracketName': '順位決定戦',
      'teamCount': sorted.length, 'type': 'tournament', 'status': 'pending',
      'courts': allCourts,
      'teamIds': sorted.map((e) => e.key).toList(),
    });

    final leagueTeams = sorted.map((e) => {'teamId': e.key, 'teamName': e.value['teamName'] as String}).toList();

    // チーム数に応じた適切なSE構造を使用
    if (sorted.length >= 8) {
      await _generate8TeamSE(bracketRef, sorted, allCourts, leagueTeams);
    } else if (sorted.length >= 5) {
      await _generate5to7TeamSE(bracketRef, sorted, allCourts, leagueTeams);
    } else if (sorted.length == 4) {
      await _generate4TeamSE(bracketRef, sorted, allCourts, leagueTeams);
    } else if (sorted.length == 3) {
      await _generate3TeamSE(bracketRef, sorted, allCourts, leagueTeams);
    } else if (sorted.length == 2) {
      await bracketRef.collection('matches').add({
        'round': 'final', 'matchNumber': 1,
        'teamAId': sorted[0].key, 'teamAName': sorted[0].value['teamName'],
        'teamBId': sorted[1].key, 'teamBName': sorted[1].value['teamName'],
        'refereeTeamId': '', 'refereeTeamName': '',
        'subRefereeTeamId': '', 'subRefereeTeamName': '',
        'courtNumber': allCourts.first, 'courtId': 'court_${allCourts.first}',
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

    // ブラケット内の全チームを収集（審判割り当て用）
    final teamMap = <String, String>{}; // teamId -> teamName
    for (var doc in matchesSnap.docs) {
      final m = doc.data() as Map<String, dynamic>;
      final aId = m['teamAId'] as String? ?? '';
      final bId = m['teamBId'] as String? ?? '';
      if (aId.isNotEmpty) teamMap[aId] = (m['teamAName'] ?? '') as String;
      if (bId.isNotEmpty) teamMap[bId] = (m['teamBName'] ?? '') as String;
    }
    final leagueTeams = teamMap.entries.map((e) => {'teamId': e.key, 'teamName': e.value}).toList();

    // 審判カウント（既割当分をカウント）
    final mainRefCount = <String, int>{};
    final subRefCount = <String, int>{};
    for (var t in leagueTeams) { mainRefCount[t['teamId']!] = 0; subRefCount[t['teamId']!] = 0; }
    for (var doc in matchesSnap.docs) {
      final m = doc.data() as Map<String, dynamic>;
      final rId = m['refereeTeamId'] as String? ?? '';
      final sId = m['subRefereeTeamId'] as String? ?? '';
      if (rId.isNotEmpty && mainRefCount.containsKey(rId)) mainRefCount[rId] = (mainRefCount[rId] ?? 0) + 1;
      if (sId.isNotEmpty && subRefCount.containsKey(sId)) subRefCount[sId] = (subRefCount[sId] ?? 0) + 1;
    }

    // 審判割り当てヘルパー（出場チーム+同時進行チームを除外して最少回数のチームを選出）
    Map<String, String> _pickRefsForMatch(Set<String> busyIds) {
      final available = leagueTeams.where((t) => !busyIds.contains(t['teamId'])).toList();
      available.sort((a, b) => (mainRefCount[a['teamId']]!).compareTo(mainRefCount[b['teamId']]!));
      String refId = '', refName = '', subRefId = '', subRefName = '';
      if (available.isNotEmpty) {
        refId = available.first['teamId']!;
        refName = available.first['teamName']!;
        mainRefCount[refId] = (mainRefCount[refId] ?? 0) + 1;
      }
      if (leagueTeams.length >= 4 && available.length >= 2) {
        final subCandidates = available.where((t) => t['teamId'] != refId).toList();
        subCandidates.sort((a, b) => (subRefCount[a['teamId']]!).compareTo(subRefCount[b['teamId']]!));
        if (subCandidates.isNotEmpty) {
          subRefId = subCandidates.first['teamId']!;
          subRefName = subCandidates.first['teamName']!;
          subRefCount[subRefId] = (subRefCount[subRefId] ?? 0) + 1;
        }
      }
      return {'refereeTeamId': refId, 'refereeTeamName': refName, 'subRefereeTeamId': subRefId, 'subRefereeTeamName': subRefName};
    }

    // QF → SF winner + SF loser (8-team and 5-7 team with BYEs)
    if (byRound.containsKey('qf')) {
      final qf = byRound['qf']!;
      final allDone = qf.every((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed');

      if (allDone && qf.length >= 4) {
        // 8-team: 4 QF matches → SF
        // クロスコート: q1(A) vs q2(B), q3(A) vs q4(B)
        final q1 = qf[0].data() as Map<String, dynamic>;
        final q2 = qf[1].data() as Map<String, dynamic>;
        final q3 = qf[2].data() as Map<String, dynamic>;
        final q4 = qf[3].data() as Map<String, dynamic>;

        final sfW = byRound['sf_winner'] ?? [];
        if (sfW.length >= 2) {
          if (!_isCompleted(sfW[0])) {
            final aId = _winnerId(q1), bId = _winnerId(q2);
            final refs = _pickRefsForMatch({aId, bId, _winnerId(q3), _winnerId(q4), _loserId(q1), _loserId(q2), _loserId(q3), _loserId(q4)});
            await sfW[0].reference.update({
              'teamAId': aId, 'teamAName': _winnerName(q1),
              'teamBId': bId, 'teamBName': _winnerName(q2),
              'status': 'pending', ...refs,
            });
          }
          if (!_isCompleted(sfW[1])) {
            final aId = _winnerId(q3), bId = _winnerId(q4);
            final refs = _pickRefsForMatch({aId, bId, _winnerId(q1), _winnerId(q2), _loserId(q1), _loserId(q2), _loserId(q3), _loserId(q4)});
            await sfW[1].reference.update({
              'teamAId': aId, 'teamAName': _winnerName(q3),
              'teamBId': bId, 'teamBName': _winnerName(q4),
              'status': 'pending', ...refs,
            });
          }
        }

        final sfL = byRound['sf_loser'] ?? [];
        if (sfL.length >= 2) {
          if (!_isCompleted(sfL[0])) {
            final aId = _loserId(q1), bId = _loserId(q2);
            final refs = _pickRefsForMatch({aId, bId, _loserId(q3), _loserId(q4), _winnerId(q1), _winnerId(q2), _winnerId(q3), _winnerId(q4)});
            await sfL[0].reference.update({
              'teamAId': aId, 'teamAName': _loserName(q1),
              'teamBId': bId, 'teamBName': _loserName(q2),
              'status': 'pending', ...refs,
            });
          }
          if (!_isCompleted(sfL[1])) {
            final aId = _loserId(q3), bId = _loserId(q4);
            final refs = _pickRefsForMatch({aId, bId, _loserId(q1), _loserId(q2), _winnerId(q1), _winnerId(q2), _winnerId(q3), _winnerId(q4)});
            await sfL[1].reference.update({
              'teamAId': aId, 'teamAName': _loserName(q3),
              'teamBId': bId, 'teamBName': _loserName(q4),
              'status': 'pending', ...refs,
            });
          }
        }
      } else if (allDone && qf.isNotEmpty) {
        // 5-7 team: fewer than 4 QF matches (BYE付き)
        // qfIndex フィールドでQFスロット番号を取得
        final qfBySlot = <int, Map<String, dynamic>>{};
        for (var doc in qf) {
          final data = doc.data() as Map<String, dynamic>;
          final qi = data['qfIndex'] as int? ?? -1;
          if (qi >= 0) qfBySlot[qi] = data;
        }

        // SF勝者側を更新: クロスコート SF[0]={QF0勝者(A) vs QF1勝者(B)}, SF[1]={QF2勝者(A) vs QF3勝者(B)}
        final sfW = byRound['sf_winner'] ?? [];
        const sfQfMapping = [[0, 1], [2, 3]]; // クロスコートのQFペア
        for (int si = 0; si < sfW.length && si < 2; si++) {
          if (_isCompleted(sfW[si])) continue;
          final sfData = sfW[si].data() as Map<String, dynamic>;
          final qiA = sfQfMapping[si][0];  // SF0→QF0,QF2  SF1→QF1,QF3
          final qiB = sfQfMapping[si][1];

          final updates = <String, dynamic>{};
          // teamA側: QFスロットAの勝者（BYEなら既にSFに配置済み）
          if (qfBySlot.containsKey(qiA)) {
            updates['teamAId'] = _winnerId(qfBySlot[qiA]!);
            updates['teamAName'] = _winnerName(qfBySlot[qiA]!);
          }
          // teamB側: QFスロットBの勝者
          if (qfBySlot.containsKey(qiB)) {
            updates['teamBId'] = _winnerId(qfBySlot[qiB]!);
            updates['teamBName'] = _winnerName(qfBySlot[qiB]!);
          }

          // 両チーム確定したらpendingに + 審判割り当て
          final newAId = updates['teamAId'] ?? sfData['teamAId'] ?? '';
          final newBId = updates['teamBId'] ?? sfData['teamBId'] ?? '';
          if ((newAId as String).isNotEmpty && (newBId as String).isNotEmpty) {
            updates['status'] = 'pending';
            final refs = _pickRefsForMatch({newAId, newBId});
            updates.addAll(refs);
          }
          if (updates.isNotEmpty) await sfW[si].reference.update(updates);
        }

        // 敗者側: QF敗者を5位決定戦やsf_loserに配置
        final qfLosers = <Map<String, String>>[];
        for (var doc in qf) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'completed') {
            qfLosers.add({'id': _loserId(data), 'name': _loserName(data)});
          }
        }

        // 5位決定戦（2敗者の場合）
        final f5th = byRound['final_5th']?.firstOrNull;
        if (f5th != null && !_isCompleted(f5th) && qfLosers.length >= 2) {
          final aId = qfLosers[0]['id']!, bId = qfLosers[1]['id']!;
          final refs = _pickRefsForMatch({aId, bId});
          await f5th.reference.update({
            'teamAId': aId, 'teamAName': qfLosers[0]['name'],
            'teamBId': bId, 'teamBName': qfLosers[1]['name'],
            'status': 'pending', ...refs,
          });
        }

        // sf_loser（7チームの3敗者: 最初の2チームで対戦）
        final sfL = byRound['sf_loser'] ?? [];
        if (sfL.isNotEmpty && !_isCompleted(sfL[0]) && qfLosers.length >= 2) {
          final aId = qfLosers[0]['id']!, bId = qfLosers[qfLosers.length - 1]['id']!;
          final refs = _pickRefsForMatch({aId, bId});
          await sfL[0].reference.update({
            'teamAId': aId, 'teamAName': qfLosers[0]['name'],
            'teamBId': bId, 'teamBName': qfLosers[qfLosers.length - 1]['name'],
            'status': 'pending', ...refs,
          });
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
          final aId = _winnerId(sw1), bId = _winnerId(sw2);
          final refs = _pickRefsForMatch({aId, bId, _loserId(sw1), _loserId(sw2)});
          await f1st.reference.update({
            'teamAId': aId, 'teamAName': _winnerName(sw1),
            'teamBId': bId, 'teamBName': _winnerName(sw2),
            'status': 'pending', ...refs,
          });
        }
        final f3rd = byRound['final_3rd']?.firstOrNull;
        if (f3rd != null && !_isCompleted(f3rd)) {
          final aId = _loserId(sw1), bId = _loserId(sw2);
          final refs = _pickRefsForMatch({aId, bId, _winnerId(sw1), _winnerId(sw2)});
          await f3rd.reference.update({
            'teamAId': aId, 'teamAName': _loserName(sw1),
            'teamBId': bId, 'teamBName': _loserName(sw2),
            'status': 'pending', ...refs,
          });
        }
      }
    }

    // SF loser → Final 5th + 7th
    if (byRound.containsKey('sf_loser')) {
      final sfL = byRound['sf_loser']!;
      final allDone = sfL.every((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed');
      if (allDone && sfL.length >= 2) {
        // 8チーム: 2試合の敗者側
        final sl1 = sfL[0].data() as Map<String, dynamic>;
        final sl2 = sfL[1].data() as Map<String, dynamic>;

        final f5th = byRound['final_5th']?.firstOrNull;
        if (f5th != null && !_isCompleted(f5th)) {
          final aId = _winnerId(sl1), bId = _winnerId(sl2);
          final refs = _pickRefsForMatch({aId, bId, _loserId(sl1), _loserId(sl2)});
          await f5th.reference.update({
            'teamAId': aId, 'teamAName': _winnerName(sl1),
            'teamBId': bId, 'teamBName': _winnerName(sl2),
            'status': 'pending', ...refs,
          });
        }
        final f7th = byRound['final_7th']?.firstOrNull;
        if (f7th != null && !_isCompleted(f7th)) {
          final aId = _loserId(sl1), bId = _loserId(sl2);
          final refs = _pickRefsForMatch({aId, bId, _winnerId(sl1), _winnerId(sl2)});
          await f7th.reference.update({
            'teamAId': aId, 'teamAName': _loserName(sl1),
            'teamBId': bId, 'teamBName': _loserName(sl2),
            'status': 'pending', ...refs,
          });
        }
      } else if (allDone && sfL.length == 1) {
        // 7チーム: 1試合の敗者側 → 勝者が5位決定戦へ（第3の敗者と対戦）
        final sl1 = sfL[0].data() as Map<String, dynamic>;
        final f5th = byRound['final_5th']?.firstOrNull;
        if (f5th != null && !_isCompleted(f5th)) {
          // 5位決定戦のteamBにsf_loser勝者を配置
          final f5thData = f5th.data() as Map<String, dynamic>;
          final updates = <String, dynamic>{};
          // teamAが既にQF敗者で埋まっている場合、teamBに入れる
          if ((f5thData['teamAId'] as String? ?? '').isNotEmpty) {
            updates['teamBId'] = _winnerId(sl1);
            updates['teamBName'] = _winnerName(sl1);
          } else {
            updates['teamAId'] = _winnerId(sl1);
            updates['teamAName'] = _winnerName(sl1);
          }
          // 両チーム揃ったらpending
          final newAId = updates['teamAId'] ?? f5thData['teamAId'] ?? '';
          final newBId = updates['teamBId'] ?? f5thData['teamBId'] ?? '';
          if ((newAId as String).isNotEmpty && (newBId as String).isNotEmpty) {
            updates['status'] = 'pending';
            final refs = _pickRefsForMatch({newAId as String, newBId as String});
            updates.addAll(refs);
          }
          await f5th.reference.update(updates);
        }
        // sf_loser敗者 = 7位（自動確定）
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
          final aId = _winnerId(s1), bId = _winnerId(s2);
          final refs = _pickRefsForMatch({aId, bId, _loserId(s1), _loserId(s2)});
          await f1st.reference.update({
            'teamAId': aId, 'teamAName': _winnerName(s1),
            'teamBId': bId, 'teamBName': _winnerName(s2),
            'status': 'pending', ...refs,
          });
        }
        final f3rd = byRound['final_3rd']?.firstOrNull;
        if (f3rd != null && !_isCompleted(f3rd)) {
          final aId = _loserId(s1), bId = _loserId(s2);
          final refs = _pickRefsForMatch({aId, bId, _winnerId(s1), _winnerId(s2)});
          await f3rd.reference.update({
            'teamAId': aId, 'teamAName': _loserName(s1),
            'teamBId': bId, 'teamBName': _loserName(s2),
            'status': 'pending', ...refs,
          });
        }
      } else if (allDone && semi.length == 1) {
        // 3チーム: semi(2位vs3位) → final_1st(1位vs勝者)
        final s1 = semi[0].data() as Map<String, dynamic>;
        final f1st = byRound['final_1st']?.firstOrNull;
        if (f1st != null && !_isCompleted(f1st)) {
          final f1stData = f1st.data() as Map<String, dynamic>;
          final aId = f1stData['teamAId'] as String? ?? '';
          final bId = _winnerId(s1);
          final loserId = _loserId(s1);
          final refs = _pickRefsForMatch({aId, bId});
          await f1st.reference.update({
            'teamBId': bId, 'teamBName': _winnerName(s1),
            'refereeTeamId': loserId.isNotEmpty ? loserId : (refs['refereeTeamId'] ?? ''),
            'refereeTeamName': loserId.isNotEmpty ? _loserName(s1) : (refs['refereeTeamName'] ?? ''),
            'subRefereeTeamId': refs['subRefereeTeamId'] ?? '',
            'subRefereeTeamName': refs['subRefereeTeamName'] ?? '',
            'status': aId.isNotEmpty && bId.isNotEmpty ? 'pending' : 'waiting',
          });
        }
      }
    }
  }

  /// リーグ数に応じたリーグ名を返す
  /// 1 → [順位決定トーナメント]
  /// 2 → [上位リーグ, 下位リーグ]
  /// 3 → [上位リーグ, 中位リーグ, 下位リーグ]
  /// 4 → [上位リーグ, 中位①リーグ, 中位②リーグ, 下位リーグ]
  List<String> _getLeagueNames(int count) {
    switch (count) {
      case 1:
        return ['順位決定トーナメント'];
      case 2:
        return ['上位リーグ', '下位リーグ'];
      case 3:
        return ['上位リーグ', '中位リーグ', '下位リーグ'];
      case 4:
        return ['上位リーグ', '中位①リーグ', '中位②リーグ', '下位リーグ'];
      default:
        final names = <String>['上位リーグ'];
        for (int i = 1; i < count - 1; i++) {
          names.add('中位${count > 3 ? "①②③④⑤⑥⑦⑧"[i - 1] : ""}リーグ');
        }
        names.add('下位リーグ');
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

  /// 既存ブラケットにコート・審判を後付け更新
  Future<void> updateBracketCourtsAndReferees(String tournamentId) async {
    final tournDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    final totalCourts = (tournDoc.data()?['courts'] ?? 2) as int;

    final bracketsSnap = await _firestore.collection('tournaments').doc(tournamentId)
        .collection('brackets').orderBy('bracketNumber').get();
    if (bracketsSnap.docs.isEmpty) return;

    final leagueCount = bracketsSnap.docs.length;

    // コートをリーグに均等配分
    final courtsPerLeague = <int, List<int>>{};
    int courtIdx = 1;
    for (int b = 0; b < leagueCount; b++) {
      final courtCount = (totalCourts / leagueCount).ceil().clamp(1, totalCourts);
      courtsPerLeague[b] = [];
      for (int c = 0; c < courtCount && courtIdx <= totalCourts; c++) {
        courtsPerLeague[b]!.add(courtIdx++);
      }
      if (courtsPerLeague[b]!.isEmpty) {
        courtsPerLeague[b]!.add(b + 1);
      }
    }

    for (int b = 0; b < bracketsSnap.docs.length; b++) {
      final bracketDoc = bracketsSnap.docs[b];
      final leagueCourts = courtsPerLeague[b] ?? [b + 1];

      // ブラケットドキュメントにcourtsとteamIdsを追加
      final matchesSnap = await bracketDoc.reference
          .collection('matches').orderBy('matchNumber').get();

      // 正しい時間順に並び替え（qf→sf_winner→sf_loser→7位→5位→3位→決勝）
      const _roundTemporalOrder = {
        'qf': 0, 'semi': 1, 'sf_winner': 2, 'sf_loser': 3,
        'round-robin': 4,
        'final_7th': 5, 'final_5th': 6, 'final_3rd': 7, 'final_1st': 8, 'final': 9,
      };
      final docs = matchesSnap.docs.toList()..sort((a, b) {
        final aRound = (a.data())['round'] as String? ?? '';
        final bRound = (b.data())['round'] as String? ?? '';
        final aPri = _roundTemporalOrder[aRound] ?? 99;
        final bPri = _roundTemporalOrder[bRound] ?? 99;
        if (aPri != bPri) return aPri.compareTo(bPri);
        final aNum = (a.data())['matchNumber'] as int? ?? 0;
        final bNum = (b.data())['matchNumber'] as int? ?? 0;
        return aNum.compareTo(bNum);
      });

      // リーグ内の全チームIDを収集
      final teamMap = <String, String>{}; // teamId -> teamName
      for (var mDoc in matchesSnap.docs) {
        final m = mDoc.data();
        final aId = m['teamAId'] as String? ?? '';
        final bId = m['teamBId'] as String? ?? '';
        if (aId.isNotEmpty) teamMap[aId] = m['teamAName'] ?? '';
        if (bId.isNotEmpty) teamMap[bId] = m['teamBName'] ?? '';
      }
      final leagueTeams = teamMap.entries.map((e) => {'teamId': e.key, 'teamName': e.value}).toList();

      // ブラケットドキュメント更新
      await bracketDoc.reference.update({
        'courts': leagueCourts,
        'teamIds': teamMap.keys.toList(),
      });

      // 審判カウント
      final mainRefCount = <String, int>{};
      final subRefCount = <String, int>{};
      for (var t in leagueTeams) { mainRefCount[t['teamId']!] = 0; subRefCount[t['teamId']!] = 0; }

      final courtCount = leagueCourts.length;

      // スロット毎の審判割当を記録（同時進行する試合間で審判が重複しないように）
      final slotReferees = <int, Set<String>>{};

      for (int i = 0; i < docs.length; i++) {
        final mDoc = docs[i];
        final m = mDoc.data();
        final aId = m['teamAId'] as String? ?? '';
        final bId = m['teamBId'] as String? ?? '';

        final courtNum = leagueCourts[i % courtCount];
        final concurrentSlot = i ~/ courtCount;

        // チームが確定している試合のみ審判割当
        String refId = '', refName = '', subRefId = '', subRefName = '';
        if (aId.isNotEmpty && bId.isNotEmpty) {
          // 同時進行する試合の全出場チーム＋既に割り当てられた審判を収集
          final busyIds = <String>{aId, bId};
          for (int j = 0; j < docs.length; j++) {
            if (j != i && (j ~/ courtCount) == concurrentSlot) {
              final other = docs[j].data();
              final otherA = other['teamAId'] as String? ?? '';
              final otherB = other['teamBId'] as String? ?? '';
              if (otherA.isNotEmpty) busyIds.add(otherA);
              if (otherB.isNotEmpty) busyIds.add(otherB);
            }
          }
          // 同スロットで既に審判割当済みのチームも除外
          busyIds.addAll(slotReferees[concurrentSlot] ?? {});

          final available = leagueTeams.where((t) => !busyIds.contains(t['teamId'])).toList();
          available.sort((a, b2) => (mainRefCount[a['teamId']]!).compareTo(mainRefCount[b2['teamId']]!));
          if (available.isNotEmpty) {
            refId = available.first['teamId']!;
            refName = available.first['teamName']!;
            mainRefCount[refId] = (mainRefCount[refId] ?? 0) + 1;
            slotReferees.putIfAbsent(concurrentSlot, () => {}).add(refId);
          }
          if (leagueTeams.length >= 4 && available.length >= 2) {
            final subCandidates = available.where((t) => t['teamId'] != refId).toList();
            subCandidates.sort((a, b2) => (subRefCount[a['teamId']]!).compareTo(subRefCount[b2['teamId']]!));
            if (subCandidates.isNotEmpty) {
              subRefId = subCandidates.first['teamId']!;
              subRefName = subCandidates.first['teamName']!;
              subRefCount[subRefId] = (subRefCount[subRefId] ?? 0) + 1;
              slotReferees.putIfAbsent(concurrentSlot, () => {}).add(subRefId);
            }
          }
        }

        await mDoc.reference.update({
          'matchNumber': i + 1,
          'courtNumber': courtNum,
          'courtId': 'court_$courtNum',
          'refereeTeamId': refId,
          'refereeTeamName': refName,
          'subRefereeTeamId': subRefId,
          'subRefereeTeamName': subRefName,
        });
      }
    }
  }

}
