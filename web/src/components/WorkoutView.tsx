import { useState, useEffect, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { workoutClient, withUserId } from '@/lib/client'
import { create } from '@bufbuild/protobuf'
import {
  type Workout,
  type ProposedSet,
  type CompletedSet,
  Exercise,
  ProposedSetSchema,
} from '@/gen/workout/v1/workout_pb'
import { RestTimer } from './RestTimer'
import { ExerciseGroup, groupSetsByExercise } from './ExerciseGroup'

function WorkoutTimer({ startTime }: { startTime: bigint }) {
  const [elapsed, setElapsed] = useState(0)

  useEffect(() => {
    const startSecs = Number(startTime)
    const update = () => setElapsed(Math.floor(Date.now() / 1000) - startSecs)
    update()
    const interval = setInterval(update, 1000)
    return () => clearInterval(interval)
  }, [startTime])

  const hrs = Math.floor(elapsed / 3600)
  const mins = Math.floor((elapsed % 3600) / 60)
  const secs = elapsed % 60
  return (
    <span className="font-mono text-lg">
      {hrs > 0 && `${hrs}:`}{String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
    </span>
  )
}

interface WorkoutViewProps {
  workoutId: string
  userId: string
  onBack: () => void
}

export function WorkoutView({ workoutId, userId, onBack }: WorkoutViewProps) {
  const [workout, setWorkout] = useState<Workout | null>(null)
  const [proposedSets, setProposedSets] = useState<ProposedSet[]>([])
  const [completedSets, setCompletedSets] = useState<CompletedSet[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Rest timer
  const [restUntil, setRestUntil] = useState<number | null>(null)

  // Add set form
  const [newSetExercise, setNewSetExercise] = useState<Exercise>(Exercise.SQUAT)
  const [newSetReps, setNewSetReps] = useState(5)
  const [newSetWeight, setNewSetWeight] = useState(135)
  const [newSetWarmup, setNewSetWarmup] = useState(false)

  const loadWorkout = useCallback(async () => {
    try {
      const response = await workoutClient.getWorkout(
        { workoutId },
        withUserId(userId)
      )
      if (response.workout) {
        setWorkout(response.workout)
        setProposedSets(response.proposedSets)
        setCompletedSets(response.completedSets)

        // Restore rest timer from most recent completed set
        const lastCompleted = response.completedSets
          .filter((c) => c.endedAt > 0n && c.restUntil > 0n)
          .sort((a, b) => Number(b.endedAt - a.endedAt))[0]
        if (lastCompleted) {
          const restUntilSecs = Number(lastCompleted.restUntil)
          const now = Math.floor(Date.now() / 1000)
          if (restUntilSecs > now) {
            setRestUntil(restUntilSecs)
          }
        }
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load workout')
    }
  }, [workoutId, userId])

  useEffect(() => {
    loadWorkout()
  }, [loadWorkout])

  const handleSetUpdated = (completedSet: CompletedSet) => {
    setCompletedSets((prev) => {
      const idx = prev.findIndex((c) => c.proposedSetId === completedSet.proposedSetId)
      if (idx >= 0) {
        const next = [...prev]
        next[idx] = completedSet
        return next
      }
      return [...prev, completedSet]
    })

    // If set was completed (has endedAt), start rest timer from server's rest_until
    if (completedSet.endedAt > 0n && completedSet.restUntil > 0n) {
      setRestUntil(Number(completedSet.restUntil))
    }
  }

  const handleMoveGroup = async (fromIndex: number, toIndex: number) => {
    const groups = groupSetsByExercise(proposedSets)
    const reordered = [...groups]
    const [moved] = reordered.splice(fromIndex, 1)
    reordered.splice(toIndex, 0, moved)

    // Flatten and reassign workout_order
    let order = 0
    const newSets: ProposedSet[] = []
    for (const group of reordered) {
      for (const set of group.sets) {
        newSets.push(create(ProposedSetSchema, {
          ...set,
          workoutOrder: order++,
        }))
      }
    }

    try {
      const response = await workoutClient.modifyProposedSets(
        { workoutId, proposedSets: newSets },
        withUserId(userId)
      )
      setProposedSets(response.proposedSets)
    } catch (e) {
      console.error('Failed to reorder sets:', e)
    }
  }

  const handleAddSet = async () => {
    setLoading(true)
    try {
      const newSet = create(ProposedSetSchema, {
        exercise: newSetExercise,
        targetReps: newSetReps,
        targetWeight: newSetWeight,
        warmup: newSetWarmup,
        workoutOrder: proposedSets.length,
      })

      const response = await workoutClient.modifyProposedSets(
        {
          workoutId,
          proposedSets: [...proposedSets, newSet],
        },
        withUserId(userId)
      )
      setProposedSets(response.proposedSets)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to add set')
    } finally {
      setLoading(false)
    }
  }

  const handleEndWorkout = async () => {
    setLoading(true)
    try {
      await workoutClient.endWorkout(
        { workoutId },
        withUserId(userId)
      )
      onBack()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to end workout')
    } finally {
      setLoading(false)
    }
  }

  const isWorkoutEnded = workout ? workout.endTime > 0n : false
  const groups = groupSetsByExercise(proposedSets)
  const completedCount = completedSets.filter((c) => c.endedAt > 0n).length

  const formatTime = (timestamp: bigint | number) => {
    if (!timestamp) return 'N/A'
    return new Date(Number(timestamp) * 1000).toLocaleString()
  }

  const formatDuration = (start: bigint, end: bigint) => {
    if (!start || !end) return ''
    const seconds = Number(end - start)
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}m ${secs}s`
  }

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-4">
        <div className="flex items-center justify-between">
          <Button variant="ghost" onClick={onBack}>
            &larr; Back
          </Button>
          <div className="flex items-center gap-3">
            {workout && !isWorkoutEnded && (
              <WorkoutTimer startTime={workout.startTime} />
            )}
            {!isWorkoutEnded && (
              <Button variant="destructive" onClick={handleEndWorkout} disabled={loading}>
                End Workout
              </Button>
            )}
          </div>
        </div>

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md">
            {error}
          </div>
        )}

        {/* Rest Timer */}
        {restUntil && (
          <RestTimer restUntil={restUntil} onDismiss={() => setRestUntil(null)} />
        )}

        {/* Workout Info */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle>
              {isWorkoutEnded ? 'Workout Complete' : (workout?.name || 'Custom Workout')}
            </CardTitle>
            <CardDescription>
              Started: {formatTime(workout?.startTime || 0n)}
              {isWorkoutEnded && workout && (
                <> | Duration: {formatDuration(workout.startTime, workout.endTime)}</>
              )}
              {!isWorkoutEnded && (
                <> | {completedCount}/{proposedSets.length} sets completed</>
              )}
            </CardDescription>
          </CardHeader>
        </Card>

        {/* Exercise Groups */}
        <div className="space-y-3">
          {groups.length === 0 ? (
            <Card>
              <CardContent className="py-6">
                <p className="text-muted-foreground text-center">No sets added yet</p>
              </CardContent>
            </Card>
          ) : (
            groups.map((group, idx) => (
              <ExerciseGroup
                key={`${group.exercise}-${idx}`}
                group={group}
                groupIndex={idx}
                totalGroups={groups.length}
                completedSets={completedSets}
                workoutId={workoutId}
                userId={userId}
                isWorkoutEnded={isWorkoutEnded}
                onSetUpdated={handleSetUpdated}
                onMoveUp={() => handleMoveGroup(idx, idx - 1)}
                onMoveDown={() => handleMoveGroup(idx, idx + 1)}
              />
            ))
          )}
        </div>

        {/* Add new set */}
        {!isWorkoutEnded && (
          <Card>
            <CardHeader>
              <CardTitle>Add Set</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <label className="text-sm text-muted-foreground">Exercise</label>
                <select
                  className="w-full mt-1 p-2 border rounded-md bg-background"
                  value={newSetExercise}
                  onChange={(e) => setNewSetExercise(Number(e.target.value) as Exercise)}
                >
                  <option value={Exercise.SQUAT}>Squat</option>
                  <option value={Exercise.BENCH_PRESS}>Bench Press</option>
                  <option value={Exercise.DEADLIFT}>Deadlift</option>
                  <option value={Exercise.OVERHEAD_PRESS}>Overhead Press</option>
                  <option value={Exercise.BARBELL_ROW}>Barbell Row</option>
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-muted-foreground">Target Reps</label>
                  <Input
                    type="number"
                    value={newSetReps}
                    onChange={(e) => setNewSetReps(Number(e.target.value))}
                  />
                </div>
                <div>
                  <label className="text-sm text-muted-foreground">Target Weight (lbs)</label>
                  <Input
                    type="number"
                    value={newSetWeight}
                    onChange={(e) => setNewSetWeight(Number(e.target.value))}
                  />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="warmup"
                  checked={newSetWarmup}
                  onChange={(e) => setNewSetWarmup(e.target.checked)}
                  className="rounded"
                />
                <label htmlFor="warmup" className="text-sm">Warmup set</label>
              </div>
              <Button onClick={handleAddSet} disabled={loading} className="w-full">
                {loading ? 'Adding...' : 'Add Set'}
              </Button>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  )
}
