import { useState, useEffect, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { workoutClient, withUserId } from '@/lib/client'
import { create } from '@bufbuild/protobuf'
import {
  type Workout,
  type ProposedSet,
  type CompletedSet,
  type ProposedWorkout,
  Exercise,
  ProposedSetSchema,
} from '@/gen/workout/v1/workout_pb'

type AppView = 'login' | 'home' | 'workout'

const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: 'Select Exercise',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench Press',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'Overhead Press',
  [Exercise.BARBELL_ROW]: 'Barbell Row',
}

function App() {
  const [view, setView] = useState<AppView>('login')
  const [userId, setUserId] = useState('')
  const [currentUserId, setCurrentUserId] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  // Workout state
  const [currentWorkoutId, setCurrentWorkoutId] = useState<string | null>(null)
  const [currentWorkout, setCurrentWorkout] = useState<Workout | null>(null)
  const [proposedSets, setProposedSets] = useState<ProposedSet[]>([])
  const [completedSets, setCompletedSets] = useState<CompletedSet[]>([])
  const [workoutHistory, setWorkoutHistory] = useState<Workout[]>([])
  const [proposedWorkouts, setProposedWorkouts] = useState<ProposedWorkout[]>([])

  // New set form
  const [newSetExercise, setNewSetExercise] = useState<Exercise>(Exercise.SQUAT)
  const [newSetReps, setNewSetReps] = useState(5)
  const [newSetWeight, setNewSetWeight] = useState(135)
  const [newSetWarmup, setNewSetWarmup] = useState(false)

  // Set completion form
  const [completingSetId, setCompletingSetId] = useState<string | null>(null)
  const [actualReps, setActualReps] = useState(0)
  const [actualWeight, setActualWeight] = useState(0)
  const [restSeconds, setRestSeconds] = useState(180)

  // Rest timer
  const [restEndTime, setRestEndTime] = useState<number | null>(null)
  const [restRemaining, setRestRemaining] = useState(0)

  // Rest timer effect
  useEffect(() => {
    if (!restEndTime) return

    const interval = setInterval(() => {
      const remaining = Math.max(0, restEndTime - Date.now())
      setRestRemaining(Math.ceil(remaining / 1000))
      if (remaining <= 0) {
        setRestEndTime(null)
      }
    }, 100)

    return () => clearInterval(interval)
  }, [restEndTime])

  const handleLogin = async () => {
    if (!userId.trim()) {
      setError('Please enter a user ID')
      return
    }
    setCurrentUserId(userId.trim())
    setView('home')
    setError(null)
    loadWorkoutHistory(userId.trim())
    loadProposedWorkouts(userId.trim())
  }

  const loadWorkoutHistory = async (uid: string) => {
    try {
      const response = await workoutClient.listWorkouts({}, withUserId(uid))
      setWorkoutHistory(response.workouts)
    } catch (e) {
      console.error('Failed to load workout history:', e)
    }
  }

  const loadProposedWorkouts = async (uid: string) => {
    try {
      const response = await workoutClient.getProposedWorkoutSchedule(
        { userId: uid },
        withUserId(uid)
      )
      setProposedWorkouts(response.proposedWorkouts)
    } catch (e) {
      console.error('Failed to load proposed workouts:', e)
    }
  }

  const loadWorkout = useCallback(async (workoutId: string) => {
    try {
      const response = await workoutClient.getWorkout(
        { workoutId },
        withUserId(currentUserId)
      )
      if (response.workout) {
        setCurrentWorkout(response.workout)
        setProposedSets(response.proposedSets)
        setCompletedSets(response.completedSets)
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load workout')
    }
  }, [currentUserId])

  const handleStartWorkout = async (proposedWorkout?: ProposedWorkout) => {
    setLoading(true)
    setError(null)

    try {
      const name = proposedWorkout?.name || ''
      const sets = proposedWorkout?.proposedSets || []

      const response = await workoutClient.startWorkout(
        { name, proposedSets: sets },
        withUserId(currentUserId)
      )
      setCurrentWorkoutId(response.id)
      setView('workout')
      await loadWorkout(response.id)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to start workout')
    } finally {
      setLoading(false)
    }
  }

  const handleAddSet = async () => {
    if (!currentWorkoutId) return

    setLoading(true)
    try {
      const newSet = create(ProposedSetSchema, {
        exercise: newSetExercise,
        targetReps: newSetReps,
        targetWeight: newSetWeight,
        warmup: newSetWarmup,
        workoutOrder: proposedSets.length,
      })

      const response = await workoutClient.modifyProposedSets(
        {
          workoutId: currentWorkoutId,
          proposedSets: [...proposedSets, newSet],
        },
        withUserId(currentUserId)
      )
      setProposedSets(response.proposedSets)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to add set')
    } finally {
      setLoading(false)
    }
  }

  const handleRemoveSet = async (setId: string) => {
    if (!currentWorkoutId) return

    setLoading(true)
    try {
      const filtered = proposedSets.filter(s => s.id !== setId)
      const response = await workoutClient.modifyProposedSets(
        {
          workoutId: currentWorkoutId,
          proposedSets: filtered,
        },
        withUserId(currentUserId)
      )
      setProposedSets(response.proposedSets)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to remove set')
    } finally {
      setLoading(false)
    }
  }

  const handleStartSet = async (proposedSetId: string) => {
    if (!currentWorkoutId) return

    const proposed = proposedSets.find(s => s.id === proposedSetId)
    if (proposed) {
      setActualReps(proposed.targetReps)
      setActualWeight(proposed.targetWeight)
    }
    setCompletingSetId(proposedSetId)
  }

  const handleCompleteSet = async () => {
    if (!currentWorkoutId || !completingSetId) return

    setLoading(true)
    try {
      const response = await workoutClient.completeSet(
        {
          workoutId: currentWorkoutId,
          proposedSetId: completingSetId,
          actualReps,
          actualWeight,
          restSeconds,
        },
        withUserId(currentUserId)
      )

      if (response.completedSet) {
        setCompletedSets(prev => [...prev, response.completedSet!])
        // Start rest timer
        setRestEndTime(Date.now() + restSeconds * 1000)
      }
      setCompletingSetId(null)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to complete set')
    } finally {
      setLoading(false)
    }
  }

  const handleEndWorkout = async () => {
    if (!currentWorkoutId) return

    setLoading(true)
    try {
      await workoutClient.endWorkout(
        { workoutId: currentWorkoutId },
        withUserId(currentUserId)
      )
      setCurrentWorkoutId(null)
      setCurrentWorkout(null)
      setProposedSets([])
      setCompletedSets([])
      setRestEndTime(null)
      setView('home')
      loadWorkoutHistory(currentUserId)
      loadProposedWorkouts(currentUserId)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to end workout')
    } finally {
      setLoading(false)
    }
  }

  const handleViewWorkout = async (workoutId: string) => {
    setCurrentWorkoutId(workoutId)
    await loadWorkout(workoutId)
    setView('workout')
  }

  const formatTime = (timestamp: bigint | number) => {
    if (!timestamp) return 'N/A'
    return new Date(Number(timestamp) * 1000).toLocaleString()
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

  const isSetCompleted = (proposedSetId: string) => {
    return completedSets.some(c => c.proposedSetId === proposedSetId && c.endedAt > 0n)
  }

  const getCompletedSet = (proposedSetId: string) => {
    return completedSets.find(c => c.proposedSetId === proposedSetId && c.endedAt > 0n)
  }

  const isWorkoutEnded = currentWorkout && currentWorkout.endTime > 0n

  // Group sets by exercise for display
  const groupSetsByExercise = (sets: ProposedSet[]) => {
    const groups: { exercise: Exercise; sets: ProposedSet[] }[] = []
    let currentExercise: Exercise | null = null
    let currentGroup: ProposedSet[] = []

    for (const set of sets) {
      if (set.exercise !== currentExercise) {
        if (currentGroup.length > 0 && currentExercise !== null) {
          groups.push({ exercise: currentExercise, sets: currentGroup })
        }
        currentExercise = set.exercise
        currentGroup = [set]
      } else {
        currentGroup.push(set)
      }
    }

    if (currentGroup.length > 0 && currentExercise !== null) {
      groups.push({ exercise: currentExercise, sets: currentGroup })
    }

    return groups
  }

  // Login view
  if (view === 'login') {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-4">
        <Card className="w-full max-w-md">
          <CardHeader className="text-center">
            <CardTitle className="text-3xl font-bold">Lift</CardTitle>
            <CardDescription>Enter your user ID to start tracking</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {error && (
              <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
                {error}
              </div>
            )}
            <Input
              placeholder="User ID"
              value={userId}
              onChange={(e) => setUserId(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleLogin()}
              autoFocus
            />
            <Button onClick={handleLogin} className="w-full">
              Continue
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  // Home view
  if (view === 'home') {
    return (
      <div className="min-h-screen bg-background p-4">
        <div className="max-w-2xl mx-auto space-y-6">
          <div className="flex items-center justify-between">
            <h1 className="text-3xl font-bold">Lift</h1>
            <Button variant="ghost" onClick={() => { setView('login'); setCurrentUserId('') }}>
              Logout
            </Button>
          </div>

          <p className="text-muted-foreground">Welcome, {currentUserId}</p>

          {error && (
            <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md">
              {error}
            </div>
          )}

          {/* Proposed Workouts */}
          {proposedWorkouts.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Your Schedule</CardTitle>
                <CardDescription>StrongLifts 5x5 - Pick a workout to start</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                {proposedWorkouts.map((pw, idx) => {
                  const exerciseGroups = groupSetsByExercise(pw.proposedSets)
                  const isToday = idx === 0

                  return (
                    <div
                      key={idx}
                      className={`p-4 rounded-lg border ${
                        isToday ? 'border-primary bg-primary/5' : 'bg-muted'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <div>
                          <span className={`font-bold ${isToday ? 'text-primary' : ''}`}>
                            {pw.name}
                          </span>
                          <span className="text-sm text-muted-foreground ml-2">
                            {formatDate(pw.scheduledFor)}
                          </span>
                          {isToday && (
                            <span className="ml-2 text-xs bg-primary text-primary-foreground px-2 py-0.5 rounded">
                              Next
                            </span>
                          )}
                        </div>
                        <Button
                          size="sm"
                          onClick={() => handleStartWorkout(pw)}
                          disabled={loading}
                        >
                          Start
                        </Button>
                      </div>
                      <div className="text-sm text-muted-foreground">
                        {exerciseGroups.map((g, i) => (
                          <span key={i}>
                            {i > 0 && ' • '}
                            {EXERCISE_NAMES[g.exercise]} {g.sets.length}×{g.sets[0]?.targetReps} @ {g.sets[0]?.targetWeight}lbs
                          </span>
                        ))}
                      </div>
                    </div>
                  )
                })}
              </CardContent>
            </Card>
          )}

          {/* Custom Workout */}
          <Button
            onClick={() => handleStartWorkout()}
            disabled={loading}
            variant="outline"
            className="w-full"
          >
            {loading ? 'Starting...' : 'Start Custom Workout'}
          </Button>

          {/* Workout History */}
          {workoutHistory.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Workout History</CardTitle>
                <CardDescription>Your previous workouts</CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  {workoutHistory.map((workout) => (
                    <li
                      key={workout.id}
                      className="p-3 bg-muted rounded-md flex justify-between items-center cursor-pointer hover:bg-muted/80 transition-colors"
                      onClick={() => handleViewWorkout(workout.id)}
                    >
                      <div>
                        <span className="font-medium">
                          {workout.name || 'Custom Workout'}
                        </span>
                        <span className="text-sm text-muted-foreground ml-2">
                          {workout.endTime > 0n ? formatDuration(workout.startTime, workout.endTime) : 'In Progress'}
                        </span>
                      </div>
                      <span className="text-sm text-muted-foreground">
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

  // Workout view
  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-4">
        <div className="flex items-center justify-between">
          <Button variant="ghost" onClick={() => { setView('home'); setCurrentWorkoutId(null) }}>
            &larr; Back
          </Button>
          {!isWorkoutEnded && (
            <Button variant="destructive" onClick={handleEndWorkout} disabled={loading}>
              End Workout
            </Button>
          )}
        </div>

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md">
            {error}
          </div>
        )}

        {/* Rest Timer */}
        {restEndTime && restRemaining > 0 && (
          <Card className="border-primary">
            <CardContent className="pt-6">
              <div className="text-center">
                <p className="text-sm text-muted-foreground">Rest Time Remaining</p>
                <p className="text-5xl font-bold font-mono">
                  {Math.floor(restRemaining / 60)}:{String(restRemaining % 60).padStart(2, '0')}
                </p>
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-2"
                  onClick={() => setRestEndTime(null)}
                >
                  Skip Rest
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Workout Info */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle>
              {isWorkoutEnded ? 'Workout Complete' : (currentWorkout?.name || 'Custom Workout')}
            </CardTitle>
            <CardDescription>
              Started: {formatTime(currentWorkout?.startTime || 0n)}
              {isWorkoutEnded && currentWorkout && (
                <> | Duration: {formatDuration(currentWorkout.startTime, currentWorkout.endTime)}</>
              )}
            </CardDescription>
          </CardHeader>
        </Card>

        {/* Set completion modal */}
        {completingSetId && (
          <Card className="border-2 border-primary">
            <CardHeader>
              <CardTitle>Complete Set</CardTitle>
              <CardDescription>
                {EXERCISE_NAMES[proposedSets.find(s => s.id === completingSetId)?.exercise || Exercise.UNSPECIFIED]}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-muted-foreground">Actual Reps</label>
                  <Input
                    type="number"
                    value={actualReps}
                    onChange={(e) => setActualReps(Number(e.target.value))}
                  />
                </div>
                <div>
                  <label className="text-sm text-muted-foreground">Actual Weight (lbs)</label>
                  <Input
                    type="number"
                    value={actualWeight}
                    onChange={(e) => setActualWeight(Number(e.target.value))}
                  />
                </div>
              </div>
              <div>
                <label className="text-sm text-muted-foreground">Rest (seconds)</label>
                <div className="flex gap-2 mt-1">
                  {[60, 90, 120, 180, 300].map((secs) => (
                    <Button
                      key={secs}
                      variant={restSeconds === secs ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setRestSeconds(secs)}
                    >
                      {secs >= 60 ? `${secs / 60}m` : `${secs}s`}
                    </Button>
                  ))}
                </div>
              </div>
              <div className="flex gap-2">
                <Button onClick={handleCompleteSet} disabled={loading} className="flex-1">
                  {loading ? 'Saving...' : 'Complete Set'}
                </Button>
                <Button variant="outline" onClick={() => setCompletingSetId(null)}>
                  Cancel
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Sets list */}
        <Card>
          <CardHeader>
            <CardTitle>Sets</CardTitle>
            <CardDescription>
              {completedSets.filter(c => c.endedAt > 0n).length} / {proposedSets.length} completed
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            {proposedSets.length === 0 ? (
              <p className="text-muted-foreground text-center py-4">No sets added yet</p>
            ) : (
              proposedSets.map((set, idx) => {
                const completed = isSetCompleted(set.id)
                const completedData = getCompletedSet(set.id)

                return (
                  <div
                    key={set.id}
                    className={`p-3 rounded-md border flex items-center justify-between ${
                      completed ? 'bg-green-500/10 border-green-500/30' : 'bg-muted'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <span className="text-lg font-bold text-muted-foreground w-6">
                        {idx + 1}
                      </span>
                      <div>
                        <div className="font-medium">
                          {EXERCISE_NAMES[set.exercise]}
                          {set.warmup && (
                            <span className="ml-2 text-xs bg-yellow-500/20 text-yellow-600 px-1.5 py-0.5 rounded">
                              Warmup
                            </span>
                          )}
                        </div>
                        <div className="text-sm text-muted-foreground">
                          {completed && completedData ? (
                            <span className="text-green-600">
                              {completedData.actualReps} reps @ {completedData.actualWeight} lbs
                            </span>
                          ) : (
                            <span>
                              {set.targetReps} reps @ {set.targetWeight} lbs
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      {!completed && !isWorkoutEnded && (
                        <>
                          <Button
                            size="sm"
                            onClick={() => handleStartSet(set.id)}
                            disabled={!!completingSetId}
                          >
                            Complete
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => handleRemoveSet(set.id)}
                            disabled={loading}
                          >
                            Remove
                          </Button>
                        </>
                      )}
                      {completed && (
                        <span className="text-green-600 text-sm font-medium">Done</span>
                      )}
                    </div>
                  </div>
                )
              })
            )}
          </CardContent>
        </Card>

        {/* Add new set */}
        {!isWorkoutEnded && (
          <Card>
            <CardHeader>
              <CardTitle>Add Set</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <label className="text-sm text-muted-foreground">Exercise</label>
                <select
                  className="w-full mt-1 p-2 border rounded-md bg-background"
                  value={newSetExercise}
                  onChange={(e) => setNewSetExercise(Number(e.target.value) as Exercise)}
                >
                  <option value={Exercise.SQUAT}>Squat</option>
                  <option value={Exercise.BENCH_PRESS}>Bench Press</option>
                  <option value={Exercise.DEADLIFT}>Deadlift</option>
                  <option value={Exercise.OVERHEAD_PRESS}>Overhead Press</option>
                  <option value={Exercise.BARBELL_ROW}>Barbell Row</option>
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-muted-foreground">Target Reps</label>
                  <Input
                    type="number"
                    value={newSetReps}
                    onChange={(e) => setNewSetReps(Number(e.target.value))}
                  />
                </div>
                <div>
                  <label className="text-sm text-muted-foreground">Target Weight (lbs)</label>
                  <Input
                    type="number"
                    value={newSetWeight}
                    onChange={(e) => setNewSetWeight(Number(e.target.value))}
                  />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="warmup"
                  checked={newSetWarmup}
                  onChange={(e) => setNewSetWarmup(e.target.checked)}
                  className="rounded"
                />
                <label htmlFor="warmup" className="text-sm">Warmup set</label>
              </div>
              <Button onClick={handleAddSet} disabled={loading} className="w-full">
                {loading ? 'Adding...' : 'Add Set'}
              </Button>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  )
}

export default App
