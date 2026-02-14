import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { workoutClient, userClient, withUserId } from '@/lib/client'
import type { Workout, ExerciseStatus } from '@/gen/workout/v1/workout_pb'
import { Exercise, ExerciseCategory, ProposedSetSchema } from '@/gen/workout/v1/workout_pb'
import { create } from '@bufbuild/protobuf'
import { SessionHeader } from './SessionHeader'
import { SHORT_NAMES } from '@/lib/exercises'
import { Loader2, Settings, Check, Lock } from 'lucide-react'

const CATEGORY_NAMES: Record<ExerciseCategory, string> = {
  [ExerciseCategory.UNSPECIFIED]: '',
  [ExerciseCategory.COMPOUND]: 'Compound',
  [ExerciseCategory.AUXILIARY]: 'Auxiliary',
}

interface HomeViewProps {
  userId: string
  onSettings: () => void
  onStartWorkout: (workoutId: string) => void
  onViewWorkout: (workoutId: string) => void
  onViewHistory: () => void
}

export function HomeView({ userId, onSettings, onStartWorkout, onViewWorkout, onViewHistory }: HomeViewProps) {
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

      // Auto-select: always_include + up to 3 recovered compound exercises, no auxiliary
      const autoSelected = new Set<number>()
      let compoundCount = 0
      for (const s of scheduleRes.exerciseStatuses) {
        if (s.alwaysInclude) {
          autoSelected.add(s.exercise)
          if (s.category === ExerciseCategory.COMPOUND) compoundCount++
        }
      }
      for (const s of scheduleRes.exerciseStatuses) {
        if (s.category === ExerciseCategory.COMPOUND && s.recovered && !autoSelected.has(s.exercise) && compoundCount < 3) {
          autoSelected.add(s.exercise)
          compoundCount++
        }
      }
      setSelectedExercises(autoSelected)
    } catch (e) {
      console.error('Failed to load data:', e)
    }
  }

  const toggleExercise = (exercise: number, alwaysInclude: boolean) => {
    if (alwaysInclude) return // can't deselect always-include
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

  const formatDate = (timestamp: bigint | number) => {
    if (!timestamp) return 'N/A'
    return new Date(Number(timestamp) * 1000).toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
    })
  }

  const formatDuration = (start: bigint, end: bigint) => {
    if (!start || !end) return ''
    const seconds = Number(end - start)
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}m ${secs}s`
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
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-bold tracking-tighter">LIFT</h1>
          <button onClick={onSettings} className="p-2 hover:bg-muted rounded-md transition-colors">
            <Settings className="w-5 h-5" />
          </button>
        </div>

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
          <div className="text-center py-2">
            <span className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Last workout </span>
            <span className="text-lg font-black">{timeSinceLastWorkout}</span>
            <span className="text-xs font-bold uppercase tracking-widest text-muted-foreground"> ago</span>
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
                    className={`relative rounded-lg border p-2 cursor-pointer transition-all text-center ${
                      isSelected
                        ? 'border-primary bg-primary/5 ring-1 ring-primary/20'
                        : 'border-border opacity-50'
                    }`}
                    onClick={() => toggleExercise(s.exercise, s.alwaysInclude)}
                  >
                    {/* Selection icon */}
                    <div className="absolute top-1 right-1">
                      {s.alwaysInclude ? (
                        <Lock className="w-2.5 h-2.5 text-primary" />
                      ) : isSelected ? (
                        <Check className="w-2.5 h-2.5 text-primary" />
                      ) : null}
                    </div>

                    {/* Recovery dot */}
                    <div className="absolute top-1 left-1">
                      <div className={`w-1.5 h-1.5 rounded-full ${
                        s.recovered ? 'bg-green-500' : 'bg-amber-500'
                      }`} />
                    </div>

                    {/* Exercise name */}
                    <div className="text-[10px] font-black uppercase tracking-tight leading-tight mt-1">
                      {SHORT_NAMES[s.exercise as Exercise] || '?'}
                    </div>

                    {/* Weight */}
                    <div className="text-sm font-black tabular-nums leading-none mt-0.5">
                      {s.targetWeight}
                    </div>

                    {/* Sets x Reps */}
                    <div className="text-[8px] font-bold text-muted-foreground uppercase">
                      {s.defaultSets}x{s.defaultReps}
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

        {/* History */}
        <Button
          onClick={onViewHistory}
          variant="outline"
          className="w-full text-xs uppercase tracking-widest font-bold"
        >
          View All Progress Charts
        </Button>

        {workoutHistory.length > 0 && (
          <Card className="opacity-70 hover:opacity-100 transition-opacity">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs uppercase tracking-widest text-muted-foreground font-bold">History</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-1">
                {workoutHistory.slice(0, 5).map((workout) => (
                  <li
                    key={workout.id}
                    className="p-2 hover:bg-muted rounded-md flex justify-between items-center cursor-pointer transition-colors"
                    onClick={() => onViewWorkout(workout.id)}
                  >
                    <div className="flex flex-col">
                      <span className="font-bold uppercase text-sm tracking-tight">
                        {workout.name || 'Workout'}
                      </span>
                      <span className="text-[10px] text-muted-foreground uppercase font-bold">
                        {workout.endTime > 0n ? formatDuration(workout.startTime, workout.endTime) : 'In Progress'}
                      </span>
                    </div>
                    <span className="text-[10px] font-bold uppercase text-muted-foreground">
                      {formatDate(workout.startTime)}
                    </span>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  )
}
