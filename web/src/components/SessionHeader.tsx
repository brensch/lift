import { useState, useMemo } from 'react'
import { Button } from '@/components/ui/button'
import { Users } from 'lucide-react'
import { useMultiplayer } from '@/hooks/useMultiplayer'
import { MultiplayerModal } from './MultiplayerModal'
import { ParticipantTicker } from './ParticipantTicker'
import { ParticipantStatusView } from './ParticipantStatusView'
import { ExerciseGroup, groupSetsByExercise } from './ExerciseGroup'

import { Modal } from './ui/modal'

interface SessionHeaderProps {
  userId: string
  workoutId?: string
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
            className={`flex items-center gap-2 px-3 h-8 rounded-full transition-colors shrink-0 ${sessionStatus ? 'bg-primary/10 text-primary hover:bg-primary/20' : 'text-muted-foreground border border-dashed'}`}
          >
            <Users className="w-4 h-4" />
            <span className="text-[10px] uppercase font-bold tracking-tight">
              {sessionStatus ? 'Add People' : 'New Session'}
            </span>
            {activeParticipantsCount > 1 && (
              <span className="text-xs font-black">({activeParticipantsCount})</span>
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
        <Modal
          title={`Viewing ${peepParticipant.user?.name}'s Workout`}
          onClose={() => setPeepUserId(null)}
          className="max-w-md"
          headerClassName="bg-primary text-primary-foreground border-primary"
          closeButtonClassName="text-primary-foreground hover:bg-primary-foreground/20 hover:text-primary-foreground"
        >
          <div className="p-4 space-y-4">
            <ParticipantStatusView status={peepParticipant} layout="detail" />

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
          </div>
        </Modal>
      )}

      {showModal && (
        <MultiplayerModal 
          userId={userId} 
          workoutId={workoutId} 
          sessionId={sessionStatus?.sessionId}
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