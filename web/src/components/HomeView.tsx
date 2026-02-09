import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { workoutClient, userClient, withUserId } from '@/lib/client'
import type { Workout, ProposedWorkout, ProposedSet } from '@/gen/workout/v1/workout_pb'
import { Exercise } from '@/gen/workout/v1/workout_pb'
import { SessionHeader } from './SessionHeader'

const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: 'Select Exercise',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench Press',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'Overhead Press',
  [Exercise.BARBELL_ROW]: 'Barbell Row',
}

const EXERCISE_EMOJIS: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '❓',
  [Exercise.SQUAT]: '🦵',
  [Exercise.BENCH_PRESS]: '🏋️',
  [Exercise.DEADLIFT]: '⚡',
  [Exercise.OVERHEAD_PRESS]: '🙌',
  [Exercise.BARBELL_ROW]: '🚣',
}

interface HomeViewProps {
  userId: string
  onLogout: () => void
  onStartWorkout: (workoutId: string) => void
  onViewWorkout: (workoutId: string) => void
}

function groupSetsByExercise(sets: ProposedSet[]) {
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

export function HomeView({ userId, onLogout, onStartWorkout, onViewWorkout }: HomeViewProps) {
  const [userName, setUserName] = useState<string>('')
  const [workoutHistory, setWorkoutHistory] = useState<Workout[]>([])
  const [proposedWorkouts, setProposedWorkouts] = useState<ProposedWorkout[]>([])
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
      setProposedWorkouts(scheduleRes.proposedWorkouts)
    } catch (e) {
      console.error('Failed to load data:', e)
    }
  }

  const handleStartWorkout = async (proposedWorkout?: ProposedWorkout) => {
    setLoading(true)
    setError(null)
    try {
      const name = proposedWorkout?.name || ''
      const sets = proposedWorkout?.proposedSets || []
      const response = await workoutClient.startWorkout(
        { name, proposedSets: sets },
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

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Lift</h1>
          <div className="flex items-center gap-2">
            <Button variant="ghost" onClick={onLogout}>
              Logout
            </Button>
          </div>
        </div>

        <SessionHeader userId={userId} />

        <p className="text-muted-foreground">Welcome, {userName || userId}</p>

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md">
            {error}
          </div>
        )}

        {/* Workout in Progress */}
        {activeWorkout ? (
          <Card className="border-2 border-primary animate-pulse">
            <CardHeader className="text-center">
              <CardTitle className="text-primary">Workout in Progress</CardTitle>
              <CardDescription>You have an active workout session</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col items-center gap-4">
              <div className="text-center">
                <p className="text-xl font-bold">{activeWorkout.name || 'Custom Workout'}</p>
                <p className="text-sm text-muted-foreground">Started at {new Date(Number(activeWorkout.startTime) * 1000).toLocaleTimeString()}</p>
              </div>
              <Button 
                className="w-full h-12 text-lg font-bold"
                onClick={() => onStartWorkout(activeWorkout.id)}
              >
                Resume Workout
              </Button>
            </CardContent>
          </Card>
        ) : (
          <>
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
                        <div className="flex flex-wrap gap-1.5 mt-1">
                          {exerciseGroups.map((g, i) => (
                            <span
                              key={i}
                              className="inline-flex items-center gap-1 rounded-full bg-background border px-2.5 py-1 text-xs font-medium"
                            >
                              <span>{EXERCISE_EMOJIS[g.exercise]}</span>
                              <span>{EXERCISE_NAMES[g.exercise]}</span>
                              <span className="text-muted-foreground">
                                {g.sets.length}&times;{g.sets[0]?.targetReps} &middot; {g.sets[0]?.targetWeight}lbs
                              </span>
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
          </>
        )}

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
                    onClick={() => onViewWorkout(workout.id)}
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