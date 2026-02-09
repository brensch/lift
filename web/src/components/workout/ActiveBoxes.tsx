import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Pencil, User as UserIcon } from 'lucide-react'
import { type ProposedSet, type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { type ParticipantStatus } from '@/gen/workout/v1/group_pb'
import { EXERCISE_NAMES } from '@/lib/exercises'
import { useElapsed, useCountdown, fmtElapsed } from '@/hooks/useTimer'
import { cn } from '@/lib/utils'

interface ActionBoxProps {
  children: React.ReactNode
  className?: string
  borderColor?: string
  bgColor?: string
  title?: React.ReactNode
  icon?: React.ReactNode
  label?: string
}

function ActionBox({ children, className, borderColor, bgColor, title, icon, label }: ActionBoxProps) {
  return (
    <Card className={cn("border-2 transition-colors relative overflow-hidden", borderColor, bgColor, className)}>
      {label && (
        <div className="absolute top-0 right-0 bg-muted-foreground/10 text-muted-foreground text-[10px] font-bold px-2 py-1 rounded-bl-lg uppercase tracking-wider">
          {label}
        </div>
      )}
      <CardContent className="pt-6 pb-4">
        {(title || icon) && (
          <div className="flex items-center justify-center gap-2 mb-2 text-muted-foreground">
            {icon}
            {title && <span className="text-sm font-medium uppercase tracking-wider">{title}</span>}
          </div>
        )}
        {children}
      </CardContent>
    </Card>
  )
}

export function GroupNextUpBox({ participant, restUntil, nextSet }: {
  participant: ParticipantStatus
  restUntil: number
  nextSet?: ProposedSet
}) {
  const remaining = useCountdown(restUntil)
  const isChatting = remaining <= 0

  if (!nextSet) return null

  return (
    <ActionBox
      label="Group"
      borderColor="border-purple-500/30"
      bgColor="bg-purple-500/5"
      icon={<UserIcon className="w-4 h-4" />}
      title={
        <span>
          <span className="font-bold text-foreground">{participant.user?.name || 'Someone'}</span> is {isChatting ? 'chatting' : 'resting'}
        </span>
      }
    >
      <div className="text-center">
        {isChatting ? (
           <p className="text-lg font-mono text-purple-600 font-semibold animate-pulse">
             Overdue
           </p>
        ) : (
          <p className="text-3xl font-bold font-mono text-foreground/80">
            {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, '0')}
          </p>
        )}
        
        <div className="mt-2 text-sm text-muted-foreground">
          Up next: <span className="font-medium text-foreground">{EXERCISE_NAMES[nextSet.exercise as Exercise]}</span>
          <span className="mx-1">•</span>
          {nextSet.targetReps} &times; {nextSet.targetWeight}lbs
        </div>
      </div>
    </ActionBox>
  )
}

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
    <ActionBox
      label="You"
      borderColor="border-blue-500/50"
      bgColor="bg-blue-500/5"
      title="Resting"
    >
      <div className="text-center">
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
    </ActionBox>
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
    <ActionBox
      label="You"
      borderColor={proposedSet.warmup ? 'border-blue-500' : 'border-primary'}
      className="shadow-sm"
    >
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm text-muted-foreground font-medium uppercase tracking-wide">
          {EXERCISE_NAMES[proposedSet.exercise as Exercise]}
          {proposedSet.warmup && ' (Warmup)'}
        </span>
        <span className="font-mono text-muted-foreground">{fmtElapsed(elapsed)}</span>
      </div>
      <div className="text-center mb-6">
        <div className="text-3xl font-bold flex items-center justify-center gap-2">
          {proposedSet.targetWeight} <span className="text-lg text-muted-foreground font-normal">lbs</span>
          <button onClick={onEditWeight} className="inline-flex text-muted-foreground hover:text-foreground">
            <Pencil className="w-4 h-4" />
          </button>
        </div>
        <div className="text-5xl font-black text-primary mt-1">{proposedSet.targetReps} <span className="text-2xl text-muted-foreground font-medium">reps</span></div>
      </div>
      
      <div className="text-center space-y-3">
        <div className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Log Reps</div>
        <div className="flex flex-wrap gap-2 justify-center">
          {buttons.map((n) => (
            <Button
              key={n}
              size="lg"
              variant={n === maxReps ? 'default' : 'outline'}
              onClick={() => { setLoading(true); onComplete(n) }}
              disabled={loading}
              className="min-w-[48px] h-12 text-lg font-bold"
            >
              {n}
            </Button>
          ))}
        </div>
      </div>
      
      {proposedSet.warmup && onSkip && (
        <Button variant="ghost" size="sm" className="w-full mt-4 text-muted-foreground hover:text-foreground" onClick={() => { setLoading(true); onSkip() }} disabled={loading}>
          Skip Warmup
        </Button>
      )}
    </ActionBox>
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
    <ActionBox
      label="You"
      borderColor="border-orange-500/50"
      bgColor="bg-orange-500/5"
      title="Chat Time"
    >
      <div className="text-center">
        <p className="text-4xl font-bold font-mono text-orange-500">
          {fmtElapsed(elapsed)}
        </p>
        <p className="text-sm text-muted-foreground mt-2 italic">"{message}"</p>
        <div className="mt-4 pt-4 border-t border-orange-500/20">
          <p className="text-sm text-muted-foreground mb-3">
            Next: <span className="font-medium text-foreground">{EXERCISE_NAMES[nextSet.exercise as Exercise]}</span> {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
            {nextSet.warmup && ' (Warmup)'}
            <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
              <Pencil className="w-3.5 h-3.5" />
            </button>
          </p>
          <div className="flex gap-2 justify-center">
            <Button onClick={onStart} disabled={loading} size="lg" className="w-full max-w-[200px]">Start Set</Button>
            {nextSet.warmup && onSkipWarmup && (
              <Button variant="ghost" onClick={onSkipWarmup} disabled={loading} className="text-muted-foreground">Skip</Button>
            )}
          </div>
        </div>
      </div>
    </ActionBox>
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
    <ActionBox
      label="You"
      borderColor="border-dashed border-muted-foreground/30"
      title="Next Up"
    >
      <div className="text-center">
        <p className="text-xl font-bold mb-1">
          {EXERCISE_NAMES[nextSet.exercise as Exercise]}
          {nextSet.warmup && <span className="ml-2 text-xs bg-blue-500/20 text-blue-600 px-1.5 py-0.5 rounded align-middle">Warmup</span>}
        </p>
        <p className="text-muted-foreground mb-4">
          {nextSet.targetReps} reps @ {nextSet.targetWeight} lbs
          <button onClick={onEditWeight} className="ml-1.5 inline-flex align-middle text-muted-foreground hover:text-foreground">
            <Pencil className="w-3.5 h-3.5" />
          </button>
        </p>
        <div className="flex gap-2 justify-center">
          <Button onClick={onStart} disabled={loading} size="lg" className="w-full max-w-[200px]">Start Set</Button>
          {nextSet.warmup && onSkipWarmup && (
            <Button variant="ghost" onClick={onSkipWarmup} disabled={loading} className="text-muted-foreground">Skip</Button>
          )}
        </div>
      </div>
    </ActionBox>
  )
}
