import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Modal } from '@/components/ui/modal'
import { PlateCalculator } from '@/components/PlateCalculator'
import { Exercise, type ProposedSet } from '@/gen/workout/v1/workout_pb'
import { EXERCISE_NAMES } from '@/lib/exercises'

export function AddSetModal({ onAdd, onClose }: {
  onAdd: (exercise: Exercise, opts: { warmups: boolean; setCount: number; targetWeight: number }) => void
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

        <Button className="w-full" onClick={() => onAdd(exercise, { warmups, setCount, targetWeight: weight })}>
          Add
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
