package service

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"connectrpc.com/connect"
	"github.com/google/uuid"

	workoutv1 "github.com/brensch/lift/backend/gen/workout/v1"
	"github.com/brensch/lift/backend/gen/workout/v1/workoutv1connect"
	"github.com/brensch/lift/backend/internal/db"
	"github.com/brensch/lift/backend/internal/interceptor"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// Rest time configuration (in seconds)
// TESTING MODE: Using short times
const (
	RestSuccessSeconds = 180 // Production: 180 (3 min)
	RestFailureSeconds = 300 // Production: 300 (5 min)
)

// WorkoutService implements the WorkoutService RPC handlers
type WorkoutService struct {
	workoutv1connect.UnimplementedWorkoutServiceHandler
	dbManager *db.Manager
}

// NewWorkoutService creates a new workout service
func NewWorkoutService(dbManager *db.Manager) *WorkoutService {
	return &WorkoutService{
		dbManager: dbManager,
	}
}

// GetWorkoutState returns the current workout state
func (s *WorkoutService) GetWorkoutState(
	ctx context.Context,
	req *connect.Request[workoutv1.GetWorkoutStateRequest],
) (*connect.Response[workoutv1.GetWorkoutStateResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get or create today's session (this also populates planned_sets for new sessions)
	sessionID, sessionStartedAt, _, err := s.getOrCreateTodaySession(ctx, database, req.Msg.StartNewSession)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get the stored plan for this session
	plannedSets, err := s.getPlannedSets(ctx, database, sessionID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	plan := &workoutv1.Plan{
		UserId: username,
		Sets:   plannedSets,
	}

	// Get all activities for this session
	timeline, err := s.getSessionActivities(ctx, database, sessionID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Find current activity (one without ended_at)
	var currentActivity *workoutv1.Activity
	for _, a := range timeline {
		if a.EndedAt == nil || a.EndedAt.AsTime().IsZero() {
			currentActivity = a
			break
		}
	}

	// Calculate remaining sets
	completedSets := s.countCompletedSets(timeline)
	remainingSets := s.calculateRemainingSets(plan.Sets, completedSets)

	var nextSet *workoutv1.PlannedSet
	if len(remainingSets) > 0 {
		nextSet = remainingSets[0]
	}

	isComplete := len(remainingSets) == 0

	state := &workoutv1.WorkoutState{
		SessionId:        sessionID,
		SessionStartedAt: timestamppb.New(sessionStartedAt),
		Timeline:         timeline,
		CurrentActivity:  currentActivity,
		NextSet:          nextSet,
		RemainingSets:    remainingSets,
		IsComplete:       isComplete,
	}

	return connect.NewResponse(&workoutv1.GetWorkoutStateResponse{
		State: state,
		Plan:  plan,
		RestConfig: &workoutv1.RestConfig{
			SuccessSeconds: RestSuccessSeconds,
			FailureSeconds: RestFailureSeconds,
		},
	}), nil
}

// StartSet begins timing a set
func (s *WorkoutService) StartSet(
	ctx context.Context,
	req *connect.Request[workoutv1.StartSetRequest],
) (*connect.Response[workoutv1.StartSetResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	now := time.Now()
	activityID := uuid.New().String()

	// End any current activity (like a REST that's still open)
	_, err = database.ExecContext(ctx, `
		UPDATE activities SET ended_at = ? 
		WHERE session_id = ? AND ended_at IS NULL
	`, now, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Create new set activity
	_, err = database.ExecContext(ctx, `
		INSERT INTO activities (id, session_id, type, started_at, exercise, set_number, weight, target_reps)
		VALUES (?, ?, 'SET', ?, ?, ?, ?, ?)
	`, activityID, req.Msg.SessionId, now, req.Msg.Exercise.String(), req.Msg.SetNumber, req.Msg.Weight, req.Msg.TargetReps)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	activity := &workoutv1.Activity{
		Id:         activityID,
		Type:       workoutv1.ActivityType_ACTIVITY_TYPE_SET,
		StartedAt:  timestamppb.New(now),
		Exercise:   req.Msg.Exercise,
		SetNumber:  req.Msg.SetNumber,
		Weight:     req.Msg.Weight,
		TargetReps: req.Msg.TargetReps,
	}

	return connect.NewResponse(&workoutv1.StartSetResponse{
		Activity: activity,
	}), nil
}

// FinishActivity finishes any activity (set or rest)
// For SET: records actual_reps and creates a REST activity
// For REST: just ends it (actual duration = ended_at - started_at)
func (s *WorkoutService) FinishActivity(
	ctx context.Context,
	req *connect.Request[workoutv1.FinishActivityRequest],
) (*connect.Response[workoutv1.FinishActivityResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	now := time.Now()

	// Get the activity
	var activityID, typeStr string
	var startedAt time.Time
	var exerciseStr sql.NullString
	var setNumber, targetReps, plannedDuration sql.NullInt64
	var weight sql.NullFloat64

	err = database.QueryRowContext(ctx, `
		SELECT id, type, started_at, exercise, set_number, weight, target_reps, planned_duration_seconds
		FROM activities WHERE id = ?
	`, req.Msg.ActivityId).Scan(
		&activityID, &typeStr, &startedAt, &exerciseStr,
		&setNumber, &weight, &targetReps, &plannedDuration,
	)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("activity not found: %w", err))
	}

	// Build the finished activity
	finishedActivity := &workoutv1.Activity{
		Id:        activityID,
		StartedAt: timestamppb.New(startedAt),
		EndedAt:   timestamppb.New(now),
	}

	var nextActivity *workoutv1.Activity

	if typeStr == "SET" {
		// Finishing a SET
		finishedActivity.Type = workoutv1.ActivityType_ACTIVITY_TYPE_SET
		finishedActivity.ActualReps = req.Msg.ActualReps

		if exerciseStr.Valid {
			if v, ok := workoutv1.Exercise_value[exerciseStr.String]; ok {
				finishedActivity.Exercise = workoutv1.Exercise(v)
			}
		}
		if setNumber.Valid {
			finishedActivity.SetNumber = int32(setNumber.Int64)
		}
		if weight.Valid {
			finishedActivity.Weight = float32(weight.Float64)
		}
		if targetReps.Valid {
			finishedActivity.TargetReps = int32(targetReps.Int64)
		}

		// Update the set activity in DB
		_, err = database.ExecContext(ctx, `
			UPDATE activities SET ended_at = ?, actual_reps = ? WHERE id = ?
		`, now, req.Msg.ActualReps, req.Msg.ActivityId)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}

		// Determine rest duration based on reps
		restDuration := RestSuccessSeconds
		if req.Msg.ActualReps < finishedActivity.TargetReps {
			restDuration = RestFailureSeconds
		}

		// Create rest activity
		restActivityID := uuid.New().String()
		_, err = database.ExecContext(ctx, `
			INSERT INTO activities (id, session_id, type, started_at, planned_duration_seconds)
			VALUES (?, ?, 'REST', ?, ?)
		`, restActivityID, req.Msg.SessionId, now, restDuration)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}

		nextActivity = &workoutv1.Activity{
			Id:                     restActivityID,
			Type:                   workoutv1.ActivityType_ACTIVITY_TYPE_REST,
			StartedAt:              timestamppb.New(now),
			PlannedDurationSeconds: int32(restDuration),
		}

	} else if typeStr == "REST" {
		// Finishing a REST
		finishedActivity.Type = workoutv1.ActivityType_ACTIVITY_TYPE_REST
		if plannedDuration.Valid {
			finishedActivity.PlannedDurationSeconds = int32(plannedDuration.Int64)
		}

		// Update the rest activity in DB
		_, err = database.ExecContext(ctx, `
			UPDATE activities SET ended_at = ? WHERE id = ?
		`, now, req.Msg.ActivityId)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}

		// No next activity - user needs to call StartSet
		nextActivity = nil
	}

	// Get updated state
	stateResp, err := s.GetWorkoutState(ctx, connect.NewRequest(&workoutv1.GetWorkoutStateRequest{}))
	if err != nil {
		return nil, err
	}

	return connect.NewResponse(&workoutv1.FinishActivityResponse{
		FinishedActivity: finishedActivity,
		NextActivity:     nextActivity,
		State:            stateResp.Msg.State,
	}), nil
}

// UpdatePlannedWeight updates the target weight for an exercise (all sets) or a specific set
func (s *WorkoutService) UpdatePlannedWeight(
	ctx context.Context,
	req *connect.Request[workoutv1.UpdatePlannedWeightRequest],
) (*connect.Response[workoutv1.UpdatePlannedWeightResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	exerciseName := req.Msg.Exercise.String()
	newWeight := req.Msg.NewWeight

	if req.Msg.SetNumber != nil {
		// Update only the specific set
		_, err = database.ExecContext(ctx, `
			UPDATE planned_sets 
			SET target_weight = ? 
			WHERE session_id = ? AND exercise = ? AND set_number = ?
		`, newWeight, req.Msg.SessionId, exerciseName, *req.Msg.SetNumber)
	} else {
		// Update all sets for the exercise
		_, err = database.ExecContext(ctx, `
			UPDATE planned_sets 
			SET target_weight = ? 
			WHERE session_id = ? AND exercise = ?
		`, newWeight, req.Msg.SessionId, exerciseName)
	}

	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Return the updated sets
	updatedSets, err := s.getPlannedSets(ctx, database, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Filter to only return sets for the updated exercise
	var filteredSets []*workoutv1.PlannedSet
	for _, set := range updatedSets {
		if set.Exercise == req.Msg.Exercise {
			filteredSets = append(filteredSets, set)
		}
	}

	return connect.NewResponse(&workoutv1.UpdatePlannedWeightResponse{
		UpdatedSets: filteredSets,
	}), nil
}

// GetNextWorkout is the legacy RPC for backwards compatibility
func (s *WorkoutService) GetNextWorkout(
	ctx context.Context,
	req *connect.Request[workoutv1.GetNextWorkoutRequest],
) (*connect.Response[workoutv1.GetNextWorkoutResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	sessionID, _, _, err := s.getOrCreateTodaySession(ctx, database, false)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get the stored plan for this session
	plannedSets, err := s.getPlannedSets(ctx, database, sessionID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	plan := &workoutv1.Plan{
		UserId: username,
		Sets:   plannedSets,
	}

	timeline, err := s.getSessionActivities(ctx, database, sessionID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	var lastCompletedAt *timestamppb.Timestamp
	for _, a := range timeline {
		if a.Type == workoutv1.ActivityType_ACTIVITY_TYPE_SET && a.EndedAt != nil {
			lastCompletedAt = a.EndedAt
		}
	}

	return connect.NewResponse(&workoutv1.GetNextWorkoutResponse{
		Plan:               plan,
		LastSetCompletedAt: lastCompletedAt,
		CompletedSets:      timeline,
		ActiveSessionId:    sessionID,
	}), nil
}

// LogSet is the legacy RPC for backwards compatibility
func (s *WorkoutService) LogSet(
	ctx context.Context,
	req *connect.Request[workoutv1.LogSetRequest],
) (*connect.Response[workoutv1.LogSetResponse], error) {
	now := time.Now()
	return connect.NewResponse(&workoutv1.LogSetResponse{
		Success:     true,
		CompletedAt: timestamppb.New(now),
	}), nil
}

// Helper functions

// isSessionComplete checks if all planned sets in a session have been completed
func (s *WorkoutService) isSessionComplete(ctx context.Context, database *sql.DB, sessionID string) bool {
	// Get planned sets for the session
	plannedSets, err := s.getPlannedSets(ctx, database, sessionID)
	if err != nil || len(plannedSets) == 0 {
		return false
	}

	// Get all completed set activities for this session
	timeline, err := s.getSessionActivities(ctx, database, sessionID)
	if err != nil {
		return false
	}

	completedSets := s.countCompletedSets(timeline)
	remainingSets := s.calculateRemainingSets(plannedSets, completedSets)

	return len(remainingSets) == 0
}

func (s *WorkoutService) getOrCreateTodaySession(ctx context.Context, database *sql.DB, startNewSession bool) (string, time.Time, string, error) {
	today := time.Now().Truncate(24 * time.Hour)

	var sessionID string
	var startedAt time.Time
	var workoutType string
	err := database.QueryRowContext(ctx, `
		SELECT id, started_at, COALESCE(workout_type, 'A') FROM sessions 
		WHERE started_at >= ? 
		ORDER BY started_at DESC LIMIT 1
	`, today).Scan(&sessionID, &startedAt, &workoutType)

	// Check if the existing session is complete (all sets done)
	// Only create a new session if explicitly requested via startNewSession
	sessionComplete := false
	if err == nil && startNewSession {
		sessionComplete = s.isSessionComplete(ctx, database, sessionID)
	}

	if err == sql.ErrNoRows || sessionComplete {
		// Determine workout type based on last session's type
		var lastWorkoutType string
		err = database.QueryRowContext(ctx, `
			SELECT COALESCE(workout_type, 'A') FROM sessions 
			ORDER BY started_at DESC LIMIT 1
		`).Scan(&lastWorkoutType)

		// Alternate: if last was A, this is B; if last was B (or no previous), this is A
		if err == nil && lastWorkoutType == "A" {
			workoutType = "B"
		} else {
			workoutType = "A"
		}

		// Create new session with determined workout type
		sessionID = fmt.Sprintf("session-%d", time.Now().UnixNano())
		startedAt = time.Now()
		_, err = database.ExecContext(ctx, `
			INSERT INTO sessions (id, started_at, workout_type) VALUES (?, ?, ?)
		`, sessionID, startedAt, workoutType)
		if err != nil {
			return "", time.Time{}, "", err
		}

		// Populate planned_sets for this new session
		if err := s.populatePlannedSets(ctx, database, sessionID, workoutType); err != nil {
			return "", time.Time{}, "", err
		}
	} else if err != nil {
		return "", time.Time{}, "", err
	}

	return sessionID, startedAt, workoutType, nil
}

// populatePlannedSets creates the planned sets for a new session based on workout type and previous performance
func (s *WorkoutService) populatePlannedSets(ctx context.Context, database *sql.DB, sessionID string, workoutType string) error {
	isWorkoutA := workoutType == "A"

	var exercises []workoutv1.Exercise
	if isWorkoutA {
		exercises = []workoutv1.Exercise{
			workoutv1.Exercise_EXERCISE_SQUAT,
			workoutv1.Exercise_EXERCISE_BENCH,
			workoutv1.Exercise_EXERCISE_ROW,
		}
	} else {
		exercises = []workoutv1.Exercise{
			workoutv1.Exercise_EXERCISE_SQUAT,
			workoutv1.Exercise_EXERCISE_OHP,
			workoutv1.Exercise_EXERCISE_DEADLIFT,
		}
	}

	for _, exercise := range exercises {
		weight := s.getTargetWeight(database, exercise)
		reps := int32(5)
		numSets := 5
		if exercise == workoutv1.Exercise_EXERCISE_DEADLIFT {
			numSets = 1
		}

		for setNum := 1; setNum <= numSets; setNum++ {
			setID := uuid.New().String()
			_, err := database.ExecContext(ctx, `
				INSERT INTO planned_sets (id, session_id, exercise, set_number, target_weight, target_reps)
				VALUES (?, ?, ?, ?, ?, ?)
			`, setID, sessionID, exercise.String(), setNum, weight, reps)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

// getPlannedSets retrieves the planned sets for a session from the database
func (s *WorkoutService) getPlannedSets(ctx context.Context, database *sql.DB, sessionID string) ([]*workoutv1.PlannedSet, error) {
	// First, check if there's a custom exercise order for this session
	var exerciseOrder string
	err := database.QueryRowContext(ctx, `SELECT exercise_order FROM sessions WHERE id = ?`, sessionID).Scan(&exerciseOrder)
	if err != nil && err != sql.ErrNoRows {
		return nil, err
	}

	// Build the ORDER BY clause based on custom order or default
	orderByClause := s.buildExerciseOrderClause(exerciseOrder)

	query := fmt.Sprintf(`
		SELECT exercise, set_number, target_weight, target_reps
		FROM planned_sets
		WHERE session_id = ?
		ORDER BY %s, set_number ASC
	`, orderByClause)

	rows, err := database.QueryContext(ctx, query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sets []*workoutv1.PlannedSet
	for rows.Next() {
		var exerciseStr string
		var setNumber int32
		var weight float64
		var reps int32

		if err := rows.Scan(&exerciseStr, &setNumber, &weight, &reps); err != nil {
			return nil, err
		}

		exercise := workoutv1.Exercise_EXERCISE_UNSPECIFIED
		if v, ok := workoutv1.Exercise_value[exerciseStr]; ok {
			exercise = workoutv1.Exercise(v)
		}

		sets = append(sets, &workoutv1.PlannedSet{
			Exercise:     exercise,
			SetNumber:    setNumber,
			TargetWeight: float32(weight),
			TargetReps:   reps,
		})
	}

	return sets, nil
}

// buildExerciseOrderClause builds the SQL ORDER BY clause for exercises
func (s *WorkoutService) buildExerciseOrderClause(exerciseOrder string) string {
	if exerciseOrder == "" {
		// Default order
		return `CASE exercise 
			WHEN 'EXERCISE_SQUAT' THEN 1 
			WHEN 'EXERCISE_BENCH' THEN 2 
			WHEN 'EXERCISE_ROW' THEN 3 
			WHEN 'EXERCISE_OHP' THEN 2 
			WHEN 'EXERCISE_DEADLIFT' THEN 3 
		END`
	}

	// Parse custom order (comma-separated exercise names)
	exercises := strings.Split(exerciseOrder, ",")
	if len(exercises) == 0 {
		return `CASE exercise 
			WHEN 'EXERCISE_SQUAT' THEN 1 
			WHEN 'EXERCISE_BENCH' THEN 2 
			WHEN 'EXERCISE_ROW' THEN 3 
			WHEN 'EXERCISE_OHP' THEN 2 
			WHEN 'EXERCISE_DEADLIFT' THEN 3 
		END`
	}

	// Build custom CASE statement
	caseClause := "CASE exercise "
	for i, ex := range exercises {
		caseClause += fmt.Sprintf("WHEN '%s' THEN %d ", ex, i+1)
	}
	caseClause += "ELSE 999 END"

	return caseClause
}

func (s *WorkoutService) getSessionActivities(ctx context.Context, database *sql.DB, sessionID string) ([]*workoutv1.Activity, error) {
	rows, err := database.QueryContext(ctx, `
		SELECT id, type, started_at, ended_at, exercise, set_number, weight, target_reps, actual_reps, planned_duration_seconds
		FROM activities 
		WHERE session_id = ?
		ORDER BY started_at ASC
	`, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var activities []*workoutv1.Activity
	for rows.Next() {
		var a workoutv1.Activity
		var typeStr string
		var startedAt time.Time
		var endedAt sql.NullTime
		var exerciseStr sql.NullString
		var setNumber, targetReps, actualReps, plannedDuration sql.NullInt64
		var weight sql.NullFloat64

		err := rows.Scan(&a.Id, &typeStr, &startedAt, &endedAt, &exerciseStr, &setNumber, &weight, &targetReps, &actualReps, &plannedDuration)
		if err != nil {
			return nil, err
		}

		a.StartedAt = timestamppb.New(startedAt)
		if endedAt.Valid {
			a.EndedAt = timestamppb.New(endedAt.Time)
		}

		switch typeStr {
		case "SET":
			a.Type = workoutv1.ActivityType_ACTIVITY_TYPE_SET
		case "REST":
			a.Type = workoutv1.ActivityType_ACTIVITY_TYPE_REST
		}

		if exerciseStr.Valid {
			if v, ok := workoutv1.Exercise_value[exerciseStr.String]; ok {
				a.Exercise = workoutv1.Exercise(v)
			}
		}
		if setNumber.Valid {
			a.SetNumber = int32(setNumber.Int64)
		}
		if weight.Valid {
			a.Weight = float32(weight.Float64)
		}
		if targetReps.Valid {
			a.TargetReps = int32(targetReps.Int64)
		}
		if actualReps.Valid {
			a.ActualReps = int32(actualReps.Int64)
		}
		if plannedDuration.Valid {
			a.PlannedDurationSeconds = int32(plannedDuration.Int64)
		}

		activities = append(activities, &a)
	}

	return activities, nil
}

func (s *WorkoutService) countCompletedSets(timeline []*workoutv1.Activity) map[workoutv1.Exercise]int {
	counts := make(map[workoutv1.Exercise]int)
	for _, a := range timeline {
		if a.Type == workoutv1.ActivityType_ACTIVITY_TYPE_SET && a.EndedAt != nil {
			counts[a.Exercise]++
		}
	}
	return counts
}

func (s *WorkoutService) calculateRemainingSets(allSets []*workoutv1.PlannedSet, completed map[workoutv1.Exercise]int) []*workoutv1.PlannedSet {
	exerciseCounts := make(map[workoutv1.Exercise]int)
	var remaining []*workoutv1.PlannedSet

	for _, set := range allSets {
		exerciseCounts[set.Exercise]++
		if exerciseCounts[set.Exercise] > completed[set.Exercise] {
			remaining = append(remaining, set)
		}
	}

	return remaining
}

func (s *WorkoutService) getTargetWeight(database *sql.DB, exercise workoutv1.Exercise) float32 {
	exerciseName := exercise.String()
	today := time.Now().Truncate(24 * time.Hour)

	// Look at the last session before today that included this exercise.
	// Check if ALL sets of that exercise hit 5 reps - only then increase weight.
	// This ensures the working weight stays constant throughout the current workout.

	// First, find the most recent session before today that had this exercise
	var lastSessionID string
	err := database.QueryRow(`
		SELECT DISTINCT a.session_id 
		FROM activities a
		JOIN sessions s ON a.session_id = s.id
		WHERE a.exercise = ? 
		AND a.type = 'SET' 
		AND a.ended_at IS NOT NULL
		AND s.started_at < ?
		ORDER BY a.ended_at DESC 
		LIMIT 1
	`, exerciseName, today).Scan(&lastSessionID)

	if err != nil {
		// No previous session found - use starting weights
		switch exercise {
		case workoutv1.Exercise_EXERCISE_SQUAT:
			return 45
		case workoutv1.Exercise_EXERCISE_BENCH:
			return 45
		case workoutv1.Exercise_EXERCISE_ROW:
			return 65
		case workoutv1.Exercise_EXERCISE_OHP:
			return 45
		case workoutv1.Exercise_EXERCISE_DEADLIFT:
			return 95
		default:
			return 45
		}
	}

	// Get the weight used and check if all sets hit 5 reps in that session
	var lastWeight float64
	var totalSets, successfulSets int
	rows, err := database.Query(`
		SELECT weight, actual_reps FROM activities 
		WHERE session_id = ? 
		AND exercise = ? 
		AND type = 'SET' 
		AND ended_at IS NOT NULL
	`, lastSessionID, exerciseName)
	if err != nil {
		return 45 // fallback
	}
	defer rows.Close()

	for rows.Next() {
		var weight float64
		var reps int
		if err := rows.Scan(&weight, &reps); err != nil {
			continue
		}
		lastWeight = weight
		totalSets++
		if reps >= 5 {
			successfulSets++
		}
	}

	if totalSets == 0 {
		return 45 // fallback
	}

	// Only increase weight if ALL sets were successful (hit 5 reps each)
	if successfulSets == totalSets {
		if exercise == workoutv1.Exercise_EXERCISE_DEADLIFT {
			return float32(lastWeight + 10)
		}
		return float32(lastWeight + 5)
	}

	// Not all sets were successful - keep the same weight
	return float32(lastWeight)
}

// SetExerciseOrder sets the exercise order for a session
func (s *WorkoutService) SetExerciseOrder(
	ctx context.Context,
	req *connect.Request[workoutv1.SetExerciseOrderRequest],
) (*connect.Response[workoutv1.SetExerciseOrderResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Convert exercise order to comma-separated string of exercise names
	var exerciseNames []string
	for _, ex := range req.Msg.ExerciseOrder {
		exerciseNames = append(exerciseNames, ex.String())
	}
	exerciseOrderStr := strings.Join(exerciseNames, ",")

	// Update the session's exercise order
	_, err = database.ExecContext(ctx, `
		UPDATE sessions SET exercise_order = ? WHERE id = ?
	`, exerciseOrderStr, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to update exercise order: %w", err))
	}

	// Get updated planned sets with new order
	plannedSets, err := s.getPlannedSets(ctx, database, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get completed sets to calculate remaining
	timeline, err := s.getSessionActivities(ctx, database, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	completedSets := s.countCompletedSets(timeline)
	remainingSets := s.calculateRemainingSets(plannedSets, completedSets)

	return connect.NewResponse(&workoutv1.SetExerciseOrderResponse{
		RemainingSets: remainingSets,
	}), nil
}
