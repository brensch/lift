import { type Workout, type ProposedSet, type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { groupSetsByExercise } from '@/components/ExerciseGroup'
import { SHORT_NAMES } from '@/lib/exercises'
import { fmtElapsed } from '@/hooks/useTimer'
import { SessionHeader } from '@/components/SessionHeader'

function fmtTime(ts: bigint | number) {
  if (!ts) return ''
  return new Date(Number(ts) * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

export function CompletedWorkoutView({ workout, proposedSets, completedSets, userId }: {
  workout: Workout
  proposedSets: ProposedSet[]
  completedSets: CompletedSet[]
  userId: string
}) {
  const totalDuration = Number(workout.endTime - workout.startTime)

  const entries = completedSets
    .filter((c) => c.endedAt > 0n)
    .map((c) => {
      const proposed = proposedSets.find((p) => p.id === c.proposedSetId)
      return { completed: c, proposed }
    })
    .sort((a, b) => Number(a.completed.startedAt - b.completed.startedAt))

  const groups = groupSetsByExercise(proposedSets)

  const exerciseStats = groups.map((group) => {
    const workingSets = group.sets.filter((s) => !s.warmup)
    const completedWorking = workingSets
      .map((s) => completedSets.find((c) => c.proposedSetId === s.id && c.endedAt > 0n))
      .filter(Boolean) as CompletedSet[]
    const workingVolume = completedWorking.reduce((sum, c) => sum + c.actualReps * c.actualWeight, 0)
    const workingReps = completedWorking.reduce((sum, c) => sum + c.actualReps, 0)

    return {
      workingReps,
      workingVolume,
      workingSetsCompleted: completedWorking.length,
    }
  })

  const totalWorkingVolume = exerciseStats.reduce((sum, s) => sum + s.workingVolume, 0)
  const totalWorkingReps = exerciseStats.reduce((sum, s) => sum + s.workingReps, 0)
  const totalWorkingSets = exerciseStats.reduce((sum, s) => sum + s.workingSetsCompleted, 0)

  return (
    <div className="min-h-screen bg-background p-4 pt-0">
      <div className="max-w-2xl mx-auto space-y-4">
        <SessionHeader userId={userId} />
        <div className="text-center py-2">
          <h2 className="text-xl font-bold uppercase tracking-tight">{workout.name || 'Workout'}</h2>
          <p className="text-sm text-muted-foreground uppercase tracking-widest font-black">
            {new Date(Number(workout.startTime) * 1000).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}
            <span className="ml-2 opacity-50">&middot;</span>
            <span className="ml-2">{fmtElapsed(totalDuration)}</span>
          </p>
        </div>

        {/* Totals */}
        <div className="grid grid-cols-3 gap-2">
          <div className="bg-muted rounded-md px-3 py-2 text-center">
            <div className="text-lg font-bold">{totalWorkingSets}</div>
            <div className="text-xs text-muted-foreground">Working Sets</div>
          </div>
          <div className="bg-muted rounded-md px-3 py-2 text-center">
            <div className="text-lg font-bold">{totalWorkingReps}</div>
            <div className="text-xs text-muted-foreground">Working Reps</div>
          </div>
          <div className="bg-muted rounded-md px-3 py-2 text-center">
            <div className="text-lg font-bold">{totalWorkingVolume >= 1000 ? `${(totalWorkingVolume / 1000).toFixed(1)}k` : totalWorkingVolume}</div>
            <div className="text-xs text-muted-foreground">Volume (lbs)</div>
          </div>
        </div>

        {/* Set Log */}
        <div className="space-y-1">
          <div className="text-xs text-muted-foreground font-medium px-1 mb-1">
            Set Log
          </div>
          <div className="space-y-0.5">
            {entries.map((entry, i) => (
              <div key={i} className="text-xs px-2 py-1 rounded flex items-center gap-2 bg-muted/50">
                <span className="font-medium w-12 shrink-0 truncate">
                  {entry.proposed ? SHORT_NAMES[entry.proposed.exercise as Exercise] : '?'}
                </span>
                <span className="font-medium">
                  {entry.completed.actualReps}&times;{entry.completed.actualWeight}
                  {entry.proposed?.warmup ? ' (w)' : ''}
                </span>
                <span className="text-muted-foreground font-mono ml-auto">{fmtTime(entry.completed.endedAt)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
