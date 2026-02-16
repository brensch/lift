# Context Handover: Exercise Groups Refactor

## Current State
- Updated `ExerciseGroupWidget` to a modern card-based UI.
- Separated Warmup and Working sets into distinct rows with labels.
- Increased spacing and refined the visual hierarchy in `WorkoutScreen`.

## The "Big Boi" Plan
1. **New Concept: Exercise Groups**
   - A workout should consist of "Exercise Groups" (e.g., "5x5 Squats", "Deadlift Session", "Bench/Row Superset").
   - Each set must belong to an `exercise_group_id`.
   - `ExerciseGroup` table: `id`, `name`, `workout_id`, `type` (5x5, 1x5, Superset, etc.), `include_warmup`.

2. **Backend Shift (Rust)**
   - Move set-generation logic (warmup weights, set counts) from Flutter to the Rust backend.
   - New/Updated Endpoints:
     - `CreateExerciseGroup`: Takes group type, involved exercises, target weights, etc.
     - Backend validates inputs (e.g., ensures a superset has multiple exercises) and generates the `ProposedSet` entries.
   - Frontend becomes "dumb," providing inputs to the backend rather than calculating sets locally.

3. **Database/API**
   - Update Protobuf definitions to include `ExerciseGroup`.
   - Add generic API calls for modifying groups rather than individual sets.

## Next Steps
- Access the root directory to modify `.proto` files and Rust backend.
- Implement the `exercise_groups` table and logic.
- Refactor `WorkoutProvider` and modals to use the new group-based API.
