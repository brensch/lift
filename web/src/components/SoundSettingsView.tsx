import { getPresets, getCurrentSound, setCurrentSound, playSound, type SoundPreset } from '@/lib/audio'
import { useState } from 'react'

export function SoundSettingsView() {
  const [current, setCurrent] = useState<SoundPreset>(getCurrentSound())
  const presets = getPresets()

  const handleSelect = (id: SoundPreset) => {
    setCurrent(id)
    setCurrentSound(id)
    playSound(id)
  }

  return (
    <div className="space-y-4 w-full">
      <div className="space-y-3">
        <h2 className="text-2xl font-black uppercase tracking-tighter">Pick Sound</h2>
        
        <div className="p-4 bg-muted/30 rounded-xl border border-border/50">
          <p className="text-xs text-muted-foreground font-medium leading-relaxed">
            The selected sound will play automatically when a rest timer expires during your workout.
          </p>
        </div>

        <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-xl">
          <p className="text-[10px] leading-tight text-blue-500 font-bold uppercase tracking-wider">
            iOS Tip: To hear sounds when your screen is locked, tap "Share" and then "Add to Home Screen".
          </p>
        </div>
      </div>

      <div 
        className="grid gap-2 w-full"
        style={{ gridTemplateColumns: 'repeat(2, 1fr)', display: 'grid' }}
      >
        {presets.map((preset) => (
          <button
            key={preset.id}
            onClick={() => handleSelect(preset.id)}
            className={`flex flex-col items-center justify-center py-4 px-1 rounded-xl transition-all border-2 text-center relative overflow-hidden min-w-0 ${
              current === preset.id
                ? 'bg-primary border-primary text-primary-foreground shadow-md'
                : 'bg-card border-border/50 text-foreground hover:border-border hover:bg-muted/50'
            }`}
          >
            <span className="text-sm font-black uppercase tracking-tight truncate w-full px-1">
              {preset.name}
            </span>
          </button>
        ))}
      </div>
    </div>
  )
}
