import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Modal } from '@/components/ui/modal'
import { type ProposedSet, type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { type ParticipantStatus } from '@/gen/workout/v1/group_pb'
import { EXERCISE_NAMES } from '@/lib/exercises'
import { calcPlatesPerSide, PLATE_COLORS } from '@/components/PlateCalculator'
import { useElapsed, useCountdown, fmtElapsed } from '@/hooks/useTimer'
import { cn } from '@/lib/utils'

/** Shared compact box shell — left accent strip + card background */
function Box({ accent, children, className }: { accent: string; children: React.ReactNode; className?: string }) {
  return (
    <div className={cn('rounded-lg border border-border bg-card px-4 py-3 border-l-4', accent, className)}>
      {children}
    </div>
  )
}

const PLATE_H: Record<number, string> = { 45: 'h-8', 25: 'h-7', 10: 'h-6', 5: 'h-5', 2.5: 'h-4' }
const PLATE_W: Record<number, string> = { 45: 'w-2.5', 25: 'w-2', 10: 'w-1.5', 5: 'w-1.5', 2.5: 'w-1' }

const FULL_H: Record<number, string> = { 45: 'h-20', 25: 'h-16', 10: 'h-14', 5: 'h-12', 2.5: 'h-10' }
const FULL_W: Record<number, string> = { 45: 'w-4', 25: 'w-3.5', 10: 'w-3', 5: 'w-2.5', 2.5: 'w-2' }

/** Inline barbell plate visualization — tap to see full detail */
function InlinePlates({ weight }: { weight: number }) {
  const [showDetail, setShowDetail] = useState(false)
  const plates = calcPlatesPerSide(weight)
  const isEmpty = plates.length === 0
  return (
    <>
      <button className="flex items-center gap-[2px]" onClick={() => setShowDetail(true)}>
        {!isEmpty && (
          <div className="flex items-center gap-[2px] flex-row-reverse">
            {plates.map((p, i) => (
              <div key={`l-${i}`} className={`${PLATE_COLORS[p]} ${PLATE_W[p]} ${PLATE_H[p]} rounded-sm`} />
            ))}
          </div>
        )}
        <div className="h-1 w-6 bg-gray-500" />
        {!isEmpty && (
          <div className="flex items-center gap-[2px]">
            {plates.map((p, i) => (
              <div key={`r-${i}`} className={`${PLATE_COLORS[p]} ${PLATE_W[p]} ${PLATE_H[p]} rounded-sm`} />
            ))}
          </div>
        )}
      </button>
      {showDetail && (
        <Modal title={`${weight} lb`} onClose={() => setShowDetail(false)} className="max-w-sm">
          <div className="p-6 space-y-3">
            <div className="flex items-center justify-center h-24 gap-0">
              {!isEmpty && (
                <div className="flex items-center gap-0.5 flex-row-reverse">
                  {plates.map((p, i) => (
                    <div key={`l-${i}`} className={`${PLATE_COLORS[p]} ${FULL_W[p]} ${FULL_H[p]} rounded-sm`} />
                  ))}
                </div>
              )}
              <div className="h-2 w-16 bg-gray-500" />
              {!isEmpty && (
                <div className="flex items-center gap-0.5">
                  {plates.map((p, i) => (
                    <div key={`r-${i}`} className={`${PLATE_COLORS[p]} ${FULL_W[p]} ${FULL_H[p]} rounded-sm`} />
                  ))}
                </div>
              )}
            </div>
            {!isEmpty && (
              <div className="flex justify-center gap-2 text-[10px] text-muted-foreground">
                {[45, 25, 10, 5, 2.5].map((p) => (
                  <span key={p} className="flex items-center gap-0.5">
                    <span className={`inline-block w-2.5 h-2.5 rounded-sm ${PLATE_COLORS[p]}`} />
                    {p}
                  </span>
                ))}
              </div>
            )}
            <p className="text-center text-sm text-muted-foreground">
              {isEmpty ? 'Empty bar' : `${plates.join(' + ')} per side`}
            </p>
          </div>
        </Modal>
      )}
    </>
  )
}

/** Compact one-line exercise info: "Bench Press [W] · 5×135 lb" + plates */
function NextSetInfo({ set, large }: { set: ProposedSet; large?: boolean }) {
  return (
    <div className={cn('text-muted-foreground mt-0.5', large ? 'text-base' : 'text-sm')}>
      <span className="font-medium text-foreground">{EXERCISE_NAMES[set.exercise as Exercise]}</span>
      {set.warmup && (
        <span className="ml-1.5 text-[10px] bg-blue-500/15 text-blue-500 px-1 py-0.5 rounded font-medium align-middle">W</span>
      )}
      <span className="mx-1.5 opacity-40">·</span>
      <span className={cn('font-mono font-semibold text-foreground', large && 'text-lg')}>{set.targetReps}×{set.targetWeight}</span>
      <span className={cn('ml-0.5', large ? 'text-sm' : 'text-xs')}>lb</span>
      <div className="mt-1">
        <InlinePlates weight={set.targetWeight} />
      </div>
    </div>
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
    <Box accent="border-l-purple-500">
      <div className="flex items-start justify-between">
        <div className="min-w-0">
          <div className="text-xs font-semibold text-purple-500 uppercase tracking-wider">
            Next for group · {participant.user?.name || 'Someone'}
          </div>
          <NextSetInfo set={nextSet} />
        </div>
        {isChatting ? (
          <span className="text-sm font-mono text-purple-500 font-semibold animate-pulse shrink-0 ml-3">Overdue</span>
        ) : (
          <span className="text-2xl font-bold font-mono leading-none shrink-0 ml-3">
            {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, '0')}
          </span>
        )}
      </div>
    </Box>
  )
}

export function RestingBox({ restUntil, nextSet, onStartEarly, onSkipWarmup }: {
  restUntil: number
  nextSet?: ProposedSet
  onStartEarly: () => void
  onSkipWarmup?: () => void
}) {
  const remaining = useCountdown(restUntil)
  if (remaining <= 0) return null

  return (
    <Box accent="border-l-blue-500">
      <div className="flex items-start justify-between">
        <div className="min-w-0">
          <div className="text-xs font-semibold text-blue-500 uppercase tracking-wider">Next set</div>
          {nextSet && <NextSetInfo set={nextSet} large />}
        </div>
        <span className="text-4xl font-bold font-mono leading-none shrink-0 ml-3">
          {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, '0')}
        </span>
      </div>
      <div className="flex gap-2 mt-3">
        <Button size="sm" onClick={onStartEarly} className="flex-1">Start Next Set</Button>
        {nextSet?.warmup && onSkipWarmup && (
          <Button variant="ghost" size="sm" onClick={onSkipWarmup} className="text-muted-foreground">Skip</Button>
        )}
      </div>
    </Box>
  )
}

export function ActiveSetBox({ proposedSet, completedSet, onComplete, onSkip }: {
  proposedSet: ProposedSet
  completedSet: CompletedSet
  onComplete: (reps: number) => void
  onSkip?: () => void
}) {
  const elapsed = useElapsed(Number(completedSet.startedAt))
  const [loading, setLoading] = useState(false)
  const maxReps = proposedSet.targetReps
  const buttons = Array.from({ length: maxReps + 1 }, (_, i) => i)

  return (
    <Box accent={proposedSet.warmup ? 'border-l-blue-500' : 'border-l-primary'}>
      {/* Header: exercise + elapsed */}
      <div className="flex items-center justify-between mb-1">
        <div className="flex items-center gap-2">
          <span className="font-semibold">{EXERCISE_NAMES[proposedSet.exercise as Exercise]}</span>
          {proposedSet.warmup && (
            <span className="text-[10px] bg-blue-500/15 text-blue-500 px-1.5 py-0.5 rounded font-medium">Warmup</span>
          )}
        </div>
        <span className="font-mono text-sm text-muted-foreground">{fmtElapsed(elapsed)}</span>
      </div>

      {/* Weight + reps */}
      <div className="flex items-baseline gap-1.5">
        <span className="text-2xl font-bold">{proposedSet.targetWeight}</span>
        <span className="text-sm text-muted-foreground">lb</span>
        <span className="text-muted-foreground mx-1 opacity-40">·</span>
        <span className="text-2xl font-bold text-primary">{proposedSet.targetReps}</span>
        <span className="text-sm text-muted-foreground">reps</span>
      </div>
      <div className="mt-1 mb-3">
        <InlinePlates weight={proposedSet.targetWeight} />
      </div>

      {/* Log reps */}
      <div>
        <div className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider mb-1.5">How many reps did you complete cleanly?</div>
        <div className="flex flex-wrap gap-1.5">
          {buttons.map((n) => (
            <Button
              key={n}
              size="sm"
              variant={n === maxReps ? 'default' : 'outline'}
              onClick={() => { setLoading(true); onComplete(n) }}
              disabled={loading}
              className="min-w-[40px] h-10 text-base font-bold"
            >
              {n}
            </Button>
          ))}
        </div>
      </div>

      {proposedSet.warmup && onSkip && (
        <Button
          variant="ghost" size="sm"
          className="w-full mt-2 text-muted-foreground text-xs"
          onClick={() => { setLoading(true); onSkip() }}
          disabled={loading}
        >
          Skip Warmup
        </Button>
      )}
    </Box>
  )
}

export function ChatTimeBox({ restEndedAt, nextSet, onStart, loading, onSkipWarmup }: {
  restEndedAt: number
  nextSet: ProposedSet
  onStart: () => void
  loading: boolean
  onSkipWarmup?: () => void
}) {
  const elapsed = useElapsed(restEndedAt)

  return (
    <Box accent="border-l-orange-500">
      <div className="flex items-start justify-between">
        <div className="min-w-0">
          <div className="text-xs font-semibold text-orange-500 uppercase tracking-wider">Next set</div>
          <NextSetInfo set={nextSet} large />
        </div>
        <span className="text-4xl font-bold font-mono text-orange-500 leading-none shrink-0 ml-3">
          {fmtElapsed(elapsed)}
        </span>
      </div>
      <div className="flex gap-2 mt-3">
        <Button size="sm" onClick={onStart} disabled={loading} className="flex-1">Start Set</Button>
        {nextSet.warmup && onSkipWarmup && (
          <Button variant="ghost" size="sm" onClick={onSkipWarmup} disabled={loading} className="text-muted-foreground">Skip</Button>
        )}
      </div>
    </Box>
  )
}

export function NextUpBox({ nextSet, onStart, loading, onSkipWarmup }: {
  nextSet: ProposedSet
  onStart: () => void
  loading: boolean
  onSkipWarmup?: () => void
}) {
  return (
    <Box accent="border-l-muted-foreground/30" className="border-dashed">
      <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-0.5">Next up</div>
      <NextSetInfo set={nextSet} />
      <div className="flex gap-2 mt-2">
        <Button size="sm" onClick={onStart} disabled={loading} className="flex-1">Start Set</Button>
        {nextSet.warmup && onSkipWarmup && (
          <Button variant="ghost" size="sm" onClick={onSkipWarmup} disabled={loading} className="text-muted-foreground">Skip</Button>
        )}
      </div>
    </Box>
  )
}
