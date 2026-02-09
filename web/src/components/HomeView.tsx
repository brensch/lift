import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { workoutClient, userClient, withUserId } from '@/lib/client'
import type { Workout } from '@/gen/workout/v1/workout_pb'
import { Exercise, ProposedSetSchema } from '@/gen/workout/v1/workout_pb'
import { create } from '@bufbuild/protobuf'
import { SessionHeader } from './SessionHeader'
import { EXERCISE_NAMES } from '@/lib/exercises'
import { isSameDay, startOfDay, differenceInDays } from 'date-fns'
import Calendar from 'react-calendar'
import 'react-calendar/dist/Calendar.css'

interface HomeViewProps {
  userId: string
  onLogout: () => void
  onStartWorkout: (workoutId: string) => void
  onViewWorkout: (workoutId: string) => void
  onViewHistory: () => void
}

export function HomeView({ userId, onLogout, onStartWorkout, onViewWorkout, onViewHistory }: HomeViewProps) {
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

  const generateWorkoutSets = (workoutName: string) => {
    const getWeight = (ex: Exercise) => scheduleData?.exerciseStatuses.find(s => s.exercise === ex)?.targetWeight || 45
    
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

    const configs: { exercise: Exercise, reps: number, count: number }[] = []
    if (workoutName === 'Workout A') {
      configs.push({ exercise: Exercise.SQUAT, reps: 5, count: 5 })
      configs.push({ exercise: Exercise.BENCH_PRESS, reps: 5, count: 5 })
      configs.push({ exercise: Exercise.BARBELL_ROW, reps: 5, count: 5 })
    } else if (workoutName === 'Workout B') {
      configs.push({ exercise: Exercise.SQUAT, reps: 5, count: 5 })
      configs.push({ exercise: Exercise.OVERHEAD_PRESS, reps: 5, count: 5 })
      configs.push({ exercise: Exercise.DEADLIFT, reps: 5, count: 1 })
    }

    const allSets: any[] = []
    let order = 0
    for (const config of configs) {
      const weight = getWeight(config.exercise)
      // Add warmups
      const warmups = getWarmups(weight)
      for (const wu of warmups) {
        allSets.push(create(ProposedSetSchema, {
          id: crypto.randomUUID(),
          workoutOrder: order++,
          exercise: config.exercise,
          targetReps: wu.reps,
          targetWeight: wu.weight,
          warmup: true
        }))
      }
      // Add working sets
      for (let i = 0; i < config.count; i++) {
        allSets.push(create(ProposedSetSchema, {
          id: crypto.randomUUID(),
          workoutOrder: order++,
          exercise: config.exercise,
          targetReps: config.reps,
          targetWeight: weight,
          warmup: false
        }))
      }
    }
    return allSets
  }

  const handleStartWorkout = async (workoutName: string) => {
    setLoading(true)
    setError(null)
    try {
      const formattedSets = generateWorkoutSets(workoutName)

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

  const nextWorkout = scheduleData?.schedule[0]
  const today = startOfDay(new Date())
  const nextWorkoutDate = nextWorkout ? startOfDay(new Date(Number(nextWorkout.scheduledAt) * 1000)) : null
  const isRestDay = nextWorkoutDate ? !isSameDay(nextWorkoutDate, today) : false
  const daysUntilNext = nextWorkoutDate ? differenceInDays(nextWorkoutDate, today) : 0

  const getWorkoutForDay = (date: Date) => {
    const scheduled = scheduleData?.schedule.find(sw => isSameDay(new Date(Number(sw.scheduledAt) * 1000), date));
    const completed = workoutHistory.find(w => isSameDay(new Date(Number(w.startTime) * 1000), date));
    return { scheduled, completed };
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
              <Card className={isRestDay ? 'opacity-90' : 'border-primary ring-1 ring-primary/20'}>
                <CardHeader className="pb-2">
                  <div className="flex justify-between items-center">
                    <CardTitle className="text-xs uppercase tracking-widest text-muted-foreground font-bold">
                      {isRestDay ? 'Next Up' : 'Today'}
                    </CardTitle>
                    {isRestDay && (
                      <span className="text-[10px] bg-muted px-1.5 py-0.5 rounded font-black uppercase">Rest Day</span>
                    )}
                  </div>
                </CardHeader>
                <CardContent>
                  <p className="text-3xl font-black uppercase mb-1">{scheduleData?.nextRecommendedWorkoutName || 'Workout A'}</p>
                  {isRestDay && (
                    <p className="text-xs font-bold text-muted-foreground mb-4 uppercase">Next session in {daysUntilNext} day{daysUntilNext === 1 ? '' : 's'}</p>
                  )}
                  {!isRestDay && (
                    <p className="text-xs font-bold text-primary mb-4 uppercase tracking-tight">Time to lift.</p>
                  )}
                  <div className="flex flex-col gap-2">
                    <Button 
                      className="w-full font-bold uppercase tracking-tighter" 
                      onClick={() => handleStartWorkout(scheduleData?.nextRecommendedWorkoutName || 'Workout A')}
                      disabled={loading}
                    >
                      {isRestDay ? `Start ${scheduleData?.nextRecommendedWorkoutName}` : 'Start Recommended'}
                    </Button>
                    <Button 
                      variant="outline" 
                      className="w-full text-xs font-bold uppercase"
                      onClick={() => handleStartWorkout((scheduleData?.nextRecommendedWorkoutName || 'Workout A') === 'Workout A' ? 'Workout B' : 'Workout A')}
                      disabled={loading}
                    >
                      Instead, do {(scheduleData?.nextRecommendedWorkoutName || 'Workout A') === 'Workout A' ? 'Workout B' : 'Workout A'}
                    </Button>
                    <Button
                      onClick={() => handleStartWorkout('Custom')}
                      disabled={loading}
                      variant="ghost"
                      className="w-full text-[10px] uppercase tracking-widest font-bold text-muted-foreground mt-1"
                    >
                      Start Custom Session
                    </Button>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-xs uppercase tracking-widest text-muted-foreground font-bold">Calendar</CardTitle>
                </CardHeader>
                <CardContent className="py-2 calendar-container">
                  <Calendar
                    className="border-none w-full"
                    tileContent={({ date, view }) => {
                      if (view !== 'month') return null;
                      const { scheduled, completed } = getWorkoutForDay(date);
                      if (!scheduled && !completed) return null;
                      
                      const type = (completed?.name || scheduled?.workoutName || '').split(' ')[1];
                      if (!type) return null;

                      return (
                        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                          <div className="flex flex-col items-center">
                            <span className={`text-[16px] font-black italic tracking-tighter ${
                              isSameDay(date, today) ? 'text-primary-foreground' : 'text-primary'
                            } ${completed ? 'opacity-100' : 'opacity-40'}`}>
                              {type}
                            </span>
                            {completed && (
                              <div className={`w-1 h-1 rounded-full ${
                                isSameDay(date, today) ? 'bg-primary-foreground' : 'bg-primary'
                              }`} />
                            )}
                          </div>
                        </div>
                      );
                    }}
                    tileClassName={({ date }) => {
                      return isSameDay(date, today) ? 'today-tile' : '';
                    }}
                  />
                </CardContent>
              </Card>
            </div>

            {/* Exercise Status Grid */}
            <div className="space-y-4">
              <h2 className="text-xs uppercase tracking-widest text-muted-foreground font-bold px-1">Exercises</h2>
              <div className="grid grid-cols-1 gap-3">
                {scheduleData?.exerciseStatuses?.map(s => {
                  const history = s.weightHistory || []
                  const max = Math.max(...history, s.targetWeight)
                  const min = Math.min(...history, s.targetWeight)
                  const range = max - min || 10
                  
                  // Simple SVG trendline
                  let points = ""
                  try {
                    points = history.map((w: number, i: number) => {
                      const x = (i / (history.length - 1 || 1)) * 100
                      const y = 20 - ((w - min) / range) * 20
                      return `${x},${y}`
                    }).join(' ')
                  } catch (e) {
                    console.error("Failed to generate trendline points", e)
                  }

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
                            <span className="text-sm font-black uppercase tracking-tight truncate">{EXERCISE_NAMES[s.exercise] || 'Unknown'}</span>
                            <div className="flex items-center gap-2">
                              {history.length > 1 && points && (
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
                                      if (!lastPoint || lastPoint.length < 2) return null;
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
              <Button
                onClick={onViewHistory}
                variant="outline"
                className="w-full text-xs uppercase tracking-widest font-bold"
              >
                View All Progress Charts
              </Button>
            </div>
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
