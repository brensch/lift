import { Button } from '@/components/ui/button'
import { SetItem } from './SetItem'
import type { ProposedSet, CompletedSet } from '@/gen/workout/v1/workout_pb'
import { Exercise } from '@/gen/workout/v1/workout_pb'

const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: 'Select Exercise',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench Press',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'Overhead Press',
  [Exercise.BARBELL_ROW]: 'Barbell Row',
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
  workoutId: string
  userId: string
  isWorkoutEnded: boolean
  onSetUpdated: (completedSet: CompletedSet) => void
  onMoveUp: () => void
  onMoveDown: () => void
}

export function ExerciseGroup({
  group,
  groupIndex,
  totalGroups,
  completedSets,
  workoutId,
  userId,
  isWorkoutEnded,
  onSetUpdated,
  onMoveUp,
  onMoveDown,
}: ExerciseGroupProps) {
  const allCompleted = group.sets.every((s) =>
    completedSets.some((c) => c.proposedSetId === s.id && c.endedAt > 0n)
  )

  const completedCount = group.sets.filter((s) =>
    completedSets.some((c) => c.proposedSetId === s.id && c.endedAt > 0n)
  ).length

  return (
    <div className="border rounded-lg p-3 space-y-2">
      <div className="flex items-center justify-between">
        <div className="font-bold text-sm">
          {EXERCISE_NAMES[group.exercise]}
          <span className="ml-2 text-muted-foreground font-normal">
            {completedCount}/{group.sets.length}
          </span>
        </div>
        {!isWorkoutEnded && !allCompleted && (
          <div className="flex gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={onMoveUp}
              disabled={groupIndex === 0}
              className="h-7 w-7 p-0"
            >
              ↑
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={onMoveDown}
              disabled={groupIndex === totalGroups - 1}
              className="h-7 w-7 p-0"
            >
              ↓
            </Button>
          </div>
        )}
      </div>
      <div className="space-y-2">
        {group.sets.map((set) => {
          const completed = completedSets.find(
            (c) => c.proposedSetId === set.id
          )
          return (
            <SetItem
              key={set.id}
              proposedSet={set}
              completedSet={completed}
              workoutId={workoutId}
              userId={userId}
              isWorkoutEnded={isWorkoutEnded}
              onSetUpdated={onSetUpdated}
            />
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
