import { useState, useEffect } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'

interface RestTimerProps {
  restUntil: number // unix seconds
  onDismiss: () => void
}

export function RestTimer({ restUntil, onDismiss }: RestTimerProps) {
  const [remaining, setRemaining] = useState(0)

  useEffect(() => {
    const update = () => {
      const left = Math.max(0, restUntil - Math.floor(Date.now() / 1000))
      setRemaining(left)
      if (left <= 0) {
        onDismiss()
      }
    }
    update()
    const interval = setInterval(update, 100)
    return () => clearInterval(interval)
  }, [restUntil, onDismiss])

  if (remaining <= 0) return null

  return (
    <Card className="border-primary">
      <CardContent className="pt-6">
        <div className="text-center">
          <p className="text-sm text-muted-foreground">Rest Time Remaining</p>
          <p className="text-5xl font-bold font-mono">
            {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, '0')}
          </p>
          <Button
            variant="outline"
            size="sm"
            className="mt-2"
            onClick={onDismiss}
          >
            Skip Rest
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
