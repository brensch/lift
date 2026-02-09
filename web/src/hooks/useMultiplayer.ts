import { useState, useEffect, useRef } from 'react'
import { multiplayerClient, withUserId } from '@/lib/client'
import { type SessionStatus } from '@/gen/workout/v1/group_pb'

export function useMultiplayer(userId: string, workoutId?: string) {
  const [sessionStatus, setSessionStatus] = useState<SessionStatus | null>(null)
  const lastSyncWorkoutId = useRef<string | undefined>(undefined)

  useEffect(() => {
    let active = true
    let timeoutId: number | undefined

    const poll = async () => {
      try {
        // 1. Check current active session
        const { sessionId: activeSessionId } = await multiplayerClient.getMyActiveSession({}, withUserId(userId))
        
        if (!activeSessionId) {
          if (active) setSessionStatus(null);
          lastSyncWorkoutId.current = undefined;
          return;
        }

        // 1.5 Sync our current workout ID to the session if it has changed
        if (workoutId !== lastSyncWorkoutId.current) {
          await multiplayerClient.updateActiveWorkout({ workoutId: workoutId || '' }, withUserId(userId))
          lastSyncWorkoutId.current = workoutId;
        }

        // 2. Get the list of participants in this session
        const status = await multiplayerClient.getSessionStatus({ sessionId: activeSessionId }, withUserId(userId))

        if (active) {
          setSessionStatus((prev) => {
            const replacer = (_: string, v: any) => typeof v === 'bigint' ? v.toString() : v;
            
            if (!prev) return status;

            // Preserve references for participants that haven't changed to benefit from React.memo
            let changed = false;
            const mergedParticipants = status.participants.map(nextP => {
              const prevP = prev.participants.find(p => p.user?.id === nextP.user?.id);
              if (prevP && JSON.stringify(prevP, replacer) === JSON.stringify(nextP, replacer)) {
                return prevP;
              }
              changed = true;
              return nextP;
            });

            if (!changed && JSON.stringify(prev, replacer) === JSON.stringify(status, replacer)) {
              return prev;
            }

            return { ...status, participants: mergedParticipants };
          });
        }
      } catch (e) {
        console.error('Multiplayer polling error:', e)
      } finally {
        if (active) {
          timeoutId = window.setTimeout(poll, 1000)
        }
      }
    }

    poll()
    return () => { 
      active = false
      if (timeoutId) clearTimeout(timeoutId)
    }
  }, [userId, workoutId])

  return sessionStatus
}
