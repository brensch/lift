import { useState, useEffect, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { multiplayerClient, withUserId } from '@/lib/client'
import QRCode from 'react-qr-code'
import { Html5QrcodeScanner } from 'html5-qrcode'
import { Camera, X, Share } from 'lucide-react'

interface MultiplayerModalProps {
  userId: string
  workoutId?: string // Current workout ID if any
  onClose: () => void
  onJoinSession: (sessionId: string) => void
}

export function MultiplayerModal({ userId, workoutId, onClose, onJoinSession }: MultiplayerModalProps) {
  const [activeSessionId, setActiveSessionId] = useState<string>('')
  const [showScanner, setShowScanner] = useState(false)
  const scannerRef = useRef<Html5QrcodeScanner | null>(null)

  useEffect(() => {
    multiplayerClient.getMyActiveSession({}, withUserId(userId))
      .then(res => {
        if (res.sessionId) setActiveSessionId(res.sessionId);
      })
      .catch(console.error);
  }, [userId]);

  useEffect(() => {
    if (showScanner) {
      scannerRef.current = new Html5QrcodeScanner(
        "qr-reader",
        { fps: 10, qrbox: { width: 250, height: 250 } },
        false
      );
      scannerRef.current.render((decodedText) => {
        // Expected format: http://.../?join=SESSION_ID
        try {
          const url = new URL(decodedText);
          const joinId = url.searchParams.get('join');
          if (joinId) {
            handleJoin(joinId);
          }
        } catch (e) {
          console.error('Invalid QR code:', decodedText);
        }
      }, () => {
        // Just ignore scan errors
      });

      return () => {
        if (scannerRef.current) {
          scannerRef.current.clear().catch(console.error);
        }
      };
    }
  }, [showScanner]);

  const handleStartSession = async () => {
    if (!workoutId) return;
    try {
      const res = await multiplayerClient.startSession({ workoutId }, withUserId(userId));
      console.log('Started session:', res.sessionId);
      setActiveSessionId(res.sessionId);
      onJoinSession(res.sessionId);
    } catch (e) {
      console.error('Failed to start session:', e);
    }
  };

  const handleJoin = async (sessionId: string) => {
    try {
      await multiplayerClient.joinSession({ sessionId, workoutId: workoutId || '' }, withUserId(userId));
      console.log('Joined session:', sessionId);
      setActiveSessionId(sessionId);
      onJoinSession(sessionId);
      onClose();
    } catch (e) {
      console.error('Failed to join session:', e);
    }
  };

  const handleLeave = async () => {
    try {
      await multiplayerClient.leaveSession({}, withUserId(userId));
      setActiveSessionId('');
    } catch (e) {
      console.error('Failed to leave session:', e);
    }
  };

  const joinUrl = activeSessionId ? `${window.location.origin}/?join=${activeSessionId}` : '';

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
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <Card className="w-full max-w-md max-h-[90vh] overflow-hidden flex flex-col" onClick={(e) => e.stopPropagation()}>
        <CardContent className="pt-6 space-y-4 overflow-y-auto">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold">Multiplayer</h2>
            <Button variant="ghost" size="icon" onClick={onClose}>
              <X className="w-5 h-5" />
            </Button>
          </div>

          {!activeSessionId ? (
            <div className="space-y-4 py-4">
              <Button 
                className="w-full h-12 text-lg font-bold" 
                disabled={!workoutId}
                onClick={handleStartSession}
              >
                Start a Session
              </Button>
              <p className="text-sm text-muted-foreground text-center">
                {!workoutId ? 'Start a workout to create a session' : 'Create a session to let others follow your progress'}
              </p>
              
              <div className="relative">
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
                >
                  <Camera className="w-4 h-4 mr-2" /> {showScanner ? 'Cancel Scan' : 'Scan QR Code'}
                </Button>
              </div>

              {showScanner && (
                <div className="py-4">
                  <div id="qr-reader" className="w-full rounded-lg overflow-hidden border" />
                </div>
              )}
            </div>
          ) : (
            <div className="flex flex-col items-center space-y-4 py-4">
              <div className="bg-white p-4 rounded-xl">
                <QRCode value={joinUrl} size={200} />
              </div>
              <p className="text-sm text-muted-foreground text-center">
                Active Session ID: <span className="font-mono">{activeSessionId}</span>
              </p>
              <div className="flex gap-2 w-full">
                <Button variant="outline" className="flex-1" onClick={handleShare}>
                  <Share className="w-4 h-4 mr-2" /> Share Link
                </Button>
                <Button variant="destructive" className="flex-1" onClick={handleLeave}>
                  Leave Session
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
