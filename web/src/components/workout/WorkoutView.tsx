import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { workoutClient, withUserId } from '@/lib/client'
import { create } from '@bufbuild/protobuf'
import { LoadingSpinner } from '@/components/ui/loading'
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
import { playDing } from '@/lib/audio'

import { RestingBox, ActiveSetBox, ChatTimeBox, NextUpBox, GroupNextUpBox } from './ActiveBoxes'
import { CompletedWorkoutView } from './CompletedView'
import { SetLog } from './SetLog'
import { AddSetModal, EditExerciseModal, DeleteSetModal, EndWorkoutModal } from './Modals'

function WorkoutElapsedTimer({ startTime }: { startTime: bigint }) {
  const elapsed = useElapsed(Number(startTime))
  return <span className="font-mono text-lg">{fmtElapsed(elapsed)}</span>
}

interface WorkoutViewProps {
  workoutId: string
  userId: string
}

export function WorkoutView({ workoutId, userId }: WorkoutViewProps) {
  const [workout, setWorkout] = useState<Workout | null>(null)
  const [exerciseGroups, setExerciseGroups] = useState<ExerciseGroup[]>([])
  const [proposedSets, setProposedSets] = useState<ProposedSet[]>([])
  const [completedSets, setCompletedSets] = useState<CompletedSet[]>([])
  const [loading, setLoading] = useState(false)
  const [activeRestEnd, setActiveRestEnd] = useState<number | null>(null)
  const [isResting, setIsResting] = useState(false)
  const [showAddModal, setShowAddModal] = useState(false)
  const [editingExerciseIdx, setEditingExerciseIdx] = useState<number | null>(null)
  const [setToDelete, setSetToDelete] = useState<string | null>(null)
  const [showEndModal, setShowEndModal] = useState(false)
  const sessionStatus = useMultiplayer(userId, workoutId)

  // --- Load ---

  const loadWorkout = useCallback(async () => {
    try {
      const response = await workoutClient.getWorkout({ workoutId }, withUserId(userId))
      if (response.workout) {
        setWorkout(response.workout)
        setExerciseGroups(response.exerciseGroups.sort((a, b) => a.workoutOrder - b.workoutOrder))
        setProposedSets(response.proposedSets.sort((a, b) => Number(a.workoutOrder - b.workoutOrder)))
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
      playDing()
      return
    }
    const timeout = setTimeout(() => {
      setIsResting(false)
      playDing()
    }, remaining * 1000)
    return () => clearTimeout(timeout)
  }, [activeRestEnd, isResting])

  // --- Derived ---

  const isWorkoutEnded = workout ? workout.endTime > 0n : false
  const isSetDone = (setId: string) => completedSets.some((c) => c.proposedSetId === setId && c.endedAt > 0n)
  const activeCompleted = completedSets.find((c) => c.endedAt === 0n)
  const activeProposed = activeCompleted ? proposedSets.find((p) => p.id === activeCompleted.proposedSetId) : undefined
  const nextSet = [...proposedSets].sort((a, b) => Number(a.workoutOrder - b.workoutOrder)).find((p) => !isSetDone(p.id) && p.id !== activeProposed?.id)
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
      const pNextSet = [...p.proposedSets].sort((a, b) => Number(a.workoutOrder - b.workoutOrder)).find((s) => !isPSetDone(s.id))

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

    const top = candidates[0]
    if (!top) return null

    return { ...top, isMe: top.p.user?.id === userId }
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

  const handleEditExercise = async (groupIdx: number, opts: { warmups: boolean; setCount: number; targetWeights: number[] }) => {
    const groups = exerciseGroups.length > 0 
      ? exerciseGroups.map(eg => ({
          exercise: proposedSets.find(s => s.exerciseGroupId === eg.id)?.exercise ?? Exercise.UNSPECIFIED,
          sets: proposedSets.filter(s => s.exerciseGroupId === eg.id),
          group: eg
        }))
      : groupSetsByExercise(proposedSets)

    const group = groups[groupIdx]
    if (!group || !group.group) return

    try {
      const res = await workoutClient.updateExerciseGroup({
        workoutId,
        exerciseGroupId: group.group.id,
        name: group.group.name,
        sets: opts.setCount,
        reps: 5, // Default reps if not specified
        weights: opts.targetWeights,
        includeWarmup: opts.warmups,
      }, withUserId(userId))
      
      setExerciseGroups(prev => prev.map(g => g.id === res.group?.id ? res.group : g).sort((a, b) => a.workoutOrder - b.workoutOrder))
      setProposedSets(prev => [
        ...prev.filter(s => s.exerciseGroupId !== res.group?.id),
        ...res.generatedSets
      ].sort((a, b) => Number(a.workoutOrder - b.workoutOrder)))
    } catch (e) { console.error(e) }
    setEditingExerciseIdx(null)
  }

  const handleDeleteExercise = async (groupIdx: number) => {
    const groups = exerciseGroups.length > 0 
      ? exerciseGroups.map(eg => ({
          exercise: proposedSets.find(s => s.exerciseGroupId === eg.id)?.exercise ?? Exercise.UNSPECIFIED,
          sets: proposedSets.filter(s => s.exerciseGroupId === eg.id),
          group: eg
        }))
      : groupSetsByExercise(proposedSets)

    const group = groups[groupIdx]
    if (!group || !group.group) return

    try {
      await workoutClient.deleteExerciseGroup({ workoutId, exerciseGroupId: group.group.id }, withUserId(userId))
      setExerciseGroups(prev => prev.filter(g => g.id !== group.group?.id))
      setProposedSets(prev => prev.filter(s => s.exerciseGroupId !== group.group?.id))
    } catch (e) { console.error(e) }
    setEditingExerciseIdx(null)
  }

  const handleMoveGroup = async (from: number, to: number) => {
    const ids = [...exerciseGroups.map(g => g.id)]
    const [moved] = ids.splice(from, 1)
    ids.splice(to, 0, moved)
    
    // Optimistic
    setExerciseGroups(prev => {
      const next = [...prev]
      const [m] = next.splice(from, 1)
      next.splice(to, 0, m)
      return next.map((g, i) => ({ ...g, workoutOrder: i })).sort((a, b) => a.workoutOrder - b.workoutOrder)
    })

    try {
      await workoutClient.reorderExerciseGroups({ workoutId, exerciseGroupIds: ids }, withUserId(userId))
      await loadWorkout() // Reload to get correct set order
    } catch (e) { console.error(e); loadWorkout() }
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

  const handleAddExercise = async (ex: Exercise, opts: { warmups: boolean; setCount: number; targetWeights: number[] }) => {
    try {
      const res = await workoutClient.createExerciseGroup({
        workoutId,
        name: Exercise[ex], // Or look up short name
        type: 1, // STRAIGHT
        exercises: [ex],
        sets: opts.setCount,
        reps: 5,
        weights: opts.targetWeights,
        includeWarmup: opts.warmups,
      }, withUserId(userId))
      
      if (res.group) setExerciseGroups(prev => [...prev, res.group!])
      setProposedSets(prev => [...prev, ...res.generatedSets].sort((a, b) => Number(a.workoutOrder - b.workoutOrder)))
    } catch (e) { console.error(e) }
    setShowAddModal(false)
  }

  const handleDeleteSet = async () => {
    if (!setToDelete) return
    try {
      await workoutClient.deleteCompletedSet({ workoutId, completedSetId: setToDelete }, withUserId(userId))
      setCompletedSets((prev) => prev.filter((c) => c.id !== setToDelete))
      setSetToDelete(null)
    } catch (e) {
      console.error('Failed to delete set:', e)
    }
  }

  // --- Render ---

  if (isWorkoutEnded && workout) {
    return <CompletedWorkoutView workout={workout} proposedSets={proposedSets} completedSets={completedSets} userId={userId} />
  }

  const editingGroup = editingExerciseIdx !== null
    ? groupSetsByExercise(proposedSets)[editingExerciseIdx] ?? null
    : null

  return (
    <div className="min-h-screen bg-background p-4 pt-0 pb-24">
      <div className="max-w-2xl mx-auto space-y-4">
        {/* Workout Controls */}
        <div className="flex items-center justify-between bg-muted/30 p-3 rounded-xl border border-border/50">
          <div className="flex flex-col">
            <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest leading-none mb-1">Duration</span>
            {workout && <WorkoutElapsedTimer startTime={workout.startTime} />}
          </div>
          <Button variant="destructive" size="sm" className="font-bold uppercase tracking-tight" onClick={() => setShowEndModal(true)} disabled={loading}>
            {loading ? <LoadingSpinner size="sm" className="mr-2 text-destructive-foreground" /> : null}
            End Workout
          </Button>
        </div>

        <SessionHeader userId={userId} workoutId={workoutId} />

        {/* Group Up Next — only show when multiple participants */}
        {groupNextUp && sessionStatus && sessionStatus.participants.length > 1 && (
          <GroupNextUpBox
            participant={groupNextUp.p}
            restUntil={groupNextUp.state.restUntil}
            nextSet={groupNextUp.state.nextSet}
            isMe={groupNextUp.isMe}
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
              <Button onClick={() => setShowEndModal(true)} className="mt-3">Finish Workout</Button>
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
          exerciseGroups={exerciseGroups}
          proposedSets={proposedSets} completedSets={completedSets} activeSetId={activeProposed?.id}
          onMove={handleMoveGroup} onEdit={(idx) => setEditingExerciseIdx(idx)} onAdd={() => setShowAddModal(true)}
        />

        {/* Set Log */}
        <SetLog userId={userId} completedSets={completedSets} proposedSets={proposedSets} sessionStatus={sessionStatus} onDelete={setSetToDelete} />

        {/* Modals */}
        {setToDelete && (
          <DeleteSetModal onClose={() => setSetToDelete(null)} onConfirm={handleDeleteSet} />
        )}
        {editingGroup && editingExerciseIdx !== null && (
          <EditExerciseModal
            group={editingGroup}
            onSave={(opts) => handleEditExercise(editingExerciseIdx, opts)}
            onDelete={() => handleDeleteExercise(editingExerciseIdx)}
            onClose={() => setEditingExerciseIdx(null)}
          />
        )}
        {showEndModal && (
          <EndWorkoutModal onClose={() => setShowEndModal(false)} onConfirm={() => { setShowEndModal(false); handleEndWorkout() }} />
        )}
        {showAddModal && (
          <AddSetModal onClose={() => setShowAddModal(false)} onAdd={handleAddExercise} />
        )}
      </div>
    </div>
  )
}

function ExerciseGroupsList({ exerciseGroups, proposedSets, completedSets, activeSetId, onMove, onEdit, onAdd }: {
  exerciseGroups: ExerciseGroup[]
  proposedSets: ProposedSet[]
  completedSets: CompletedSet[]
  activeSetId?: string
  onMove: (from: number, to: number) => void
  onEdit: (groupIdx: number) => void
  onAdd: () => void
}) {
  const groups = useMemo(() => {
    if (exerciseGroups.length === 0) {
      return groupSetsByExercise(proposedSets)
    }
    return exerciseGroups.map(eg => ({
      exercise: proposedSets.find(s => s.exerciseGroupId === eg.id)?.exercise ?? Exercise.UNSPECIFIED,
      sets: proposedSets.filter(s => s.exerciseGroupId === eg.id),
      group: eg
    }))
  }, [exerciseGroups, proposedSets])

  return (
    <div className="space-y-1">
      {groups.map((group, idx) => (
        <ExerciseGroup
          key={group.group?.id ?? `${group.exercise}-${idx}`}
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
