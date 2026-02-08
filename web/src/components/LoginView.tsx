import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'

interface LoginViewProps {
  onLogin: (userId: string) => void
}

export function LoginView({ onLogin }: LoginViewProps) {
  const [userId, setUserId] = useState('')
  const [error, setError] = useState<string | null>(null)

  const handleLogin = () => {
    if (!userId.trim()) {
      setError('Please enter a user ID')
      return
    }
    onLogin(userId.trim())
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <CardTitle className="text-3xl font-bold">Lift</CardTitle>
          <CardDescription>Enter your user ID to start tracking</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {error && (
            <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
              {error}
            </div>
          )}
          <Input
            placeholder="User ID"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleLogin()}
            autoFocus
          />
          <Button onClick={handleLogin} className="w-full">
            Continue
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
