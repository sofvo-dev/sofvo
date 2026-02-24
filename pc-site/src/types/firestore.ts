/** 試合のセットスコア */
export interface SetScore {
  a: number;
  b: number;
}

/** 試合結果 */
export interface MatchResult {
  setsA: number;
  setsB: number;
  totalPointsA: number;
  totalPointsB: number;
  winner: string; // teamId or "引き分け"
}

/** 試合データ */
export interface Match {
  id: string;
  matchOrder: number;
  courtId: string;
  courtNumber: number;
  teamAId: string;
  teamAName: string;
  teamBId: string;
  teamBName: string;
  refereeTeamId?: string;
  refereeTeamName?: string;
  subRefereeTeamName?: string;
  status: "pending" | "completed" | "waiting";
  sets: SetScore[];
  result?: MatchResult;
  refereeConfirmed?: boolean;
  confirmedByA?: boolean;
  confirmedByB?: boolean;
}

/** 順位データ */
export interface Standing {
  teamId: string;
  teamName: string;
  matchPoints: number;
  pointDiff: number;
  totalPoints: number;
  wins: number;
  losses: number;
  draws: number;
  rank: number;
}

/** 予選ラウンドごとのルール */
export interface PreliminaryRoundRules {
  sets?: number;
  points?: number;
  deuce?: boolean;
  deuceCap?: number;
}

/** スコアリング設定（セット形式により使用するフィールドが異なる） */
export interface ScoringConfig {
  // 1セットマッチ用
  win?: number;
  lose?: number;
  // 2セットマッチ用
  win20?: number;
  win11?: number;
  draw?: number;
  lose11?: number;
  lose02?: number;
  // 3セット（2セット先取）用
  win21?: number;
  lose12?: number;
}

/** 大会ルール */
export interface TournamentRules {
  management?: {
    teamsPerCourt?: number;
  };
  preliminary?: {
    rounds?: number;
    // Flat format (rounds=1)
    sets?: number;
    points?: number;
    deuce?: boolean;
    deuceCap?: number;
    // Per-round format (rounds=2)
    round1?: PreliminaryRoundRules;
    round2?: PreliminaryRoundRules;
  };
  scoring?: {
    enabled?: boolean;
    // Flat scoring (rounds=1) — keys from ScoringConfig
    win?: number;
    lose?: number;
    win20?: number;
    win11?: number;
    draw?: number;
    lose11?: number;
    lose02?: number;
    win21?: number;
    lose12?: number;
    // Per-round scoring (rounds=2)
    round1?: ScoringConfig;
    round2?: ScoringConfig;
  };
  final?: {
    enabled?: boolean;
    sets?: number;
    points?: number;
    deuce?: boolean;
    deuceCap?: number;
    thirdPlace?: boolean;
    loserRevival?: boolean;
    format?: string;
    tierCount?: number;
  };
  other?: {
    uniformRequired?: boolean;
    snsVideoAllowed?: boolean;
    lunchBreak?: string;
  };
}

/** 大会スケジュール */
export interface TournamentSchedule {
  doors?: string;
  reception?: string;
  meeting?: string;
  ceremony?: string;
  matchStart?: string;
  lunch?: string;
  finals?: string;
  end?: string;
  openTime?: string;
  receptionTime?: string;
  ceremonyTime?: string;
  matchStartTime?: string;
  finalsTime?: string;
  closingTime?: string;
}

/** 大会データ */
export interface Tournament {
  id: string;
  title: string;
  date: string;
  location: string;
  venueId?: string;
  venueAddress?: string;
  courts: number;
  maxTeams: number;
  currentTeams: number;
  entryFee?: number;
  format?: string;
  type: string; // "メンズ" | "レディース" | "混合"
  status: string;
  organizerId: string;
  organizerName?: string;
  currentRound?: number;
  rules?: TournamentRules;
  schedule?: TournamentSchedule;
  deadline?: string;
  area?: string;
}

/** エントリー */
export interface Entry {
  teamId: string;
  teamName: string;
  enteredBy: string;
  enteredAt: unknown;
}

/** ブラケット試合 */
export interface BracketMatch extends Match {
  round?: number;
  position?: number;
}
