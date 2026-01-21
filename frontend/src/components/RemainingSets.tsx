import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { BarbellCalculator } from "@/components/BarbellCalculator";
import { useWorkout } from "@/context/WorkoutContext";
import { Exercise } from "@/lib/api";

function exerciseToString(exercise: Exercise): string {
  switch (exercise) {
    case Exercise.SQUAT:
      return "Squat";
    case Exercise.BENCH:
      return "Bench Press";
    case Exercise.DEADLIFT:
      return "Deadlift";
    case Exercise.OHP:
      return "Overhead Press";
    case Exercise.ROW:
      return "Barbell Row";
    default:
      return "Unknown";
  }
}

function exerciseEmoji(exercise: Exercise): string {
  switch (exercise) {
    case Exercise.SQUAT:
      return "🦵";
    case Exercise.BENCH:
      return "💪";
    case Exercise.DEADLIFT:
      return "🏋️";
    case Exercise.OHP:
      return "🙆";
    case Exercise.ROW:
      return "🚣";
    default:
      return "❓";
  }
}

export function RemainingSets() {
  const { workoutState, phase, remainingSetsGrouped, nextSet, handleUpdateWeight } = useWorkout();
  
  // Weight editing state (for barbell calculator modal)
  const [editingExercise, setEditingExercise] = useState<Exercise | null>(null);
  const [editingCurrentWeight, setEditingCurrentWeight] = useState<number>(45);

  // Open the barbell calculator for an exercise
  const openWeightEditor = (exercise: Exercise, currentWeight: number) => {
    setEditingExercise(exercise);
    setEditingCurrentWeight(currentWeight);
  };

  // Close the barbell calculator
  const closeWeightEditor = () => {
    setEditingExercise(null);
  };

  // Don't show in preview phase or if no remaining sets
  if (phase === "preview" || !workoutState || workoutState.remainingSets.length === 0) {
    return null;
  }

  return (
    <>
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-lg">Remaining Sets</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {Object.entries(remainingSetsGrouped).map(([exercise, sets]) => {
              const exerciseNum = Number(exercise) as Exercise;
              
              return (
                <div key={exercise} className="space-y-1">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span>{exerciseEmoji(exerciseNum)}</span>
                      <span>{exerciseToString(exerciseNum)}</span>
                      <span className="text-sm text-muted-foreground">
                        @ {sets[0]?.targetWeight} lbs
                      </span>
                      <Button 
                        variant="ghost" 
                        size="sm"
                        className="h-6 w-6 p-0"
                        onClick={() => openWeightEditor(exerciseNum, sets[0]?.targetWeight ?? 45)}
                      >
                        ✏️
                      </Button>
                    </div>
                    <div className="flex gap-1">
                      {sets.map((set, idx) => (
                        <div 
                          key={idx}
                          className={`w-8 h-8 rounded flex items-center justify-center text-sm ${
                            set === nextSet 
                              ? "bg-primary text-primary-foreground font-bold" 
                              : "bg-muted text-muted-foreground"
                          }`}
                        >
                          {set.setNumber}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Barbell Calculator Modal */}
      <BarbellCalculator
        isOpen={editingExercise !== null}
        onClose={closeWeightEditor}
        currentWeight={editingCurrentWeight}
        onSubmit={(newWeight) => {
          if (editingExercise !== null) {
            handleUpdateWeight(editingExercise, newWeight);
            closeWeightEditor();
          }
        }}
        exerciseName={editingExercise !== null ? exerciseToString(editingExercise) : ""}
      />
    </>
  );
}
