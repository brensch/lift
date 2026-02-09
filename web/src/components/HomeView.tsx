import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { workoutClient, userClient, withUserId } from '@/lib/client'
import type { Workout, ProposedWorkout, ProposedSet } from '@/gen/workout/v1/workout_pb'
import { Exercise } from '@/gen/workout/v1/workout_pb'
import { SessionHeader } from './SessionHeader'
import { EXERCISE_NAMES, EXERCISE_EMOJIS } from '@/lib/exercises'

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

        <p className="text-muted-foreground">Hi, {userName || userId}</p>

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
            {/* Schedule */}
            {proposedWorkouts.length > 0 && (() => {
              const nextDate = new Date(Number(proposedWorkouts[0].scheduledFor) * 1000)
              const today = new Date()
              today.setHours(0, 0, 0, 0)
              nextDate.setHours(0, 0, 0, 0)
              const daysUntil = Math.round((nextDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
              const isToday = daysUntil <= 0

              // Track which workout names have had a Start button
              const startShown = new Set<string>()

              return (
                <div className="space-y-2">
                  {!isToday && (
                    <div className="rounded-lg border border-dashed p-3 text-center text-muted-foreground">
                      Rest day — next workout in {daysUntil} {daysUntil === 1 ? 'day' : 'days'}
                    </div>
                  )}
                  {proposedWorkouts.map((pw, idx) => {
                    const exerciseGroups = groupSetsByExercise(pw.proposedSets)
                    const showStart = !startShown.has(pw.name)
                    if (showStart) startShown.add(pw.name)

                    return (
                      <div
                        key={idx}
                        className={`rounded-lg border p-3 ${
                          idx === 0 && isToday ? 'border-primary bg-primary/5' : ''
                        }`}
                      >
                        <div className="flex items-baseline gap-2">
                          <span className={`font-bold ${idx === 0 && isToday ? 'text-primary' : ''}`}>
                            {idx === 0 && isToday ? 'Today' : formatDate(pw.scheduledFor)}
                          </span>
                          <span className="text-sm text-muted-foreground">{pw.name}</span>
                        </div>
                        <div className="flex flex-wrap gap-1.5 mt-2">
                          {exerciseGroups.map((g, i) => {
                            const workingSets = g.sets.filter((s) => !s.warmup)
                            return (
                              <span
                                key={i}
                                className="inline-flex items-center gap-1 rounded-full bg-background border px-2.5 py-0.5 text-xs font-medium"
                              >
                                <span>{EXERCISE_EMOJIS[g.exercise]}</span>
                                <span>{EXERCISE_NAMES[g.exercise]}</span>
                                <span className="text-muted-foreground">
                                  {workingSets.length}&times;{workingSets[0]?.targetReps} &middot; {workingSets[0]?.targetWeight}lbs
                                </span>
                              </span>
                            )
                          })}
                        </div>
                        {showStart && (
                          <Button
                            className="w-full mt-3"
                            variant={idx === 0 ? 'default' : 'outline'}
                            onClick={() => handleStartWorkout(pw)}
                            disabled={loading}
                          >
                            {loading ? 'Starting...' : `Start ${pw.name}`}
                          </Button>
                        )}
                      </div>
                    )
                  })}
                </div>
              )
            })()}

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