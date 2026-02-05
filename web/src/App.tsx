import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { workoutClient } from '@/lib/client'
import type { Workout } from '@/gen/workout/v1/workout_pb'

function App() {
  const [userId, setUserId] = useState('')
  const [workouts, setWorkouts] = useState<Workout[]>([])
  const [currentWorkout, setCurrentWorkout] = useState<Workout | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const handleStartWorkout = async () => {
    if (!userId.trim()) {
      setError('Please enter a user ID')
      return
    }

    setLoading(true)
    setError(null)

    try {
      const response = await workoutClient.startWorkout({ userId })
      if (response.workout) {
        setCurrentWorkout(response.workout)
        setWorkouts(prev => [response.workout!, ...prev])
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to start workout')
    } finally {
      setLoading(false)
    }
  }

  const formatTime = (timestamp: bigint | number | string) => {
    if (!timestamp) return 'N/A'
    return new Date(Number(timestamp) * 1000).toLocaleString()
  }

  return (
    <div className="min-h-screen bg-background p-8">
      <div className="max-w-2xl mx-auto space-y-6">
        <h1 className="text-4xl font-bold text-center mb-8">Lift Workout Tracker</h1>

        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md">
            {error}
          </div>
        )}

        <Card>
          <CardHeader>
            <CardTitle>Start a Workout</CardTitle>
            <CardDescription>Enter your user ID to begin tracking</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex gap-4">
              <Input
                placeholder="User ID"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleStartWorkout()}
              />
              <Button onClick={handleStartWorkout} disabled={loading}>
                {loading ? 'Starting...' : 'Start Workout'}
              </Button>
            </div>
          </CardContent>
        </Card>

        {currentWorkout && (
          <Card>
            <CardHeader>
              <CardTitle>Current Workout</CardTitle>
              <CardDescription>ID: {currentWorkout.id}</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Started: {formatTime(currentWorkout.startTime)}
              </p>
              <div className="mt-4 flex gap-2">
                <Button variant="outline" disabled>
                  Add Set (Not implemented)
                </Button>
                <Button variant="destructive" disabled>
                  End Workout (Not implemented)
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {workouts.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle>Workout History</CardTitle>
              <CardDescription>Your recent workouts this session</CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2">
                {workouts.map((workout) => (
                  <li
                    key={workout.id}
                    className="p-3 bg-muted rounded-md flex justify-between items-center"
                  >
                    <span className="font-mono text-sm">{workout.id.slice(0, 8)}...</span>
                    <span className="text-sm text-muted-foreground">
                      {formatTime(workout.startTime)}
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

export default App
