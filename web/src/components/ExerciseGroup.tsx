import type { ProposedSet, CompletedSet } from '@/gen/workout/v1/workout_pb'
import { Exercise } from '@/gen/workout/v1/workout_pb'

const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'OHP',
  [Exercise.BARBELL_ROW]: 'Row',
}

export interface ExerciseGroupData {
  exercise: Exercise
  sets: ProposedSet[]
}

interface ExerciseGroupProps {
  group: ExerciseGroupData
  groupIndex: number
  totalGroups: number
  completedSets: CompletedSet[]
  activeSetId?: string
  isWorkoutEnded: boolean
  onMoveUp: () => void
  onMoveDown: () => void
}

export function ExerciseGroup({
  group,
  groupIndex,
  totalGroups,
  completedSets,
  activeSetId,
  isWorkoutEnded,
  onMoveUp,
  onMoveDown,
}: ExerciseGroupProps) {
  const allCompleted = group.sets.every((s) =>
    completedSets.some((c) => c.proposedSetId === s.id && c.endedAt > 0n)
  )

  return (
    <div className={`flex items-center gap-2 px-3 py-2 rounded-md border ${allCompleted ? 'bg-green-500/5 border-green-500/20' : 'bg-muted/50'}`}>
      {/* Reorder arrows */}
      {!isWorkoutEnded && !allCompleted && (
        <div className="flex flex-col gap-0.5 -ml-1">
          <button
            onClick={onMoveUp}
            disabled={groupIndex === 0}
            className="text-xs text-muted-foreground hover:text-foreground disabled:opacity-20 leading-none"
          >
            ▲
          </button>
          <button
            onClick={onMoveDown}
            disabled={groupIndex === totalGroups - 1}
            className="text-xs text-muted-foreground hover:text-foreground disabled:opacity-20 leading-none"
          >
            ▼
          </button>
        </div>
      )}

      {/* Exercise name */}
      <span className={`text-sm font-medium w-16 shrink-0 ${allCompleted ? 'text-green-600' : ''}`}>
        {EXERCISE_NAMES[group.exercise]}
      </span>

      {/* Set indicators */}
      <div className="flex gap-1.5 flex-wrap flex-1">
        {group.sets.map((set) => {
          const completed = completedSets.find(
            (c) => c.proposedSetId === set.id && c.endedAt > 0n
          )
          const isActive = set.id === activeSetId

          if (completed) {
            const hitTarget = completed.actualReps >= set.targetReps
            return (
              <span
                key={set.id}
                className={`text-xs px-1.5 py-0.5 rounded ${hitTarget ? 'bg-green-500/20 text-green-600' : 'bg-yellow-500/20 text-yellow-600'}`}
                title={`${completed.actualReps}×${completed.actualWeight}`}
              >
                ✓{completed.actualReps < set.targetReps ? completed.actualReps : ''}
              </span>
            )
          }

          return (
            <span
              key={set.id}
              className={`text-xs px-1.5 py-0.5 rounded ${
                isActive
                  ? 'bg-primary/20 text-primary font-bold ring-1 ring-primary'
                  : 'bg-muted text-muted-foreground'
              }`}
            >
              {set.targetReps}×{set.targetWeight}
            </span>
          )
        })}
      </div>
    </div>
  )
}

export function groupSetsByExercise(sets: ProposedSet[]): ExerciseGroupData[] {
  const groups: ExerciseGroupData[] = []
  let currentExercise: Exercise | null = null
  let currentGroup: ProposedSet[] = []

  for (const set of sets) {
    if (set.exercise !== currentExercise) {
      if (currentGroup.length > 0 && currentExercise !== null) {
        groups.push({ exercise: currentExercise, sets: currentGroup })
      }
      currentExercise = set.exercise
      currentGroup = [set]
    } else {
      currentGroup.push(set)
    }
  }

  if (currentGroup.length > 0 && currentExercise !== null) {
    groups.push({ exercise: currentExercise, sets: currentGroup })
  }

  return groups
}
