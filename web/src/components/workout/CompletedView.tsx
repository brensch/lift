import { type Workout, type ProposedSet, type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { groupSetsByExercise } from '@/components/ExerciseGroup'
import { SHORT_NAMES } from '@/lib/exercises'
import { fmtElapsed } from '@/hooks/useTimer'
import { SessionHeader } from '@/components/SessionHeader'

export function CompletedWorkoutView({ workout, proposedSets, completedSets, userId, onBack }: {
  workout: Workout
  proposedSets: ProposedSet[]
  completedSets: CompletedSet[]
  userId: string
  onBack: () => void
}) {
  const totalDuration = Number(workout.endTime - workout.startTime)
  const workoutStart = Number(workout.startTime)

  const entries = completedSets
    .filter((c) => c.endedAt > 0n)
    .map((c) => {
      const proposed = proposedSets.find((p) => p.id === c.proposedSetId)
      return { completed: c, proposed }
    })
    .sort((a, b) => Number(a.completed.startedAt - b.completed.startedAt))

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-3">
        <div className="flex items-center justify-between">
          <button onClick={onBack} className="text-3xl font-bold hover:opacity-80 transition-opacity">
            Lift
          </button>
          <span className="text-sm text-muted-foreground">{fmtElapsed(totalDuration)}</span>
        </div>
        <SessionHeader userId={userId} />
        <div className="text-center py-2">
          <h2 className="text-xl font-bold">{workout.name || 'Workout'}</h2>
          <p className="text-sm text-muted-foreground">
            {new Date(Number(workout.startTime) * 1000).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}
          </p>
        </div>
        {/* Timeline bar */}
        {totalDuration > 0 && (
          <div className="relative h-8 bg-muted rounded-full overflow-hidden">
            {entries.map((e, i) => {
              const start = Number(e.completed.startedAt) - workoutStart
              const end = Number(e.completed.endedAt) - workoutStart
              const left = (start / totalDuration) * 100
              const width = Math.max(((end - start) / totalDuration) * 100, 0.5)
              return (
                <div
                  key={i}
                  className={`absolute top-0 h-full ${e.proposed && e.completed.actualReps >= e.proposed.targetReps ? 'bg-green-500' : 'bg-yellow-500'}`}
                  style={{ left: `${left}%`, width: `${width}%` }}
                />
              )
            })}
          </div>
        )}
        {/* Summary by exercise */}
        <div className="grid grid-cols-2 gap-2">
          {groupSetsByExercise(proposedSets).map((group, i) => {
            const done = group.sets.filter((s) => completedSets.some((c) => c.proposedSetId === s.id && c.endedAt > 0n)).length
            return (
              <div key={i} className="bg-muted rounded-md px-3 py-2 text-sm">
                <span className="font-medium">{SHORT_NAMES[group.exercise as Exercise]}</span>
                <span className="text-muted-foreground ml-1">{done}/{group.sets.length}</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
