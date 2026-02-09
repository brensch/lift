import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Modal } from '@/components/ui/modal'
import { PlateCalculator } from '@/components/PlateCalculator'
import { Exercise, type ProposedSet } from '@/gen/workout/v1/workout_pb'
import { EXERCISE_NAMES } from '@/lib/exercises'

export function PlateCalculatorModal({ weight, onSave, onClose }: {
  weight: number
  onSave: (weight: number) => void
  onClose: () => void
}) {
  const [value, setValue] = useState(weight)

  return (
    <Modal title="Edit Weight" onClose={onClose} className="max-w-sm">
      <div className="p-6 space-y-4">
        <PlateCalculator weight={value} onChange={setValue} />
        <div className="flex gap-2 pt-2">
          <Button variant="outline" className="flex-1" onClick={onClose}>Cancel</Button>
          <Button className="flex-1" onClick={() => onSave(value)}>Save</Button>
        </div>
      </div>
    </Modal>
  )
}

export function AddSetModal({ onAdd, onClose, loading }: {
  onAdd: (exercise: Exercise, reps: number, weight: number, warmup: boolean) => void
  onClose: () => void
  loading: boolean
}) {
  const [exercise, setExercise] = useState<Exercise>(Exercise.SQUAT)
  const [reps, setReps] = useState(5)
  const [weight, setWeight] = useState(135)
  const [warmup, setWarmup] = useState(false)

  return (
    <Modal title="Add Set" onClose={onClose} className="max-w-sm">
      <div className="p-6 space-y-4">
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
        <Button className="w-full h-12 text-lg font-bold" onClick={() => onAdd(exercise, reps, weight, warmup)} disabled={loading}>
          {loading ? 'Adding...' : 'Add Set'}
        </Button>
      </div>
    </Modal>
  )
}

export function EditExerciseModal({ group, onSave, onDelete, onClose }: {
  group: { exercise: Exercise; sets: ProposedSet[] }
  onSave: (opts: { warmups: boolean; setCount: number; targetWeight: number }) => void
  onDelete: () => void
  onClose: () => void
}) {
  const workingSets = group.sets.filter((s) => !s.warmup)
  const hasWarmups = group.sets.some((s) => s.warmup)
  const workingWeight = workingSets[0]?.targetWeight ?? 45

  const [warmups, setWarmups] = useState(hasWarmups)
  const [setCount, setSetCount] = useState(workingSets.length)
  const [weight, setWeight] = useState(workingWeight)
  const [confirmDelete, setConfirmDelete] = useState(false)

  return (
    <Modal title={`Edit ${EXERCISE_NAMES[group.exercise]}`} onClose={onClose} className="max-w-sm">
      <div className="p-6 space-y-4">
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

        <Button className="w-full" onClick={() => onSave({ warmups, setCount, targetWeight: weight })}>
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
