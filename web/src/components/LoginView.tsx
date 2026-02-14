import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { register, login } from '@/lib/auth'
import { LoadingSpinner } from '@/components/ui/loading'

interface LoginViewProps {
  onLogin: (userId: string) => void
}

export function LoginView({ onLogin }: LoginViewProps) {
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const completeLogin = (result: { session_token: string; user_id: string }) => {
    localStorage.setItem('liftSessionToken', result.session_token)
    localStorage.setItem('liftUserId', result.user_id)
    onLogin(result.user_id)
  }

  const handleSignIn = async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await login()
      completeLogin(result)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to sign in')
    } finally {
      setLoading(false)
    }
  }

  const handleRegister = async () => {
    if (!username.trim()) {
      setError('Please enter a display name')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const result = await register(username.trim())
      completeLogin(result)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to register')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <CardTitle className="text-3xl font-bold tracking-tighter">LIFT</CardTitle>
          <CardDescription>
            Track your workouts
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {error && (
            <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
              {error}
            </div>
          )}

          <div className="space-y-4">
            <h3 className="font-semibold text-center text-lg">New user?</h3>
            <Input
              placeholder="Display Name"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleRegister()}
              disabled={loading}
            />
            <Button onClick={handleRegister} className="w-full" disabled={loading}>
              {loading ? <><LoadingSpinner size="sm" className="mr-2 text-primary-foreground" /> Creating account...</> : 'Sign up'}
            </Button>
          </div>

          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t" />
            </div>
            <div className="relative flex justify-center text-xs uppercase">
              <span className="bg-card px-2 text-muted-foreground">Or</span>
            </div>
          </div>

          <div className="space-y-4">
            <h3 className="font-semibold text-center text-lg">Coming back?</h3>
            <Button onClick={handleSignIn} variant="outline" className="w-full" disabled={loading}>
              {loading ? <><LoadingSpinner size="sm" className="mr-2" /> Signing in...</> : 'Sign in'}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
