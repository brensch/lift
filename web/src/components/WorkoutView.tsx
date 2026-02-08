import { useState, useEffect, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
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
import { ExerciseGroup, groupSetsByExercise } from './ExerciseGroup'

const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench Press',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'Overhead Press',
  [Exercise.BARBELL_ROW]: 'Barbell Row',
}

// --- small timer helpers ---

function useElapsed(startSecs: number) {
  const [elapsed, setElapsed] = useState(() => Math.floor(Date.now() / 1000) - startSecs)
  useEffect(() => {
    const update = () => setElapsed(Math.floor(Date.now() / 1000) - startSecs)
    update()
    const id = setInterval(update, 1000)
    return () => clearInterval(id)
  }, [startSecs])
  return elapsed
}

function useCountdown(untilSecs: number) {
  const [remaining, setRemaining] = useState(() => Math.max(0, untilSecs - Math.floor(Date.now() / 1000)))
  useEffect(() => {
    const update = () => setRemaining(Math.max(0, untilSecs - Math.floor(Date.now() / 1000)))
    update()
    const id = setInterval(update, 200)
    return () => clearInterval(id)
  }, [untilSecs])
  return remaining
}

function formatElapsed(secs: number) {
  const h = Math.floor(secs / 3600)
  const m = Math.floor((secs % 3600) / 60)
  const s = secs % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

// --- Active box sub-components ---

function RestingBox({
  restUntil,
  nextSet,
  onStartEarly,
}: {
  restUntil: number
  nextSet?: ProposedSet
  onStartEarly: () => void
}) {
  const remaining = useCountdown(restUntil)

  if (remaining <= 0) return null

  return (
    <Card className="border-2 border-blue-500/50 bg-blue-500/5">
      <CardContent className="pt-6 pb-4">
        <div className="text-center">
          <p className="text-sm text-muted-foreground mb-1">Rest</p>
          <p className="text-5xl font-bold font-mono">
            {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, '0')}
          </p>
          {nextSet && (
            <p className="text-sm text-muted-foreground mt-3">
              Up next: {EXERCISE_NAMES[nextSet.exercise]} {nextSet.targetReps}×{nextSet.targetWeight}lbs
            </p>
          )}
          <Button className="mt-3" onClick={onStartEarly}>
            Start Next Set Early
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function ActiveSetBox({
  proposedSet,
  completedSet,
  onComplete,
}: {
  proposedSet: ProposedSet
  completedSet: CompletedSet
  onComplete: (reps: number) => void
}) {
  const elapsed = useElapsed(Number(completedSet.startedAt))
  const [loading, setLoading] = useState(false)
  const maxReps = proposedSet.targetReps
  const buttons = Array.from({ length: maxReps + 1 }, (_, i) => i)

  const handleClick = async (reps: number) => {
    setLoading(true)
    onComplete(reps)
  }

  return (
    <Card className="border-2 border-primary">
      <CardContent className="pt-6 pb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm text-muted-foreground">
            {EXERCISE_NAMES[proposedSet.exercise]}
            {proposedSet.warmup && ' (Warmup)'}
          </span>
          <span className="font-mono text-muted-foreground">{formatElapsed(elapsed)}</span>
        </div>
        <div className="text-center mb-4">
          <div className="text-3xl font-bold">{proposedSet.targetWeight} lbs</div>
          <div className="text-4xl font-bold text-primary">{proposedSet.targetReps} reps</div>
        </div>
        <div className="text-xs text-muted-foreground mb-2 text-center">How many did you get?</div>
        <div className="flex flex-wrap gap-2 justify-center">
          {buttons.map((n) => (
            <Button
              key={n}
              size="sm"
              variant={n === maxReps ? 'default' : 'outline'}
              onClick={() => handleClick(n)}
              disabled={loading}
              className="min-w-[40px]"
            >
              {n}
            </Button>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function NextUpBox({
  nextSet,
  onStart,
  loading,
}: {
  nextSet: ProposedSet
  onStart: () => void
  loading: boolean
}) {
  return (
    <Card className="border-2 border-dashed border-muted-foreground/30">
      <CardContent className="pt-6 pb-4">
        <div className="text-center">
          <p className="text-sm text-muted-foreground mb-1">Next up</p>
          <p className="text-lg font-bold">
            {EXERCISE_NAMES[nextSet.exercise]}
            {nextSet.warmup && <span className="ml-2 text-xs bg-yellow-500/20 text-yellow-600 px-1.5 py-0.5 rounded">Warmup</span>}
          </p>
          <p className="text-muted-foreground">
            {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
          </p>
          <Button className="mt-3" onClick={onStart} disabled={loading}>
            Start Set
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

// --- Main WorkoutView ---

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

        // Restore rest timer
        const lastCompleted = response.completedSets
          .filter((c) => c.endedAt > 0n && c.restUntil > 0n)
          .sort((a, b) => Number(b.endedAt - a.endedAt))[0]
        if (lastCompleted) {
          const ru = Number(lastCompleted.restUntil)
          if (ru > Math.floor(Date.now() / 1000)) {
            setRestUntil(ru)
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

  // Clear rest timer when it expires
  useEffect(() => {
    if (!restUntil) return
    const remaining = restUntil - Math.floor(Date.now() / 1000)
    if (remaining <= 0) { setRestUntil(null); return }
    const timeout = setTimeout(() => setRestUntil(null), remaining * 1000)
    return () => clearTimeout(timeout)
  }, [restUntil])

  // --- derived state ---

  const isWorkoutEnded = workout ? workout.endTime > 0n : false

  const isSetDone = (setId: string) =>
    completedSets.some((c) => c.proposedSetId === setId && c.endedAt > 0n)

  // The active set is one that's been started but not completed
  const activeCompleted = completedSets.find((c) => c.endedAt === 0n)
  const activeProposed = activeCompleted
    ? proposedSets.find((p) => p.id === activeCompleted.proposedSetId)
    : undefined

  // Next set = first proposed set that isn't done and isn't active
  const nextSet = proposedSets.find(
    (p) => !isSetDone(p.id) && p.id !== activeProposed?.id
  )

  const groups = groupSetsByExercise(proposedSets)
  const completedCount = completedSets.filter((c) => c.endedAt > 0n).length

  // --- handlers ---

  const handleSetUpdated = (cs: CompletedSet) => {
    setCompletedSets((prev) => {
      const idx = prev.findIndex((c) => c.proposedSetId === cs.proposedSetId)
      if (idx >= 0) {
        const next = [...prev]
        next[idx] = cs
        return next
      }
      return [...prev, cs]
    })
    if (cs.endedAt > 0n && cs.restUntil > 0n) {
      setRestUntil(Number(cs.restUntil))
    }
  }

  const handleStartSet = async (proposedSetId: string) => {
    setLoading(true)
    setRestUntil(null) // clear rest if starting early
    try {
      const response = await workoutClient.startSet(
        { workoutId, proposedSetId },
        withUserId(userId)
      )
      if (response.completedSet) handleSetUpdated(response.completedSet)
    } catch (e) {
      console.error('Failed to start set:', e)
    } finally {
      setLoading(false)
    }
  }

  const handleCompleteSet = async (proposedSetId: string, reps: number) => {
    const proposed = proposedSets.find((p) => p.id === proposedSetId)
    try {
      const response = await workoutClient.completeSet(
        {
          workoutId,
          proposedSetId,
          actualReps: reps,
          actualWeight: proposed?.targetWeight || 0,
        },
        withUserId(userId)
      )
      if (response.completedSet) handleSetUpdated(response.completedSet)
    } catch (e) {
      console.error('Failed to complete set:', e)
    }
  }

  const handleStartNextEarly = () => {
    if (nextSet) handleStartSet(nextSet.id)
  }

  const handleMoveGroup = async (fromIndex: number, toIndex: number) => {
    const reordered = [...groups]
    const [moved] = reordered.splice(fromIndex, 1)
    reordered.splice(toIndex, 0, moved)

    let order = 0
    const newSets: ProposedSet[] = []
    for (const group of reordered) {
      for (const set of group.sets) {
        newSets.push(create(ProposedSetSchema, { ...set, workoutOrder: order++ }))
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
        { workoutId, proposedSets: [...proposedSets, newSet] },
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
      await workoutClient.endWorkout({ workoutId }, withUserId(userId))
      onBack()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to end workout')
    } finally {
      setLoading(false)
    }
  }

  // --- render ---

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-3">
        {/* Header */}
        <div className="flex items-center justify-between">
          <Button variant="ghost" size="sm" onClick={onBack}>
            &larr; Back
          </Button>
          <div className="flex items-center gap-3">
            {workout && !isWorkoutEnded && (
              <WorkoutElapsedTimer startTime={workout.startTime} />
            )}
            {isWorkoutEnded && workout && (
              <span className="text-sm text-muted-foreground">
                {formatElapsed(Number(workout.endTime - workout.startTime))}
              </span>
            )}
            <span className="text-xs text-muted-foreground">
              {completedCount}/{proposedSets.length}
            </span>
            {!isWorkoutEnded && (
              <Button variant="destructive" size="sm" onClick={handleEndWorkout} disabled={loading}>
                End
              </Button>
            )}
          </div>
        </div>

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-3 py-2 rounded-md text-sm">
            {error}
          </div>
        )}

        {/* Active Box — the one interactive element */}
        {!isWorkoutEnded && (
          <>
            {activeProposed && activeCompleted ? (
              // Currently doing a set
              <ActiveSetBox
                proposedSet={activeProposed}
                completedSet={activeCompleted}
                onComplete={(reps) => handleCompleteSet(activeProposed.id, reps)}
              />
            ) : restUntil && restUntil > Math.floor(Date.now() / 1000) ? (
              // Resting
              <RestingBox
                restUntil={restUntil}
                nextSet={nextSet}
                onStartEarly={handleStartNextEarly}
              />
            ) : nextSet ? (
              // Ready for next set
              <NextUpBox
                nextSet={nextSet}
                onStart={() => handleStartSet(nextSet.id)}
                loading={loading}
              />
            ) : (
              // All sets done
              <Card className="border-2 border-green-500/50 bg-green-500/5">
                <CardContent className="pt-6 pb-4 text-center">
                  <p className="text-lg font-bold text-green-600">All sets complete!</p>
                  <Button variant="destructive" className="mt-3" onClick={handleEndWorkout}>
                    End Workout
                  </Button>
                </CardContent>
              </Card>
            )}
          </>
        )}

        {/* Compact exercise groups */}
        <div className="space-y-1">
          {groups.map((group, idx) => (
            <ExerciseGroup
              key={`${group.exercise}-${idx}`}
              group={group}
              groupIndex={idx}
              totalGroups={groups.length}
              completedSets={completedSets}
              activeSetId={activeProposed?.id}
              isWorkoutEnded={isWorkoutEnded}
              onMoveUp={() => handleMoveGroup(idx, idx - 1)}
              onMoveDown={() => handleMoveGroup(idx, idx + 1)}
            />
          ))}
        </div>

        {/* Add new set */}
        {!isWorkoutEnded && (
          <Card>
            <CardHeader className="pb-2 pt-4">
              <CardTitle className="text-sm">Add Set</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 pb-4">
              <div className="grid grid-cols-4 gap-2">
                <div className="col-span-2">
                  <select
                    className="w-full p-2 border rounded-md bg-background text-sm"
                    value={newSetExercise}
                    onChange={(e) => setNewSetExercise(Number(e.target.value) as Exercise)}
                  >
                    <option value={Exercise.SQUAT}>Squat</option>
                    <option value={Exercise.BENCH_PRESS}>Bench Press</option>
                    <option value={Exercise.DEADLIFT}>Deadlift</option>
                    <option value={Exercise.OVERHEAD_PRESS}>OHP</option>
                    <option value={Exercise.BARBELL_ROW}>Row</option>
                  </select>
                </div>
                <Input
                  type="number"
                  value={newSetReps}
                  onChange={(e) => setNewSetReps(Number(e.target.value))}
                  placeholder="Reps"
                  className="text-sm"
                />
                <Input
                  type="number"
                  value={newSetWeight}
                  onChange={(e) => setNewSetWeight(Number(e.target.value))}
                  placeholder="Weight"
                  className="text-sm"
                />
              </div>
              <div className="flex items-center justify-between">
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={newSetWarmup}
                    onChange={(e) => setNewSetWarmup(e.target.checked)}
                    className="rounded"
                  />
                  Warmup
                </label>
                <Button size="sm" onClick={handleAddSet} disabled={loading}>
                  {loading ? 'Adding...' : 'Add'}
                </Button>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  )
}

function WorkoutElapsedTimer({ startTime }: { startTime: bigint }) {
  const elapsed = useElapsed(Number(startTime))
  return <span className="font-mono text-lg">{formatElapsed(elapsed)}</span>
}
