import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";

// Standard barbell weight
const BAR_WEIGHT = 45;

// Standard plate weights (in lbs) - one side
const PLATE_WEIGHTS = [45, 35, 25, 10, 5, 2.5];

// Plate colors for visualization
const PLATE_COLORS: Record<number, string> = {
  45: "bg-blue-600",
  35: "bg-yellow-500",
  25: "bg-green-600",
  10: "bg-gray-500",
  5: "bg-red-600",
  2.5: "bg-gray-400",
};

// Plate widths for visualization (relative)
const PLATE_WIDTHS: Record<number, string> = {
  45: "w-8",
  35: "w-7",
  25: "w-6",
  10: "w-4",
  5: "w-3",
  2.5: "w-2",
};

// Plate heights for visualization
const PLATE_HEIGHTS: Record<number, string> = {
  45: "h-24",
  35: "h-22",
  25: "h-20",
  10: "h-16",
  5: "h-14",
  2.5: "h-12",
};

interface BarbellCalculatorProps {
  isOpen: boolean;
  onClose: () => void;
  currentWeight: number;
  onSubmit: (weight: number) => void;
  exerciseName: string;
}

function calculatePlates(totalWeight: number): number[] {
  // Weight on each side (subtract bar, divide by 2)
  let weightPerSide = (totalWeight - BAR_WEIGHT) / 2;
  const plates: number[] = [];

  if (weightPerSide < 0) {
    return plates;
  }

  for (const plate of PLATE_WEIGHTS) {
    while (weightPerSide >= plate) {
      plates.push(plate);
      weightPerSide -= plate;
    }
  }

  return plates;
}

export function BarbellCalculator({
  isOpen,
  onClose,
  currentWeight,
  onSubmit,
  exerciseName,
}: BarbellCalculatorProps) {
  const [weight, setWeight] = useState(currentWeight);

  // Reset weight when modal opens with new value
  useEffect(() => {
    if (isOpen) {
      setWeight(currentWeight);
    }
  }, [isOpen, currentWeight]);

  const plates = calculatePlates(weight);
  
  // Min weight is just the bar (45 lbs)
  const minWeight = BAR_WEIGHT;
  // Max weight - reasonable upper limit
  const maxWeight = 500;

  const handleIncrement = (amount: number) => {
    const newWeight = Math.min(maxWeight, Math.max(minWeight, weight + amount));
    // Round to nearest 5
    setWeight(Math.round(newWeight / 5) * 5);
  };

  const handleSubmit = () => {
    onSubmit(weight);
    onClose();
  };

  // Quick weight presets
  const presets = [45, 95, 135, 185, 225, 275, 315];

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Set Weight - {exerciseName}</DialogTitle>
        </DialogHeader>

        <div className="space-y-6 py-4">
          {/* Weight display */}
          <div className="text-center">
            <div className="text-5xl font-bold font-mono">{weight}</div>
            <div className="text-muted-foreground">lbs</div>
          </div>

          {/* Increment/Decrement buttons */}
          <div className="flex justify-center gap-2">
            <Button
              variant="outline"
              size="lg"
              onClick={() => handleIncrement(-10)}
              disabled={weight <= minWeight}
            >
              -10
            </Button>
            <Button
              variant="outline"
              size="lg"
              onClick={() => handleIncrement(-5)}
              disabled={weight <= minWeight}
            >
              -5
            </Button>
            <Button
              variant="outline"
              size="lg"
              onClick={() => handleIncrement(5)}
              disabled={weight >= maxWeight}
            >
              +5
            </Button>
            <Button
              variant="outline"
              size="lg"
              onClick={() => handleIncrement(10)}
              disabled={weight >= maxWeight}
            >
              +10
            </Button>
          </div>

          {/* Barbell visualization */}
          <div className="flex items-center justify-center py-4 overflow-hidden">
            {/* Left sleeve/collar area */}
            <div className="w-2 h-6 bg-gray-700 rounded-l" />
            
            {/* Left plates (reversed for visual) */}
            <div className="flex items-center">
              {[...plates].reverse().map((plate, idx) => (
                <div
                  key={`left-${idx}`}
                  className={`${PLATE_COLORS[plate]} ${PLATE_WIDTHS[plate]} ${PLATE_HEIGHTS[plate]} rounded-sm border border-black/20`}
                  title={`${plate} lbs`}
                />
              ))}
            </div>

            {/* Bar */}
            <div className="w-16 h-3 bg-gray-600" />

            {/* Right plates */}
            <div className="flex items-center">
              {plates.map((plate, idx) => (
                <div
                  key={`right-${idx}`}
                  className={`${PLATE_COLORS[plate]} ${PLATE_WIDTHS[plate]} ${PLATE_HEIGHTS[plate]} rounded-sm border border-black/20`}
                  title={`${plate} lbs`}
                />
              ))}
            </div>

            {/* Right sleeve/collar area */}
            <div className="w-2 h-6 bg-gray-700 rounded-r" />
          </div>

          {/* Plate breakdown */}
          <div className="text-center text-sm text-muted-foreground">
            {weight === BAR_WEIGHT ? (
              <span>Empty bar ({BAR_WEIGHT} lbs)</span>
            ) : (
              <span>
                Bar ({BAR_WEIGHT}) + {plates.map(p => `${p}`).join(" + ")} × 2 each side
              </span>
            )}
          </div>

          {/* Quick presets */}
          <div className="flex flex-wrap justify-center gap-2">
            {presets.map((preset) => (
              <Button
                key={preset}
                variant={weight === preset ? "default" : "outline"}
                size="sm"
                onClick={() => setWeight(preset)}
              >
                {preset}
              </Button>
            ))}
          </div>

          {/* Slider */}
          <div className="px-4">
            <input
              type="range"
              min={minWeight}
              max={maxWeight}
              step={5}
              value={weight}
              onChange={(e) => setWeight(Number(e.target.value))}
              className="w-full h-2 bg-muted rounded-lg appearance-none cursor-pointer accent-primary"
            />
            <div className="flex justify-between text-xs text-muted-foreground mt-1">
              <span>{minWeight} lbs</span>
              <span>{maxWeight} lbs</span>
            </div>
          </div>
        </div>

        <DialogFooter className="gap-2 sm:gap-0">
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={handleSubmit}>
            Set Weight
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
