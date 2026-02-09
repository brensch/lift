import { useState, useEffect, useCallback, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { workoutClient, withUserId } from '@/lib/client'
import { create } from '@bufbuild/protobuf'
import {
  type Workout,
  type ProposedSet,
  type CompletedSet,
  Exercise,
  ProposedSetSchema,
} from '@/gen/workout/v1/workout_pb'
import { ExerciseGroup, groupSetsByExercise } from '@/components/ExerciseGroup'
import { rebuildExerciseSets } from '@/lib/warmup'
import { SessionHeader } from '@/components/SessionHeader'
import { useMultiplayer } from '@/hooks/useMultiplayer'
import { useElapsed, fmtElapsed } from '@/hooks/useTimer'

import { RestingBox, ActiveSetBox, ChatTimeBox, NextUpBox } from './ActiveBoxes'
import { CompletedWorkoutView } from './CompletedView'
import { SetLog } from './SetLog'
import { PlateCalculatorModal, AddSetModal, EditExerciseModal } from './Modals'

function WorkoutElapsedTimer({ startTime }: { startTime: bigint }) {
  const elapsed = useElapsed(Number(startTime))
  return <span className="font-mono text-lg">{fmtElapsed(elapsed)}</span>
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
  const [restUntil, setRestUntil] = useState<number | null>(null)
  const [restEndedAt, setRestEndedAt] = useState<number | null>(null)
  const [showAddModal, setShowAddModal] = useState(false)
  const [editingSetId, setEditingSetId] = useState<string | null>(null)
  const [editingExerciseIdx, setEditingExerciseIdx] = useState<number | null>(null)
  const saveCounterRef = useRef(0)
  const sessionStatus = useMultiplayer(userId, workoutId)

  // --- Load ---

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

  useEffect(() => { loadWorkout() }, [loadWorkout])

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

  // --- Derived ---

  const isWorkoutEnded = workout ? workout.endTime > 0n : false
  const isSetDone = (setId: string) => completedSets.some((c) => c.proposedSetId === setId && c.endedAt > 0n)
  const activeCompleted = completedSets.find((c) => c.endedAt === 0n)
  const activeProposed = activeCompleted ? proposedSets.find((p) => p.id === activeCompleted.proposedSetId) : undefined
  const nextSet = proposedSets.find((p) => !isSetDone(p.id) && p.id !== activeProposed?.id)
  const allSetsDone = proposedSets.length > 0 && proposedSets.every((p) => isSetDone(p.id)) && !activeCompleted

  // --- Handlers ---

  const handleSetUpdated = (cs: CompletedSet) => {
    setCompletedSets((prev) => {
      const idx = prev.findIndex((c) => c.proposedSetId === cs.proposedSetId)
      if (idx >= 0) { const next = [...prev]; next[idx] = cs; return next }
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

  /** Re-number all sets across groups, optimistic-update, then persist to server. */
  const saveGroups = (groups: { exercise: Exercise; sets: ProposedSet[] }[]) => {
    const thisCounter = ++saveCounterRef.current
    let order = 0
    const updatedSets = groups.flatMap((g) =>
      g.sets.map((s) => create(ProposedSetSchema, { ...s, workoutOrder: order++ }))
    )
    setProposedSets(updatedSets)
    workoutClient.modifyProposedSets({ workoutId, proposedSets: updatedSets }, withUserId(userId))
      .then((res) => {
        if (saveCounterRef.current === thisCounter) setProposedSets(res.proposedSets)
      }).catch(console.error)
  }

  const handleUpdateWeight = (setId: string, newWeight: number) => {
    const groups = groupSetsByExercise(proposedSets)
    const groupIdx = groups.findIndex((g) => g.sets.some((s) => s.id === setId))
    if (groupIdx === -1) return
    const rebuilt = rebuildExerciseSets(groups[groupIdx].sets, { targetWeight: newWeight }, isSetDone)
    saveGroups(groups.map((g, i) => i === groupIdx ? { ...g, sets: rebuilt } : g))
    setEditingSetId(null)
  }

  const handleEditExercise = (groupIdx: number, opts: { warmups: boolean; setCount: number; targetWeight: number }) => {
    const groups = groupSetsByExercise(proposedSets)
    if (!groups[groupIdx]) return
    const rebuilt = rebuildExerciseSets(groups[groupIdx].sets, opts, isSetDone)
    saveGroups(groups.map((g, i) => i === groupIdx ? { ...g, sets: rebuilt } : g))
    setEditingExerciseIdx(null)
  }

  const handleDeleteExercise = (groupIdx: number) => {
    saveGroups(groupSetsByExercise(proposedSets).filter((_, i) => i !== groupIdx))
    setEditingExerciseIdx(null)
  }

  const handleMoveGroup = (from: number, to: number) => {
    const groups = [...groupSetsByExercise(proposedSets)]
    const [moved] = groups.splice(from, 1)
    groups.splice(to, 0, moved)
    saveGroups(groups)
  }

  const handleSkipWarmup = async (setId: string) => {
    const proposed = proposedSets.find((p) => p.id === setId)
    if (!proposed) return
    try {
      const response = await workoutClient.completeSet({
        workoutId, proposedSetId: setId,
        actualReps: proposed.targetReps, actualWeight: proposed.targetWeight,
      }, withUserId(userId))
      if (response.completedSet) {
        const cs = response.completedSet
        setCompletedSets((prev) => {
          const idx = prev.findIndex((c) => c.proposedSetId === cs.proposedSetId)
          if (idx >= 0) { const next = [...prev]; next[idx] = cs; return next }
          return [...prev, cs]
        })
      }
      setRestUntil(null); setRestEndedAt(null)
    } catch (e) { console.error(e) }
  }

  const handleEndWorkout = async () => {
    setLoading(true)
    try {
      const response = await workoutClient.endWorkout({ workoutId }, withUserId(userId))
      if (response.workout) setWorkout(response.workout)
      await loadWorkout()
    } catch (e) { console.error(e) } finally { setLoading(false) }
  }

  const handleAddSet = async (ex: Exercise, r: number, w: number, warmup: boolean) => {
    const newSet = create(ProposedSetSchema, {
      id: crypto.randomUUID(),
      exercise: ex, targetReps: r, targetWeight: w, warmup, workoutOrder: proposedSets.length,
    })
    const res = await workoutClient.modifyProposedSets({
      workoutId, proposedSets: [...proposedSets, newSet],
    }, withUserId(userId))
    setProposedSets(res.proposedSets)
    setShowAddModal(false)
  }

  // --- Render ---

  if (isWorkoutEnded && workout) {
    return <CompletedWorkoutView workout={workout} proposedSets={proposedSets} completedSets={completedSets} userId={userId} onBack={onBack} />
  }

  // Resolve weight for edit modal: use working weight even when editing a warmup set,
  // and look within the same group (not by exercise type) to avoid cross-group confusion.
  const editingWeightInfo = (() => {
    if (!editingSetId) return null
    const editSet = proposedSets.find((p) => p.id === editingSetId)
    if (!editSet) return null
    const group = groupSetsByExercise(proposedSets).find((g) => g.sets.some((s) => s.id === editingSetId))
    const workingWeight = editSet.warmup
      ? group?.sets.find((s) => !s.warmup)?.targetWeight || editSet.targetWeight
      : editSet.targetWeight
    return { setId: editingSetId, weight: workingWeight }
  })()

  const editingGroup = editingExerciseIdx !== null
    ? groupSetsByExercise(proposedSets)[editingExerciseIdx] ?? null
    : null

  return (
    <div className="min-h-screen bg-background p-4 pb-24">
      <div className="max-w-2xl mx-auto space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <button onClick={onBack} className="text-3xl font-bold hover:opacity-80 transition-opacity">Lift</button>
          <div className="flex items-center gap-2">
            {workout && <WorkoutElapsedTimer startTime={workout.startTime} />}
            <Button variant="destructive" size="sm" onClick={handleEndWorkout} disabled={loading}>End</Button>
          </div>
        </div>

        <SessionHeader userId={userId} workoutId={workoutId} />

        {/* Active Area */}
        {activeProposed && activeCompleted ? (
          <ActiveSetBox
            proposedSet={activeProposed} completedSet={activeCompleted}
            onComplete={(reps) => handleCompleteSet(activeProposed.id, reps)}
            onEditWeight={() => setEditingSetId(activeProposed.id)}
            onSkip={activeProposed.warmup ? () => handleSkipWarmup(activeProposed.id) : undefined}
          />
        ) : allSetsDone ? (
          <Card className="border-2 border-green-500/50 bg-green-500/5">
            <CardContent className="pt-6 pb-4 text-center">
              <p className="text-lg font-bold text-green-600">All sets complete!</p>
              <Button onClick={handleEndWorkout} className="mt-3">Finish Workout</Button>
            </CardContent>
          </Card>
        ) : restUntil && restUntil > Math.floor(Date.now() / 1000) ? (
          <RestingBox
            restUntil={restUntil} nextSet={nextSet}
            onStartEarly={() => nextSet && handleStartSet(nextSet.id)}
            onEditWeight={nextSet ? () => setEditingSetId(nextSet.id) : undefined}
            onSkipWarmup={nextSet?.warmup ? () => handleSkipWarmup(nextSet.id) : undefined}
          />
        ) : restEndedAt && nextSet ? (
          <ChatTimeBox
            restEndedAt={restEndedAt} nextSet={nextSet}
            onStart={() => handleStartSet(nextSet.id)} loading={loading}
            onEditWeight={() => setEditingSetId(nextSet.id)}
            onSkipWarmup={nextSet.warmup ? () => handleSkipWarmup(nextSet.id) : undefined}
          />
        ) : nextSet ? (
          <NextUpBox
            nextSet={nextSet} onStart={() => handleStartSet(nextSet.id)} loading={loading}
            onEditWeight={() => setEditingSetId(nextSet.id)}
            onSkipWarmup={nextSet.warmup ? () => handleSkipWarmup(nextSet.id) : undefined}
          />
        ) : null}

        {/* Exercise Groups */}
        <ExerciseGroupsList
          proposedSets={proposedSets} completedSets={completedSets} activeSetId={activeProposed?.id}
          onMove={handleMoveGroup} onEdit={(idx) => setEditingExerciseIdx(idx)} onAdd={() => setShowAddModal(true)}
        />

        {/* Set Log */}
        <SetLog userId={userId} completedSets={completedSets} proposedSets={proposedSets} sessionStatus={sessionStatus} />

        {/* Modals */}
        {editingWeightInfo && (
          <PlateCalculatorModal
            weight={editingWeightInfo.weight}
            onSave={(w) => handleUpdateWeight(editingWeightInfo.setId, w)}
            onClose={() => setEditingSetId(null)}
          />
        )}
        {editingGroup && editingExerciseIdx !== null && (
          <EditExerciseModal
            group={editingGroup}
            onSave={(opts) => handleEditExercise(editingExerciseIdx, opts)}
            onDelete={() => handleDeleteExercise(editingExerciseIdx)}
            onClose={() => setEditingExerciseIdx(null)}
          />
        )}
        {showAddModal && (
          <AddSetModal onClose={() => setShowAddModal(false)} loading={loading} onAdd={handleAddSet} />
        )}
      </div>
    </div>
  )
}

function ExerciseGroupsList({ proposedSets, completedSets, activeSetId, onMove, onEdit, onAdd }: {
  proposedSets: ProposedSet[]
  completedSets: CompletedSet[]
  activeSetId?: string
  onMove: (from: number, to: number) => void
  onEdit: (groupIdx: number) => void
  onAdd: () => void
}) {
  const groups = groupSetsByExercise(proposedSets)
  return (
    <div className="space-y-1">
      {groups.map((group, idx) => (
        <ExerciseGroup
          key={`${group.exercise}-${idx}`}
          group={group} groupIndex={idx} totalGroups={groups.length}
          completedSets={completedSets} activeSetId={activeSetId} isWorkoutEnded={false}
          onMoveUp={() => onMove(idx, idx - 1)} onMoveDown={() => onMove(idx, idx + 1)}
          onEdit={() => onEdit(idx)}
        />
      ))}
      <button onClick={onAdd} className="w-full py-1.5 rounded-md border border-dashed border-muted-foreground/30 text-muted-foreground hover:text-foreground text-sm transition-colors">
        + Add Exercise
      </button>
    </div>
  )
}
