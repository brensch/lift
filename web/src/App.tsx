import { useState, useEffect, useCallback } from 'react'
import { LoginView } from '@/components/LoginView'
import { HomeView } from '@/components/HomeView'
import { PasskeysView } from '@/components/PasskeysView'
import { WorkoutView } from '@/components/workout/WorkoutView'
import { ProgressView } from '@/components/ProgressView'
import { WorkoutHistoryView } from '@/components/WorkoutHistoryView'
import { SoundSettingsView } from '@/components/SoundSettingsView'
import { GlobalHeader } from '@/components/GlobalHeader'
import { workoutClient, userClient, multiplayerClient, withUserId } from '@/lib/client'
import { logout } from '@/lib/auth'
import { type SessionStatus } from '@/gen/workout/v1/group_pb'
import { Button } from '@/components/ui/button'
import { Modal } from '@/components/ui/modal'
import { X } from 'lucide-react'

type Route =
  | { view: 'login' }
  | { view: 'home' }
  | { view: 'workout'; workoutId: string }
  | { view: 'progress' }
  | { view: 'workout-history' }
  | { view: 'passkeys' }
  | { view: 'pick-sound' }

function parseRoute(path: string): Route {
  const parts = path.split('/').filter(Boolean)

  if (parts.length >= 2 && parts[0] === 'workout') {
    return { view: 'workout', workoutId: parts[1] }
  }

  if (parts.length >= 1 && parts[0] === 'progress') {
    return { view: 'progress' }
  }

  if (parts.length >= 1 && parts[0] === 'history') {
    return { view: 'workout-history' }
  }

  if (parts.length >= 1 && parts[0] === 'passkeys') {
    return { view: 'passkeys' }
  }

  if (parts.length >= 1 && parts[1] === 'pick-sound') {
    return { view: 'pick-sound' }
  }

  if (parts.length >= 1 && parts[0] === 'pick-sound') {
    return { view: 'pick-sound' }
  }

  if (path === '/' || path === '') {
    // If we are at root, we might be logged in or not. 
    // We'll let the App component decide based on localStorage.
    // For parsing, we return 'home' as a placeholder if not login.
    return { view: 'home' }
  }

  return { view: 'login' }
}

function routeToPath(route: Route): string {
  switch (route.view) {
    case 'login':
      return '/'
    case 'home':
      return '/'
    case 'workout':
      return `/workout/${route.workoutId}`
    case 'progress':
      return `/progress`
    case 'workout-history':
      return `/history`
    case 'passkeys':
      return `/passkeys`
    case 'pick-sound':
      return `/pick-sound`
  }
}

function App() {
  const [userId, setUserId] = useState<string | null>(() => localStorage.getItem('liftUserId'))
  const [userName, setUserName] = useState<string>('')
  const [route, setRoute] = useState<Route>(() => {
    // Check for join parameter in URL
    const params = new URLSearchParams(window.location.search)
    const joinId = params.get('join')
    if (joinId) {
      sessionStorage.setItem('liftJoinSession', joinId)
      // Clean up URL
      const url = new URL(window.location.href)
      url.searchParams.delete('join')
      window.history.replaceState(null, '', url.pathname)
    }

    // Check localStorage for saved userId
    const savedUserId = localStorage.getItem('liftUserId')
    if (!savedUserId) {
      return { view: 'login' }
    }

    const parsed = parseRoute(window.location.pathname)
    if (parsed.view === 'login') {
        return { view: 'home' }
    }
    return parsed
  })

  const [pendingJoin, setPendingJoin] = useState<{ sessionId: string, status: SessionStatus } | null>(null)
  const [joinSuccess, setJoinSuccess] = useState<string | null>(null)
  const [joinError, setJoinError] = useState<string | null>(null)

  useEffect(() => {
    if (userId) {
      userClient.getUser({ userId }, withUserId(userId))
        .then((res) => {
          if (res.user) setUserName(res.user.name)
        })
        .catch(console.error)
    } else {
      setUserName('')
    }
  }, [userId])

  const navigate = useCallback((newRoute: Route) => {
    setRoute(newRoute)
    const path = routeToPath(newRoute)
    window.history.pushState(null, '', path)
  }, [])

  // Handle joining a session after login
  useEffect(() => {
    if (route.view !== 'login' && userId) {
      const joinId = sessionStorage.getItem('liftJoinSession')
      if (joinId) {
        multiplayerClient.getCurrentSession({ sessionId: joinId }, withUserId(userId))
          .then((response) => {
             if (response.sessionStatus) {
                setPendingJoin({ sessionId: joinId, status: response.sessionStatus })
             } else {
                 throw new Error("Session not found");
             }
          })
          .catch(e => {
            console.error('Failed to get session status:', e)
            sessionStorage.removeItem('liftJoinSession')
          })
      }
    }
  }, [route, userId])

  const handleConfirmJoin = async () => {
    if (!pendingJoin || route.view === 'login' || !userId) return;
    
    // workoutId is optional for joining
    const workoutId = route.view === 'workout' ? route.workoutId : '';

    try {
      await multiplayerClient.joinSession({ sessionId: pendingJoin.sessionId, workoutId }, withUserId(userId));
      sessionStorage.removeItem('liftJoinSession');
      setPendingJoin(null);
      setJoinSuccess(`Joined session with ${pendingJoin.status.participants.length} people`);
      
      // Check for active workout and navigate to it
      try {
        const { workout } = await workoutClient.getActiveWorkout({}, withUserId(userId));
        if (workout) {
          navigate({ view: 'workout', workoutId: workout.id });
        }
      } catch (e) {
        console.error('Failed to check for active workout after join:', e);
      }
      
      setTimeout(() => setJoinSuccess(null), 5000);
    } catch (e) {
      console.error('Failed to join session:', e);
      setJoinError('Failed to join session.');
      setPendingJoin(null);
      sessionStorage.removeItem('liftJoinSession');
      setTimeout(() => setJoinError(null), 5000);
    }
  };

  // Sync URL on initial load (in case we redirected from localStorage)
  useEffect(() => {
    const currentPath = routeToPath(route)
    if (window.location.pathname !== currentPath) {
      window.history.replaceState(null, '', currentPath)
    }
  }, [])

  // Handle browser back/forward
  useEffect(() => {
    const handlePopState = () => {
      const savedUserId = localStorage.getItem('liftUserId')
      if (!savedUserId) {
        setUserId(null)
        setRoute({ view: 'login' })
        return
      }
      
      setUserId(savedUserId)
      const parsed = parseRoute(window.location.pathname)
      setRoute(parsed)
    }
    window.addEventListener('popstate', handlePopState)
    return () => window.removeEventListener('popstate', handlePopState)
  }, [])

  const handleLogin = (newUserId: string) => {
    localStorage.setItem('liftUserId', newUserId)
    setUserId(newUserId)
    navigate({ view: 'home' })
  }

  const handleLogout = async () => {
    await logout()
    localStorage.removeItem('liftUserId')
    localStorage.removeItem('liftSessionToken')
    setUserId(null)
    navigate({ view: 'login' })
  }

  return (
    <>
      <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[100] w-full max-w-sm px-4 space-y-2 pointer-events-none">
        {joinSuccess && (
          <div className="bg-green-600 text-white p-3 rounded-lg shadow-xl flex items-center justify-between pointer-events-auto animate-in fade-in slide-in-from-top-4">
            <span className="text-sm font-bold">{joinSuccess}</span>
            <button onClick={() => setJoinSuccess(null)}><X className="w-4 h-4" /></button>
          </div>
        )}
        {joinError && (
          <div className="bg-destructive text-white p-3 rounded-lg shadow-xl flex items-center justify-between pointer-events-auto animate-in fade-in slide-in-from-top-4">
            <span className="text-sm font-bold">{joinError}</span>
            <button onClick={() => setJoinError(null)}><X className="w-4 h-4" /></button>
          </div>
        )}
      </div>

      {pendingJoin && (
        <Modal 
          title="Join Session?" 
          description="Would you like to join the session with these people?"
          onClose={() => { setPendingJoin(null); sessionStorage.removeItem('liftJoinSession'); }}
          className="max-w-sm"
        >
          <div className="p-6 space-y-4">
            <div className="space-y-2">
              {pendingJoin.status.participants.map(p => (
                <div key={p.user?.id} className="flex items-center gap-2 p-2 bg-muted rounded-md">
                  <div className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center text-xs font-bold text-primary">
                    {p.user?.name[0].toUpperCase()}
                  </div>
                  <span className="font-medium">{p.user?.name}</span>
                </div>
              ))}
            </div>
            <div className="flex gap-2 pt-2">
              <Button variant="outline" className="flex-1" onClick={() => { setPendingJoin(null); sessionStorage.removeItem('liftJoinSession'); }}>
                Cancel
              </Button>
              <Button className="flex-1" onClick={handleConfirmJoin}>
                Join
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {route.view !== 'login' && userId && (
        <GlobalHeader 
          currentView={route.view}
          onNavigate={(newView: { view: any }) => navigate(newView as Route)}
          onLogout={handleLogout}
          userName={userName}
        />
      )}

      {(() => {
        if (!userId && route.view !== 'login') return <LoginView onLogin={handleLogin} />

        switch (route.view) {
          case 'login':
            return <LoginView onLogin={handleLogin} />

          case 'home':
            return (
              <HomeView
                userId={userId!}
                onStartWorkout={(workoutId) =>
                  navigate({ view: 'workout', workoutId })
                }
              />
            )

          case 'workout':
            return (
              <WorkoutView
                workoutId={route.workoutId}
                userId={userId!}
              />
            )

          case 'progress':
            return (
              <ProgressView
                userId={userId!}
              />
            )

          case 'workout-history':
            return (
              <WorkoutHistoryView
                userId={userId!}
                onViewWorkout={(workoutId) => navigate({ view: 'workout', workoutId })}
              />
            )

          case 'passkeys':
            return (
              <PasskeysView
              />
            )

          case 'pick-sound':
            return (
              <div className="max-w-2xl mx-auto p-4 pb-24">
                <SoundSettingsView />
              </div>
            )
        }
      })()}
    </>
  )
}

export default App