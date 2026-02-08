import { useState, useEffect } from 'react'
import { multiplayerClient, withUserId } from '@/lib/client'
import { type SessionStatus } from '@/gen/workout/v1/group_pb'

export function useMultiplayer(userId: string) {
  const [sessionStatus, setSessionStatus] = useState<SessionStatus | null>(null)

  useEffect(() => {
    let active = true
    let timeoutId: number | undefined

    const poll = async () => {
      try {
        // 1. Check current active session in local DB
        const { sessionId: activeSessionId } = await multiplayerClient.getMyActiveSession({}, withUserId(userId))
        console.debug('Active Session ID:', activeSessionId);
        
        if (!activeSessionId) {
          if (active) setSessionStatus(null);
          return;
        }

        // 2. Get the list of participants in this session
        const status = await multiplayerClient.getSessionStatus({ sessionId: activeSessionId }, withUserId(userId))
        console.debug('Session participants count:', status.participants.length);

        // 3. Parallel lookups for each participant's workout progress
        const participantUpdates = await Promise.all(
          status.participants.map(async (p) => {
            if (!p.activeWorkoutId) {
              return p;
            }
            try {
              console.debug(`Fetching workout for participant ${p.user?.id} with workout ${p.activeWorkoutId}`);
              return await multiplayerClient.getParticipantWorkout(
                { userId: p.user?.id || '', workoutId: p.activeWorkoutId },
                withUserId(userId)
              );
            } catch (e) {
              console.error(`Failed to get workout for participant ${p.user?.id}:`, e);
              return p; // Return original if lookup fails
            }
          })
        );

        if (active) {
          setSessionStatus({
            ...status,
            participants: participantUpdates,
          });
        }
      } catch (e) {
        console.error('Multiplayer polling error:', e)
      } finally {
        if (active) {
          timeoutId = window.setTimeout(poll, 5000)
        }
      }
    }

    poll()
    return () => { 
      active = false
      if (timeoutId) clearTimeout(timeoutId)
    }
  }, [userId])

  return sessionStatus
}
