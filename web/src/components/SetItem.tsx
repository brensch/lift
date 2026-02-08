import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { workoutClient, withUserId } from '@/lib/client'
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

interface SetItemProps {
  proposedSet: ProposedSet
  completedSet?: CompletedSet
  workoutId: string
  userId: string
  isWorkoutEnded: boolean
  onSetUpdated: (completedSet: CompletedSet) => void
}

function SetTimer({ startedAt }: { startedAt: bigint }) {
  const [elapsed, setElapsed] = useState(0)

  useEffect(() => {
    const startSecs = Number(startedAt)
    const update = () => setElapsed(Math.floor(Date.now() / 1000) - startSecs)
    update()
    const interval = setInterval(update, 1000)
    return () => clearInterval(interval)
  }, [startedAt])

  const mins = Math.floor(elapsed / 60)
  const secs = elapsed % 60
  return (
    <span className="font-mono text-muted-foreground">
      {mins}:{String(secs).padStart(2, '0')}
    </span>
  )
}

export function SetItem({
  proposedSet,
  completedSet,
  workoutId,
  userId,
  isWorkoutEnded,
  onSetUpdated,
}: SetItemProps) {
  const [loading, setLoading] = useState(false)

  const isCompleted = completedSet && completedSet.endedAt > 0n
  const isStarted = completedSet && completedSet.endedAt === 0n

  const handleStartSet = async () => {
    setLoading(true)
    try {
      const response = await workoutClient.startSet(
        { workoutId, proposedSetId: proposedSet.id },
        withUserId(userId)
      )
      if (response.completedSet) {
        onSetUpdated(response.completedSet)
      }
    } catch (e) {
      console.error('Failed to start set:', e)
    } finally {
      setLoading(false)
    }
  }

  const handleSelectRep = async (reps: number) => {
    setLoading(true)
    try {
      const response = await workoutClient.completeSet(
        {
          workoutId,
          proposedSetId: proposedSet.id,
          actualReps: reps,
          actualWeight: proposedSet.targetWeight,
        },
        withUserId(userId)
      )
      if (response.completedSet) {
        onSetUpdated(response.completedSet)
      }
    } catch (e) {
      console.error('Failed to complete set:', e)
    } finally {
      setLoading(false)
    }
  }

  // Completed
  if (isCompleted) {
    return (
      <div className="p-3 rounded-md border bg-green-500/10 border-green-500/30">
        <div className="flex items-center justify-between">
          <div>
            <div className="font-medium text-green-600">
              {EXERCISE_NAMES[proposedSet.exercise]}
              {proposedSet.warmup && (
                <span className="ml-2 text-xs bg-yellow-500/20 text-yellow-600 px-1.5 py-0.5 rounded">
                  Warmup
                </span>
              )}
            </div>
            <div className="text-sm text-green-600">
              {completedSet!.actualReps} reps @ {completedSet!.actualWeight} lbs
            </div>
          </div>
          <span className="text-green-600 text-sm font-medium">Done</span>
        </div>
      </div>
    )
  }

  // Started — show target info + set timer + rep buttons immediately
  if (isStarted) {
    const maxReps = proposedSet.targetReps
    const buttons = Array.from({ length: maxReps + 1 }, (_, i) => i)

    return (
      <div className="p-4 rounded-md border-2 border-primary bg-primary/5">
        <div className="flex items-center justify-between mb-2">
          <div className="text-sm text-muted-foreground">
            {EXERCISE_NAMES[proposedSet.exercise]}
            {proposedSet.warmup && ' (Warmup)'}
          </div>
          <SetTimer startedAt={completedSet!.startedAt} />
        </div>
        <div className="text-center mb-3">
          <div className="text-3xl font-bold">
            {proposedSet.targetWeight} lbs
          </div>
          <div className="text-4xl font-bold text-primary">
            {proposedSet.targetReps} reps
          </div>
        </div>
        <div className="text-sm text-muted-foreground mb-2 text-center">How many did you get?</div>
        <div className="flex flex-wrap gap-2 justify-center">
          {buttons.map((n) => (
            <Button
              key={n}
              size="sm"
              variant={n === maxReps ? 'default' : 'outline'}
              onClick={() => handleSelectRep(n)}
              disabled={loading}
              className="min-w-[40px]"
            >
              {n}
            </Button>
          ))}
        </div>
      </div>
    )
  }

  // Pending
  return (
    <div className="p-3 rounded-md border bg-muted">
      <div className="flex items-center justify-between">
        <div>
          <div className="font-medium">
            {EXERCISE_NAMES[proposedSet.exercise]}
            {proposedSet.warmup && (
              <span className="ml-2 text-xs bg-yellow-500/20 text-yellow-600 px-1.5 py-0.5 rounded">
                Warmup
              </span>
            )}
          </div>
          <div className="text-sm text-muted-foreground">
            {proposedSet.targetReps} reps @ {proposedSet.targetWeight} lbs
          </div>
        </div>
        {!isWorkoutEnded && (
          <Button size="sm" onClick={handleStartSet} disabled={loading}>
            Start Set
          </Button>
        )}
      </div>
    </div>
  )
}
