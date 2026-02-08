import { useState, useEffect, useCallback } from 'react'
import { LoginView } from '@/components/LoginView'
import { HomeView } from '@/components/HomeView'
import { WorkoutView } from '@/components/WorkoutView'

type Route =
  | { view: 'login' }
  | { view: 'home'; userId: string }
  | { view: 'workout'; userId: string; workoutId: string }

function parseRoute(path: string): Route {
  const parts = path.split('/').filter(Boolean)

  if (parts.length >= 3 && parts[1] === 'workout') {
    return { view: 'workout', userId: parts[0], workoutId: parts[2] }
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
  }
}

function App() {
  const [route, setRoute] = useState<Route>(() => {
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
    navigate({ view: 'login' })
  }

  switch (route.view) {
    case 'login':
      return <LoginView onLogin={handleLogin} />

    case 'home':
      return (
        <HomeView
          userId={route.userId}
          onLogout={handleLogout}
          onStartWorkout={(workoutId) =>
            navigate({ view: 'workout', userId: route.userId, workoutId })
          }
          onViewWorkout={(workoutId) =>
            navigate({ view: 'workout', userId: route.userId, workoutId })
          }
        />
      )

    case 'workout':
      return (
        <WorkoutView
          workoutId={route.workoutId}
          userId={route.userId}
          onBack={() => navigate({ view: 'home', userId: route.userId })}
        />
      )
  }
}

export default App
