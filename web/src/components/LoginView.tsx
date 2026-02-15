import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { register, login } from '@/lib/auth'
import { LoadingSpinner } from '@/components/ui/loading'
import { cn } from '@/lib/utils'
import { Dumbbell, Users, Zap, TrendingUp, CheckCircle2 } from 'lucide-react'

interface LoginViewProps {
  onLogin: (userId: string) => void
}

export function LoginView({ onLogin }: LoginViewProps) {
  const [mode, setMode] = useState<'signin' | 'signup'>('signup')
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const completeLogin = (result: { sessionToken: string; userId: string }) => {
    localStorage.setItem('liftSessionToken', result.sessionToken)
    localStorage.setItem('liftUserId', result.userId)
    onLogin(result.userId)
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
      <div className="w-full max-w-md flex flex-col items-center space-y-12">
        
        {/* Branding */}
        <div className="text-center space-y-2">
          <h1 className="text-4xl font-bold tracking-tighter leading-none text-foreground">LIFT</h1>
          <p className="text-muted-foreground text-xl font-medium">Social Strength System</p>
        </div>

        <div className="w-full space-y-8">
          <Card className="border shadow-lg overflow-hidden">
          <CardHeader className="space-y-4 pb-4">
            {/* Mode Switcher */}
            <div className="flex p-1 bg-muted rounded-lg">
              <button
                onClick={() => { setMode('signup'); setError(null) }}
                className={cn(
                  "flex-1 py-2 text-sm font-medium rounded-md transition-all duration-200",
                  mode === 'signup' 
                    ? "bg-background text-foreground shadow-sm" 
                    : "text-foreground/50 hover:text-foreground"
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
                    : "text-foreground/50 hover:text-foreground"
                )}
              >
                Sign In
              </button>
            </div>
            
            <p className="text-center text-sm text-muted-foreground px-4">
              {mode === 'signup' 
                ? 'Pick a display name, ez game.' 
                : 'Use the passkey on your device to sign in.'}
            </p>
          </CardHeader>

          <CardContent className="space-y-4">
            {error && (
              <div className="p-3 text-sm font-medium text-destructive bg-destructive/10 rounded-md border border-destructive/20">
                {error}
              </div>
            )}

            <div className="relative min-h-[120px]">
              {mode === 'signup' ? (
                <div className="space-y-4 animate-in fade-in slide-in-from-bottom-2 duration-300">
                  <Input
                    placeholder="Display Name"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleRegister()}
                    disabled={loading}
                    className="h-11 border-foreground/20 shadow-sm focus:border-primary"
                    autoFocus
                  />
                  <Button 
                    onClick={handleRegister} 
                    className="w-full h-11 text-base font-semibold" 
                    disabled={loading}
                  >
                    {loading ? <><LoadingSpinner size="sm" className="mr-2 text-primary-foreground" /> Creating...</> : 'Create Account With Passkey'}
                  </Button>
                </div>
              ) : (
                <div className="pt-2 animate-in fade-in duration-300">
                  <Button 
                    onClick={handleSignIn} 
                    className="w-full h-11 text-base font-semibold" 
                    disabled={loading}
                  >
                    {loading ? <><LoadingSpinner size="sm" className="mr-2 text-primary-foreground" /> Verifying...</> : 'Sign In with Passkey'}
                  </Button>
                </div>
              )}
            </div>
          </CardContent>
          </Card>

          {/* Feature List */}
          <div className="space-y-4 pt-4 px-2">
            <Feature icon={TrendingUp} label="Smart Progressive Overload" />
            <Feature icon={Users} label="Group workouts to keep each other on task" />
            <Feature icon={CheckCircle2} label="Simple workout selection and tracking" />
          </div>
        </div>
      </div>
    </div>
  )
}

function Feature({ icon: Icon, label }: { icon: any, label: string }) {
  return (
    <div className="flex items-center gap-4 px-2">
      <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-lg bg-muted text-primary">
        <Icon className="w-5 h-5" />
      </div>
      <span className="text-sm font-medium text-muted-foreground leading-tight">{label}</span>
    </div>
  )
}