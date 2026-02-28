"use client";

import type { Tournament, Entry } from "@/types/firestore";

interface TournamentInfoProps {
  tournament: Tournament;
  entries: Entry[];
}

export default function TournamentInfo({ tournament, entries }: TournamentInfoProps) {
  const t = tournament;
  const mapQuery = t.venueAddress || t.location;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* 基本情報 */}
      <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
        <div className="section-header-navy px-5 py-4 flex items-center gap-2">
          <svg className="w-4.5 h-4.5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>
          <h3 className="text-sm font-bold text-foreground">基本情報</h3>
        </div>
        <div className="p-5 space-y-4">
          <InfoRow label="大会名" value={t.title} icon="trophy" />
          <InfoRow label="開催日" value={t.date} icon="calendar" />
          <InfoRow label="会場" value={t.location} icon="location" />
          {t.venueAddress && <InfoRow label="住所" value={t.venueAddress} icon="map" />}
          <InfoRow label="種別" value={t.type} icon="tag" />
          {t.format && <InfoRow label="形式" value={t.format} icon="format" />}
          <InfoRow label="コート数" value={`${t.courts}コート`} icon="court" />
          <InfoRow label="参加チーム" value={`${entries.length} / ${t.maxTeams}チーム`} icon="team" />
          {t.entryFee !== undefined && (
            <InfoRow label="参加費" value={t.entryFee > 0 ? `¥${t.entryFee.toLocaleString()}` : "無料"} icon="yen" />
          )}
          {t.organizerName && <InfoRow label="主催者" value={t.organizerName} icon="person" />}
          {t.deadline && <InfoRow label="申込締切" value={t.deadline} icon="deadline" />}
          {t.area && <InfoRow label="エリア" value={t.area} icon="area" />}
        </div>
        {t.description && (
          <div className="px-5 pb-5 -mt-1">
            <div className="p-3 bg-gray-50 rounded-xl">
              <p className="text-xs font-medium text-muted mb-1">大会説明・備考</p>
              <p className="text-sm text-foreground whitespace-pre-wrap leading-relaxed">{t.description}</p>
            </div>
          </div>
        )}
      </div>

      {/* スケジュール */}
      {t.schedule && Object.values(t.schedule).some((v) => v) && (
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="section-header-gold px-5 py-4 flex items-center gap-2">
            <svg className="w-4.5 h-4.5 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            <h3 className="text-sm font-bold text-foreground">スケジュール</h3>
          </div>
          <div className="p-5 space-y-0">
            {t.schedule.doors && <ScheduleRow time={t.schedule.doors} label="開場" color="text-blue-600" bg="bg-blue-50" />}
            {t.schedule.openTime && <ScheduleRow time={t.schedule.openTime} label="開場" color="text-blue-600" bg="bg-blue-50" />}
            {t.schedule.reception && <ScheduleRow time={t.schedule.reception} label="受付" color="text-teal-600" bg="bg-teal-50" />}
            {t.schedule.receptionTime && <ScheduleRow time={t.schedule.receptionTime} label="受付" color="text-teal-600" bg="bg-teal-50" />}
            {t.schedule.meeting && <ScheduleRow time={t.schedule.meeting} label="ミーティング" color="text-indigo-600" bg="bg-indigo-50" />}
            {t.schedule.ceremony && <ScheduleRow time={t.schedule.ceremony} label="開会式" color="text-primary" bg="bg-primary/5" />}
            {t.schedule.ceremonyTime && <ScheduleRow time={t.schedule.ceremonyTime} label="開会式" color="text-primary" bg="bg-primary/5" />}
            {t.schedule.matchStart && <ScheduleRow time={t.schedule.matchStart} label="試合開始" color="text-green-600" bg="bg-green-50" />}
            {t.schedule.matchStartTime && <ScheduleRow time={t.schedule.matchStartTime} label="試合開始" color="text-green-600" bg="bg-green-50" />}
            {t.schedule.lunch && <ScheduleRow time={t.schedule.lunch} label="昼休憩" color="text-orange-600" bg="bg-orange-50" />}
            {t.schedule.finals && <ScheduleRow time={t.schedule.finals} label="決勝" color="text-amber-600" bg="bg-amber-50" />}
            {t.schedule.finalsTime && <ScheduleRow time={t.schedule.finalsTime} label="決勝" color="text-amber-600" bg="bg-amber-50" />}
            {t.schedule.end && <ScheduleRow time={t.schedule.end} label="終了" color="text-gray-600" bg="bg-gray-50" />}
            {t.schedule.closingTime && <ScheduleRow time={t.schedule.closingTime} label="閉会" color="text-gray-600" bg="bg-gray-50" />}
          </div>
        </div>
      )}

      {/* ルール */}
      {t.rules && (
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="px-5 py-4 flex items-center gap-2" style={{ background: "linear-gradient(135deg, rgba(46,125,50,0.06) 0%, rgba(46,125,50,0.02) 100%)", borderBottom: "1px solid rgba(46,125,50,0.08)" }}>
            <svg className="w-4.5 h-4.5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15a2.251 2.251 0 012.1 1.466" /></svg>
            <h3 className="text-sm font-bold text-foreground">ルール</h3>
          </div>
          <div className="p-5">
            {t.rules.preliminary && (
              <div className="mb-5">
                <h4 className="text-xs font-bold text-primary uppercase mb-3 flex items-center gap-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-primary" />
                  予選
                </h4>
                <div className="grid grid-cols-2 gap-3">
                  {t.rules.preliminary.rounds && (
                    <RuleChip label="ラウンド" value={`${t.rules.preliminary.rounds}`} />
                  )}
                  {t.rules.preliminary.sets && (
                    <RuleChip label="セット" value={`${t.rules.preliminary.sets}`} />
                  )}
                  {t.rules.preliminary.points && (
                    <RuleChip label="ポイント" value={`${t.rules.preliminary.points}点`} />
                  )}
                  {t.rules.preliminary.deuce !== undefined && (
                    <RuleChip label="デュース" value={t.rules.preliminary.deuce ? "あり" : "なし"} />
                  )}
                  {t.rules.preliminary.deuceCap && (
                    <RuleChip label="キャップ" value={`${t.rules.preliminary.deuceCap}点`} />
                  )}
                </div>
              </div>
            )}

            {t.rules.scoring && (
              <div className="mb-5">
                <h4 className="text-xs font-bold text-accent uppercase mb-3 flex items-center gap-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-accent" />
                  勝ち点
                </h4>
                <div className="flex flex-wrap gap-2">
                  {t.rules.scoring.win20 !== undefined && <PointBadge label="2-0勝" value={t.rules.scoring.win20} color="bg-green-50 text-green-700 border-green-200" />}
                  {t.rules.scoring.win11 !== undefined && <PointBadge label="2-1勝" value={t.rules.scoring.win11} color="bg-blue-50 text-blue-700 border-blue-200" />}
                  {t.rules.scoring.draw !== undefined && <PointBadge label="引分" value={t.rules.scoring.draw} color="bg-gray-50 text-gray-700 border-gray-200" />}
                  {t.rules.scoring.lose11 !== undefined && <PointBadge label="1-2負" value={t.rules.scoring.lose11} color="bg-orange-50 text-orange-700 border-orange-200" />}
                  {t.rules.scoring.lose02 !== undefined && <PointBadge label="0-2負" value={t.rules.scoring.lose02} color="bg-red-50 text-red-700 border-red-200" />}
                </div>
              </div>
            )}

            {t.rules.final?.enabled && (
              <div>
                <h4 className="text-xs font-bold text-purple-600 uppercase mb-3 flex items-center gap-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-purple-600" />
                  決勝
                </h4>
                <div className="grid grid-cols-2 gap-3">
                  {t.rules.final.sets && <RuleChip label="セット" value={`${t.rules.final.sets}`} />}
                  {t.rules.final.points && <RuleChip label="ポイント" value={`${t.rules.final.points}点`} />}
                  {t.rules.final.format && <RuleChip label="形式" value={t.rules.final.format} />}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 会場マップ */}
      {mapQuery && (
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="px-5 py-4 flex items-center gap-2" style={{ background: "linear-gradient(135deg, rgba(21,101,192,0.06) 0%, rgba(21,101,192,0.02) 100%)", borderBottom: "1px solid rgba(21,101,192,0.08)" }}>
            <svg className="w-4.5 h-4.5 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 6.75V15m6-6v8.25m.503 3.498l4.875-2.437c.381-.19.622-.58.622-1.006V4.82c0-.836-.88-1.38-1.628-1.006l-3.869 1.934c-.317.159-.69.159-1.006 0L9.503 3.252a1.125 1.125 0 00-1.006 0L3.622 5.689C3.24 5.88 3 6.27 3 6.695V19.18c0 .836.88 1.38 1.628 1.006l3.869-1.934c.317-.159.69-.159 1.006 0l4.994 2.497c.317.158.69.158 1.006 0z" /></svg>
            <h3 className="text-sm font-bold text-foreground">会場マップ</h3>
          </div>
          <div className="map-container" style={{ height: 280 }}>
            <iframe
              src={`https://maps.google.com/maps?q=${encodeURIComponent(mapQuery)}&output=embed&hl=ja`}
              allowFullScreen
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
            />
          </div>
        </div>
      )}
    </div>
  );
}

const iconPaths: Record<string, string> = {
  trophy: "M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M18.75 4.236c.982.143 1.954.317 2.916.52A6.003 6.003 0 0016.27 9.728M18.75 4.236V4.5c0 2.108-.966 3.99-2.48 5.228m0 0a6.003 6.003 0 01-4.52 1.772 6.003 6.003 0 01-4.52-1.772",
  calendar: "M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5",
  location: "M15 10.5a3 3 0 11-6 0 3 3 0 016 0z",
  tag: "M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z",
  yen: "M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
  person: "M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z",
};

function InfoRow({ label, value, icon }: { label: string; value: string; icon?: string }) {
  return (
    <div className="flex items-center justify-between py-1.5 border-b border-gray-50 last:border-0">
      <span className="text-sm text-muted flex items-center gap-2">
        {icon && iconPaths[icon] && (
          <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d={iconPaths[icon]} />
          </svg>
        )}
        {label}
      </span>
      <span className="text-sm font-medium text-foreground">{value}</span>
    </div>
  );
}

function ScheduleRow({ time, label, color, bg }: { time: string; label: string; color: string; bg: string }) {
  return (
    <div className="flex items-center gap-4 py-2.5 border-b border-gray-50 last:border-0">
      <div className={`px-2.5 py-1 rounded-lg ${bg} ${color} text-sm font-mono font-bold min-w-[56px] text-center`}>
        {time}
      </div>
      <span className="text-sm text-foreground font-medium">{label}</span>
    </div>
  );
}

function RuleChip({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between px-3 py-2 bg-gray-50 rounded-lg">
      <span className="text-xs text-muted">{label}</span>
      <span className="text-sm font-bold text-foreground">{value}</span>
    </div>
  );
}

function PointBadge({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border ${color}`}>
      {label}: {value}pt
    </span>
  );
}
