import type { ProposedSet, CompletedSet, ExerciseGroup as ExerciseGroupProto } from '@/gen/workout/v1/workout_pb'
import { Exercise } from '@/gen/workout/v1/workout_pb'
import { Pencil } from 'lucide-react'
import { SHORT_NAMES } from '@/lib/exercises'

export interface ExerciseGroupData {
  exercise: Exercise
  sets: ProposedSet[]
  group?: ExerciseGroupProto
}

interface ExerciseGroupProps {
  group: ExerciseGroupData
  groupIndex: number
  totalGroups: number
  completedSets: CompletedSet[]
  activeSetId?: string
  isWorkoutEnded: boolean
  onMoveUp?: () => void
  onMoveDown?: () => void
  onEdit?: () => void
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
  onEdit,
}: ExerciseGroupProps) {
  const workingSets = group.sets.filter((s) => !s.warmup)
  const allCompleted = workingSets.length > 0 && workingSets.every((s) =>
    completedSets.some((c) => c.proposedSetId === s.id && c.endedAt > 0n)
  )

  return (
    <div className={`flex items-center gap-2 px-3 py-2 rounded-md border ${allCompleted ? 'bg-green-500/5 border-green-500/20' : 'bg-muted/50'}`}>
      {/* Reorder arrows */}
      {!isWorkoutEnded && !allCompleted && onMoveUp && onMoveDown && (
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

      {/* Exercise name + edit icon */}
      <span className={`text-sm font-medium w-16 shrink-0 ${allCompleted ? 'text-green-600' : ''}`}>
        {SHORT_NAMES[group.exercise]}
      </span>
      {!isWorkoutEnded && onEdit && (
        <button
          onClick={onEdit}
          className="text-muted-foreground hover:text-foreground -ml-1 shrink-0"
        >
          <Pencil className="w-3 h-3" />
        </button>
      )}

      {/* Set indicators */}
      <div className="flex gap-2 flex-wrap flex-1">
        {group.sets.map((set) => {
          const completed = completedSets.find(
            (c) => c.proposedSetId === set.id && c.endedAt > 0n
          )
          const isActive = set.id === activeSetId
          const isSuperset = group.group?.type === 2 // ExerciseGroupType.EXERCISE_GROUP_TYPE_SUPERSET
          const exerciseName = SHORT_NAMES[set.exercise]

          if (completed) {
            if (set.warmup) {
              return (
                <span
                  key={set.id}
                  className="text-[13px] px-2 py-1 rounded bg-blue-500/20 text-blue-600 font-bold"
                  title={`Warmup: ${completed.actualReps}×${completed.actualWeight}`}
                >
                  {isSuperset && `${exerciseName} `}W
                </span>
              )
            }
            const hitTarget = completed.actualReps >= set.targetReps
            return (
              <span
                key={set.id}
                className={`text-[13px] px-2 py-1 rounded font-bold ${hitTarget ? 'bg-green-500/20 text-green-600' : 'bg-yellow-500/20 text-yellow-600'}`}
                title={`${completed.actualReps}×${completed.actualWeight}`}
              >
                {isSuperset && `${exerciseName} `}✓{completed.actualReps < set.targetReps ? completed.actualReps : ''}
              </span>
            )
          }

          if (set.warmup) {
            return (
              <span
                key={set.id}
                className={`text-[13px] px-2 py-1 rounded ${
                  isActive
                    ? 'bg-blue-500/20 text-blue-600 font-bold ring-1 ring-blue-500'
                    : 'border border-blue-500/40 text-blue-600'
                }`}
              >
                {isSuperset && `${exerciseName} `}W:{set.targetReps}×{set.targetWeight}
              </span>
            )
          }

          return (
            <span
              key={set.id}
              className={`text-[13px] px-2 py-1 rounded ${
                isActive
                  ? 'bg-primary/20 text-primary font-bold ring-1 ring-primary'
                  : 'bg-muted text-muted-foreground'
              }`}
            >
              {isSuperset && `${exerciseName} `}{set.targetReps}×{set.targetWeight}
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
