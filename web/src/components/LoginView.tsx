import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { register, login } from '@/lib/auth'
import { LoadingSpinner } from '@/components/ui/loading'
import { cn } from '@/lib/utils'
import { Dumbbell, Users, Zap, Key } from 'lucide-react'

interface LoginViewProps {
  onLogin: (userId: string) => void
}

export function LoginView({ onLogin }: LoginViewProps) {
  const [mode, setMode] = useState<'signin' | 'signup'>('signup')
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
    <div className="min-h-screen w-full bg-background flex flex-col items-center justify-center p-4 sm:p-8">
      <div className="w-full max-w-md flex flex-col items-center space-y-8">
        
        {/* Branding */}
        <div className="text-center space-y-2">
          <h1 className="text-4xl font-bold tracking-tighter leading-none text-foreground">LIFT</h1>
          <p className="text-muted-foreground text-xl font-medium">Social Strength Protocol</p>
        </div>

        <div className="w-full space-y-8">
          <Card className="border shadow-lg">
          <CardHeader className="space-y-1 pb-4">
            {/* Mode Switcher */}
            <div className="flex p-1 bg-muted rounded-lg mb-4">
              <button
                onClick={() => { setMode('signup'); setError(null) }}
                className={cn(
                  "flex-1 py-2 text-sm font-medium rounded-md transition-all duration-200",
                  mode === 'signup' 
                    ? "bg-background text-foreground shadow-sm" 
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                Sign Up
              </button>
              <button
                onClick={() => { setMode('signin'); setError(null) }}
                className={cn(
                  "flex-1 py-2 text-sm font-medium rounded-md transition-all duration-200",
                  mode === 'signin' 
                    ? "bg-background text-foreground shadow-sm" 
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                Sign In
              </button>
            </div>
            

            <CardDescription className="text-center">
              {mode === 'signup' 
                ? 'Enter your display name to get started' 
                : 'Use your passkey to sign in securely'}
            </CardDescription>
          </CardHeader>

          <CardContent className="space-y-4">
            {error && (
              <div className="p-3 text-sm font-medium text-destructive bg-destructive/10 rounded-md border border-destructive/20">
                {error}
              </div>
            )}

            {mode === 'signup' ? (
              <div className="space-y-4 animate-in fade-in slide-in-from-left-2 duration-300">
                <div className="space-y-2">
                  <Input
                    placeholder="Display Name"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleRegister()}
                    disabled={loading}
                    className="h-11"
                    autoFocus
                  />
                </div>
                <Button 
                  onClick={handleRegister} 
                  className="w-full h-11 text-base font-semibold" 
                  disabled={loading}
                >
                  {loading ? <><LoadingSpinner size="sm" className="mr-2 text-primary-foreground" /> Creating...</> : 'Get Started'}
                </Button>
              </div>
            ) : (
              <div className="space-y-6 py-2 animate-in fade-in slide-in-from-right-2 duration-300">
                <div className="flex flex-col items-center justify-center gap-4 text-center">
                  <div className="h-16 w-16 bg-primary/10 rounded-full flex items-center justify-center">
                    <Key className="h-8 w-8 text-primary" />
                  </div>
                  <p className="text-sm text-muted-foreground max-w-[240px]">
                    Authenticate instantly with FaceID, TouchID, or your device PIN.
                  </p>
                </div>
                <Button 
                  onClick={handleSignIn} 
                  className="w-full h-11 text-base font-semibold" 
                  disabled={loading}
                >
                  {loading ? <><LoadingSpinner size="sm" className="mr-2 text-primary-foreground" /> Verifying...</> : 'Sign In with Passkey'}
                </Button>
              </div>
            )}
          </CardContent>
          </Card>

          {/* Feature Grid - Only visible on large screens or if there's space */}
          {mode === 'signup' && (
            <div className="grid grid-cols-3 gap-4 pt-4 px-2">
              <Feature icon={Zap} label="Smart Progress" />
              <Feature icon={Users} label="Multiplayer" />
              <Feature icon={Dumbbell} label="Pure Lifting" />
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function Feature({ icon: Icon, label }: { icon: any, label: string }) {
  return (
    <div className="flex flex-col items-center gap-2 text-center">
      <div className="p-2 rounded-full bg-muted text-muted-foreground">
        <Icon className="w-5 h-5" />
      </div>
      <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">{label}</span>
    </div>
  )
}