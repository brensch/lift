let audioCtx: AudioContext | null = null;

export function playDing() {
  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
    }

    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }

    const playOne = (delay: number) => {
      const oscillator = audioCtx!.createOscillator();
      const harmonic = audioCtx!.createOscillator();
      const gainNode = audioCtx!.createGain();

      oscillator.connect(gainNode);
      harmonic.connect(gainNode);
      gainNode.connect(audioCtx!.destination);

      const start = audioCtx!.currentTime + delay;
      const duration = 0.8;

      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(1320, start);
      oscillator.frequency.exponentialRampToValueAtTime(1200, start + duration * 0.5);

      harmonic.type = 'sine';
      harmonic.frequency.setValueAtTime(2640, start);
      harmonic.frequency.exponentialRampToValueAtTime(2400, start + duration * 0.4);

      // Maximum gain (1.0)
      gainNode.gain.setValueAtTime(1.0, start);
      gainNode.gain.exponentialRampToValueAtTime(0.0001, start + duration);

      oscillator.start(start);
      harmonic.start(start);
      oscillator.stop(start + duration);
      harmonic.stop(start + duration);
    };

    playOne(0);
    playOne(0.2); // Play again after 200ms
  } catch (e) {
    console.error('Failed to play ding:', e);
  }
}
