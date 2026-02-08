import { useState, useEffect, useCallback, useMemo } from 'react'
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
import { Pencil, Users } from 'lucide-react'
import { MultiplayerModal } from './MultiplayerModal'

import { useMultiplayer } from '@/hooks/useMultiplayer'
import { ParticipantTicker } from './ParticipantTicker'

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

function RestingBox({ restUntil, nextSet, onStartEarly, onEditWeight }: {
  restUntil: number
  nextSet?: ProposedSet
  onStartEarly: () => void
  onEditWeight?: () => void
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
              Up next: {EXERCISE_NAMES[nextSet.exercise as Exercise]} {nextSet.targetReps}&times;{nextSet.targetWeight}lbs
              {onEditWeight && (
                <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
                  <Pencil className="w-3.5 h-3.5" />
                </button>
              )}
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

function ActiveSetBox({ proposedSet, completedSet, onComplete, onEditWeight }: {
  proposedSet: ProposedSet
  completedSet: CompletedSet
  onComplete: (reps: number) => void
  onEditWeight: () => void
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
            {EXERCISE_NAMES[proposedSet.exercise as Exercise]}
            {proposedSet.warmup && ' (Warmup)'}
          </span>
          <span className="font-mono text-muted-foreground">{fmtElapsed(elapsed)}</span>
        </div>
        <div className="text-center mb-4">
          <div className="text-3xl font-bold">
            {proposedSet.targetWeight} lbs
            <button onClick={onEditWeight} className="ml-2 inline-flex align-middle text-muted-foreground hover:text-foreground">
              <Pencil className="w-4 h-4" />
            </button>
          </div>
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

function ChatTimeBox({ restEndedAt, nextSet, onStart, loading, onEditWeight }: {
  restEndedAt: number
  nextSet: ProposedSet
  onStart: () => void
  loading: boolean
  onEditWeight: () => void
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
              Next: {EXERCISE_NAMES[nextSet.exercise as Exercise]} {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
              <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
                <Pencil className="w-3.5 h-3.5" />
              </button>
            </p>
            <Button onClick={onStart} disabled={loading}>Start Set</Button>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function NextUpBox({ nextSet, onStart, loading, onEditWeight }: {
  nextSet: ProposedSet; onStart: () => void; loading: boolean; onEditWeight: () => void
}) {
  return (
    <Card className="border-2 border-dashed border-muted-foreground/30">
      <CardContent className="pt-6 pb-4">
        <div className="text-center">
          <p className="text-sm text-muted-foreground mb-1">Next up</p>
          <p className="text-lg font-bold">
            {EXERCISE_NAMES[nextSet.exercise as Exercise]}
            {nextSet.warmup && <span className="ml-2 text-xs bg-yellow-500/20 text-yellow-600 px-1.5 py-0.5 rounded">Warmup</span>}
          </p>
          <p className="text-muted-foreground">
            {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
            <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
              <Pencil className="w-3.5 h-3.5" />
            </button>
          </p>
          <Button className="mt-3" onClick={onStart} disabled={loading}>Start Set</Button>
        </div>
      </CardContent>
    </Card>
  )
}

// --- Plate Calculator Modal ---

function PlateCalculatorModal({ weight, onSave, onClose }: {
  weight: number
  onSave: (weight: number) => void
  onClose: () => void
}) {
  const [value, setValue] = useState(weight)
  const snap = (v: number) => Math.round(v / 5) * 5
  const clamped = Math.max(45, Math.min(500, value))

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <Card className="w-full max-w-sm" onClick={(e) => e.stopPropagation()}>
        <CardContent className="pt-6 space-y-4">
          <div className="flex items-center justify-between mb-1">
            <span className="font-bold">Edit Weight</span>
            <button onClick={onClose} className="text-muted-foreground hover:text-foreground text-xl leading-none">&times;</button>
          </div>
          <Input
            type="number"
            value={clamped}
            onChange={(e) => setValue(snap(Number(e.target.value)))}
            className="text-3xl font-bold text-center h-14 text-foreground"
            min={45}
            max={500}
            step={5}
          />
          <div className="flex gap-2">
            <Button variant="outline" className="flex-1" onClick={onClose}>Cancel</Button>
            <Button className="flex-1" onClick={() => onSave(clamped)}>Save</Button>
          </div>
        </CardContent>
      </Card>
    </div>
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

// --- Completed workout view ---

function CompletedWorkoutView({ workout, proposedSets, completedSets, onBack }: {
  workout: Workout
  proposedSets: ProposedSet[]
  completedSets: CompletedSet[]
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
          <Button variant="ghost" size="sm" onClick={onBack}>&larr; Back</Button>
          <span className="text-sm text-muted-foreground">{fmtElapsed(totalDuration)}</span>
        </div>
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

// --- Set History ---

function SetLog({ completedSets, proposedSets }: {
  completedSets: CompletedSet[]
  proposedSets: ProposedSet[]
}) {
  const done = completedSets
    .filter((c) => c.endedAt > 0n)
    .sort((a, b) => Number(b.endedAt - a.endedAt))

  if (done.length === 0) return null

  return (
    <div className="space-y-0.5">
      <div className="text-xs text-muted-foreground font-medium px-1 mb-1">Set Log</div>
      {done.map((c, i) => {
        const proposed = proposedSets.find((p) => p.id === c.proposedSetId)
        return (
          <div key={i} className="text-xs px-2 py-1 rounded flex items-center gap-2 bg-muted/50">
            <span className="font-medium w-12 shrink-0 truncate">{proposed ? SHORT_NAMES[proposed.exercise as Exercise] : '?'}</span>
            <span className="font-medium">{c.actualReps}&times;{c.actualWeight}</span>
            <span className="text-muted-foreground font-mono ml-auto">{fmtTime(c.endedAt)}</span>
          </div>
        )
      })}
    </div>
  )
}

// --- Multiplayer Components ---

function ActiveSummaryOverlay({ proposedSet, completedSet }: { proposedSet: ProposedSet; completedSet: CompletedSet }) {
  const elapsed = useElapsed(Number(completedSet.startedAt))
  return (
    <div className="fixed bottom-4 left-4 right-4 z-40">
      <Card className="border-2 border-primary bg-background/95 backdrop-blur shadow-lg">
        <CardContent className="py-3 px-4 flex items-center justify-between">
          <div className="min-w-0">
            <p className="text-[10px] font-bold uppercase text-primary tracking-wider">Your Active Set</p>
            <p className="font-bold text-sm truncate">
              {EXERCISE_NAMES[proposedSet.exercise as Exercise]} &middot; {proposedSet.targetWeight}lbs
            </p>
          </div>
          <div className="flex items-center gap-3 ml-4">
             <div className="text-right">
               <p className="text-xl font-bold leading-none">{proposedSet.targetReps}</p>
               <p className="text-[10px] text-muted-foreground uppercase">reps</p>
             </div>
             <div className="w-px h-8 bg-border" />
             <span className="font-mono font-bold text-primary">{fmtElapsed(elapsed)}</span>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

function WorkoutElapsedTimer({ startTime }: { startTime: bigint }) {
  const elapsed = useElapsed(Number(startTime))
  return <span className="font-mono text-lg">{fmtElapsed(elapsed)}</span>
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
  const [restUntil, setRestUntil] = useState<number | null>(null)
  const [restEndedAt, setRestEndedAt] = useState<number | null>(null)
  const [showAddModal, setShowAddModal] = useState(false)
  const [editingSetId, setEditingSetId] = useState<string | null>(null)
  
  // Multiplayer state
  const sessionStatus = useMultiplayer(userId)
  const [peepUserId, setPeepUserId] = useState<string | null>(null)
  const [showMultiplayerModal, setShowMultiplayerModal] = useState(false)

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
      console.error('Failed to load workout:', e)
    }
  }, [workoutId, userId])

  useEffect(() => {
    loadWorkout()
  }, [loadWorkout, userId])

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
  const isSetDone = (setId: string) => completedSets.some((c) => c.proposedSetId === setId && c.endedAt > 0n)
  const activeCompleted = completedSets.find((c) => c.endedAt === 0n)
  const activeProposed = activeCompleted ? proposedSets.find((p) => p.id === activeCompleted.proposedSetId) : undefined
  const nextSet = proposedSets.find((p) => !isSetDone(p.id) && p.id !== activeProposed?.id)
  const allSetsDone = proposedSets.length > 0 && proposedSets.every((p) => isSetDone(p.id)) && !activeCompleted

  // Peep data
  const peepParticipant = useMemo(() => {
    if (!peepUserId || !sessionStatus) return null
    return sessionStatus.participants.find(p => p.user?.id === peepUserId)
  }, [peepUserId, sessionStatus])

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
    if (cs.endedAt > 0n && cs.restUntil > 0n) setRestUntil(Number(cs.restUntil))
  }

  const handleStartSet = async (proposedSetId: string) => {
    setLoading(true); setRestUntil(null); setRestEndedAt(null)
    try {
      const response = await workoutClient.startSet({ workoutId, proposedSetId }, withUserId(userId))
      if (response.completedSet) handleSetUpdated(response.completedSet)
    } catch (e) { console.error(e) } finally { setLoading(false) }
  }

  const handleCompleteSet = async (proposedSetId: string, reps: number) => {
    const proposed = proposedSets.find((p) => p.id === proposedSetId)
    try {
      const response = await workoutClient.completeSet({
        workoutId, proposedSetId, actualReps: reps, actualWeight: proposed?.targetWeight || 0,
      }, withUserId(userId))
      if (response.completedSet) handleSetUpdated(response.completedSet)
    } catch (e) { console.error(e) }
  }

  const handleUpdateWeight = (setId: string, newWeight: number) => {
    const updatedSets = proposedSets.map((s) => s.id === setId || (s.exercise === proposedSets.find(p => p.id === setId)?.exercise && !isSetDone(s.id))
      ? create(ProposedSetSchema, { ...s, targetWeight: newWeight }) : s)
    setProposedSets(updatedSets); setEditingSetId(null)
    workoutClient.modifyProposedSets({ workoutId, proposedSets: updatedSets }, withUserId(userId))
      .then((res) => setProposedSets(res.proposedSets)).catch(console.error)
  }

  const handleEndWorkout = async () => {
    setLoading(true)
    try {
      const response = await workoutClient.endWorkout({ workoutId }, withUserId(userId))
      if (response.workout) setWorkout(response.workout); await loadWorkout()
    } catch (e) { console.error(e) } finally { setLoading(false) }
  }

  if (isWorkoutEnded && workout) return <CompletedWorkoutView workout={workout} proposedSets={proposedSets} completedSets={completedSets} onBack={onBack} />

  return (
    <div className="min-h-screen bg-background p-4 pb-24">
      <div className="max-w-2xl mx-auto space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <Button variant="ghost" size="sm" onClick={onBack}>&larr; Back</Button>
          <div className="flex items-center gap-2">
            {workout && <WorkoutElapsedTimer startTime={workout.startTime} />}
            <Button variant="ghost" size="icon" onClick={() => setShowMultiplayerModal(true)}>
              <Users className={`w-5 h-5 ${sessionStatus ? 'text-primary' : ''}`} />
            </Button>
            <Button variant="destructive" size="sm" onClick={handleEndWorkout} disabled={loading}>End</Button>
          </div>
        </div>

        {/* Multiplayer Chips */}
        <div className="bg-muted/30 rounded-xl p-3 border border-border/50">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Workout Session</span>
            {sessionStatus && (
              <span className="text-[10px] font-mono text-muted-foreground bg-background px-1.5 py-0.5 rounded border">
                ID: {sessionStatus.sessionId}
              </span>
            )}
          </div>
          <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar min-h-[40px] items-center">
            {sessionStatus && sessionStatus.participants.length > 1 ? (
              sessionStatus.participants.filter(p => p.user?.id !== userId).map((p) => (
                <ParticipantTicker 
                  key={p.user?.id} 
                  status={p} 
                  isPeeping={peepUserId === p.user?.id}
                  onPeep={() => setPeepUserId(peepUserId === p.user?.id ? null : p.user?.id || null)}
                />
              ))
            ) : (
              <p className="text-xs text-muted-foreground italic">No other participants yet. Share your session to invite friends!</p>
            )}
          </div>
        </div>

        {/* Main View (Peep or Self) */}
        {peepParticipant ? (
          <div className="space-y-4">
            <div className="flex items-center justify-between bg-primary/5 p-3 rounded-lg border border-primary/20">
              <span className="text-sm font-bold text-primary">Viewing {peepParticipant.user?.name}'s Workout</span>
              <Button size="sm" variant="ghost" onClick={() => setPeepUserId(null)}>Close</Button>
            </div>
            
            {peepParticipant.currentSet ? (
              <Card className="border-2 border-primary/50">
                <CardContent className="pt-6 pb-4 text-center">
                  <p className="text-sm text-muted-foreground mb-1">{peepParticipant.isResting ? 'Next Set' : 'Currently Doing'}</p>
                  <p className="text-2xl font-bold">{EXERCISE_NAMES[peepParticipant.currentSet.exercise as Exercise]}</p>
                  <p className="text-4xl font-bold text-primary">{peepParticipant.currentSet.targetReps} &times; {peepParticipant.currentSet.targetWeight} lbs</p>
                  {peepParticipant.isResting && (
                    <div className="mt-4 pt-4 border-t">
                       <p className="text-xs text-muted-foreground">Rest ends at {fmtTime(peepParticipant.restUntil)}</p>
                    </div>
                  )}
                </CardContent>
              </Card>
            ) : (
               <Card><CardContent className="py-12 text-center text-muted-foreground">User is not currently doing a set.</CardContent></Card>
            )}

            <div className="opacity-60 pointer-events-none scale-95 origin-top transition-all">
               <ExerciseGroupsList proposedSets={peepParticipant.proposedSets} completedSets={peepParticipant.completedSets} />
            </div>
          </div>
        ) : (
          <>
            {/* Active Box (Self) */}
            {activeProposed && activeCompleted ? (
              <ActiveSetBox proposedSet={activeProposed} completedSet={activeCompleted} onComplete={(reps) => handleCompleteSet(activeProposed.id, reps)} onEditWeight={() => setEditingSetId(activeProposed.id)} />
            ) : allSetsDone ? (
              <Card className="border-2 border-green-500/50 bg-green-500/5"><CardContent className="pt-6 pb-4 text-center"><p className="text-lg font-bold text-green-600">All sets complete!</p><Button onClick={handleEndWorkout} className="mt-3">Finish Workout</Button></CardContent></Card>
            ) : restUntil && restUntil > Math.floor(Date.now() / 1000) ? (
              <RestingBox restUntil={restUntil} nextSet={nextSet} onStartEarly={() => nextSet && handleStartSet(nextSet.id)} onEditWeight={nextSet ? () => setEditingSetId(nextSet.id) : undefined} />
            ) : restEndedAt && nextSet ? (
              <ChatTimeBox restEndedAt={restEndedAt} nextSet={nextSet} onStart={() => handleStartSet(nextSet.id)} loading={loading} onEditWeight={() => setEditingSetId(nextSet.id)} />
            ) : nextSet ? (
              <NextUpBox nextSet={nextSet} onStart={() => handleStartSet(nextSet.id)} loading={loading} onEditWeight={() => setEditingSetId(nextSet.id)} />
            ) : null}

            <ExerciseGroupsList 
              proposedSets={proposedSets} 
              completedSets={completedSets} 
              activeSetId={activeProposed?.id}
              onMove={(f, t) => {
                const reordered = [...groupSetsByExercise(proposedSets)]; const [moved] = reordered.splice(f, 1); reordered.splice(t, 0, moved)
                let order = 0; const newSets = reordered.flatMap(g => g.sets.map(s => create(ProposedSetSchema, { ...s, workoutOrder: order++ })))
                workoutClient.modifyProposedSets({ workoutId, proposedSets: newSets }, withUserId(userId)).then(res => setProposedSets(res.proposedSets))
              }}
              onAdd={() => setShowAddModal(true)}
            />
          </>
        )}

        {/* Set log */}
        <SetLog completedSets={completedSets} proposedSets={proposedSets} />

        {/* Overlay when peeping */}
        {peepUserId && activeProposed && activeCompleted && (
          <ActiveSummaryOverlay proposedSet={activeProposed} completedSet={activeCompleted} />
        )}

        {showMultiplayerModal && (
          <MultiplayerModal 
            userId={userId} 
            workoutId={workoutId} 
            onClose={() => setShowMultiplayerModal(false)} 
            onJoinSession={(sid) => {
              console.log('Joined session:', sid);
              // We don't necessarily want to peep immediately, just close the modal
              setShowMultiplayerModal(false);
            }} 
          />
        )}
        {editingSetId && <PlateCalculatorModal weight={proposedSets.find(p => p.id === editingSetId)?.targetWeight || 0} onSave={(w) => handleUpdateWeight(editingSetId, w)} onClose={() => setEditingSetId(null)} />}
        {showAddModal && <AddSetModal onClose={() => setShowAddModal(false)} loading={loading} onAdd={async (ex, r, w, warmup) => {
          const newSet = create(ProposedSetSchema, { exercise: ex, targetReps: r, targetWeight: w, warmup, workoutOrder: proposedSets.length })
          const res = await workoutClient.modifyProposedSets({ workoutId, proposedSets: [...proposedSets, newSet] }, withUserId(userId))
          setProposedSets(res.proposedSets); setShowAddModal(false)
        }} />}
      </div>
    </div>
  )
}

function ExerciseGroupsList({ proposedSets, completedSets, activeSetId, onMove, onAdd }: { 
  proposedSets: ProposedSet[]; 
  completedSets: CompletedSet[]; 
  activeSetId?: string;
  onMove?: (f: number, t: number) => void;
  onAdd?: () => void;
}) {
  const groups = groupSetsByExercise(proposedSets)
  return (
    <div className="space-y-1">
      {groups.map((group, idx) => (
        <ExerciseGroup
          key={`${group.exercise}-${idx}`}
          group={group}
          groupIndex={idx}
          totalGroups={groups.length}
          completedSets={completedSets}
          activeSetId={activeSetId}
          isWorkoutEnded={false}
          onMoveUp={onMove ? () => onMove(idx, idx - 1) : undefined}
          onMoveDown={onMove ? () => onMove(idx, idx + 1) : undefined}
        />
      ))}
      {onAdd && (
        <button onClick={onAdd} className="w-full py-1.5 rounded-md border border-dashed border-muted-foreground/30 text-muted-foreground hover:text-foreground text-sm transition-colors">
          + Add Exercise
        </button>
      )}
    </div>
  )
}