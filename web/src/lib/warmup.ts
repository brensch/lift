import { create } from '@bufbuild/protobuf'
import { type ProposedSet, type Exercise, ProposedSetSchema } from '@/gen/workout/v1/workout_pb'

function snapWeight(w: number): number {
  const snapped = Math.round(w / 5) * 5
  return snapped < 45 ? 45 : snapped
}

function generateWarmupDefs(workingWeight: number): { weight: number; reps: number }[] {
  if (workingWeight <= 45) return []
  if (workingWeight <= 95) return [{ weight: 45, reps: 5 }]
  if (workingWeight <= 135) return [
    { weight: 45, reps: 5 },
    { weight: snapWeight(workingWeight * 0.5), reps: 5 },
  ]
  if (workingWeight <= 225) return [
    { weight: 45, reps: 5 },
    { weight: snapWeight(workingWeight * 0.5), reps: 5 },
    { weight: snapWeight(workingWeight * 0.75), reps: 3 },
  ]
  return [
    { weight: 45, reps: 5 },
    { weight: snapWeight(workingWeight * 0.5), reps: 5 },
    { weight: snapWeight(workingWeight * 0.75), reps: 3 },
    { weight: snapWeight(workingWeight * 0.9), reps: 2 },
  ]
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
