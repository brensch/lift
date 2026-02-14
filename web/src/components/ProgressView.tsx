import { useState, useEffect } from 'react'
import { type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { groupSetsByExercise } from '@/components/ExerciseGroup'
import { EXERCISE_NAMES } from '@/lib/exercises'
import { workoutClient, withUserId } from '@/lib/client'
import { SessionHeader } from '@/components/SessionHeader'
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, CartesianGrid } from 'recharts'

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

function WeightChart({ history, range }: {
  history: ExerciseHistory[]
  range: TimeRange
}) {
  const now = Math.floor(Date.now() / 1000)
  const cutoff = rangeStartSeconds(range, now)
  const data = history
    .filter((p) => p.date >= cutoff)
    .sort((a, b) => a.date - b.date)
    .map((p) => ({
      date: p.date * 1000,
      weight: p.weight,
    }))

  if (data.length === 0) {
    return <div className="h-[120px] flex items-center justify-center text-xs text-muted-foreground italic">No data for this period</div>
  }

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
          labelFormatter={(ts) => new Date(ts as number).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}
          formatter={(value) => [`${value} lbs`, 'Weight']}
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
      </LineChart>
    </ResponsiveContainer>
  )
}

export function ProgressView({ userId }: { userId: string }) {
  const [historyByExercise, setHistoryByExercise] = useState<Record<number, ExerciseHistory[]>>({})
  const [loading, setLoading] = useState(true)
  const [timeRange, setTimeRange] = useState<TimeRange>('6m')

  useEffect(() => {
    let cancelled = false
    async function fetchHistory() {
      try {
        const listRes = await workoutClient.listWorkouts({}, withUserId(userId))
        const pastWorkouts = listRes.workouts
          .filter((w) => w.endTime > 0n)
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
          setLoading(false)
        }
      } catch (e) {
        console.error('Failed to fetch history:', e)
        if (!cancelled) setLoading(false)
      }
    }
    fetchHistory()
    return () => { cancelled = true }
  }, [userId])

  const exercisesWithHistory = Object.keys(historyByExercise).map(Number).sort()

  return (
    <div className="min-h-screen bg-background p-4 pt-0">
      <div className="max-w-2xl mx-auto space-y-4">
        <SessionHeader userId={userId} />

        {/* Time range selector */}
        <div className="flex gap-1 justify-center py-2">
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

        {loading ? (
          <div className="text-center py-8 text-muted-foreground italic">Loading history...</div>
        ) : exercisesWithHistory.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">No workout history found yet.</div>
        ) : (
          <div className="space-y-4">
            {exercisesWithHistory.map((ex) => (
              <div key={ex} className="bg-muted/50 rounded-lg border p-3 space-y-2">
                <div className="font-bold text-sm">{EXERCISE_NAMES[ex as Exercise]}</div>
                <WeightChart
                  history={historyByExercise[ex]}
                  range={timeRange}
                />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
