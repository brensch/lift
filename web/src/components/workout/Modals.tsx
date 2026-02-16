import { useState, useMemo } from 'react'
import { Button } from '@/components/ui/button'
import { Modal } from '@/components/ui/modal'
import { PlateCalculator } from '@/components/PlateCalculator'
import { Exercise, type ProposedSet } from '@/gen/workout/v1/workout_pb'
import { EXERCISE_NAMES } from '@/lib/exercises'

export function AddSetModal({ onAdd, onClose }: {
  onAdd: (exercise: Exercise, opts: { warmups: boolean; setCount: number; targetWeights: number[] }) => void
  onClose: () => void
}) {
  const [exercise, setExercise] = useState<Exercise>(Exercise.SQUAT)
  const [warmups, setWarmups] = useState(true)
  const [setCount, setSetCount] = useState(5)
  const [weight, setWeight] = useState(135)

  return (
    <Modal title="Add Exercise" onClose={onClose} className="max-w-sm">
      <div className="p-6 space-y-4">
        <select
          className="w-full p-2 border rounded-md bg-background text-base [&]:pr-10"
          value={exercise}
          onChange={(e) => setExercise(Number(e.target.value) as Exercise)}
        >
          {Object.entries(EXERCISE_NAMES)
            .filter(([k]) => Number(k) !== Exercise.UNSPECIFIED)
            .map(([k, name]) => (
              <option key={k} value={k}>{name}</option>
            ))}
        </select>

        <PlateCalculator weight={weight} onChange={setWeight} />

        <div>
          <label className="text-sm font-medium mb-1 block">Working Sets</label>
          <div className="flex items-center gap-3">
            <Button variant="outline" size="sm" onClick={() => setSetCount(Math.max(1, setCount - 1))} disabled={setCount <= 1}>-</Button>
            <span className="text-lg font-bold w-8 text-center">{setCount}</span>
            <Button variant="outline" size="sm" onClick={() => setSetCount(Math.min(10, setCount + 1))} disabled={setCount >= 10}>+</Button>
          </div>
        </div>

        <label className="flex items-center gap-3 py-1">
          <input type="checkbox" checked={warmups} onChange={(e) => setWarmups(e.target.checked)} className="rounded w-4 h-4" />
          <span className="text-sm font-medium">Warmup sets</span>
        </label>

        <Button className="w-full" onClick={() => onAdd(exercise, { warmups, setCount, targetWeights: [weight] })}>
          Add
        </Button>
      </div>
    </Modal>
  )
}

export function EditExerciseModal({ group, onSave, onDelete, onClose }: {
  group: { exercise: Exercise; sets: ProposedSet[]; group?: any }
  onSave: (opts: { warmups: boolean; setCount: number; targetWeights: number[] }) => void
  onDelete: () => void
  onClose: () => void
}) {
  const workingSets = group.sets.filter((s) => !s.warmup)
  const hasWarmups = group.sets.some((s) => s.warmup)

  // Get unique exercises in this group to handle supersets
  const uniqueExercises = useMemo(() => {
    const exercises: Exercise[] = []
    group.sets.forEach(s => {
      if (!exercises.includes(s.exercise)) exercises.push(s.exercise)
    })
    return exercises
  }, [group.sets])

  // Initial weights
  const initialWeights = useMemo(() => {
    if (group.group?.type === 2) { // SUPERSET
      return uniqueExercises.map(ex => group.sets.find(s => s.exercise === ex)?.targetWeight ?? 45)
    } else if (group.group?.type === 3) { // DROPSET
      return workingSets.map(s => s.targetWeight)
    } else {
      return [workingSets[0]?.targetWeight ?? 45]
    }
  }, [group, uniqueExercises, workingSets])

  const [warmups, setWarmups] = useState(hasWarmups)
  const [setCount, setSetCount] = useState(
    group.group?.type === 2 
      ? workingSets.length / uniqueExercises.length 
      : workingSets.length
  )
  const [weights, setWeights] = useState<number[]>(initialWeights)
  const [confirmDelete, setConfirmDelete] = useState(false)

  const updateWeight = (idx: number, w: number) => {
    const next = [...weights]
    next[idx] = w
    setWeights(next)
  }

  return (
    <Modal title={`Edit ${group.group?.name || EXERCISE_NAMES[group.exercise]}`} onClose={onClose} className="max-w-sm">
      <div className="p-6 space-y-4">
        <div className="space-y-6">
          {group.group?.type === 2 ? (
            uniqueExercises.map((ex, i) => (
              <div key={ex} className="space-y-2">
                <label className="text-sm font-bold uppercase tracking-wider text-muted-foreground">
                  {EXERCISE_NAMES[ex]}
                </label>
                <PlateCalculator weight={weights[i] || 45} onChange={(w) => updateWeight(i, w)} />
              </div>
            ))
          ) : group.group?.type === 3 ? (
            <div className="space-y-4">
              <label className="text-sm font-bold uppercase tracking-wider text-muted-foreground">
                Set Weights (Dropset)
              </label>
              {Array.from({ length: setCount }).map((_, i) => {
                // Ensure we have enough weights in the state
                if (i >= weights.length) {
                  const lastWeight = weights[weights.length - 1] || 45
                  const nextWeight = Math.max(0, lastWeight - 10)
                  setWeights([...weights, nextWeight])
                }
                return (
                  <div key={i} className="space-y-2 border-t pt-4 first:border-0 first:pt-0">
                    <span className="text-xs font-bold text-muted-foreground">SET {i + 1}</span>
                    <PlateCalculator weight={weights[i] || 45} onChange={(w) => updateWeight(i, w)} />
                  </div>
                )
              })}
            </div>
          ) : (
            <PlateCalculator weight={weights[0] || 45} onChange={(w) => updateWeight(0, w)} />
          )}
        </div>

        <div className="pt-4 border-t">
          <label className="text-sm font-medium mb-1 block">
            {group.group?.type === 2 ? 'Rounds' : 'Working Sets'}
          </label>
          <div className="flex items-center gap-3">
            <Button variant="outline" size="sm" onClick={() => setSetCount(Math.max(1, setCount - 1))} disabled={setCount <= 1}>-</Button>
            <span className="text-lg font-bold w-8 text-center">{setCount}</span>
            <Button variant="outline" size="sm" onClick={() => setSetCount(Math.min(10, setCount + 1))} disabled={setCount >= 10}>+</Button>
          </div>
        </div>

        <label className="flex items-center gap-3 py-1">
          <input type="checkbox" checked={warmups} onChange={(e) => setWarmups(e.target.checked)} className="rounded w-4 h-4" />
          <span className="text-sm font-medium">Warmup sets</span>
        </label>

        <Button className="w-full" onClick={() => onSave({ warmups, setCount, targetWeights: weights })}>
          Save
        </Button>

        <div className="border-t pt-3">
          {confirmDelete ? (
            <div className="flex gap-2">
              <Button variant="outline" className="flex-1" onClick={() => setConfirmDelete(false)}>Cancel</Button>
              <Button variant="destructive" className="flex-1" onClick={onDelete}>Confirm Delete</Button>
            </div>
          ) : (
            <Button variant="ghost" className="w-full text-destructive hover:text-destructive" onClick={() => setConfirmDelete(true)}>
              Delete Exercise
            </Button>
          )}
        </div>
      </div>
    </Modal>
  )
}

export function EndWorkoutModal({ onClose, onConfirm }: { onClose: () => void; onConfirm: () => void }) {
  return (
    <Modal title="End Workout" onClose={onClose} className="max-w-xs">
      <div className="p-6 space-y-4">
        <p className="text-sm">Are you sure you want to end this workout?</p>
        <div className="flex gap-2">
          <Button variant="outline" className="flex-1" onClick={onClose}>Cancel</Button>
          <Button variant="destructive" className="flex-1" onClick={onConfirm}>End</Button>
        </div>
      </div>
    </Modal>
  )
}

export function DeleteSetModal({ onClose, onConfirm }: { onClose: () => void; onConfirm: () => void }) {
  return (
    <Modal title="Delete Set" onClose={onClose} className="max-w-xs">
      <div className="p-6 space-y-4">
        <p className="text-sm">Are you sure you want to remove this completed set?</p>
        <div className="flex gap-2">
          <Button variant="outline" className="flex-1" onClick={onClose}>Cancel</Button>
          <Button variant="destructive" className="flex-1" onClick={onConfirm}>Delete</Button>
        </div>
      </div>
    </Modal>
  )
}
