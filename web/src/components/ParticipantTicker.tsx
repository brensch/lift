import { type ParticipantStatus } from '@/gen/workout/v1/group_pb'
import { ParticipantStatusView } from './ParticipantStatusView'

export function ParticipantTicker({ status, isPeeping, onPeep }: { 
  status: ParticipantStatus; 
  isPeeping: boolean;
  onPeep: () => void 
}) {
  const activeCompletedSet = status.completedSets.find(c => c.endedAt === 0n)
  const lastCompletedSet = [...status.completedSets]
    .filter(c => c.endedAt > 0n)
    .sort((a, b) => Number(b.endedAt - a.endedAt))[0]

  const isResting = lastCompletedSet && Number(lastCompletedSet.restUntil) > Date.now() / 1000

  const dotColor = isResting 
    ? 'bg-blue-400 animate-pulse' 
    : activeCompletedSet
      ? 'bg-green-400'
      : lastCompletedSet
        ? 'bg-orange-400'
        : 'bg-gray-400'

  return (
    <button
      onClick={onPeep}
      className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-xs font-medium transition-all shrink-0 ${
        isPeeping 
          ? 'bg-primary border-primary text-primary-foreground shadow-md scale-105' 
          : 'bg-muted/50 border-transparent hover:bg-muted text-muted-foreground'
      }`}
    >
      <div className={`w-2 h-2 rounded-full ${dotColor}`} />
      <ParticipantStatusView status={status} layout="chip" />
    </button>
  )
}
