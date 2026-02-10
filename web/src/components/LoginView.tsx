import { useState, useEffect, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { register, login, loginStart, loginFinish, browserSupportsWebAuthnAutofill } from '@/lib/auth'

interface LoginViewProps {
  onLogin: (userId: string) => void
}

export function LoginView({ onLogin }: LoginViewProps) {
  const [mode, setMode] = useState<'signin' | 'register'>('signin')
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const conditionalUIStarted = useRef(false)

  // Start conditional UI (autofill) on mount when in sign-in mode
  useEffect(() => {
    if (mode !== 'signin' || conditionalUIStarted.current) return
    conditionalUIStarted.current = true

    const startConditionalUI = async () => {
      try {
        const supported = await browserSupportsWebAuthnAutofill()
        if (!supported) return

        // Get a discoverable challenge for conditional UI
        const startData = await loginStart()
        const result = await loginFinish(startData, true)

        // If we get here, the user picked a passkey from autofill
        localStorage.setItem('liftSessionToken', result.session_token)
        localStorage.setItem('liftUserId', result.user_id)
        onLogin(result.user_id)
      } catch {
        // Conditional UI was cancelled or not supported — that's fine
      }
    }

    startConditionalUI()
  }, [mode, onLogin])

  const handleSignIn = async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await login(username.trim() || undefined)
      localStorage.setItem('liftSessionToken', result.session_token)
      localStorage.setItem('liftUserId', result.user_id)
      onLogin(result.user_id)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to sign in')
    } finally {
      setLoading(false)
    }
  }

  const handleRegister = async () => {
    if (!username.trim()) {
      setError('Please enter a username')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const result = await register(username.trim())
      localStorage.setItem('liftSessionToken', result.session_token)
      localStorage.setItem('liftUserId', result.user_id)
      onLogin(result.user_id)
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
          <CardTitle className="text-3xl font-bold">Lift</CardTitle>
          <CardDescription>
            {mode === 'signin' ? 'Sign in with your passkey' : 'Create a new account'}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {error && (
            <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
              {error}
            </div>
          )}

          {mode === 'signin' ? (
            <>
              <Input
                placeholder="Username (optional for security keys)"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSignIn()}
                disabled={loading}
                autoComplete="username webauthn"
              />
              <Button onClick={handleSignIn} className="w-full" disabled={loading}>
                {loading ? 'Signing in...' : 'Sign in'}
              </Button>
              <div className="text-center text-sm text-muted-foreground">
                Don't have an account?{' '}
                <button
                  className="text-primary underline"
                  onClick={() => { setMode('register'); setError(null) }}
                >
                  Create one
                </button>
              </div>
            </>
          ) : (
            <>
              <Input
                placeholder="Username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleRegister()}
                disabled={loading}
                autoFocus
              />
              <Button onClick={handleRegister} className="w-full" disabled={loading}>
                {loading ? 'Creating account...' : 'Create Account'}
              </Button>
              <div className="text-center text-sm text-muted-foreground">
                Already have an account?{' '}
                <button
                  className="text-primary underline"
                  onClick={() => { setMode('signin'); setError(null) }}
                >
                  Sign in
                </button>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
