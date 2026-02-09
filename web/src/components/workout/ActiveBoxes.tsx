import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Pencil } from 'lucide-react'
import { type ProposedSet, type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { EXERCISE_NAMES } from '@/lib/exercises'
import { useElapsed, useCountdown, fmtElapsed } from '@/hooks/useTimer'

export function RestingBox({ restUntil, nextSet, onStartEarly, onEditWeight, onSkipWarmup }: {
  restUntil: number
  nextSet?: ProposedSet
  onStartEarly: () => void
  onEditWeight?: () => void
  onSkipWarmup?: () => void
}) {
  const remaining = useCountdown(restUntil)
  if (remaining <= 0) return null

  return (
    <Card className="border-2 border-blue-500/50 bg-blue-500/5">
      <CardContent className="pt-6 pb-4">
        <div className="text-center">
          <p className="text-sm text-muted-foreground mb-1">Rest</p>
          <p className="text-5xl font-bold font-mono">
            {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, '0')}
          </p>
          {nextSet && (
            <p className="text-sm text-muted-foreground mt-3">
              Up next: {EXERCISE_NAMES[nextSet.exercise as Exercise]} {nextSet.targetReps}&times;{nextSet.targetWeight}lbs
              {nextSet.warmup && ' (Warmup)'}
              {onEditWeight && (
                <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
                  <Pencil className="w-3.5 h-3.5" />
                </button>
              )}
            </p>
          )}
          <div className="flex gap-2 justify-center mt-3">
            <Button onClick={onStartEarly}>Start Next Set Early</Button>
            {nextSet?.warmup && onSkipWarmup && (
              <Button variant="ghost" onClick={onSkipWarmup} className="text-muted-foreground">Skip</Button>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

export function ActiveSetBox({ proposedSet, completedSet, onComplete, onEditWeight, onSkip }: {
  proposedSet: ProposedSet
  completedSet: CompletedSet
  onComplete: (reps: number) => void
  onEditWeight: () => void
  onSkip?: () => void
}) {
  const elapsed = useElapsed(Number(completedSet.startedAt))
  const [loading, setLoading] = useState(false)
  const maxReps = proposedSet.targetReps
  const buttons = Array.from({ length: maxReps + 1 }, (_, i) => i)

  return (
    <Card className={`border-2 ${proposedSet.warmup ? 'border-blue-500' : 'border-primary'}`}>
      <CardContent className="pt-6 pb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm text-muted-foreground">
            {EXERCISE_NAMES[proposedSet.exercise as Exercise]}
            {proposedSet.warmup && ' (Warmup)'}
          </span>
          <span className="font-mono text-muted-foreground">{fmtElapsed(elapsed)}</span>
        </div>
        <div className="text-center mb-4">
          <div className="text-3xl font-bold">
            {proposedSet.targetWeight} lbs
            <button onClick={onEditWeight} className="ml-2 inline-flex align-middle text-muted-foreground hover:text-foreground">
              <Pencil className="w-4 h-4" />
            </button>
          </div>
          <div className="text-4xl font-bold text-primary">{proposedSet.targetReps} reps</div>
        </div>
        <div className="text-xs text-muted-foreground mb-2 text-center">How many did you get?</div>
        <div className="flex flex-wrap gap-2 justify-center">
          {buttons.map((n) => (
            <Button
              key={n}
              size="sm"
              variant={n === maxReps ? 'default' : 'outline'}
              onClick={() => { setLoading(true); onComplete(n) }}
              disabled={loading}
              className="min-w-[40px]"
            >
              {n}
            </Button>
          ))}
        </div>
        {proposedSet.warmup && onSkip && (
          <Button variant="ghost" size="sm" className="w-full mt-2 text-muted-foreground" onClick={() => { setLoading(true); onSkip() }} disabled={loading}>
            Skip Warmup
          </Button>
        )}
      </CardContent>
    </Card>
  )
}

const CHAT_MESSAGES = [
  "The barbell misses you...",
  "Your gains are evaporating",
  "Less yapping, more repping!",
  "The weights aren't gonna lift themselves",
  "Sir, this is a gym",
  "Your muscles are falling asleep",
  "Chat time's over... any minute now",
  "The squat rack is judging you",
]

export function ChatTimeBox({ restEndedAt, nextSet, onStart, loading, onEditWeight, onSkipWarmup }: {
  restEndedAt: number
  nextSet: ProposedSet
  onStart: () => void
  loading: boolean
  onEditWeight: () => void
  onSkipWarmup?: () => void
}) {
  const elapsed = useElapsed(restEndedAt)
  const [message] = useState(() => CHAT_MESSAGES[Math.floor(Math.random() * CHAT_MESSAGES.length)])

  return (
    <Card className="border-2 border-orange-500/50 bg-orange-500/5">
      <CardContent className="pt-6 pb-4">
        <div className="text-center">
          <p className="text-sm text-muted-foreground mb-1">Chat Time</p>
          <p className="text-4xl font-bold font-mono text-orange-500">
            {fmtElapsed(elapsed)}
          </p>
          <p className="text-sm text-muted-foreground mt-2 italic">{message}</p>
          <div className="mt-3">
            <p className="text-xs text-muted-foreground mb-1">
              Next: {EXERCISE_NAMES[nextSet.exercise as Exercise]} {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
              {nextSet.warmup && ' (Warmup)'}
              <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
                <Pencil className="w-3.5 h-3.5" />
              </button>
            </p>
            <div className="flex gap-2 justify-center">
              <Button onClick={onStart} disabled={loading}>Start Set</Button>
              {nextSet.warmup && onSkipWarmup && (
                <Button variant="ghost" onClick={onSkipWarmup} disabled={loading} className="text-muted-foreground">Skip</Button>
              )}
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

export function NextUpBox({ nextSet, onStart, loading, onEditWeight, onSkipWarmup }: {
  nextSet: ProposedSet
  onStart: () => void
  loading: boolean
  onEditWeight: () => void
  onSkipWarmup?: () => void
}) {
  return (
    <Card className="border-2 border-dashed border-muted-foreground/30">
      <CardContent className="pt-6 pb-4">
        <div className="text-center">
          <p className="text-sm text-muted-foreground mb-1">Next up</p>
          <p className="text-lg font-bold">
            {EXERCISE_NAMES[nextSet.exercise as Exercise]}
            {nextSet.warmup && <span className="ml-2 text-xs bg-blue-500/20 text-blue-600 px-1.5 py-0.5 rounded">Warmup</span>}
          </p>
          <p className="text-muted-foreground">
            {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
            <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
              <Pencil className="w-3.5 h-3.5" />
            </button>
          </p>
          <div className="flex gap-2 justify-center mt-3">
            <Button onClick={onStart} disabled={loading}>Start Set</Button>
            {nextSet.warmup && onSkipWarmup && (
              <Button variant="ghost" onClick={onSkipWarmup} disabled={loading} className="text-muted-foreground">Skip</Button>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
