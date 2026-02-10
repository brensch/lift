import { create } from '@bufbuild/protobuf'
import { type ProposedSet, ProposedSetSchema } from '@/gen/workout/v1/workout_pb'

// Plate-friendly warmup stops (bar + combinations of 45/25 plates per side)
const PLATE_STOPS = [45, 95, 135, 185, 225, 275, 315, 365, 405, 455, 495, 545, 585, 635]

const REP_SCHEMES: Record<number, number[]> = {
  1: [5],
  2: [5, 5],
  3: [5, 5, 3],
  4: [5, 5, 3, 2],
}

function generateWarmupDefs(workingWeight: number): { weight: number; reps: number }[] {
  if (workingWeight <= 45) return []

  const candidates = PLATE_STOPS.filter((w) => w < workingWeight)
  if (candidates.length === 0) return []

  let selected: number[]
  if (candidates.length <= 4) {
    selected = candidates
  } else {
    // Pick 4 evenly spaced: first, two from middle, last
    const n = candidates.length
    const step = (n - 1) / 3
    selected = [
      candidates[0],
      candidates[Math.round(step)],
      candidates[Math.round(step * 2)],
      candidates[n - 1],
    ]
  }

  const reps = REP_SCHEMES[selected.length]
  return selected.map((weight, i) => ({ weight, reps: reps[i] }))
}

/**
 * Rebuild an exercise group's sets. Handles weight changes, warmup toggle, and set count.
 * Completed sets are always preserved; only pending sets get replaced.
 * New sets get client-side UUIDs so optimistic updates have unique React keys.
 *
 * @param opts.targetWeight - new working weight
 * @param opts.warmups      - enable/disable warmups (default: keep current)
 * @param opts.setCount     - number of working sets (default: keep current)
 */
export function rebuildExerciseSets(
  existingSets: ProposedSet[],
  opts: { targetWeight: number; warmups?: boolean; setCount?: number },
  isSetDone: (setId: string) => boolean,
): ProposedSet[] {
  if (existingSets.length === 0) return []
  const exercise = existingSets[0].exercise
  const wantWarmups = opts.warmups ?? existingSets.some((s) => s.warmup)
  const wantSetCount = opts.setCount ?? existingSets.filter((s) => !s.warmup).length
  const targetReps = existingSets.find((s) => !s.warmup)?.targetReps ?? 5

  // --- warmup sets ---
  const completedWarmups = existingSets.filter((s) => s.warmup && isSetDone(s.id))
  const pendingWarmups = existingSets.filter((s) => s.warmup && !isSetDone(s.id))

  let warmupSets: ProposedSet[]
  if (!wantWarmups) {
    warmupSets = completedWarmups
  } else {
    const defs = generateWarmupDefs(opts.targetWeight)
    const pendingNeeded = Math.max(0, defs.length - completedWarmups.length)
    const newPending: ProposedSet[] = []
    for (let i = 0; i < pendingNeeded; i++) {
      const def = defs[completedWarmups.length + i]
      if (i < pendingWarmups.length) {
        // Reuse existing pending warmup (preserves ID)
        newPending.push(create(ProposedSetSchema, {
          ...pendingWarmups[i],
          targetWeight: def.weight,
          targetReps: def.reps,
        }))
      } else {
        // New warmup — generate client-side UUID
        newPending.push(create(ProposedSetSchema, {
          id: crypto.randomUUID(),
          exercise,
          targetReps: def.reps,
          targetWeight: def.weight,
          warmup: true,
        }))
      }
    }
    warmupSets = [...completedWarmups, ...newPending]
  }

  // --- working sets ---
  const completedWorking = existingSets.filter((s) => !s.warmup && isSetDone(s.id))
  const pendingWorking = existingSets.filter((s) => !s.warmup && !isSetDone(s.id))
  const pendingNeeded = Math.max(0, wantSetCount - completedWorking.length)

  const newPendingWorking: ProposedSet[] = []
  for (let i = 0; i < pendingNeeded; i++) {
    if (i < pendingWorking.length) {
      newPendingWorking.push(create(ProposedSetSchema, {
        ...pendingWorking[i],
        targetWeight: opts.targetWeight,
        targetReps,
      }))
    } else {
      newPendingWorking.push(create(ProposedSetSchema, {
        id: crypto.randomUUID(),
        exercise,
        targetReps,
        targetWeight: opts.targetWeight,
        warmup: false,
      }))
    }
  }

  return [...warmupSets, ...completedWorking, ...newPendingWorking]
}
