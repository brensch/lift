import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'

import { userClient } from '@/lib/client'

interface LoginViewProps {
  onLogin: (userId: string) => void
}

export function LoginView({ onLogin }: LoginViewProps) {
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleLogin = async () => {
    if (!username.trim()) {
      setError('Please enter a username')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const response = await userClient.createUser({ name: username.trim() })
      if (response.user) {
        onLogin(response.user.id)
      } else {
        setError('Failed to login')
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to login')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <CardTitle className="text-3xl font-bold">Lift</CardTitle>
          <CardDescription>Enter a unique username to start tracking</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {error && (
            <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
              {error}
            </div>
          )}
          <Input
            placeholder="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleLogin()}
            disabled={loading}
            autoFocus
          />
          <Button onClick={handleLogin} className="w-full" disabled={loading}>
            {loading ? 'Logging in...' : 'Continue'}
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
