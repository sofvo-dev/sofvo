"use client";

import type { Tournament, Entry } from "@/types/firestore";

interface TournamentInfoProps {
  tournament: Tournament;
  entries: Entry[];
}

export default function TournamentInfo({ tournament, entries }: TournamentInfoProps) {
  const t = tournament;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* 基本情報 */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="px-5 py-4 bg-gray-50 border-b border-gray-100">
          <h3 className="text-sm font-bold text-foreground">基本情報</h3>
        </div>
        <div className="p-5 space-y-4">
          <InfoRow label="大会名" value={t.title} />
          <InfoRow label="開催日" value={t.date} />
          <InfoRow label="会場" value={t.location} />
          {t.venueAddress && <InfoRow label="住所" value={t.venueAddress} />}
          <InfoRow label="種別" value={t.type} />
          {t.format && <InfoRow label="形式" value={t.format} />}
          <InfoRow label="コート数" value={`${t.courts}コート`} />
          <InfoRow label="参加チーム" value={`${entries.length} / ${t.maxTeams}チーム`} />
          {t.entryFee !== undefined && (
            <InfoRow label="参加費" value={`¥${t.entryFee.toLocaleString()}`} />
          )}
          {t.organizerName && <InfoRow label="主催者" value={t.organizerName} />}
          {t.deadline && <InfoRow label="申込締切" value={t.deadline} />}
          {t.area && <InfoRow label="エリア" value={t.area} />}
        </div>
      </div>

      {/* スケジュール */}
      {t.schedule && Object.keys(t.schedule).length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="px-5 py-4 bg-gray-50 border-b border-gray-100">
            <h3 className="text-sm font-bold text-foreground">スケジュール</h3>
          </div>
          <div className="p-5 space-y-3">
            {t.schedule.doors && <ScheduleRow time={t.schedule.doors} label="開場" />}
            {t.schedule.openTime && <ScheduleRow time={t.schedule.openTime} label="開場" />}
            {t.schedule.reception && <ScheduleRow time={t.schedule.reception} label="受付" />}
            {t.schedule.receptionTime && <ScheduleRow time={t.schedule.receptionTime} label="受付" />}
            {t.schedule.meeting && <ScheduleRow time={t.schedule.meeting} label="ミーティング" />}
            {t.schedule.ceremony && <ScheduleRow time={t.schedule.ceremony} label="開会式" />}
            {t.schedule.ceremonyTime && <ScheduleRow time={t.schedule.ceremonyTime} label="開会式" />}
            {t.schedule.matchStart && <ScheduleRow time={t.schedule.matchStart} label="試合開始" />}
            {t.schedule.matchStartTime && <ScheduleRow time={t.schedule.matchStartTime} label="試合開始" />}
            {t.schedule.lunch && <ScheduleRow time={t.schedule.lunch} label="昼休憩" />}
            {t.schedule.finals && <ScheduleRow time={t.schedule.finals} label="決勝" />}
            {t.schedule.finalsTime && <ScheduleRow time={t.schedule.finalsTime} label="決勝" />}
            {t.schedule.end && <ScheduleRow time={t.schedule.end} label="終了" />}
            {t.schedule.closingTime && <ScheduleRow time={t.schedule.closingTime} label="閉会" />}
          </div>
        </div>
      )}

      {/* ルール */}
      {t.rules && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="px-5 py-4 bg-gray-50 border-b border-gray-100">
            <h3 className="text-sm font-bold text-foreground">ルール</h3>
          </div>
          <div className="p-5">
            {/* 予選ルール */}
            {t.rules.preliminary && (
              <div className="mb-4">
                <h4 className="text-xs font-semibold text-muted uppercase mb-3">予選</h4>
                <div className="space-y-2">
                  {t.rules.preliminary.rounds && (
                    <InfoRow label="ラウンド数" value={`${t.rules.preliminary.rounds}ラウンド`} />
                  )}
                  {t.rules.preliminary.sets && (
                    <InfoRow label="セット数" value={`${t.rules.preliminary.sets}セット`} />
                  )}
                  {t.rules.preliminary.points && (
                    <InfoRow label="ポイント" value={`${t.rules.preliminary.points}点`} />
                  )}
                  {t.rules.preliminary.deuce !== undefined && (
                    <InfoRow label="デュース" value={t.rules.preliminary.deuce ? "あり" : "なし"} />
                  )}
                  {t.rules.preliminary.deuceCap && (
                    <InfoRow label="デュースキャップ" value={`${t.rules.preliminary.deuceCap}点`} />
                  )}
                </div>
              </div>
            )}

            {/* 勝ち点 */}
            {t.rules.scoring && (
              <div className="mb-4">
                <h4 className="text-xs font-semibold text-muted uppercase mb-3">勝ち点</h4>
                <div className="space-y-2">
                  {t.rules.scoring.win20 !== undefined && (
                    <InfoRow label="2-0勝ち" value={`${t.rules.scoring.win20}点`} />
                  )}
                  {t.rules.scoring.win11 !== undefined && (
                    <InfoRow label="2-1勝ち" value={`${t.rules.scoring.win11}点`} />
                  )}
                  {t.rules.scoring.draw !== undefined && (
                    <InfoRow label="引き分け" value={`${t.rules.scoring.draw}点`} />
                  )}
                  {t.rules.scoring.lose11 !== undefined && (
                    <InfoRow label="1-2負け" value={`${t.rules.scoring.lose11}点`} />
                  )}
                  {t.rules.scoring.lose02 !== undefined && (
                    <InfoRow label="0-2負け" value={`${t.rules.scoring.lose02}点`} />
                  )}
                </div>
              </div>
            )}

            {/* 決勝ルール */}
            {t.rules.final?.enabled && (
              <div>
                <h4 className="text-xs font-semibold text-muted uppercase mb-3">決勝</h4>
                <div className="space-y-2">
                  {t.rules.final.sets && (
                    <InfoRow label="セット数" value={`${t.rules.final.sets}セット`} />
                  )}
                  {t.rules.final.points && (
                    <InfoRow label="ポイント" value={`${t.rules.final.points}点`} />
                  )}
                  {t.rules.final.format && (
                    <InfoRow label="形式" value={t.rules.final.format} />
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between">
      <span className="text-sm text-muted">{label}</span>
      <span className="text-sm font-medium text-foreground">{value}</span>
    </div>
  );
}

function ScheduleRow({ time, label }: { time: string; label: string }) {
  return (
    <div className="flex items-center gap-4">
      <span className="text-sm font-mono font-bold text-primary w-14">{time}</span>
      <span className="text-sm text-foreground">{label}</span>
    </div>
  );
}
