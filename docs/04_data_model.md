# Firestore データモデル

## tournaments（大会）
- id, title, date, location, venueId, venueAddress
- courts, maxTeams, currentTeams, entryFee
- format（4人制）, type（メンズ/レディース/ミックス）
- status（募集中/満員/開催中/決勝中/終了/開催済み）
- organizerId, organizerName
- rules: { preliminary: {sets, target, deuce, deuceCap}, final: {...}, scoring: {enabled, win20, win11diff, ...} }
- schedule: { doors, reception, meeting, ceremony, matchStart, lunch, finals, end, cleanup }
- entryDeadline（締切日時）
- checkInMethod（qr_team / qr_organizer / manual）

### サブコレクション
- entries: { teamId, teamName, enteredBy, enteredAt }
- rounds/round_N: { roundNumber, courtCount }
  - matches: { courtId, courtNumber, matchOrder, teamAId, teamAName, teamBId, teamBName, refereeTeamId, refereeTeamName, status, sets, result, confirmedByA, confirmedByB }
  - standings/courtId/teams: { teamId, teamName, matchPoints, pointDiff, totalPoints, wins, losses, draws, rank }
- brackets: { bracketId, type, matches... }
- timeline: { authorId, authorName, authorAvatar, text, isOrganizer, pinned, likesCount, createdAt }
- checkIns: { teamId, teamName, checkedInAt, checkedInBy }

## users（ユーザー）
- uid, nickname, avatarUrl, bio, followersCount, followingCount

## teams（チーム）
- teamId, teamName, ownerId, memberIds[], createdAt

## venues（会場）
- venueId, name, address, courts, facilities
