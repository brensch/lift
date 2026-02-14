import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { workoutClient, userClient, withUserId } from '@/lib/client'
import type { Workout, ExerciseStatus } from '@/gen/workout/v1/workout_pb'
import { Exercise, ExerciseCategory, ProposedSetSchema } from '@/gen/workout/v1/workout_pb'
import { create } from '@bufbuild/protobuf'
import { SessionHeader } from './SessionHeader'
import { SHORT_NAMES } from '@/lib/exercises'
import { Loader2, Check } from 'lucide-react'

const CATEGORY_NAMES: Record<ExerciseCategory, string> = {
  [ExerciseCategory.UNSPECIFIED]: '',
  [ExerciseCategory.COMPOUND]: 'Compound',
  [ExerciseCategory.AUXILIARY]: 'Auxiliary',
}

interface HomeViewProps {
  userId: string
  onStartWorkout: (workoutId: string) => void
}

export function HomeView({ userId, onStartWorkout }: HomeViewProps) {
  const [_userName, setUserName] = useState<string>('')
  const [workoutHistory, setWorkoutHistory] = useState<Workout[]>([])
  const [exerciseStatuses, setExerciseStatuses] = useState<ExerciseStatus[]>([])
  const [selectedExercises, setSelectedExercises] = useState<Set<number>>(new Set())
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const activeWorkout = workoutHistory.find(w => w.endTime === 0n)

  useEffect(() => {
    loadData()
    userClient.getUser({ userId }, withUserId(userId))
      .then((res: { user?: { name: string } }) => {
        if (res.user) setUserName(res.user.name)
      })
      .catch(console.error)
  }, [userId])

  const loadData = async () => {
    try {
      const [workoutsRes, scheduleRes] = await Promise.all([
        workoutClient.listWorkouts({}, withUserId(userId)),
        workoutClient.getProposedWorkoutSchedule({ userId }, withUserId(userId)),
      ])
      setWorkoutHistory(workoutsRes.workouts)
      setExerciseStatuses(scheduleRes.exerciseStatuses)

      // Auto-select: start with always_include, then fill up to 3 with oldest compounds
      const autoSelected = new Set<number>()
      
      // 1. Add always_include
      for (const s of scheduleRes.exerciseStatuses) {
        if (s.alwaysInclude) {
          autoSelected.add(s.exercise)
        }
      }

      // 2. Fill up to 3 from the oldest compounds
      const sortedCompounds = [...scheduleRes.exerciseStatuses]
        .filter(s => s.category === ExerciseCategory.COMPOUND)
        .sort((a, b) => Number(a.lastPerformedAt - b.lastPerformedAt))

      for (const s of sortedCompounds) {
        if (autoSelected.size >= 3) break
        autoSelected.add(s.exercise)
      }
      
      setSelectedExercises(autoSelected)
    } catch (e) {
      console.error('Failed to load data:', e)
    }
  }

  const toggleExercise = (exercise: number) => {
    setSelectedExercises(prev => {
      const next = new Set(prev)
      if (next.has(exercise)) {
        next.delete(exercise)
      } else {
        next.add(exercise)
      }
      return next
    })
  }

  const generateWorkoutSets = () => {
    const PLATE_STOPS = [45, 95, 135, 185, 225, 275, 315, 365, 405, 455, 495, 545, 585, 635]
    const REP_SCHEMES: Record<number, number[]> = { 1: [5], 2: [5, 5], 3: [5, 5, 3], 4: [5, 5, 3, 2] }

    const getWarmups = (weight: number) => {
      if (weight <= 45) return []
      const candidates = PLATE_STOPS.filter(w => w < weight)
      if (candidates.length === 0) return []
      let selected: number[]
      if (candidates.length <= 4) {
        selected = candidates
      } else {
        const n = candidates.length
        const step = (n - 1) / 3
        selected = [candidates[0], candidates[Math.round(step)], candidates[Math.round(step * 2)], candidates[n - 1]]
      }
      const reps = REP_SCHEMES[selected.length]
      return selected.map((w, i) => ({ weight: w, reps: reps[i] }))
    }

    const allSets: any[] = []
    let order = 0

    // Use the exercise statuses in order, filtered to selected
    for (const s of exerciseStatuses) {
      if (!selectedExercises.has(s.exercise)) continue

      const weight = s.targetWeight
      const warmups = getWarmups(weight)
      for (const wu of warmups) {
        allSets.push(create(ProposedSetSchema, {
          id: crypto.randomUUID(),
          workoutOrder: order++,
          exercise: s.exercise as Exercise,
          targetReps: wu.reps,
          targetWeight: wu.weight,
          warmup: true
        }))
      }
      for (let i = 0; i < s.defaultSets; i++) {
        allSets.push(create(ProposedSetSchema, {
          id: crypto.randomUUID(),
          workoutOrder: order++,
          exercise: s.exercise as Exercise,
          targetReps: s.defaultReps,
          targetWeight: weight,
          warmup: false
        }))
      }
    }
    return allSets
  }

  const handleStartWorkout = async () => {
    if (selectedExercises.size === 0) return
    setLoading(true)
    setError(null)
    try {
      const formattedSets = generateWorkoutSets()
      const now = new Date()
      const workoutName = now.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })

      const response = await workoutClient.startWorkout(
        { name: workoutName, proposedSets: formattedSets },
        withUserId(userId)
      )
      onStartWorkout(response.id)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to start workout')
    } finally {
      setLoading(false)
    }
  }

  const formatTimeSince = (timestamp: bigint | number) => {
    if (!timestamp || timestamp === 0n || timestamp === 0) return ''
    const diff = Date.now() / 1000 - Number(timestamp)
    if (diff < 60) return 'now'
    if (diff < 3600) return `${Math.floor(diff / 60)}m`
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`
    return `${Math.floor(diff / 86400)}d`
  }

  // Time since last workout
  const lastCompletedWorkout = workoutHistory.find(w => w.endTime > 0n)
  const timeSinceLastWorkout = (() => {
    if (!lastCompletedWorkout) return null
    const diff = Date.now() / 1000 - Number(lastCompletedWorkout.startTime)
    const hours = Math.floor(diff / 3600)
    if (hours < 24) return `${hours}h`
    const days = Math.floor(hours / 24)
    return `${days}d`
  })()

  // Group exercises by category from API
  const exercisesByCategory = exerciseStatuses.reduce((acc, s) => {
    const cat = s.category || ExerciseCategory.UNSPECIFIED
    if (!acc[cat]) acc[cat] = []
    acc[cat].push(s)
    return acc
  }, {} as Record<number, ExerciseStatus[]>)

  // Sort categories: compound first, then auxiliary
  const sortedCategories = Object.keys(exercisesByCategory)
    .map(Number)
    .sort((a, b) => a - b)
    .filter(c => c !== ExerciseCategory.UNSPECIFIED)

  return (
    <div className="h-full bg-background p-4 pt-0">
      <div className="max-w-2xl mx-auto space-y-6">
        <SessionHeader userId={userId} />

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
            {error}
          </div>
        )}

        {/* Active Workout Resume */}
        {activeWorkout && (
          <Card className="border-2 border-primary animate-pulse">
            <CardHeader className="pb-2">
              <CardTitle className="text-primary text-sm uppercase tracking-wider">Active Session</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col gap-4">
                <div>
                  <p className="text-2xl font-black uppercase">{activeWorkout.name || 'Workout'}</p>
                  <p className="text-xs text-muted-foreground">Started {new Date(Number(activeWorkout.startTime) * 1000).toLocaleTimeString()}</p>
                </div>
                <Button
                  size="lg"
                  className="w-full font-bold uppercase tracking-tighter"
                  onClick={() => onStartWorkout(activeWorkout.id)}
                >
                  Resume
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Time since last workout */}
        {timeSinceLastWorkout && !activeWorkout && (
          <div className="flex items-baseline gap-1.5 px-1 py-0.5">
            <span className="text-[10px] font-black uppercase tracking-widest text-muted-foreground/50">Last workout:</span>
            <span className="text-sm font-black">{timeSinceLastWorkout} ago</span>
          </div>
        )}

        {/* Exercise Selection by Category */}
        {sortedCategories.map(cat => (
          <div key={cat} className="space-y-2">
            <h2 className="text-xs uppercase tracking-widest text-muted-foreground font-bold px-1">
              {CATEGORY_NAMES[cat as ExerciseCategory] || 'Exercises'}
            </h2>
            <div className="grid grid-cols-3 gap-1.5">
              {exercisesByCategory[cat].map(s => {
                const isSelected = selectedExercises.has(s.exercise)

                return (
                  <div
                    key={s.exercise}
                    className={`relative flex flex-col justify-between rounded-lg border p-2 cursor-pointer transition-all shadow-sm h-full ${
                      isSelected
                        ? 'border-primary bg-primary/5 ring-1 ring-primary/20 shadow-md'
                        : 'border-border bg-card hover:bg-muted/50'
                    }`}
                    onClick={() => toggleExercise(s.exercise)}
                  >
                    {/* Header: Name & Status */}
                    <div className="flex justify-between items-start mb-1">
                      <span className="text-[13px] font-black uppercase tracking-tighter text-foreground leading-none truncate mr-1">
                        {SHORT_NAMES[s.exercise as Exercise] || '?'}
                      </span>
                      <div className="flex items-center">
                        {isSelected && (
                          <Check className="w-2.5 h-2.5 text-primary" />
                        )}
                      </div>
                    </div>

                    {/* Body: Weight & Sets */}
                    <div className="flex flex-col items-center justify-center py-0.5">
                      <div className="text-lg font-black tabular-nums tracking-tighter text-foreground">
                        {s.targetWeight}
                        <span className="text-[8px] text-muted-foreground ml-0.5 font-bold uppercase">lb</span>
                      </div>
                      <div className="text-[8px] font-bold text-muted-foreground uppercase tracking-tight bg-muted/30 px-1 rounded">
                        {s.defaultSets}x{s.defaultReps}
                      </div>
                    </div>

                    {/* Footer: Recovery & Explanation */}
                    <div className="mt-1 space-y-0.5">
                       {/* Recovery Info */}
                       <div className="flex items-center gap-1 scale-[0.7] origin-left w-[140%]">
                          <div className={`w-1.5 h-1.5 rounded-full ring-1 ring-background shrink-0 ${
                            s.recovered ? 'bg-green-500' : 'bg-amber-500'
                          }`} />
                          <span className="text-[10px] font-bold text-muted-foreground/70 uppercase tracking-tighter truncate">
                            {s.lastPerformedAt ? formatTimeSince(s.lastPerformedAt) : 'New'}
                          </span>
                        </div>

                        {/* Explanation (only if relevant/selected) */}
                        {isSelected && s.explanation && (
                          <div className="scale-[0.7] origin-left w-[140%] -mt-0.5">
                            <div className="text-[10px] text-muted-foreground/60 leading-tight border-t border-border/20 pt-1 normal-case font-medium line-clamp-2">
                              {s.explanation}
                            </div>
                          </div>
                        )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        ))}

        {/* Start Workout Button */}
        {!activeWorkout && selectedExercises.size > 0 && (
          <Button
            size="lg"
            className="w-full font-bold uppercase tracking-tighter text-lg py-6"
            onClick={handleStartWorkout}
            disabled={loading}
          >
            {loading ? <Loader2 className="mr-2 h-5 w-5 animate-spin" /> : null}
            Start Workout ({selectedExercises.size} exercise{selectedExercises.size !== 1 ? 's' : ''})
          </Button>
        )}
      </div>
    </div>
  )
}
