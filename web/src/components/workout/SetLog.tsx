import { cn } from '@/lib/utils'
import { X } from 'lucide-react'
import { type ProposedSet, type CompletedSet, Exercise } from '@/gen/workout/v1/workout_pb'
import { SHORT_NAMES } from '@/lib/exercises'

function fmtTime(ts: bigint | number) {
  if (!ts) return ''
  return new Date(Number(ts) * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

interface LogEntry {
  completed: CompletedSet
  proposed?: ProposedSet
  userName?: string
  isMe: boolean
}

export function SetLog({ userId, completedSets, proposedSets, sessionStatus, onDelete }: {
  userId: string
  completedSets: CompletedSet[]
  proposedSets: ProposedSet[]
  sessionStatus: any
  onDelete: (id: string) => void
}) {
  const allEntries: LogEntry[] = []

  completedSets
    .filter((c) => c.endedAt > 0n)
    .forEach((c) => {
      allEntries.push({
        completed: c,
        proposed: proposedSets.find((p) => p.id === c.proposedSetId),
        userName: 'You',
        isMe: true,
      })
    })

  if (sessionStatus) {
    sessionStatus.participants.forEach((p: any) => {
      if (p.user?.id === userId) return
      p.completedSets
        .filter((c: any) => c.endedAt > 0n)
        .forEach((c: any) => {
          allEntries.push({
            completed: c,
            proposed: p.proposedSets.find((ps: any) => ps.id === c.proposedSetId),
            userName: p.user?.name || '?',
            isMe: false,
          })
        })
    })
  }

  const sortedEntries = allEntries.sort((a, b) => Number(b.completed.endedAt - a.completed.endedAt))

  if (sortedEntries.length === 0) return null

  const isGroup = sessionStatus && sessionStatus.participants.length > 1

  return (
    <div className="space-y-1">
      <div className="text-xs text-muted-foreground font-medium px-1 mb-1 flex justify-between items-center">
        <span>Set Log</span>
        {isGroup && <span className="text-[10px] opacity-60 uppercase">Group Session</span>}
      </div>
      <div className="space-y-0.5">
        {sortedEntries.map((entry, i) => (
          <div key={i} className={cn(
            "text-xs px-2 py-1 rounded flex items-center gap-2",
            entry.isMe ? "bg-muted/50" : "bg-primary/5 border-l-2 border-primary/30"
          )}>
            {isGroup && (
              <span className={cn(
                "font-bold w-16 shrink-0 truncate",
                entry.isMe ? "text-muted-foreground" : "text-primary"
              )}>
                {entry.userName}
              </span>
            )}
            <span className="font-medium w-12 shrink-0 truncate">
              {entry.proposed ? SHORT_NAMES[entry.proposed.exercise as Exercise] : '?'}
            </span>
            <span className="font-medium">{entry.completed.actualReps}&times;{entry.completed.actualWeight}{entry.proposed?.warmup ? ' (w)' : ''}</span>
            <span className="text-muted-foreground font-mono ml-auto">{fmtTime(entry.completed.endedAt)}</span>
            {entry.isMe && (
              <button
                onClick={() => onDelete(entry.completed.id)}
                className="text-muted-foreground/50 hover:text-destructive transition-colors ml-1 p-0.5 rounded-full hover:bg-destructive/10"
              >
                <X size={12} />
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
