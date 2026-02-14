import { useState, useMemo } from 'react'
import { Plus, Users } from 'lucide-react'
import { LoadingSpinner } from '@/components/ui/loading'
import { useMultiplayer } from '@/hooks/useMultiplayer'
import { multiplayerClient, withUserId } from '@/lib/client'
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
  const [loading, setLoading] = useState(false)
  const [tempSessionId, setTempSessionId] = useState<string | null>(null)
  const [peepUserId, setPeepUserId] = useState<string | null>(null)

  const participants = sessionStatus?.participants || []
  const otherParticipants = participants.filter(p => p.user?.id !== userId)

  const peepParticipant = useMemo(() => {
    if (!peepUserId || !sessionStatus) return null
    return sessionStatus.participants.find(p => p.user?.id === peepUserId)
  }, [peepUserId, sessionStatus])

  const handleStartSession = async () => {
    setLoading(true)
    try {
      const res = await multiplayerClient.startSession({ workoutId: workoutId || '' }, withUserId(userId))
      setTempSessionId(res.sessionId)
      setShowModal(true)
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="w-full space-y-2">
      <div className="flex items-center justify-between gap-2">
        <div className="flex gap-2 overflow-x-auto no-scrollbar items-center py-1">
          <button
            onClick={() => {
              if (sessionStatus) setShowModal(true)
              else handleStartSession()
            }}
            disabled={loading}
            className={`flex items-center justify-center gap-1 px-3 py-1.5 rounded-full border transition-all shrink-0 min-h-[38px] text-xs font-medium bg-primary text-primary-foreground hover:bg-primary/90 border-transparent shadow-sm`}
          >
            {loading ? (
              <LoadingSpinner size="sm" className="text-primary-foreground" />
            ) : sessionStatus ? (
              <>
                <Users className="w-4 h-4" />
                <Plus className="w-3 h-3 opacity-70" />
              </>
            ) : (
              <span>Start Group Session</span>
            )}
          </button>

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
          sessionId={sessionStatus?.sessionId || tempSessionId || undefined}
          onClose={() => setShowModal(false)} 
          onJoinSession={(sid) => {
            console.log('Joined session:', sid);
            if (!sid) setShowModal(false);
          }} 
        />
      )}
    </div>
  )
}