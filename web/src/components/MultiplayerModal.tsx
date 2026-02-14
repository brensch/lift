import { useState, useEffect, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { multiplayerClient, withUserId } from '@/lib/client'
import { QRCodeSVG } from 'qrcode.react'
import { Html5QrcodeScanner } from 'html5-qrcode'
import { Modal } from '@/components/ui/modal'
import { LoadingSpinner } from '@/components/ui/loading'

interface MultiplayerModalProps {
  userId: string
  workoutId?: string // Current workout ID if any
  sessionId?: string // Current session ID if any
  onClose: () => void
  onJoinSession: (sessionId: string) => void
}

export function MultiplayerModal({ userId, workoutId, sessionId, onClose, onJoinSession }: MultiplayerModalProps) {
  const [localActiveSessionId, setLocalActiveSessionId] = useState<string>('')
  const [showScanner, setShowScanner] = useState(false)
  const [loading, setLoading] = useState(false)
  const scannerRef = useRef<Html5QrcodeScanner | null>(null)

  // Use the prop if available, otherwise use local state (from start/join actions)
  const activeSessionId = localActiveSessionId || sessionId || ''
  const effectiveSessionId = activeSessionId === '__NONE__' ? '' : activeSessionId
  const joinUrl = effectiveSessionId ? `${window.location.origin}/?join=${effectiveSessionId}` : ''

  useEffect(() => {
    if (showScanner) {
      scannerRef.current = new Html5QrcodeScanner(
        "qr-reader",
        { fps: 10, qrbox: { width: 250, height: 250 } },
        false
      );
      scannerRef.current.render((decodedText) => {
        try {
          const url = new URL(decodedText);
          const joinId = url.searchParams.get('join');
          if (joinId) {
            handleJoin(joinId);
          }
        } catch (e) {
          console.error('Invalid QR code:', decodedText);
        }
      }, () => {});

      return () => {
        if (scannerRef.current) {
          scannerRef.current.clear().catch(console.error);
        }
      };
    }
  }, [showScanner]);

  const handleStartSession = async () => {
    setLoading(true);
    try {
      const res = await multiplayerClient.startSession({ workoutId: workoutId || '' }, withUserId(userId));
      setLocalActiveSessionId(res.sessionId);
      onJoinSession(res.sessionId);
    } catch (e) {
      console.error('Failed to start session:', e);
    } finally {
      setLoading(false);
    }
  };

  const handleJoin = async (id: string) => {
    setLoading(true);
    try {
      await multiplayerClient.joinSession({ sessionId: id, workoutId: workoutId || '' }, withUserId(userId));
      setLocalActiveSessionId(id);
      onJoinSession(id);
      onClose();
    } catch (e) {
      console.error('Failed to join session:', e);
    } finally {
      setLoading(false);
    }
  };

  const handleLeave = async () => {
    setLoading(true);
    try {
      await multiplayerClient.leaveSession({}, withUserId(userId));
      setLocalActiveSessionId('__NONE__');
      onJoinSession('');
    } catch (e) {
      console.error('Failed to leave session:', e);
    } finally {
      setLoading(false);
    }
  };

  const handleShare = async () => {
    if (!joinUrl) return;
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Join my workout on Lift',
          text: `I'm working out! Join my session to see my progress:`,
          url: joinUrl,
        });
      } catch (e) {
        console.error('Error sharing:', e);
      }
    } else {
      try {
        await navigator.clipboard.writeText(joinUrl);
        alert('Link copied to clipboard!');
      } catch (e) {
        console.error('Error copying to clipboard:', e);
      }
    }
  };

  return (
    <Modal 
      title="Multiplayer" 
      onClose={onClose}
      className="max-w-md"
    >
      <div className="p-6 space-y-4">
        {!effectiveSessionId ? (
          <div className="space-y-4">
            <Button 
              className="w-full h-12 text-lg font-bold" 
              onClick={handleStartSession}
              disabled={loading}
            >
              {loading ? <LoadingSpinner size="sm" className="mr-2 text-primary-foreground" /> : null}
              Start a Session
            </Button>
            <p className="text-sm text-muted-foreground text-center">
              Create a session to let others follow your progress
            </p>
            
            <div className="relative py-2">
              <div className="absolute inset-0 flex items-center">
                <span className="w-full border-t" />
              </div>
              <div className="relative flex justify-center text-xs uppercase">
                <span className="bg-background px-2 text-muted-foreground">Or scan to join</span>
              </div>
            </div>

            <div className="flex gap-2">
              <Button 
                variant={showScanner ? 'default' : 'outline'} 
                className="flex-1"
                onClick={() => setShowScanner(!showScanner)}
                disabled={loading}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4 mr-2"><path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/></svg> {showScanner ? 'Cancel Scan' : 'Scan QR Code'}
              </Button>
            </div>

            {showScanner && (
              <div className="py-4">
                <div id="qr-reader" className="w-full rounded-lg overflow-hidden border" />
              </div>
            )}
          </div>
        ) : (
          <div className="flex flex-col items-center space-y-4">
            <div className="bg-white p-4 rounded-xl shadow-inner border">
              <QRCodeSVG value={joinUrl} size={200} />
            </div>
            <p className="text-sm text-muted-foreground text-center">
              Active Session ID: <span className="font-mono font-bold text-foreground">{effectiveSessionId}</span>
            </p>
            <div className="flex gap-2 w-full pt-2">
              <Button variant="outline" className="flex-1 text-destructive hover:text-destructive" onClick={handleLeave} disabled={loading}>
                {loading ? <LoadingSpinner size="sm" className="mr-2 text-destructive" /> : 'Leave Session'}
              </Button>
              <Button variant="default" className="flex-1" onClick={handleShare}>
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4 mr-2"><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" x2="12" y1="2" y2="15"/></svg> Share Link
              </Button>
            </div>
          </div>
        )}
      </div>
    </Modal>
  )
}
