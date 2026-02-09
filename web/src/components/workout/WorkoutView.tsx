import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
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
import { type ParticipantStatus } from '@/gen/workout/v1/group_pb'
import { ExerciseGroup, groupSetsByExercise } from '@/components/ExerciseGroup'
import { rebuildExerciseSets } from '@/lib/warmup'
import { SessionHeader } from '@/components/SessionHeader'
import { useMultiplayer } from '@/hooks/useMultiplayer'
import { useElapsed, fmtElapsed } from '@/hooks/useTimer'

import { RestingBox, ActiveSetBox, ChatTimeBox, NextUpBox, GroupNextUpBox } from './ActiveBoxes'
import { CompletedWorkoutView } from './CompletedView'
import { SetLog } from './SetLog'
import { AddSetModal, EditExerciseModal } from './Modals'

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
  const [activeRestEnd, setActiveRestEnd] = useState<number | null>(null)
  const [isResting, setIsResting] = useState(false)
  const [showAddModal, setShowAddModal] = useState(false)
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

        const activeSet = response.completedSets.find(c => c.endedAt === 0n)
        if (activeSet) {
           setActiveRestEnd(null)
           setIsResting(false)
           return
        }

        const lastCompleted = response.completedSets
          .filter((c) => c.endedAt > 0n && c.restUntil > 0n)
          .sort((a, b) => Number(b.endedAt - a.endedAt))[0]
          
        if (lastCompleted) {
          const ru = Number(lastCompleted.restUntil)
          setActiveRestEnd(ru)
          setIsResting(ru > Math.floor(Date.now() / 1000))
        }
      }
    } catch (e) {
      console.error('Failed to load workout:', e)
    }
  }, [workoutId, userId])

  useEffect(() => { loadWorkout() }, [loadWorkout])

  useEffect(() => {
    if (!activeRestEnd || !isResting) return
    const remaining = activeRestEnd - Math.floor(Date.now() / 1000)
    if (remaining <= 0) {
      setIsResting(false)
      return
    }
    const timeout = setTimeout(() => {
      setIsResting(false)
    }, remaining * 1000)
    return () => clearTimeout(timeout)
  }, [activeRestEnd, isResting])

  // --- Derived ---

  const isWorkoutEnded = workout ? workout.endTime > 0n : false
  const isSetDone = (setId: string) => completedSets.some((c) => c.proposedSetId === setId && c.endedAt > 0n)
  const activeCompleted = completedSets.find((c) => c.endedAt === 0n)
  const activeProposed = activeCompleted ? proposedSets.find((p) => p.id === activeCompleted.proposedSetId) : undefined
  const nextSet = proposedSets.find((p) => !isSetDone(p.id) && p.id !== activeProposed?.id)
  const allSetsDone = proposedSets.length > 0 && proposedSets.every((p) => isSetDone(p.id)) && !activeCompleted

  // Determine "Next Up" for group
  const groupNextUp = useMemo(() => {
    if (!sessionStatus) return null
    const now = Math.floor(Date.now() / 1000)
    
    const getParticipantState = (p: ParticipantStatus) => {
      // Find last completed set with rest
      const lastCompleted = p.completedSets
        .filter((c) => c.endedAt > 0n && c.restUntil > 0n)
        .sort((a, b) => Number(b.endedAt - a.endedAt))[0]
      
      const restUntil = lastCompleted ? Number(lastCompleted.restUntil) : 0
      
      // Check if actively working out (started set but not ended)
      const activeSet = p.completedSets.find(c => c.endedAt === 0n)
      if (activeSet) return null 

      // Find next set
      const isPSetDone = (setId: string) => p.completedSets.some((c) => c.proposedSetId === setId && c.endedAt > 0n)
      const pActiveProposedId = activeSet?.proposedSetId
      const pNextSet = p.proposedSets.find((s) => !isPSetDone(s.id) && s.id !== pActiveProposedId)
      
      if (!pNextSet) return null

      if (restUntil > now) {
         return { type: 'resting', restUntil, nextSet: pNextSet, score: restUntil - now }
      } else {
         return { type: 'chatting', restUntil, nextSet: pNextSet, score: now - restUntil }
      }
    }

    const candidates = sessionStatus.participants
      .map(p => ({ p, state: getParticipantState(p) }))
      .filter((x): x is { p: ParticipantStatus, state: NonNullable<ReturnType<typeof getParticipantState>> } => x.state !== null)
    
    // Sort: Chatting (descending overdue) > Resting (ascending remaining)
    candidates.sort((a, b) => {
        if (a.state.type === 'chatting' && b.state.type === 'resting') return -1
        if (a.state.type === 'resting' && b.state.type === 'chatting') return 1
        
        if (a.state.type === 'chatting' && b.state.type === 'chatting') {
            return b.state.score - a.state.score // Longest chatting first
        }
        if (a.state.type === 'resting' && b.state.type === 'resting') {
            return a.state.score - b.state.score // Soonest to finish first
        }
        return 0
    })

    return candidates[0]
  }, [sessionStatus, userId])

  // --- Handlers ---

  const handleSetUpdated = (cs: CompletedSet) => {
    setCompletedSets((prev) => {
      const idx = prev.findIndex((c) => c.proposedSetId === cs.proposedSetId)
      if (idx >= 0) { const next = [...prev]; next[idx] = cs; return next }
      return [...prev, cs]
    })
    if (cs.endedAt > 0n && cs.restUntil > 0n) {
      const ru = Number(cs.restUntil)
      setActiveRestEnd(ru)
      setIsResting(ru > Math.floor(Date.now() / 1000))
    }
  }

  const handleStartSet = async (proposedSetId: string) => {
    setLoading(true); setActiveRestEnd(null); setIsResting(false)
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
      setActiveRestEnd(null); setIsResting(false)
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

  const handleAddExercise = (ex: Exercise, opts: { warmups: boolean; setCount: number; targetWeight: number }) => {
    const seed = [create(ProposedSetSchema, {
      id: crypto.randomUUID(),
      exercise: ex, targetReps: 5, targetWeight: opts.targetWeight, warmup: false,
    })]
    const newSets = rebuildExerciseSets(seed, opts, () => false)
    const groups = groupSetsByExercise(proposedSets)
    saveGroups([...groups, { exercise: ex, sets: newSets }])
    setShowAddModal(false)
  }

  // --- Render ---

  if (isWorkoutEnded && workout) {
    return <CompletedWorkoutView workout={workout} proposedSets={proposedSets} completedSets={completedSets} userId={userId} onBack={onBack} />
  }

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

        {/* Group Up Next */}
        {groupNextUp && (
          <GroupNextUpBox 
            participant={groupNextUp.p} 
            restUntil={groupNextUp.state.restUntil} 
            nextSet={groupNextUp.state.nextSet} 
          />
        )}

        {/* Active Area */}
        {activeProposed && activeCompleted ? (
          <ActiveSetBox
            proposedSet={activeProposed} completedSet={activeCompleted}
            onComplete={(reps) => handleCompleteSet(activeProposed.id, reps)}
            onSkip={activeProposed.warmup ? () => handleSkipWarmup(activeProposed.id) : undefined}
          />
        ) : allSetsDone ? (
          <Card className="border-2 border-green-500/50 bg-green-500/5">
            <CardContent className="pt-6 pb-4 text-center">
              <p className="text-lg font-bold text-green-600">All sets complete!</p>
              <Button onClick={handleEndWorkout} className="mt-3">Finish Workout</Button>
            </CardContent>
          </Card>
        ) : isResting && activeRestEnd ? (
          <RestingBox
            restUntil={activeRestEnd} nextSet={nextSet}
            onStartEarly={() => nextSet && handleStartSet(nextSet.id)}
            onSkipWarmup={nextSet?.warmup ? () => handleSkipWarmup(nextSet.id) : undefined}
          />
        ) : activeRestEnd && nextSet ? (
          <ChatTimeBox
            restEndedAt={activeRestEnd} nextSet={nextSet}
            onStart={() => handleStartSet(nextSet.id)} loading={loading}
            onSkipWarmup={nextSet.warmup ? () => handleSkipWarmup(nextSet.id) : undefined}
          />
        ) : nextSet ? (
          <NextUpBox
            nextSet={nextSet} onStart={() => handleStartSet(nextSet.id)} loading={loading}
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
        {editingGroup && editingExerciseIdx !== null && (
          <EditExerciseModal
            group={editingGroup}
            onSave={(opts) => handleEditExercise(editingExerciseIdx, opts)}
            onDelete={() => handleDeleteExercise(editingExerciseIdx)}
            onClose={() => setEditingExerciseIdx(null)}
          />
        )}
        {showAddModal && (
          <AddSetModal onClose={() => setShowAddModal(false)} onAdd={handleAddExercise} />
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
