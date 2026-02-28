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
  winner: string;
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
  type: string;
  status: string;
  organizerId: string;
  organizerName?: string;
  currentRound?: number;
  rules?: TournamentRules;
  schedule?: TournamentSchedule;
  deadline?: string;
  description?: string;
  area?: string;
  icon?: string;
  createdAt?: unknown;
}

/** エントリー */
export interface Entry {
  teamId: string;
  teamName: string;
  enteredBy: string;
  enteredAt: unknown;
  memberUids?: string[];
}

/** ブラケット試合 */
export interface BracketMatch extends Match {
  round?: number;
  position?: number;
}

/** 投稿 */
export interface Post {
  id: string;
  userId: string;
  userNickname: string;
  userAvatarUrl?: string;
  text: string;
  images?: string[];
  imageBase64?: string;
  likesCount: number;
  commentsCount: number;
  badgeName?: string;
  tournamentId?: string;
  createdAt: unknown;
}

/** コメント */
export interface PostComment {
  id: string;
  userId: string;
  userNickname: string;
  userAvatarUrl?: string;
  text: string;
  createdAt: unknown;
}

/** チャットルーム */
export interface ChatRoom {
  id: string;
  type: "dm" | "group" | "tournament";
  name?: string;
  members: string[];
  memberNames: Record<string, string>;
  linkedId?: string;
  lastMessage?: string;
  lastMessageAt?: unknown;
  lastRead?: Record<string, unknown>;
  createdAt?: unknown;
}

/** チャットメッセージ */
export interface ChatMessage {
  id: string;
  senderId: string;
  text: string;
  imageUrl?: string;
  createdAt: unknown;
  editedAt?: unknown;
}

/** 募集 */
export interface Recruitment {
  id: string;
  userId: string;
  userNickname?: string;
  title: string;
  tournament?: string;
  tournamentId?: string;
  status: string;
  needed?: number;
  approvedCount?: number;
  pendingCount?: number;
  experienceLevel?: string;
  text?: string;
  createdAt: unknown;
}

/** チーム */
export interface Team {
  id: string;
  name: string;
  ownerId: string;
  memberIds: string[];
  memberNames: Record<string, string>;
  memberAvatars?: Record<string, string>;
  isMain?: boolean;
  createdAt?: unknown;
}

/** ガジェット */
export interface Gadget {
  id: string;
  name: string;
  category: string;
  description?: string;
  imageUrl?: string;
  url?: string;
  memo?: string;
  createdAt: unknown;
}

/** 通知 */
export interface AppNotification {
  id: string;
  type: "like" | "comment" | "follow" | "system";
  senderId?: string;
  senderName?: string;
  senderAvatar?: string;
  message: string;
  read: boolean;
  createdAt: unknown;
}

/** ブックマーク */
export interface Bookmark {
  id: string;
  type: "tournament" | "recruitment";
  targetId: string;
  title: string;
  date?: string;
  location?: string;
  status?: string;
  alerts?: string[];
  createdAt: unknown;
}

/** 会場 */
export interface Venue {
  id: string;
  name: string;
  address: string;
  courts?: number;
  rating?: number;
  createdBy?: string;
  createdAt?: unknown;
}

/** バッジ定義 */
export interface BadgeDefinition {
  id: string;
  name: string;
  description: string;
  icon: string;
  color: string;
  threshold: number;
  currentValue: number;
}

/** テンプレート */
export interface TournamentTemplate {
  id: string;
  name: string;
  type?: string;
  maxTeams?: number;
  courts?: number;
  location?: string;
  memo?: string;
  format?: string;
  rules?: TournamentRules;
  createdAt?: unknown;
  updatedAt?: unknown;
}

/** 大会収支の支出 */
export interface Expense {
  id: string;
  name: string;
  amount: number;
  createdAt?: unknown;
  updatedAt?: unknown;
}

/** チェックイン */
export interface CheckIn {
  teamId: string;
  teamName: string;
  checkedInAt: unknown;
}

/** お知らせ */
export interface Notice {
  id: string;
  type: string;
  title: string;
  body: string;
  createdAt: unknown;
}
