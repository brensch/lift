import { useState, useEffect } from 'react'
import { type Workout, type ProposedSet, type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { groupSetsByExercise } from '@/components/ExerciseGroup'
import { SHORT_NAMES, EXERCISE_NAMES, EXERCISE_EMOJIS } from '@/lib/exercises'
import { fmtElapsed } from '@/hooks/useTimer'
import { SessionHeader } from '@/components/SessionHeader'
import { workoutClient, withUserId } from '@/lib/client'
import { Button } from '@/components/ui/button'
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, CartesianGrid, ReferenceDot } from 'recharts'

function fmtTime(ts: bigint | number) {
  if (!ts) return ''
  return new Date(Number(ts) * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

interface ExerciseHistory {
  date: number // unix seconds
  weight: number
}

type TimeRange = '1m' | '6m' | '1y' | 'all'

const RANGE_LABELS: Record<TimeRange, string> = {
  '1m': '1M',
  '6m': '6M',
  '1y': '1Y',
  'all': 'All',
}

function rangeStartSeconds(range: TimeRange, now: number): number {
  switch (range) {
    case '1m': return now - 30 * 86400
    case '6m': return now - 182 * 86400
    case '1y': return now - 365 * 86400
    case 'all': return 0
  }
}

function WeightChart({ history, currentWeight, currentDate, range }: {
  history: ExerciseHistory[]
  currentWeight: number
  currentDate: number
  range: TimeRange
}) {
  const cutoff = rangeStartSeconds(range, currentDate)
  const allPoints = [
    ...history.filter((p) => p.date >= cutoff),
    { date: currentDate, weight: currentWeight },
  ].sort((a, b) => a.date - b.date)

  const data = allPoints.map((p) => ({
    date: p.date * 1000,
    weight: p.weight,
  }))

  const weights = data.map((d) => d.weight)
  const minW = Math.min(...weights)
  const maxW = Math.max(...weights)
  const pad = Math.max((maxW - minW) * 0.1, 2.5)

  return (
    <ResponsiveContainer width="100%" height={120}>
      <LineChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -16 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="hsl(0 0% 50% / 0.15)" />
        <XAxis
          dataKey="date"
          type="number"
          domain={['dataMin', 'dataMax']}
          tickFormatter={(ts: number) => new Date(ts).toLocaleDateString([], { month: 'short', day: 'numeric' })}
          tick={{ fontSize: 10 }}
          stroke="hsl(0 0% 50% / 0.4)"
          tickLine={false}
        />
        <YAxis
          domain={[Math.floor(minW - pad), Math.ceil(maxW + pad)]}
          tick={{ fontSize: 10 }}
          stroke="hsl(0 0% 50% / 0.4)"
          tickLine={false}
          width={40}
        />
        <Tooltip
          labelFormatter={(ts: number) => new Date(ts).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}
          formatter={(value: number) => [`${value} lbs`, 'Weight']}
          contentStyle={{ fontSize: 12, background: 'hsl(0 0% 10%)', border: '1px solid hsl(0 0% 20%)', borderRadius: 6 }}
          labelStyle={{ color: 'hsl(0 0% 70%)' }}
          itemStyle={{ color: 'hsl(142 76% 50%)' }}
        />
        <Line
          type="monotone"
          dataKey="weight"
          stroke="hsl(142, 76%, 36%)"
          strokeWidth={2}
          dot={{ r: 3, fill: 'hsl(142, 76%, 36%)' }}
          activeDot={{ r: 5, stroke: 'white', strokeWidth: 2 }}
        />
        <ReferenceDot
          x={currentDate * 1000}
          y={currentWeight}
          r={5}
          fill="hsl(142, 76%, 36%)"
          stroke="white"
          strokeWidth={2}
        />
      </LineChart>
    </ResponsiveContainer>
  )
}

export function CompletedWorkoutView({ workout, proposedSets, completedSets, userId, onBack }: {
  workout: Workout
  proposedSets: ProposedSet[]
  completedSets: CompletedSet[]
  userId: string
  onBack: () => void
}) {
  const [historyByExercise, setHistoryByExercise] = useState<Record<number, ExerciseHistory[]>>({})
  const [loadingHistory, setLoadingHistory] = useState(true)
  const [timeRange, setTimeRange] = useState<TimeRange>('6m')

  const totalDuration = Number(workout.endTime - workout.startTime)
  const workoutStart = Number(workout.startTime)

  const entries = completedSets
    .filter((c) => c.endedAt > 0n)
    .map((c) => {
      const proposed = proposedSets.find((p) => p.id === c.proposedSetId)
      return { completed: c, proposed }
    })
    .sort((a, b) => Number(a.completed.startedAt - b.completed.startedAt))

  const groups = groupSetsByExercise(proposedSets)

  const exerciseStats = groups.map((group) => {
    const workingSets = group.sets.filter((s) => !s.warmup)
    const warmupSets = group.sets.filter((s) => s.warmup)
    const completedWorking = workingSets
      .map((s) => completedSets.find((c) => c.proposedSetId === s.id && c.endedAt > 0n))
      .filter(Boolean) as CompletedSet[]
    const completedWarmup = warmupSets
      .map((s) => completedSets.find((c) => c.proposedSetId === s.id && c.endedAt > 0n))
      .filter(Boolean) as CompletedSet[]

    const workingVolume = completedWorking.reduce((sum, c) => sum + c.actualReps * c.actualWeight, 0)
    const warmupVolume = completedWarmup.reduce((sum, c) => sum + c.actualReps * c.actualWeight, 0)
    const workingReps = completedWorking.reduce((sum, c) => sum + c.actualReps, 0)
    const workingWeight = workingSets[0]?.targetWeight || 0

    return {
      exercise: group.exercise,
      workingWeight,
      workingSetsTotal: workingSets.length,
      workingSetsCompleted: completedWorking.length,
      warmupSetsCompleted: completedWarmup.length,
      workingReps,
      workingVolume,
      totalVolume: workingVolume + warmupVolume,
    }
  })

  const totalWorkingVolume = exerciseStats.reduce((sum, s) => sum + s.workingVolume, 0)
  const totalWorkingReps = exerciseStats.reduce((sum, s) => sum + s.workingReps, 0)
  const totalWorkingSets = exerciseStats.reduce((sum, s) => sum + s.workingSetsCompleted, 0)

  useEffect(() => {
    let cancelled = false
    async function fetchHistory() {
      try {
        const listRes = await workoutClient.listWorkouts({}, withUserId(userId))
        const pastWorkouts = listRes.workouts
          .filter((w) => w.endTime > 0n && w.id !== workout.id)
          .sort((a, b) => Number(a.startTime - b.startTime))

        const byExercise: Record<number, ExerciseHistory[]> = {}

        const results = await Promise.all(
          pastWorkouts.map((w) =>
            workoutClient.getWorkout({ workoutId: w.id }, withUserId(userId))
              .then((res) => ({ workout: w, proposedSets: res.proposedSets, completedSets: res.completedSets }))
              .catch(() => null)
          )
        )

        for (const result of results) {
          if (!result) continue
          const { workout: w, proposedSets: ps, completedSets: cs } = result
          const wGroups = groupSetsByExercise(ps)
          for (const g of wGroups) {
            const workingSets = g.sets.filter((s) => !s.warmup)
            const anyCompleted = workingSets.some((s) => cs.some((c) => c.proposedSetId === s.id && c.endedAt > 0n))
            if (!anyCompleted) continue

            const maxWeight = Math.max(
              ...workingSets
                .map((s) => cs.find((c) => c.proposedSetId === s.id && c.endedAt > 0n))
                .filter(Boolean)
                .map((c) => (c as CompletedSet).actualWeight)
            )
            if (!byExercise[g.exercise]) byExercise[g.exercise] = []
            byExercise[g.exercise].push({ date: Number(w.startTime), weight: maxWeight })
          }
        }

        if (!cancelled) {
          setHistoryByExercise(byExercise)
          setLoadingHistory(false)
        }
      } catch (e) {
        console.error('Failed to fetch history:', e)
        if (!cancelled) setLoadingHistory(false)
      }
    }
    fetchHistory()
    return () => { cancelled = true }
  }, [workout.id, userId])

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <button onClick={onBack} className="text-3xl font-bold hover:opacity-80 transition-opacity">
            Lift
          </button>
          <span className="text-sm text-muted-foreground">{fmtElapsed(totalDuration)}</span>
        </div>
        <SessionHeader userId={userId} />
        <div className="text-center py-2">
          <h2 className="text-xl font-bold">{workout.name || 'Workout'}</h2>
          <p className="text-sm text-muted-foreground">
            {new Date(Number(workout.startTime) * 1000).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}
          </p>
        </div>

        {/* Timeline bar */}
        {totalDuration > 0 && (
          <div className="relative h-10 bg-muted rounded-full overflow-hidden">
            {entries.map((e, i) => {
              const start = Number(e.completed.startedAt) - workoutStart
              const end = Number(e.completed.endedAt) - workoutStart
              const left = (start / totalDuration) * 100
              const width = Math.max(((end - start) / totalDuration) * 100, 0.5)
              const midLeft = left + width / 2
              const emoji = e.proposed ? EXERCISE_EMOJIS[e.proposed.exercise as Exercise] : '?'
              const hitTarget = e.proposed && e.completed.actualReps >= e.proposed.targetReps
              return (
                <div key={i}>
                  <div
                    className={`absolute top-0 h-full ${hitTarget ? 'bg-green-500' : 'bg-yellow-500'}`}
                    style={{ left: `${left}%`, width: `${width}%` }}
                  />
                  <span
                    className="absolute text-sm select-none pointer-events-none"
                    style={{ left: `${midLeft}%`, top: '50%', transform: 'translate(-50%, -50%)' }}
                  >
                    {emoji}
                  </span>
                </div>
              )
            })}
          </div>
        )}

        {/* Totals */}
        <div className="grid grid-cols-3 gap-2">
          <div className="bg-muted rounded-md px-3 py-2 text-center">
            <div className="text-lg font-bold">{totalWorkingSets}</div>
            <div className="text-xs text-muted-foreground">Working Sets</div>
          </div>
          <div className="bg-muted rounded-md px-3 py-2 text-center">
            <div className="text-lg font-bold">{totalWorkingReps}</div>
            <div className="text-xs text-muted-foreground">Working Reps</div>
          </div>
          <div className="bg-muted rounded-md px-3 py-2 text-center">
            <div className="text-lg font-bold">{totalWorkingVolume >= 1000 ? `${(totalWorkingVolume / 1000).toFixed(1)}k` : totalWorkingVolume}</div>
            <div className="text-xs text-muted-foreground">Volume (lbs)</div>
          </div>
        </div>

        {/* Time range selector */}
        <div className="flex gap-1 justify-center">
          {(['1m', '6m', '1y', 'all'] as TimeRange[]).map((r) => (
            <button
              key={r}
              onClick={() => setTimeRange(r)}
              className={`px-3 py-1 text-xs rounded-full font-medium transition-colors ${
                timeRange === r
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-muted text-muted-foreground hover:text-foreground'
              }`}
            >
              {RANGE_LABELS[r]}
            </button>
          ))}
        </div>

        {/* Per-exercise breakdown */}
        <div className="space-y-3">
          {exerciseStats.map((stat, i) => (
            <div key={i} className="bg-muted/50 rounded-lg border p-3 space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-bold text-sm">{EXERCISE_NAMES[stat.exercise as Exercise]}</span>
                <span className="text-sm font-mono">
                  {stat.workingSetsCompleted}/{stat.workingSetsTotal} @ {stat.workingWeight} lbs
                </span>
              </div>
              <div className="flex gap-3 text-xs text-muted-foreground">
                <span>{stat.workingReps} reps</span>
                <span>{stat.workingVolume.toLocaleString()} lbs vol</span>
                {stat.warmupSetsCompleted > 0 && <span>+{stat.warmupSetsCompleted} warmup</span>}
              </div>
              {loadingHistory ? (
                <div className="text-xs text-muted-foreground italic px-1">Loading history...</div>
              ) : (
                <WeightChart
                  history={historyByExercise[stat.exercise] || []}
                  currentWeight={stat.workingWeight}
                  currentDate={Number(workout.startTime)}
                  range={timeRange}
                />
              )}
            </div>
          ))}
        </div>

        {/* Set Log */}
        <div className="space-y-1">
          <div className="text-xs text-muted-foreground font-medium px-1 mb-1">
            Set Log
          </div>
          <div className="space-y-0.5">
            {entries.map((entry, i) => (
              <div key={i} className="text-xs px-2 py-1 rounded flex items-center gap-2 bg-muted/50">
                <span className="font-medium w-12 shrink-0 truncate">
                  {entry.proposed ? SHORT_NAMES[entry.proposed.exercise as Exercise] : '?'}
                </span>
                <span className="font-medium">
                  {entry.completed.actualReps}&times;{entry.completed.actualWeight}
                  {entry.proposed?.warmup ? ' (w)' : ''}
                </span>
                <span className="text-muted-foreground font-mono ml-auto">{fmtTime(entry.completed.endedAt)}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Back to Home */}
        <div className="pt-4 pb-8">
          <Button onClick={onBack} variant="outline" className="w-full">
            Back to Home
          </Button>
        </div>
      </div>
    </div>
  )
}
