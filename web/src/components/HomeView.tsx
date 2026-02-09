import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { workoutClient, userClient, withUserId } from '@/lib/client'
import type { Workout } from '@/gen/workout/v1/workout_pb'
import { Exercise } from '@/gen/workout/v1/workout_pb'
import { SessionHeader } from './SessionHeader'
import { EXERCISE_NAMES } from '@/lib/exercises'

interface HomeViewProps {
  userId: string
  onLogout: () => void
  onStartWorkout: (workoutId: string) => void
  onViewWorkout: (workoutId: string) => void
}

export function HomeView({ userId, onLogout, onStartWorkout, onViewWorkout }: HomeViewProps) {
  const [userName, setUserName] = useState<string>('')
  const [workoutHistory, setWorkoutHistory] = useState<Workout[]>([])
  const [scheduleData, setScheduleData] = useState<{
    exerciseStatuses: any[],
    schedule: any[],
    nextRecommendedWorkoutName: string
  } | null>(null)
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
      setScheduleData({
        exerciseStatuses: scheduleRes.exerciseStatuses,
        schedule: scheduleRes.schedule,
        nextRecommendedWorkoutName: scheduleRes.nextRecommendedWorkoutName
      })
    } catch (e) {
      console.error('Failed to load data:', e)
    }
  }

  const handleStartWorkout = async (workoutName: string) => {
    setLoading(true)
    setError(null)
    try {
      // Find the weights from scheduleData.exerciseStatuses
      const getWeight = (ex: Exercise) => scheduleData?.exerciseStatuses.find(s => s.exercise === ex)?.targetWeight || 45

      let sets: any[] = []
      if (workoutName === 'Workout A') {
        sets = [
          { exercise: Exercise.SQUAT, weight: getWeight(Exercise.SQUAT), reps: 5, count: 5 },
          { exercise: Exercise.BENCH_PRESS, weight: getWeight(Exercise.BENCH_PRESS), reps: 5, count: 5 },
          { exercise: Exercise.BARBELL_ROW, weight: getWeight(Exercise.BARBELL_ROW), reps: 5, count: 5 },
        ]
      } else if (workoutName === 'Workout B') {
        sets = [
          { exercise: Exercise.SQUAT, weight: getWeight(Exercise.SQUAT), reps: 5, count: 5 },
          { exercise: Exercise.OVERHEAD_PRESS, weight: getWeight(Exercise.OVERHEAD_PRESS), reps: 5, count: 5 },
          { exercise: Exercise.DEADLIFT, weight: getWeight(Exercise.DEADLIFT), reps: 5, count: 1 },
        ]
      }

      let workoutOrder = 0
      const formattedSets: any[] = []
      for (const group of sets) {
        for (let i = 0; i < group.count; i++) {
          formattedSets.push({
            workoutOrder: workoutOrder++,
            exercise: group.exercise,
            targetReps: group.reps,
            targetWeight: group.weight,
            warmup: false
          })
        }
      }

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

  const formatRelativeDate = (timestamp: bigint | number) => {
    if (!timestamp || Number(timestamp) === 0) return 'Never'
    const now = Date.now() / 1000
    const diff = now - Number(timestamp)
    const days = Math.floor(diff / 86400)
    if (days === 0) return 'Today'
    if (days === 1) return 'Yesterday'
    return `${days} days ago`
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
          <h1 className="text-3xl font-bold tracking-tighter">LIFT</h1>
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="sm" onClick={onLogout}>
              Logout
            </Button>
          </div>
        </div>

        <SessionHeader userId={userId} />

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
            {error}
          </div>
        )}

        {activeWorkout ? (
          <Card className="border-2 border-primary animate-pulse">
            <CardHeader className="pb-2">
              <CardTitle className="text-primary text-sm uppercase tracking-wider">Active Session</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex justify-between items-end">
                <div>
                  <p className="text-2xl font-black uppercase">{activeWorkout.name || 'Custom Workout'}</p>
                  <p className="text-xs text-muted-foreground">Started {new Date(Number(activeWorkout.startTime) * 1000).toLocaleTimeString()}</p>
                </div>
                <Button 
                  size="lg"
                  className="font-bold uppercase tracking-tighter"
                  onClick={() => onStartWorkout(activeWorkout.id)}
                >
                  Resume
                </Button>
              </div>
            </CardContent>
          </Card>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-xs uppercase tracking-widest text-muted-foreground font-bold">Recommended</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-3xl font-black uppercase mb-4">{scheduleData?.nextRecommendedWorkoutName || 'Workout A'}</p>
                  <div className="flex flex-col gap-2">
                    <Button 
                      className="w-full font-bold uppercase tracking-tighter" 
                      onClick={() => handleStartWorkout(scheduleData?.nextRecommendedWorkoutName || 'Workout A')}
                      disabled={loading}
                    >
                      Start Recommended
                    </Button>
                    <Button 
                      variant="outline" 
                      className="w-full text-xs font-bold uppercase"
                      onClick={() => handleStartWorkout((scheduleData?.nextRecommendedWorkoutName || 'Workout A') === 'Workout A' ? 'Workout B' : 'Workout A')}
                      disabled={loading}
                    >
                      Instead, do {(scheduleData?.nextRecommendedWorkoutName || 'Workout A') === 'Workout A' ? 'Workout B' : 'Workout A'}
                    </Button>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-xs uppercase tracking-widest text-muted-foreground font-bold">Schedule</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="grid grid-cols-3 gap-2">
                    {scheduleData?.schedule.slice(0, 6).map((sw, i) => {
                      const date = new Date(Number(sw.scheduledAt) * 1000)
                      const isToday = date.toDateString() === new Date().toDateString()
                      return (
                        <div 
                          key={i} 
                          className={`p-2 rounded border flex flex-col items-center justify-center ${isToday ? 'border-primary bg-primary/5' : 'bg-muted/30'}`}
                        >
                          <span className="text-[10px] font-bold uppercase text-muted-foreground">{date.toLocaleDateString('en-US', { weekday: 'short' })}</span>
                          <span className="text-sm font-black">{date.toLocaleDateString('en-US', { day: 'numeric' })}</span>
                          <span className="text-[10px] font-bold uppercase text-primary">{sw.workoutName.split(' ')[1]}</span>
                        </div>
                      )
                    })}
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Exercise Status Grid */}
            <div className="space-y-4">
              <h2 className="text-xs uppercase tracking-widest text-muted-foreground font-bold px-1">Exercises</h2>
              <div className="grid grid-cols-1 gap-3">
                {scheduleData?.exerciseStatuses.map(s => {
                  const history = s.weightHistory || []
                  const max = Math.max(...history, s.targetWeight)
                  const min = Math.min(...history, s.targetWeight)
                  const range = max - min || 10
                  
                  // Simple SVG trendline
                  const points = history.map((w: number, i: number) => {
                    const x = (i / (history.length - 1 || 1)) * 100
                    const y = 20 - ((w - min) / range) * 20
                    return `${x},${y}`
                  }).join(' ')

                  return (
                    <Card key={s.exercise} className="overflow-hidden">
                      <div className="flex">
                        <div className="bg-primary/5 w-24 flex-shrink-0 flex flex-col items-center justify-center border-r p-2">
                          <span className="text-[10px] font-black uppercase text-primary/60 tracking-tighter">Target</span>
                          <span className="text-2xl font-black tabular-nums leading-none">{s.targetWeight}</span>
                          <span className="text-[10px] font-bold uppercase text-primary/60">LBS</span>
                        </div>
                        <div className="flex-1 p-3 flex flex-col justify-center min-w-0">
                          <div className="flex justify-between items-center mb-1">
                            <span className="text-sm font-black uppercase tracking-tight truncate">{EXERCISE_NAMES[s.exercise]}</span>
                            <div className="flex items-center gap-2">
                              {history.length > 1 && (
                                <div className="relative w-16 h-6">
                                  <svg 
                                    className="w-full h-full overflow-visible" 
                                    viewBox="-4 -4 108 28" 
                                    preserveAspectRatio="none"
                                  >
                                    <defs>
                                      <linearGradient id={`gradient-${s.exercise}`} x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="0%" stopColor="hsl(var(--primary))" stopOpacity="0.3" />
                                        <stop offset="100%" stopColor="hsl(var(--primary))" stopOpacity="0" />
                                      </linearGradient>
                                    </defs>
                                    {/* Area fill */}
                                    <path
                                      d={`M ${points} V 20 H 0 Z`}
                                      fill={`url(#gradient-${s.exercise})`}
                                      className="transition-all duration-500"
                                    />
                                    {/* The line */}
                                    <polyline
                                      points={points}
                                      fill="none"
                                      stroke="hsl(var(--primary))"
                                      strokeWidth="3"
                                      strokeLinecap="round"
                                      strokeLinejoin="round"
                                      className="transition-all duration-500"
                                    />
                                    {/* Final point highlight */}
                                    {(() => {
                                      const lastPoint = points.split(' ').pop()?.split(',');
                                      if (!lastPoint) return null;
                                      return (
                                        <circle
                                          cx={lastPoint[0]}
                                          cy={lastPoint[1]}
                                          r="3.5"
                                          fill="hsl(var(--primary))"
                                          className="animate-pulse"
                                        />
                                      );
                                    })()}
                                  </svg>
                                </div>
                              )}
                              <span className="text-[10px] font-bold uppercase text-muted-foreground whitespace-nowrap">Last: {formatRelativeDate(s.lastPerformedAt)}</span>
                            </div>
                          </div>
                          <p className="text-xs font-medium text-muted-foreground leading-relaxed">
                            {s.explanation}
                          </p>
                        </div>
                      </div>
                    </Card>
                  )
                })}
              </div>
            </div>

            <Button
              onClick={() => handleStartWorkout('Custom')}
              disabled={loading}
              variant="ghost"
              className="w-full text-xs uppercase tracking-widest font-bold text-muted-foreground"
            >
              Start Custom Session
            </Button>
          </>
        )}

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
                        {workout.name || 'Custom'}
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
