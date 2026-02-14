import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { addPasskey, listPasskeys, type PasskeyInfo } from '@/lib/auth'
import { Plus, Key } from 'lucide-react'
import { LoadingSpinner, LoadingBlock } from '@/components/ui/loading'

interface SettingsViewProps {
}

export function SettingsView({ }: SettingsViewProps) {
  const [passkeys, setPasskeys] = useState<PasskeyInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [adding, setAdding] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadPasskeys()
  }, [])

  const loadPasskeys = async () => {
    try {
      setLoading(true)
      const list = await listPasskeys()
      setPasskeys(list)
    } catch (e) {
      console.error('Failed to load passkeys:', e)
      setError('Failed to load passkeys')
    } finally {
      setLoading(false)
    }
  }

  const handleAddPasskey = async () => {
    setAdding(true)
    setError(null)
    try {
      await addPasskey()
      await loadPasskeys()
    } catch (e) {
      if (e instanceof Error && e.name === 'NotAllowedError') {
        // User cancelled the WebAuthn dialog
      } else {
        setError(e instanceof Error ? e.message : 'Failed to add passkey')
      }
    } finally {
      setAdding(false)
    }
  }

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  const formatTransports = (transports: string[]) => {
    if (transports.length === 0) return 'Unknown'
    const labels: Record<string, string> = {
      internal: 'This device',
      usb: 'USB',
      nfc: 'NFC',
      ble: 'Bluetooth',
      hybrid: 'Phone/Tablet',
    }
    return transports.map(t => labels[t] || t).join(', ')
  }

  return (
    <div className="min-h-screen bg-background p-4 pt-0">
      <div className="max-w-2xl mx-auto space-y-6">
        {error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded-md text-sm">
            {error}
          </div>
        )}

        <Card>
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <CardTitle className="text-xs uppercase tracking-widest text-muted-foreground font-bold">
                Passkeys
              </CardTitle>
              <Button
                size="sm"
                variant="outline"
                onClick={handleAddPasskey}
                disabled={adding}
                className="text-xs font-bold uppercase"
              >
                {adding ? (
                  <LoadingSpinner size="sm" className="mr-1" />
                ) : (
                  <Plus className="w-3 h-3 mr-1" />
                )}
                Add Passkey
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            {loading ? (
              <LoadingBlock text="Loading passkeys..." />
            ) : passkeys.length === 0 ? (
              <p className="text-sm text-muted-foreground py-4 text-center">
                No passkeys found
              </p>
            ) : (
              <ul className="space-y-2">
                {passkeys.map((pk, i) => (
                  <li
                    key={pk.credential_id}
                    className="flex items-center gap-3 p-3 bg-muted rounded-md"
                  >
                    <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                      <Key className="w-4 h-4 text-primary" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-bold">Passkey {i + 1}</p>
                      <p className="text-xs text-muted-foreground">
                        {formatTransports(pk.transports)} &middot; Added {formatDate(pk.created_at)}
                      </p>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
