import { useState, useEffect, useCallback } from 'react'
import { LoginView } from '@/components/LoginView'
import { HomeView } from '@/components/HomeView'
import { SettingsView } from '@/components/SettingsView'
import { WorkoutView } from '@/components/workout/WorkoutView'
import { ProgressView } from '@/components/ProgressView'
import { WorkoutHistoryView } from '@/components/WorkoutHistoryView'
import { GlobalHeader } from '@/components/GlobalHeader'
import { workoutClient, multiplayerClient, withUserId } from '@/lib/client'
import { type SessionStatus } from '@/gen/workout/v1/group_pb'
import { Button } from '@/components/ui/button'
import { Modal } from '@/components/ui/modal'
import { X } from 'lucide-react'

type Route =
  | { view: 'login' }
  | { view: 'home'; userId: string }
  | { view: 'workout'; userId: string; workoutId: string }
  | { view: 'progress'; userId: string }
  | { view: 'workout-history'; userId: string }
  | { view: 'settings'; userId: string }

function parseRoute(path: string): Route {
  const parts = path.split('/').filter(Boolean)

  if (parts.length >= 3 && parts[1] === 'workout') {
    return { view: 'workout', userId: parts[0], workoutId: parts[2] }
  }

  if (parts.length >= 2 && parts[1] === 'progress') {
    return { view: 'progress', userId: parts[0] }
  }

  if (parts.length >= 2 && parts[1] === 'history') {
    return { view: 'workout-history', userId: parts[0] }
  }

  if (parts.length >= 2 && parts[1] === 'settings') {
    return { view: 'settings', userId: parts[0] }
  }

  if (parts.length >= 1) {
    return { view: 'home', userId: parts[0] }
  }

  return { view: 'login' }
}

function routeToPath(route: Route): string {
  switch (route.view) {
    case 'login':
      return '/'
    case 'home':
      return `/${route.userId}`
    case 'workout':
      return `/${route.userId}/workout/${route.workoutId}`
    case 'progress':
      return `/${route.userId}/progress`
    case 'workout-history':
      return `/${route.userId}/history`
    case 'settings':
      return `/${route.userId}/settings`
  }
}

function App() {
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

    const parsed = parseRoute(window.location.pathname)

    // If URL has a userId, use it
    if (parsed.view !== 'login') {
      localStorage.setItem('liftUserId', parsed.view === 'home' ? parsed.userId : parsed.userId)
      return parsed
    }

    // Check localStorage for saved userId
    const savedUserId = localStorage.getItem('liftUserId')
    if (savedUserId) {
      return { view: 'home', userId: savedUserId }
    }

    return { view: 'login' }
  })

  const [pendingJoin, setPendingJoin] = useState<{ sessionId: string, status: SessionStatus } | null>(null)
  const [joinSuccess, setJoinSuccess] = useState<string | null>(null)
  const [joinError, setJoinError] = useState<string | null>(null)

  // Handle joining a session after login
  useEffect(() => {
    if (route.view !== 'login') {
      const joinId = sessionStorage.getItem('liftJoinSession')
      if (joinId) {
        multiplayerClient.getCurrentSession({ sessionId: joinId }, withUserId(route.userId))
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
  }, [route])

  const handleConfirmJoin = async () => {
    if (!pendingJoin || route.view === 'login') return;
    
    // workoutId is optional for joining
    const workoutId = route.view === 'workout' ? route.workoutId : '';

    try {
      await multiplayerClient.joinSession({ sessionId: pendingJoin.sessionId, workoutId }, withUserId(route.userId));
      sessionStorage.removeItem('liftJoinSession');
      setPendingJoin(null);
      setJoinSuccess(`Joined session with ${pendingJoin.status.participants.length} people`);
      
      // Check for active workout and navigate to it
      try {
        const { workout } = await workoutClient.getActiveWorkout({}, withUserId(route.userId));
        if (workout) {
          navigate({ view: 'workout', userId: route.userId, workoutId: workout.id });
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

  const navigate = useCallback((newRoute: Route) => {
    setRoute(newRoute)
    const path = routeToPath(newRoute)
    window.history.pushState(null, '', path)
  }, [])

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
      const parsed = parseRoute(window.location.pathname)
      if (parsed.view === 'login') {
        const savedUserId = localStorage.getItem('liftUserId')
        if (savedUserId) {
          setRoute({ view: 'home', userId: savedUserId })
          return
        }
      }
      setRoute(parsed)
    }
    window.addEventListener('popstate', handlePopState)
    return () => window.removeEventListener('popstate', handlePopState)
  }, [])

  const handleLogin = (userId: string) => {
    localStorage.setItem('liftUserId', userId)
    navigate({ view: 'home', userId })
  }

  const handleLogout = () => {
    localStorage.removeItem('liftUserId')
    localStorage.removeItem('liftSessionToken')
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

      {route.view !== 'login' && (
        <GlobalHeader 
          currentView={route.view}
          onNavigate={(newView: { view: any }) => navigate({ ...newView, userId: route.userId } as Route)}
          onLogout={handleLogout}
        />
      )}

      {(() => {
        switch (route.view) {
          case 'login':
            return <LoginView onLogin={handleLogin} />

          case 'home':
            return (
              <HomeView
                userId={route.userId}
                onStartWorkout={(workoutId) =>
                  navigate({ view: 'workout', userId: route.userId, workoutId })
                }
              />
            )

          case 'workout':
            return (
              <WorkoutView
                workoutId={route.workoutId}
                userId={route.userId}
              />
            )

          case 'progress':
            return (
              <ProgressView
                userId={route.userId}
              />
            )

          case 'workout-history':
            return (
              <WorkoutHistoryView
                userId={route.userId}
                onViewWorkout={(workoutId) => navigate({ view: 'workout', userId: route.userId, workoutId })}
              />
            )

          case 'settings':
            return (
              <SettingsView
                onLogout={handleLogout}
              />
            )
        }
      })()}
    </>
  )
}

export default App