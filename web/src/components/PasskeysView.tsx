import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { addPasskey, listPasskeys, deletePasskey, type PasskeyInfo } from '@/lib/auth'
import { Plus, Key, Trash2 } from 'lucide-react'
import { LoadingSpinner, LoadingBlock } from '@/components/ui/loading'
import { Modal } from '@/components/ui/modal'

interface PasskeysViewProps {
}

export function PasskeysView({ }: PasskeysViewProps) {
  const [passkeys, setPasskeys] = useState<PasskeyInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [adding, setAdding] = useState(false)
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null)
  const [passkeyName, setPasskeyName] = useState('')
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
      await addPasskey(passkeyName.trim() || undefined)
      setPasskeyName('')
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

  const handleDelete = async (credentialId: string) => {
    setDeletingId(credentialId)
    setError(null)
    try {
      await deletePasskey(credentialId)
      await loadPasskeys()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to delete passkey')
    } finally {
      setDeletingId(null)
      setShowDeleteConfirm(null)
    }
  }

  const formatDate = (timestamp: bigint) => {
    return new Date(Number(timestamp) * 1000).toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    })
  }

  const formatTransports = (transports: string[]) => {
    if (transports.length === 0) return null
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

        <div className="space-y-4">
          <div className="px-1 space-y-4">
            <h2 className="text-xs uppercase tracking-widest text-muted-foreground font-bold">
              Passkeys
            </h2>
            <div className="flex gap-2">
              <Input
                placeholder="Passkey Name (e.g. Work Phone)"
                value={passkeyName}
                onChange={(e) => setPasskeyName(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleAddPasskey()}
                disabled={adding}
                className="text-sm h-9"
              />
              <Button
                size="sm"
                variant="outline"
                onClick={handleAddPasskey}
                disabled={adding}
                className="text-xs font-bold uppercase whitespace-nowrap"
              >
                {adding ? (
                  <LoadingSpinner size="sm" className="mr-1" />
                ) : (
                  <Plus className="w-3 h-3 mr-1" />
                )}
                Add Passkey
              </Button>
            </div>
          </div>

          <div className="px-1">
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
                    key={pk.credentialId}
                    className="flex items-center gap-3 p-3 bg-muted rounded-md border border-border/50"
                  >
                    <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                      <Key className="w-4 h-4 text-primary" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p className="text-sm font-bold">{pk.name || `Passkey ${i + 1}`}</p>
                        {pk.createdAtIp && (
                          <span className="text-[10px] bg-muted-foreground/10 px-1.5 py-0.5 rounded text-muted-foreground font-mono">
                            {pk.createdAtIp}
                          </span>
                        )}
                      </div>
                      <div className="flex flex-wrap gap-x-2 gap-y-0.5 items-center text-xs text-muted-foreground">
                        {formatTransports(pk.transports) && (
                          <span>{formatTransports(pk.transports)}</span>
                        )}
                        {formatTransports(pk.transports) && pk.createdAt && (
                          <span>&middot;</span>
                        )}
                        <span>Added {formatDate(pk.createdAt)}</span>
                      </div>
                    </div>
                    <Button
                      size="icon"
                      variant="ghost"
                      onClick={() => setShowDeleteConfirm(pk.credentialId)}
                      disabled={deletingId !== null || passkeys.length <= 1}
                      className="text-muted-foreground hover:text-destructive transition-colors"
                    >
                      {deletingId === pk.credentialId ? (
                        <LoadingSpinner size="sm" />
                      ) : (
                        <Trash2 className="w-4 h-4" />
                      )}
                    </Button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </div>

      {showDeleteConfirm !== null && (
        <Modal
          onClose={() => !deletingId && setShowDeleteConfirm(null)}
          title="Delete Passkey"
          className="max-w-md"
        >
          <div className="p-6 space-y-6">
            <div className="p-3 bg-destructive/10 border border-destructive/20 rounded-md text-sm text-destructive font-bold leading-relaxed">
              Make sure you have one of the remaining passkeys before deleting anything. 
              If you don't have a valid passkey you cannot recover your account.
            </div>
            <p className="text-sm text-muted-foreground">
              Are you sure you want to delete this passkey? This action cannot be undone.
            </p>
            <div className="flex gap-3 pt-2">
              <Button
                variant="outline"
                className="flex-1"
                onClick={() => setShowDeleteConfirm(null)}
                disabled={deletingId !== null}
              >
                Cancel
              </Button>
              <Button
                variant="destructive"
                className="flex-1 font-bold"
                onClick={() => showDeleteConfirm && handleDelete(showDeleteConfirm)}
                disabled={deletingId !== null}
              >
                {deletingId ? <LoadingSpinner size="sm" className="mr-2" /> : null}
                {deletingId ? 'Deleting...' : 'Delete Key'}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  )
}
