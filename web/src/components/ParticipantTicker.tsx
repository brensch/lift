import { type ParticipantStatus } from '@/gen/workout/v1/group_pb'
import { Exercise } from '@/gen/workout/v1/workout_pb'

const SHORT_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Sq',
  [Exercise.BENCH_PRESS]: 'Bp',
  [Exercise.DEADLIFT]: 'Dl',
  [Exercise.OVERHEAD_PRESS]: 'Oh',
  [Exercise.BARBELL_ROW]: 'Br',
}

export function ParticipantTicker({ status, isPeeping, onPeep }: { 
  status: ParticipantStatus; 
  isPeeping: boolean;
  onPeep: () => void 
}) {
  const currentSet = status.currentSet
  
  return (
    <button
      onClick={onPeep}
      className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-xs font-medium transition-all shrink-0 ${
        isPeeping 
          ? 'bg-primary border-primary text-primary-foreground shadow-md scale-105' 
          : 'bg-muted/50 border-transparent hover:bg-muted text-muted-foreground'
      }`}
    >
      <div className={`w-2 h-2 rounded-full ${status.isResting ? 'bg-blue-400 animate-pulse' : 'bg-green-400'}`} />
      <span className="max-w-[80px] truncate">{status.user?.name}</span>
      <span className="opacity-60">
        {currentSet ? `${SHORT_NAMES[currentSet.exercise as Exercise]} ${currentSet.targetReps}x${currentSet.targetWeight}` : 'idle'}
      </span>
    </button>
  )
}
