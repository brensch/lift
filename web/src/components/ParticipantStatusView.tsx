import { type ParticipantStatus } from '@/gen/workout/v1/group_pb'
import { Exercise, type ProposedSet } from '@/gen/workout/v1/workout_pb'
import { useElapsed, useCountdown, fmtElapsed } from '@/hooks/useTimer'

const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench Press',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'Overhead Press',
  [Exercise.BARBELL_ROW]: 'Barbell Row',
}

const SHORT_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Sq',
  [Exercise.BENCH_PRESS]: 'Bp',
  [Exercise.DEADLIFT]: 'Dl',
  [Exercise.OVERHEAD_PRESS]: 'Oh',
  [Exercise.BARBELL_ROW]: 'Br',
}

function getSetInfo(proposedSet: ProposedSet, allProposed: ProposedSet[]) {
  const sameExerciseSets = allProposed.filter(s => s.exercise === proposedSet.exercise);
  const index = sameExerciseSets.findIndex(s => s.id === proposedSet.id) + 1;
  return `${index}/${sameExerciseSets.length}`;
}

interface ParticipantStatusViewProps {
  status: ParticipantStatus
  layout: 'chip' | 'detail'
}

export function ParticipantStatusView({ status, layout }: ParticipantStatusViewProps) {
  const activeCompletedSet = status.completedSets.find(c => c.endedAt === 0n)
  
  const lastCompletedSet = [...status.completedSets]
    .filter(c => c.endedAt > 0n)
    .sort((a, b) => Number(b.endedAt - a.endedAt))[0]

  const isWorkoutFinished = status.activeWorkout && Number(status.activeWorkout.endTime) > 0

  // Derive "isResting" and "restUntil" from the last completed set
  const restUntil = lastCompletedSet?.restUntil || 0n
  const isResting = !isWorkoutFinished && Number(restUntil) > Date.now() / 1000

  // Derive "currentSet" (the active one or the next one)
  const currentSet = activeCompletedSet 
    ? status.proposedSets.find(p => p.id === activeCompletedSet.proposedSetId)
    : status.proposedSets.find(p => !status.completedSets.some(c => c.proposedSetId === p.id && c.endedAt > 0n))

  const elapsedWorking = useElapsed(activeCompletedSet?.startedAt || 0n)
  const remainingRest = useCountdown(restUntil)
  const elapsedChatting = useElapsed(isResting || isWorkoutFinished ? 0n : restUntil)

  let mode = 'idle'
  let timerText = ''
  let label = ''
  let exerciseInfo = ''

  if (isWorkoutFinished) {
    mode = 'finished'
    label = 'done'
    exerciseInfo = 'Workout complete!'
  } else if (isResting) {
    mode = 'resting'
    timerText = fmtElapsed(remainingRest)
    label = 'next'
    if (currentSet) {
      exerciseInfo = `${SHORT_NAMES[currentSet.exercise as Exercise]} ${getSetInfo(currentSet, status.proposedSets)} ${currentSet.targetReps}x${currentSet.targetWeight}`
    }
  } else if (activeCompletedSet && currentSet) {
    mode = 'working'
    timerText = fmtElapsed(elapsedWorking)
    label = 'set'
    exerciseInfo = `${SHORT_NAMES[currentSet.exercise as Exercise]} ${getSetInfo(currentSet, status.proposedSets)} ${currentSet.targetReps}x${currentSet.targetWeight}`
  } else if (lastCompletedSet && !isResting) {
    mode = 'chatting'
    timerText = fmtElapsed(elapsedChatting)
    label = 'next'
    if (currentSet) {
      exerciseInfo = `${SHORT_NAMES[currentSet.exercise as Exercise]} ${getSetInfo(currentSet, status.proposedSets)} ${currentSet.targetReps}x${currentSet.targetWeight}`
    }
  } else if (currentSet) {
    mode = 'ready'
    label = 'next'
    exerciseInfo = `${SHORT_NAMES[currentSet.exercise as Exercise]} ${getSetInfo(currentSet, status.proposedSets)} ${currentSet.targetReps}x${currentSet.targetWeight}`
  }

  if (layout === 'chip') {
    return (
      <div className="flex flex-col items-start leading-[1.1]">
        <div className="flex items-center gap-1.5">
          <span className="max-w-[60px] truncate font-bold">{status.user?.name}</span>
          <span className="opacity-70 text-[9px] lowercase">{mode}</span>
          {timerText && <span className="font-mono text-[9px] opacity-90">{timerText}</span>}
        </div>
        {exerciseInfo && (
          <div className="opacity-60 font-mono text-[9px] mt-0.5">
            {label}: {exerciseInfo}
          </div>
        )}
      </div>
    )
  }

  return (
    <div className="text-center p-4 bg-muted rounded-lg border border-border">
      <div className="flex items-center justify-center gap-2 mb-1">
        <p className="text-[10px] uppercase font-black text-muted-foreground tracking-widest">{mode}</p>
        {timerText && (
          <span className="font-mono text-xs font-bold text-primary px-2 py-0.5 bg-primary/10 rounded-md">
            {timerText}
          </span>
        )}
      </div>
      {currentSet ? (
        <>
          <p className="text-xl font-bold">{EXERCISE_NAMES[currentSet.exercise as Exercise]}</p>
          <p className="text-xs font-mono opacity-70 mb-1">
            {label}: {getSetInfo(currentSet, status.proposedSets)} {currentSet.targetReps}x{currentSet.targetWeight}
          </p>
        </>
      ) : (
        <p className="text-sm italic opacity-60 py-2">No active exercise</p>
      )}
    </div>
  )
}