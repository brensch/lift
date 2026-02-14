let audioCtx: AudioContext | null = null;

export type SoundPreset = 'chord_strum' | 'bell_high' | 'mac_chime' | 'jazz_maj9' | 'classic_beep';

interface SoundDef {
  name: string;
  notes: { freq: number; type: OscillatorType; delay?: number; duration?: number }[];
}

const PRESETS: Record<SoundPreset, SoundDef> = {
  chord_strum: {
    name: 'Esoteric Strum',
    notes: [
      { freq: 233.08, type: 'triangle', delay: 0.00 }, // Bb3
      { freq: 329.63, type: 'sine', delay: 0.04 }, // E4
      { freq: 440.00, type: 'sine', delay: 0.08 }, // A4
      { freq: 587.33, type: 'triangle', delay: 0.12 }, // D5
      { freq: 739.99, type: 'sine', delay: 0.16 }, // F#5
      { freq: 987.77, type: 'sine', delay: 0.20 }  // B5
    ]
  },
  bell_high: {
    name: 'High Bell',
    notes: [
      { freq: 1320, type: 'sine', duration: 0.8 },
      { freq: 2640, type: 'sine', duration: 0.8 }
    ]
  },
  mac_chime: {
    name: 'macOS',
    notes: [
      // Sub-bass foundation - crucial for that "thud"
      { freq: 46.25, type: 'sine', delay: 0.00, duration: 5.0 }, // Gb1
      { freq: 92.50, type: 'sine', delay: 0.02, duration: 5.0 }, // Gb2

      // Rich, warm mid-section
      { freq: 138.59, type: 'triangle', delay: 0.04, duration: 4.5 }, // Db3
      { freq: 185.00, type: 'triangle', delay: 0.06, duration: 4.5 }, // Gb3
      { freq: 233.08, type: 'sine', delay: 0.08, duration: 4.0 }, // Bb3

      // Clear, shimmering top end
      { freq: 277.18, type: 'sine', delay: 0.10, duration: 3.5 }, // Db4
      { freq: 369.99, type: 'sine', delay: 0.12, duration: 3.0 }, // Gb4
      { freq: 466.16, type: 'sine', delay: 0.14, duration: 2.5 }  // Bb4
    ]
  },
  jazz_maj9: {
    name: 'Jazz Maj9',
    notes: [
      { freq: 523.25, type: 'sine' },
      { freq: 659.25, type: 'triangle' },
      { freq: 783.99, type: 'sine' },
      { freq: 987.77, type: 'triangle' },
      { freq: 1174.66, type: 'sine' }
    ]
  },
  classic_beep: {
    name: 'Classic Beep',
    notes: [
      { freq: 880, type: 'square', duration: 0.1, delay: 0.0 },
      { freq: 880, type: 'square', duration: 0.1, delay: 0.2 },
      { freq: 880, type: 'square', duration: 0.1, delay: 0.4 }
    ]
  },
  success_rise: {
    name: 'Success Rise',
    notes: [
      { freq: 523.25, type: 'sine', duration: 0.5, delay: 0.0 }, // C5
      { freq: 659.25, type: 'sine', duration: 0.5, delay: 0.1 }, // E5
      { freq: 783.99, type: 'sine', duration: 0.5, delay: 0.2 }, // G5
      { freq: 1046.50, type: 'sine', duration: 1.0, delay: 0.3 } // C6
    ]
  },
  mystic_chord: {
    name: 'Mystic Minor',
    notes: [
      { freq: 220.00, type: 'triangle', delay: 0.00 }, // A3
      { freq: 261.63, type: 'sine', delay: 0.05 }, // C4
      { freq: 311.13, type: 'sine', delay: 0.10 }, // Eb4 (m3)
      { freq: 392.00, type: 'triangle', delay: 0.15 }, // G4
      { freq: 466.16, type: 'sine', delay: 0.20 }  // Bb4 (b7)
    ]
  },
  cyber_pulse: {
    name: 'Cyber Pulse',
    notes: [
      { freq: 100, type: 'sawtooth', duration: 0.1, delay: 0.0 },
      { freq: 200, type: 'sawtooth', duration: 0.1, delay: 0.1 },
      { freq: 400, type: 'sawtooth', duration: 0.1, delay: 0.2 },
      { freq: 800, type: 'sawtooth', duration: 0.4, delay: 0.3 }
    ]
  },
  dojo_gong: {
    name: 'Dojo Gong',
    notes: [
      { freq: 98.00, type: 'triangle', duration: 3.0, delay: 0.0 }, // G2
      { freq: 146.83, type: 'triangle', duration: 2.5, delay: 0.05 }, // D3
      { freq: 196.00, type: 'sine', duration: 2.0, delay: 0.1 } // G3
    ]
  },
  zen_harmonic: {
    name: 'Zen Harmonic',
    notes: [
      { freq: 440.00, type: 'sine', duration: 4.0, delay: 0.0 },
      { freq: 659.25, type: 'sine', duration: 3.5, delay: 0.5 },
      { freq: 880.00, type: 'sine', duration: 3.0, delay: 1.0 }
    ]
  },
  retro_arcade: {
    name: 'Retro Arcade',
    notes: [
      { freq: 440, type: 'square', duration: 0.05, delay: 0.0 },
      { freq: 523, type: 'square', duration: 0.05, delay: 0.05 },
      { freq: 659, type: 'square', duration: 0.05, delay: 0.1 },
      { freq: 880, type: 'square', duration: 0.05, delay: 0.15 },
      { freq: 1046, type: 'square', duration: 0.2, delay: 0.2 }
    ]
  },
  boxing_bell: {
    name: 'Boxing Bell',
    notes: [
      { freq: 440, type: 'sine', duration: 1.0, delay: 0.0 },
      { freq: 440, type: 'sine', duration: 1.0, delay: 0.2 },
      { freq: 440, type: 'sine', duration: 1.0, delay: 0.4 }
    ]
  },
  elevator_ding: {
    name: 'Elevator Ding',
    notes: [
      { freq: 783.99, type: 'sine', duration: 1.5, delay: 0.0 } // G5
    ]
  },
  space_warp: {
    name: 'Space Warp',
    notes: [
      { freq: 200, type: 'sawtooth', duration: 0.5, delay: 0.0 },
      { freq: 300, type: 'sawtooth', duration: 0.5, delay: 0.1 },
      { freq: 500, type: 'sawtooth', duration: 0.5, delay: 0.2 }
    ]
  },
  digital_chirp: {
    name: 'Digital Chirp',
    notes: [
      { freq: 2000, type: 'sine', duration: 0.05, delay: 0.0 },
      { freq: 2500, type: 'sine', duration: 0.05, delay: 0.05 },
      { freq: 3000, type: 'sine', duration: 0.05, delay: 0.1 }
    ]
  },
  tonic_glow: {
    name: 'Tonic Glow',
    notes: [
      { freq: 196.00, type: 'sine', duration: 2.0, delay: 0.0 },
      { freq: 293.66, type: 'sine', duration: 1.8, delay: 0.1 },
      { freq: 440.00, type: 'sine', duration: 1.6, delay: 0.2 }
    ]
  },
  melodic_drop: {
    name: 'Melodic Drop',
    notes: [
      { freq: 880, type: 'sine', duration: 0.2, delay: 0.0 },
      { freq: 440, type: 'sine', duration: 0.4, delay: 0.1 }
    ]
  },
  pulse_wave: {
    name: 'Pulse Wave',
    notes: [
      { freq: 150, type: 'square', duration: 0.1, delay: 0.0 },
      { freq: 150, type: 'square', duration: 0.1, delay: 0.2 }
    ]
  },
  star_twinkle: {
    name: 'Star Twinkle',
    notes: [
      { freq: 1567.98, type: 'sine', duration: 0.3, delay: 0.0 }, // G6
      { freq: 1318.51, type: 'sine', duration: 0.3, delay: 0.1 }, // E6
      { freq: 1046.50, type: 'sine', duration: 0.3, delay: 0.2 }  // C6
    ]
  },
  neon_glitch: {
    name: 'Neon Glitch',
    notes: [
      { freq: 600, type: 'sawtooth', duration: 0.02, delay: 0.0 },
      { freq: 100, type: 'sawtooth', duration: 0.02, delay: 0.02 },
      { freq: 900, type: 'sawtooth', duration: 0.02, delay: 0.04 },
      { freq: 200, type: 'sawtooth', duration: 0.02, delay: 0.06 }
    ]
  },
  forest_bird: {
    name: 'Forest Bird',
    notes: [
      { freq: 2500, type: 'sine', duration: 0.1, delay: 0.0 },
      { freq: 3500, type: 'sine', duration: 0.1, delay: 0.05 },
      { freq: 2800, type: 'sine', duration: 0.1, delay: 0.1 }
    ]
  },
  tech_click: {
    name: 'Tech Click',
    notes: [
      { freq: 1500, type: 'square', duration: 0.01, delay: 0.0 },
      { freq: 1200, type: 'square', duration: 0.01, delay: 0.02 }
    ]
  },
  deep_thud: {
    name: 'Deep Thud',
    notes: [
      { freq: 60, type: 'triangle', duration: 0.5, delay: 0.0 },
      { freq: 40, type: 'triangle', duration: 0.8, delay: 0.05 }
    ]
  },
  crystal_shine: {
    name: 'Crystal Shine',
    notes: [
      { freq: 2093, type: 'sine', duration: 0.8, delay: 0.0 },
      { freq: 2637, type: 'sine', duration: 0.8, delay: 0.05 },
      { freq: 3135, type: 'sine', duration: 0.8, delay: 0.1 }
    ]
  },
  sub_drop: {
    name: 'Sub Drop',
    notes: [
      { freq: 80, type: 'sine', duration: 1.5, delay: 0.0 }
    ]
  },
  warning_siren: {
    name: 'Warning Siren',
    notes: [
      { freq: 600, type: 'sine', duration: 0.2, delay: 0.0 },
      { freq: 800, type: 'sine', duration: 0.2, delay: 0.2 },
      { freq: 600, type: 'sine', duration: 0.2, delay: 0.4 }
    ]
  },
  morning_dew: {
    name: 'Morning Dew',
    notes: [
      { freq: 1760, type: 'sine', duration: 0.4, delay: 0.0 },
      { freq: 1975, type: 'sine', duration: 0.4, delay: 0.1 },
      { freq: 2093, type: 'sine', duration: 0.4, delay: 0.2 }
    ]
  },
  voltage_pulse: {
    name: 'Voltage Pulse',
    notes: [
      { freq: 120, type: 'sawtooth', duration: 0.05, delay: 0.0 },
      { freq: 240, type: 'sawtooth', duration: 0.05, delay: 0.05 },
      { freq: 480, type: 'sawtooth', duration: 0.1, delay: 0.1 }
    ]
  },
  cloud_drift: {
    name: 'Cloud Drift',
    notes: [
      { freq: 392, type: 'sine', duration: 3.0, delay: 0.0 },
      { freq: 440, type: 'sine', duration: 3.0, delay: 0.5 },
      { freq: 493, type: 'sine', duration: 3.0, delay: 1.0 }
    ]
  },
  deep_echo: {
    name: 'Deep Echo',
    notes: [
      { freq: 80, type: 'triangle', duration: 2.0, delay: 0.0 },
      { freq: 120, type: 'triangle', duration: 2.0, delay: 0.1 },
      { freq: 160, type: 'triangle', duration: 2.0, delay: 0.2 }
    ]
  },
  glitch_pop: {
    name: 'Glitch Pop',
    notes: [
      { freq: 1200, type: 'square', duration: 0.02, delay: 0.0 },
      { freq: 800, type: 'square', duration: 0.02, delay: 0.05 },
      { freq: 1400, type: 'square', duration: 0.02, delay: 0.1 }
    ]
  },
  harmonic_wind: {
    name: 'Harmonic Wind',
    notes: [
      { freq: 440, type: 'sine', duration: 3.0, delay: 0.0 },
      { freq: 554.37, type: 'sine', duration: 3.0, delay: 0.2 },
      { freq: 659.25, type: 'sine', duration: 3.0, delay: 0.4 }
    ]
  },
  quartz_ping: {
    name: 'Quartz Ping',
    notes: [
      { freq: 2489.02, type: 'sine', duration: 0.5, delay: 0.0 } // Eb7
    ]
  }
};

export function getPresets() {
  return Object.entries(PRESETS).map(([id, def]) => ({ id: id as SoundPreset, name: def.name }));
}

export function getCurrentSound(): SoundPreset {
  if (typeof window === 'undefined') return 'chord_strum';
  return (localStorage.getItem('lift-rest-sound') as SoundPreset) || 'chord_strum';
}

export function setCurrentSound(preset: SoundPreset) {
  localStorage.setItem('lift-rest-sound', preset);
}

export function playSound(preset: SoundPreset = getCurrentSound()) {
  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
    }

    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }

    const def = PRESETS[preset];
    const now = audioCtx.currentTime;

    def.notes.forEach((note) => {
      const oscillator = audioCtx!.createOscillator();
      const gainNode = audioCtx!.createGain();

      const start = now + (note.delay || 0);
      const duration = note.duration || 2.0;

      oscillator.type = note.type;
      oscillator.frequency.setValueAtTime(note.freq, start);

      oscillator.connect(gainNode);
      gainNode.connect(audioCtx!.destination);

      const individualGain = 0.2;
      gainNode.gain.setValueAtTime(0, start);
      gainNode.gain.linearRampToValueAtTime(individualGain, start + 0.05);
      gainNode.gain.exponentialRampToValueAtTime(0.0001, start + duration);

      oscillator.start(start);
      oscillator.stop(start + duration);
    });

  } catch (e) {
    console.error('Failed to play sound:', e);
  }
}

// Keep playDing for backward compatibility in WorkoutView
export const playDing = () => playSound();
