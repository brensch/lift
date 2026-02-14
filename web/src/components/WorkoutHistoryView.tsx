import { useState, useEffect } from 'react'
import { workoutClient, withUserId } from '@/lib/client'
import type { Workout } from '@/gen/workout/v1/workout_pb'
import { SessionHeader } from '@/components/SessionHeader'
import { LoadingBlock } from '@/components/ui/loading'

interface WorkoutHistoryViewProps {
  userId: string
  onViewWorkout: (workoutId: string) => void
}

interface WorkoutSummary extends Workout {
  totalVolume: number
  durationSeconds: number
}

export function WorkoutHistoryView({ userId, onViewWorkout }: WorkoutHistoryViewProps) {
  const [summaries, setSummaries] = useState<WorkoutSummary[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchHistory() {
      try {
        const listRes = await workoutClient.listWorkouts({}, withUserId(userId))
        const pastWorkouts = listRes.workouts
          .filter(w => w.endTime > 0n)
          .sort((a, b) => Number(b.startTime - a.startTime))

        const detailedSummaries = await Promise.all(
          pastWorkouts.map(async (w) => {
            try {
              const res = await workoutClient.getWorkout({ workoutId: w.id }, withUserId(userId))
              const volume = res.completedSets.reduce((acc, set) => acc + (set.actualWeight * set.actualReps), 0)
              const duration = Number(w.endTime - w.startTime)
              return { ...w, totalVolume: volume, durationSeconds: duration }
            } catch (e) {
              return { ...w, totalVolume: 0, durationSeconds: 0 }
            }
          })
        )
        setSummaries(detailedSummaries)
      } catch (e) {
        console.error('Failed to fetch workout history:', e)
      } finally {
        setLoading(false)
      }
    }
    fetchHistory()
  }, [userId])

  const formatDate = (timestamp: bigint) => {
    return new Date(Number(timestamp) * 1000).toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    })
  }

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}m ${secs}s`
  }

  return (
    <div className="min-h-screen bg-background p-4 pt-0">
      <div className="max-w-2xl mx-auto space-y-6">
        <SessionHeader userId={userId} />

        {loading ? (
          <LoadingBlock text="Loading past sessions..." />
        ) : summaries.length === 0 ? (
          <div className="text-center py-12 text-muted-foreground uppercase text-xs tracking-widest">
            No workouts recorded yet.
          </div>
        ) : (
          <div className="space-y-3">
            {summaries.map((w) => (
              <div
                key={w.id}
                onClick={() => onViewWorkout(w.id)}
                className="bg-card border border-border p-4 rounded-xl cursor-pointer hover:bg-muted/50 transition-all flex flex-col gap-2 shadow-sm"
              >
                <div className="flex justify-between items-start">
                  <div className="flex flex-col">
                    <span className="text-xs font-black uppercase tracking-widest text-muted-foreground/50 leading-none mb-1">
                      {formatDate(w.startTime)}
                    </span>
                    <span className="text-lg font-black uppercase tracking-tighter">
                      {w.name || 'Workout'}
                    </span>
                  </div>
                  <div className="text-right flex flex-col items-end">
                    <span className="text-sm font-black text-foreground">
                      {w.totalVolume.toLocaleString()}
                      <span className="text-[10px] text-muted-foreground ml-1">LB</span>
                    </span>
                    <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest">
                      Total Volume
                    </span>
                  </div>
                </div>
                
                <div className="flex items-center gap-4 pt-2 border-t border-border/50">
                   <div className="flex flex-col">
                      <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest leading-none mb-0.5">Duration</span>
                      <span className="text-xs font-black">{formatDuration(w.durationSeconds)}</span>
                   </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
