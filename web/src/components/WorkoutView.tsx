import { useState, useEffect, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
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

const SHORT_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench',
  [Exercise.DEADLIFT]: 'Dead',
  [Exercise.OVERHEAD_PRESS]: 'OHP',
  [Exercise.BARBELL_ROW]: 'Row',
}

// --- timer hooks ---

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

function fmtElapsed(secs: number) {
  const h = Math.floor(secs / 3600)
  const m = Math.floor((secs % 3600) / 60)
  const s = secs % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

function fmtTime(ts: bigint | number) {
  if (!ts) return ''
  return new Date(Number(ts) * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

// --- Active box sub-components ---

function RestingBox({ restUntil, nextSet, onStartEarly }: {
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
              Up next: {EXERCISE_NAMES[nextSet.exercise]} {nextSet.targetReps}&times;{nextSet.targetWeight}lbs
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

function ActiveSetBox({ proposedSet, completedSet, onComplete }: {
  proposedSet: ProposedSet
  completedSet: CompletedSet
  onComplete: (reps: number) => void
}) {
  const elapsed = useElapsed(Number(completedSet.startedAt))
  const [loading, setLoading] = useState(false)
  const maxReps = proposedSet.targetReps
  const buttons = Array.from({ length: maxReps + 1 }, (_, i) => i)

  return (
    <Card className="border-2 border-primary">
      <CardContent className="pt-6 pb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm text-muted-foreground">
            {EXERCISE_NAMES[proposedSet.exercise]}
            {proposedSet.warmup && ' (Warmup)'}
          </span>
          <span className="font-mono text-muted-foreground">{fmtElapsed(elapsed)}</span>
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
              onClick={() => { setLoading(true); onComplete(n) }}
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

const CHAT_MESSAGES = [
  "The barbell misses you...",
  "Your gains are evaporating ☁️",
  "Less yapping, more repping!",
  "The weights aren't gonna lift themselves",
  "Sir, this is a gym",
  "Your muscles are falling asleep 😴",
  "Chat time's over... any minute now",
  "The squat rack is judging you",
]

function ChatTimeBox({ restEndedAt, nextSet, onStart, loading }: {
  restEndedAt: number
  nextSet: ProposedSet
  onStart: () => void
  loading: boolean
}) {
  const elapsed = useElapsed(restEndedAt)
  const [message] = useState(() => CHAT_MESSAGES[Math.floor(Math.random() * CHAT_MESSAGES.length)])

  return (
    <Card className="border-2 border-orange-500/50 bg-orange-500/5">
      <CardContent className="pt-6 pb-4">
        <div className="text-center">
          <p className="text-sm text-muted-foreground mb-1">💬 Chat Time</p>
          <p className="text-4xl font-bold font-mono text-orange-500">
            {fmtElapsed(elapsed)}
          </p>
          <p className="text-sm text-muted-foreground mt-2 italic">
            {message}
          </p>
          <div className="mt-3">
            <p className="text-xs text-muted-foreground mb-1">
              Next: {EXERCISE_NAMES[nextSet.exercise]} {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
            </p>
            <Button onClick={onStart} disabled={loading}>Start Set</Button>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function NextUpBox({ nextSet, onStart, loading }: {
  nextSet: ProposedSet; onStart: () => void; loading: boolean
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
          <Button className="mt-3" onClick={onStart} disabled={loading}>Start Set</Button>
        </div>
      </CardContent>
    </Card>
  )
}

// --- Add Set Modal ---

function AddSetModal({ onAdd, onClose, loading }: {
  onAdd: (exercise: Exercise, reps: number, weight: number, warmup: boolean) => void
  onClose: () => void
  loading: boolean
}) {
  const [exercise, setExercise] = useState<Exercise>(Exercise.SQUAT)
  const [reps, setReps] = useState(5)
  const [weight, setWeight] = useState(135)
  const [warmup, setWarmup] = useState(false)

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <Card className="w-full max-w-sm" onClick={(e) => e.stopPropagation()}>
        <CardContent className="pt-6 space-y-3">
          <div className="flex items-center justify-between mb-2">
            <span className="font-bold">Add Set</span>
            <button onClick={onClose} className="text-muted-foreground hover:text-foreground">&times;</button>
          </div>
          <select
            className="w-full p-2 border rounded-md bg-background text-sm"
            value={exercise}
            onChange={(e) => setExercise(Number(e.target.value) as Exercise)}
          >
            <option value={Exercise.SQUAT}>Squat</option>
            <option value={Exercise.BENCH_PRESS}>Bench Press</option>
            <option value={Exercise.DEADLIFT}>Deadlift</option>
            <option value={Exercise.OVERHEAD_PRESS}>OHP</option>
            <option value={Exercise.BARBELL_ROW}>Row</option>
          </select>
          <div className="grid grid-cols-2 gap-2">
            <Input type="number" value={reps} onChange={(e) => setReps(Number(e.target.value))} placeholder="Reps" />
            <Input type="number" value={weight} onChange={(e) => setWeight(Number(e.target.value))} placeholder="Weight" />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={warmup} onChange={(e) => setWarmup(e.target.checked)} className="rounded" />
            Warmup
          </label>
          <Button className="w-full" onClick={() => onAdd(exercise, reps, weight, warmup)} disabled={loading}>
            {loading ? 'Adding...' : 'Add'}
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}

// --- Completed workout timeline ---

function CompletedWorkoutView({ workout, proposedSets, completedSets, onBack }: {
  workout: Workout
  proposedSets: ProposedSet[]
  completedSets: CompletedSet[]
  onBack: () => void
}) {
  const totalDuration = Number(workout.endTime - workout.startTime)
  const workoutStart = Number(workout.startTime)

  // Build timeline entries sorted by startedAt
  const entries = completedSets
    .filter((c) => c.endedAt > 0n)
    .map((c) => {
      const proposed = proposedSets.find((p) => p.id === c.proposedSetId)
      return { completed: c, proposed }
    })
    .sort((a, b) => Number(a.completed.startedAt - b.completed.startedAt))

  // Compute total chat time: gap between rest_until and next set's startedAt
  let totalChatTime = 0
  for (let i = 0; i < entries.length - 1; i++) {
    const current = entries[i].completed
    const next = entries[i + 1].completed
    if (current.restUntil > 0n) {
      const gap = Number(next.startedAt) - Number(current.restUntil)
      if (gap > 0) totalChatTime += gap
    }
  }

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-3">
        <div className="flex items-center justify-between">
          <Button variant="ghost" size="sm" onClick={onBack}>&larr; Back</Button>
          <span className="text-sm text-muted-foreground">
            {fmtElapsed(totalDuration)}
          </span>
        </div>

        <div className="text-center py-2">
          <h2 className="text-xl font-bold">{workout.name || 'Workout'}</h2>
          <p className="text-sm text-muted-foreground">
            {new Date(Number(workout.startTime) * 1000).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}
            {' '}{fmtTime(workout.startTime)} &ndash; {fmtTime(workout.endTime)}
          </p>
          {totalChatTime > 0 && (
            <p className="text-sm mt-1">
              <span className="inline-flex items-center gap-1 rounded-full bg-orange-500/10 text-orange-500 px-2.5 py-0.5 text-xs font-medium">
                💬 {fmtElapsed(totalChatTime)} chat time
              </span>
            </p>
          )}
        </div>

        {/* Timeline bar */}
        {totalDuration > 0 && (
          <div className="relative h-8 bg-muted rounded-full overflow-hidden">
            {entries.map((e, i) => {
              const start = Number(e.completed.startedAt) - workoutStart
              const end = Number(e.completed.endedAt) - workoutStart
              const left = (start / totalDuration) * 100
              const width = Math.max(((end - start) / totalDuration) * 100, 0.5)
              const hitTarget = e.proposed && e.completed.actualReps >= e.proposed.targetReps
              return (
                <div
                  key={i}
                  className={`absolute top-0 h-full ${hitTarget ? 'bg-green-500' : 'bg-yellow-500'}`}
                  style={{ left: `${left}%`, width: `${width}%` }}
                  title={e.proposed ? `${EXERCISE_NAMES[e.proposed.exercise]} ${e.completed.actualReps}×${e.completed.actualWeight}` : ''}
                />
              )
            })}
          </div>
        )}

        {/* Summary by exercise */}
        <div className="grid grid-cols-2 gap-2">
          {groupSetsByExercise(proposedSets).map((group, i) => {
            const done = group.sets.filter((s) =>
              completedSets.some((c) => c.proposedSetId === s.id && c.endedAt > 0n)
            ).length
            return (
              <div key={i} className="bg-muted rounded-md px-3 py-2 text-sm">
                <span className="font-medium">{SHORT_NAMES[group.exercise]}</span>
                <span className="text-muted-foreground ml-1">{done}/{group.sets.length}</span>
                <span className="text-muted-foreground ml-1">@ {group.sets[0]?.targetWeight}lbs</span>
              </div>
            )
          })}
        </div>

        {/* Set-by-set log */}
        <div className="space-y-0.5">
          <div className="text-xs text-muted-foreground px-2 grid grid-cols-[1fr_3.5rem_3.5rem_3rem] gap-1">
            <span>Exercise</span>
            <span>Start</span>
            <span>End</span>
            <span className="text-right">Result</span>
          </div>
          {entries.map((e, i) => {
            const hitTarget = e.proposed && e.completed.actualReps >= e.proposed.targetReps
            return (
              <div
                key={i}
                className={`text-xs px-2 py-1 rounded grid grid-cols-[1fr_3.5rem_3.5rem_3rem] gap-1 items-center ${
                  hitTarget ? 'bg-green-500/5' : 'bg-yellow-500/5'
                }`}
              >
                <span className="font-medium truncate">
                  {e.proposed ? SHORT_NAMES[e.proposed.exercise] : '?'}
                  {e.proposed?.warmup && <span className="text-yellow-600 ml-1">W</span>}
                </span>
                <span className="text-muted-foreground font-mono">
                  {fmtTime(e.completed.startedAt)}
                </span>
                <span className="text-muted-foreground font-mono">
                  {fmtTime(e.completed.endedAt)}
                </span>
                <span className={`text-right font-medium ${hitTarget ? 'text-green-600' : 'text-yellow-600'}`}>
                  {e.completed.actualReps}&times;{e.completed.actualWeight}
                </span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

// --- Set History (live workout) ---

function SetLog({ completedSets, proposedSets }: {
  completedSets: CompletedSet[]
  proposedSets: ProposedSet[]
}) {
  const done = completedSets
    .filter((c) => c.endedAt > 0n)
    .sort((a, b) => Number(a.endedAt - b.endedAt))

  if (done.length === 0) return null

  return (
    <div className="space-y-0.5">
      <div className="text-xs text-muted-foreground font-medium px-1 mb-1">Set Log</div>
      {done.map((c, i) => {
        const proposed = proposedSets.find((p) => p.id === c.proposedSetId)
        const setDur = Number(c.endedAt - c.startedAt)
        const hitTarget = proposed && c.actualReps >= proposed.targetReps
        return (
          <div
            key={i}
            className={`text-xs px-2 py-1 rounded flex items-center gap-2 ${
              hitTarget ? 'bg-green-500/5' : 'bg-yellow-500/5'
            }`}
          >
            <span className="font-medium w-12 shrink-0 truncate">
              {proposed ? SHORT_NAMES[proposed.exercise] : '?'}
            </span>
            <span className={`font-medium ${hitTarget ? 'text-green-600' : 'text-yellow-600'}`}>
              {c.actualReps}&times;{c.actualWeight}
            </span>
            <span className="text-muted-foreground font-mono ml-auto">
              {fmtElapsed(setDur)}
            </span>
            <span className="text-muted-foreground font-mono">
              {fmtTime(c.endedAt)}
            </span>
          </div>
        )
      })}
    </div>
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
  const [restEndedAt, setRestEndedAt] = useState<number | null>(null)
  const [showAddModal, setShowAddModal] = useState(false)

  const loadWorkout = useCallback(async () => {
    try {
      const response = await workoutClient.getWorkout({ workoutId }, withUserId(userId))
      if (response.workout) {
        setWorkout(response.workout)
        setProposedSets(response.proposedSets)
        setCompletedSets(response.completedSets)

        const lastCompleted = response.completedSets
          .filter((c) => c.endedAt > 0n && c.restUntil > 0n)
          .sort((a, b) => Number(b.endedAt - a.endedAt))[0]
        if (lastCompleted) {
          const ru = Number(lastCompleted.restUntil)
          if (ru > Math.floor(Date.now() / 1000)) setRestUntil(ru)
        }
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load workout')
    }
  }, [workoutId, userId])

  useEffect(() => { loadWorkout() }, [loadWorkout])

  // Transition from rest → chat time when rest expires
  useEffect(() => {
    if (!restUntil) return
    const remaining = restUntil - Math.floor(Date.now() / 1000)
    if (remaining <= 0) {
      setRestEndedAt(restUntil)
      setRestUntil(null)
      return
    }
    const timeout = setTimeout(() => {
      setRestEndedAt(restUntil)
      setRestUntil(null)
    }, remaining * 1000)
    return () => clearTimeout(timeout)
  }, [restUntil])

  // --- derived ---
  const isWorkoutEnded = workout ? workout.endTime > 0n : false

  const isSetDone = (setId: string) =>
    completedSets.some((c) => c.proposedSetId === setId && c.endedAt > 0n)

  const activeCompleted = completedSets.find((c) => c.endedAt === 0n)
  const activeProposed = activeCompleted
    ? proposedSets.find((p) => p.id === activeCompleted.proposedSetId)
    : undefined

  const nextSet = proposedSets.find(
    (p) => !isSetDone(p.id) && p.id !== activeProposed?.id
  )

  const allSetsDone = proposedSets.length > 0 &&
    proposedSets.every((p) => isSetDone(p.id)) &&
    !activeCompleted

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
    setRestUntil(null)
    setRestEndedAt(null)
    try {
      const response = await workoutClient.startSet({ workoutId, proposedSetId }, withUserId(userId))
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
      const response = await workoutClient.completeSet({
        workoutId,
        proposedSetId,
        actualReps: reps,
        actualWeight: proposed?.targetWeight || 0,
      }, withUserId(userId))
      if (response.completedSet) handleSetUpdated(response.completedSet)
    } catch (e) {
      console.error('Failed to complete set:', e)
    }
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
        { workoutId, proposedSets: newSets }, withUserId(userId))
      setProposedSets(response.proposedSets)
    } catch (e) {
      console.error('Failed to reorder:', e)
    }
  }

  const handleAddSet = async (exercise: Exercise, reps: number, weight: number, warmup: boolean) => {
    setLoading(true)
    try {
      const newSet = create(ProposedSetSchema, {
        exercise, targetReps: reps, targetWeight: weight, warmup,
        workoutOrder: proposedSets.length,
      })
      const response = await workoutClient.modifyProposedSets(
        { workoutId, proposedSets: [...proposedSets, newSet] }, withUserId(userId))
      setProposedSets(response.proposedSets)
      setShowAddModal(false)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to add set')
    } finally {
      setLoading(false)
    }
  }

  const handleEndWorkout = async () => {
    setLoading(true)
    try {
      const response = await workoutClient.endWorkout({ workoutId }, withUserId(userId))
      if (response.workout) setWorkout(response.workout)
      await loadWorkout()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to end workout')
    } finally {
      setLoading(false)
    }
  }

  // --- render ---

  // Completed workout → show timeline view
  if (isWorkoutEnded && workout) {
    return (
      <CompletedWorkoutView
        workout={workout}
        proposedSets={proposedSets}
        completedSets={completedSets}
        onBack={onBack}
      />
    )
  }

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-3">
        {/* Header */}
        <div className="flex items-center justify-between">
          <Button variant="ghost" size="sm" onClick={onBack}>&larr; Back</Button>
          <div className="flex items-center gap-3">
            {workout && <WorkoutElapsedTimer startTime={workout.startTime} />}
            <span className="text-xs text-muted-foreground">{completedCount}/{proposedSets.length}</span>
            <Button variant="destructive" size="sm" onClick={handleEndWorkout} disabled={loading}>End</Button>
          </div>
        </div>

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-3 py-2 rounded-md text-sm">
            {error}
          </div>
        )}

        {/* Active Box */}
        {activeProposed && activeCompleted ? (
          <ActiveSetBox
            proposedSet={activeProposed}
            completedSet={activeCompleted}
            onComplete={(reps) => handleCompleteSet(activeProposed.id, reps)}
          />
        ) : allSetsDone ? (
          <Card className="border-2 border-green-500/50 bg-green-500/5">
            <CardContent className="pt-6 pb-4 text-center">
              <p className="text-lg font-bold text-green-600">All sets complete!</p>
              <p className="text-sm text-muted-foreground mt-1">Nice work. End your workout?</p>
              <div className="flex gap-2 justify-center mt-3">
                <Button onClick={handleEndWorkout} disabled={loading}>Finish Workout</Button>
                <Button variant="outline" onClick={() => setShowAddModal(true)}>Add More Sets</Button>
              </div>
            </CardContent>
          </Card>
        ) : restUntil && restUntil > Math.floor(Date.now() / 1000) ? (
          <RestingBox
            restUntil={restUntil}
            nextSet={nextSet}
            onStartEarly={() => nextSet && handleStartSet(nextSet.id)}
          />
        ) : restEndedAt && nextSet ? (
          <ChatTimeBox
            restEndedAt={restEndedAt}
            nextSet={nextSet}
            onStart={() => handleStartSet(nextSet.id)}
            loading={loading}
          />
        ) : nextSet ? (
          <NextUpBox nextSet={nextSet} onStart={() => handleStartSet(nextSet.id)} loading={loading} />
        ) : null}

        {/* Compact exercise groups + add button */}
        <div className="space-y-1">
          {groups.map((group, idx) => (
            <ExerciseGroup
              key={`${group.exercise}-${idx}`}
              group={group}
              groupIndex={idx}
              totalGroups={groups.length}
              completedSets={completedSets}
              activeSetId={activeProposed?.id}
              isWorkoutEnded={false}
              onMoveUp={() => handleMoveGroup(idx, idx - 1)}
              onMoveDown={() => handleMoveGroup(idx, idx + 1)}
            />
          ))}
          {/* + button */}
          <button
            onClick={() => setShowAddModal(true)}
            className="w-full py-1.5 rounded-md border border-dashed border-muted-foreground/30 text-muted-foreground hover:text-foreground hover:border-foreground/30 text-sm transition-colors"
          >
            + Add Exercise
          </button>
        </div>

        {/* Set log */}
        {workout && (
          <SetLog
            completedSets={completedSets}
            proposedSets={proposedSets}
          />
        )}

        {/* Add set modal */}
        {showAddModal && (
          <AddSetModal
            onAdd={handleAddSet}
            onClose={() => setShowAddModal(false)}
            loading={loading}
          />
        )}
      </div>
    </div>
  )
}

function WorkoutElapsedTimer({ startTime }: { startTime: bigint }) {
  const elapsed = useElapsed(Number(startTime))
  return <span className="font-mono text-lg">{fmtElapsed(elapsed)}</span>
}
