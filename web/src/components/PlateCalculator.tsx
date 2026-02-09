import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

const PLATE_COLORS: Record<number, string> = {
  45: 'bg-red-500',
  25: 'bg-blue-500',
  10: 'bg-yellow-500',
  5: 'bg-green-500',
  2.5: 'bg-gray-400',
}

const PLATE_WIDTHS: Record<number, string> = {
  45: 'w-4',
  25: 'w-3.5',
  10: 'w-3',
  5: 'w-2.5',
  2.5: 'w-2',
}

const PLATE_HEIGHTS: Record<number, string> = {
  45: 'h-20',
  25: 'h-16',
  10: 'h-14',
  5: 'h-12',
  2.5: 'h-10',
}

export function calcPlatesPerSide(weight: number): number[] {
  const available = [45, 25, 10, 5, 2.5]
  let remaining = (weight - 45) / 2
  if (remaining <= 0) return []
  const plates: number[] = []
  for (const plate of available) {
    while (remaining >= plate - 0.01) {
      plates.push(plate)
      remaining -= plate
    }
  }
  return plates
}

function snap(v: number) {
  return Math.round(v / 5) * 5
}

interface PlateCalculatorProps {
  weight: number
  onChange: (weight: number) => void
}

export function PlateCalculator({ weight, onChange }: PlateCalculatorProps) {
  const [value, setValue] = useState(weight)
  const clamped = Math.max(45, Math.min(500, value))
  const plates = calcPlatesPerSide(clamped)

  // Sync external weight changes
  useEffect(() => { setValue(weight) }, [weight])

  const update = (v: number) => {
    const s = snap(v)
    const c = Math.max(45, Math.min(500, s))
    setValue(c)
    onChange(c)
  }

  return (
    <div className="space-y-3">
      {/* Barbell visualization */}
      <div className="flex items-center justify-center h-24 gap-0">
        <div className="flex items-center gap-0.5 flex-row-reverse">
          {plates.map((p, i) => (
            <div
              key={`l-${i}`}
              className={`${PLATE_COLORS[p]} ${PLATE_WIDTHS[p]} ${PLATE_HEIGHTS[p]} rounded-sm`}
              title={`${p} lbs`}
            />
          ))}
        </div>
        <div className="h-2 w-16 bg-gray-500" />
        <div className="flex items-center gap-0.5">
          {plates.map((p, i) => (
            <div
              key={`r-${i}`}
              className={`${PLATE_COLORS[p]} ${PLATE_WIDTHS[p]} ${PLATE_HEIGHTS[p]} rounded-sm`}
              title={`${p} lbs`}
            />
          ))}
        </div>
      </div>

      {/* Plate legend */}
      <div className="flex justify-center gap-2 text-[10px] text-muted-foreground">
        {[45, 25, 10, 5, 2.5].map((p) => (
          <span key={p} className="flex items-center gap-0.5">
            <span className={`inline-block w-2.5 h-2.5 rounded-sm ${PLATE_COLORS[p]}`} />
            {p}
          </span>
        ))}
      </div>

      {/* Weight input */}
      <div className="text-center">
        <Input
          type="number"
          value={clamped}
          onChange={(e) => update(Number(e.target.value))}
          className="text-3xl font-bold text-center h-14 text-foreground"
          min={45}
          max={500}
          step={5}
        />
        <p className="text-xs text-muted-foreground mt-1">
          {clamped === 45 ? 'Empty bar' : `${plates.join(' + ')} per side`}
        </p>
      </div>

      {/* Slider */}
      <input
        type="range"
        min={45}
        max={500}
        step={5}
        value={clamped}
        onChange={(e) => update(Number(e.target.value))}
        className="w-full accent-primary"
      />

      {/* +/- buttons */}
      <div className="flex justify-center gap-2">
        <Button variant="outline" size="sm" onClick={() => update(clamped - 45)} disabled={clamped <= 45}>
          −45
        </Button>
        <Button variant="outline" size="sm" onClick={() => update(clamped - 5)} disabled={clamped <= 45}>
          −5
        </Button>
        <Button variant="outline" size="sm" onClick={() => update(clamped + 5)} disabled={clamped >= 500}>
          +5
        </Button>
        <Button variant="outline" size="sm" onClick={() => update(clamped + 45)} disabled={clamped >= 500}>
          +45
        </Button>
      </div>
    </div>
  )
}
