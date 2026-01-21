import { useState } from "react";
import { GripVertical } from "lucide-react";
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
  const { workoutState, phase, remainingSetsGrouped, orderedExercises, nextSet, handleUpdateWeight, setExerciseOrder } = useWorkout();
  
  // Weight editing state (for barbell calculator modal)
  const [editingExercise, setEditingExercise] = useState<Exercise | null>(null);
  const [editingCurrentWeight, setEditingCurrentWeight] = useState<number>(45);
  
  // Drag and drop state
  const [draggedExercise, setDraggedExercise] = useState<Exercise | null>(null);
  const [dragOverExercise, setDragOverExercise] = useState<Exercise | null>(null);

  // Open the barbell calculator for an exercise
  const openWeightEditor = (exercise: Exercise, currentWeight: number) => {
    setEditingExercise(exercise);
    setEditingCurrentWeight(currentWeight);
  };

  // Close the barbell calculator
  const closeWeightEditor = () => {
    setEditingExercise(null);
  };

  // Handle drag start
  const handleDragStart = (exercise: Exercise) => {
    setDraggedExercise(exercise);
  };

  // Handle drag over
  const handleDragOver = (e: React.DragEvent, exercise: Exercise) => {
    e.preventDefault();
    if (draggedExercise !== exercise) {
      setDragOverExercise(exercise);
    }
  };

  // Handle drag leave
  const handleDragLeave = () => {
    setDragOverExercise(null);
  };

  // Handle drop
  const handleDrop = (e: React.DragEvent, targetExercise: Exercise) => {
    e.preventDefault();
    
    if (draggedExercise !== null && draggedExercise !== targetExercise) {
      const newOrder = [...orderedExercises];
      const draggedIndex = newOrder.indexOf(draggedExercise);
      const targetIndex = newOrder.indexOf(targetExercise);
      
      // Remove dragged item and insert at target position
      newOrder.splice(draggedIndex, 1);
      newOrder.splice(targetIndex, 0, draggedExercise);
      
      setExerciseOrder(newOrder);
    }
    
    setDraggedExercise(null);
    setDragOverExercise(null);
  };

  // Handle drag end
  const handleDragEnd = () => {
    setDraggedExercise(null);
    setDragOverExercise(null);
  };

  // Don't show in preview phase or if no remaining sets
  if (phase === "preview" || !workoutState || workoutState.remainingSets.length === 0) {
    return null;
  }

  return (
    <>
      <Card>
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <CardTitle className="text-lg">Workout Queue</CardTitle>
            <span className="text-xs text-muted-foreground">
              drag to reorder
            </span>
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {orderedExercises.map((exerciseNum, index) => {
              const sets = remainingSetsGrouped[exerciseNum];
              if (!sets || sets.length === 0) return null;
              
              const isFirst = index === 0;
              const isDragging = draggedExercise === exerciseNum;
              const isDragOver = dragOverExercise === exerciseNum;
              
              return (
                <div 
                  key={exerciseNum}
                  draggable
                  onDragStart={() => handleDragStart(exerciseNum)}
                  onDragOver={(e) => handleDragOver(e, exerciseNum)}
                  onDragLeave={handleDragLeave}
                  onDrop={(e) => handleDrop(e, exerciseNum)}
                  onDragEnd={handleDragEnd}
                  className={`
                    p-3 rounded-lg cursor-grab active:cursor-grabbing
                    transition-all duration-200 select-none
                    ${isFirst 
                      ? "bg-primary/5 border-2 border-primary" 
                      : "bg-muted/30 border border-muted hover:border-muted-foreground/30"
                    }
                    ${isDragging ? "opacity-50 scale-95" : ""}
                    ${isDragOver ? "border-primary border-dashed" : ""}
                  `}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      {/* Position indicator */}
                      <div className={`
                        w-6 h-6 rounded-full flex-shrink-0
                        flex items-center justify-center text-xs font-bold
                        ${isFirst 
                          ? "bg-primary text-primary-foreground" 
                          : "bg-muted text-muted-foreground"
                        }
                      `}>
                        {index + 1}
                      </div>
                      <GripVertical className="h-4 w-4 text-muted-foreground flex-shrink-0" />
                      <span className="text-lg">{exerciseEmoji(exerciseNum)}</span>
                      <div className="flex flex-col">
                        <span className={`font-medium ${isFirst ? "text-primary" : ""}`}>
                          {exerciseToString(exerciseNum)}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          @ {sets[0]?.targetWeight} lbs
                        </span>
                      </div>
                      <Button 
                        variant="ghost" 
                        size="sm"
                        className="h-6 w-6 p-0"
                        onClick={(e) => {
                          e.stopPropagation();
                          openWeightEditor(exerciseNum, sets[0]?.targetWeight ?? 45);
                        }}
                      >
                        ✏️
                      </Button>
                    </div>
                    <div className="flex gap-1">
                      {sets.map((set, idx) => (
                        <div 
                          key={idx}
                          className={`w-7 h-7 rounded flex items-center justify-center text-xs ${
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
