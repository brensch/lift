import { useState, useMemo } from 'react'
import { Button } from '@/components/ui/button'
import { Users, X } from 'lucide-react'
import { useMultiplayer } from '@/hooks/useMultiplayer'
import { MultiplayerModal } from './MultiplayerModal'
import { ParticipantTicker } from './ParticipantTicker'
import { Card, CardContent } from '@/components/ui/card'
import { Exercise } from '@/gen/workout/v1/workout_pb'
import { ExerciseGroup, groupSetsByExercise } from './ExerciseGroup'

interface SessionHeaderProps {
  userId: string
  workoutId?: string
}

const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench Press',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'Overhead Press',
  [Exercise.BARBELL_ROW]: 'Barbell Row',
}

function fmtTime(ts: bigint | number) {
  if (!ts) return ''
  return new Date(Number(ts) * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

export function SessionHeader({ userId, workoutId }: SessionHeaderProps) {
  const sessionStatus = useMultiplayer(userId)
  const [showModal, setShowModal] = useState(false)
  const [peepUserId, setPeepUserId] = useState<string | null>(null)

  const participants = sessionStatus?.participants || []
  const otherParticipants = participants.filter(p => p.user?.id !== userId)
  const activeParticipantsCount = participants.length

  const peepParticipant = useMemo(() => {
    if (!peepUserId || !sessionStatus) return null
    return sessionStatus.participants.find(p => p.user?.id === peepUserId)
  }, [peepUserId, sessionStatus])

  return (
    <div className="w-full space-y-2">
      <div className="flex items-center justify-between gap-2">
        <div className="flex gap-2 overflow-x-auto no-scrollbar items-center py-1">
          <Button 
            variant="ghost" 
            size="sm" 
            onClick={() => setShowModal(true)}
            className={`flex items-center gap-2 px-3 h-8 rounded-full transition-colors shrink-0 ${activeParticipantsCount > 1 ? 'bg-primary/10 text-primary hover:bg-primary/20' : 'text-muted-foreground border border-dashed'}`}
          >
            <Users className="w-4 h-4" />
            {activeParticipantsCount > 1 ? (
              <span className="text-xs font-bold">{activeParticipantsCount}</span>
            ) : (
              <span className="text-[10px] uppercase font-bold tracking-tighter">Session</span>
            )}
          </Button>

          {otherParticipants.map((p) => (
            <ParticipantTicker 
              key={p.user?.id} 
              status={p} 
              isPeeping={peepUserId === p.user?.id}
              onPeep={() => setPeepUserId(peepUserId === p.user?.id ? null : p.user?.id || null)}
            />
          ))}
        </div>
      </div>

      {peepParticipant && (
        <div className="fixed inset-x-4 top-20 z-50 animate-in fade-in slide-in-from-top-4 duration-300">
          <Card className="shadow-2xl border-2 border-primary overflow-hidden max-h-[70vh] flex flex-col">
            <div className="flex items-center justify-between bg-primary text-primary-foreground p-2 px-4">
              <span className="text-sm font-bold truncate">Viewing {peepParticipant.user?.name}'s Workout</span>
              <Button size="icon" variant="ghost" className="h-8 w-8 text-primary-foreground hover:bg-primary-foreground/20" onClick={() => setPeepUserId(null)}>
                <X className="w-4 h-4" />
              </Button>
            </div>
            <CardContent className="p-4 space-y-4 overflow-y-auto">
              {peepParticipant.currentSet ? (
                <div className="text-center p-4 bg-muted rounded-lg border border-border">
                  <p className="text-[10px] uppercase font-bold text-muted-foreground mb-1">
                    {peepParticipant.isResting ? 'Next Set' : 'Currently Doing'}
                  </p>
                  <p className="text-xl font-bold">{EXERCISE_NAMES[peepParticipant.currentSet.exercise as Exercise]}</p>
                  <p className="text-3xl font-black text-primary">{peepParticipant.currentSet.targetReps} &times; {peepParticipant.currentSet.targetWeight} lbs</p>
                  {peepParticipant.isResting && (
                    <p className="text-[10px] text-muted-foreground mt-2 font-mono">Rest ends at {fmtTime(peepParticipant.restUntil)}</p>
                  )}
                </div>
              ) : (
                <div className="py-8 text-center text-muted-foreground text-sm italic">User is not currently doing a set.</div>
              )}

              <div 
                key={`peep-list-${peepParticipant.user?.id}-${peepParticipant.completedSets.length}`}
                className="opacity-80 pointer-events-none scale-95 origin-top transition-all space-y-1"
              >
                {groupSetsByExercise(peepParticipant.proposedSets).map((group, idx, all) => (
                  <ExerciseGroup
                    key={`${group.exercise}-${idx}`}
                    group={group}
                    groupIndex={idx}
                    totalGroups={all.length}
                    completedSets={peepParticipant.completedSets}
                    isWorkoutEnded={false}
                  />
                ))}
              </div>
            </CardContent>
          </Card>
          <div className="fixed inset-0 bg-black/20 -z-10 backdrop-blur-[2px]" onClick={() => setPeepUserId(null)} />
        </div>
      )}

      {showModal && (
        <MultiplayerModal 
          userId={userId} 
          workoutId={workoutId} 
          onClose={() => setShowModal(false)} 
          onJoinSession={(sid) => {
            console.log('Joined session:', sid);
            setShowModal(false);
          }} 
        />
      )}
    </div>
  )
}