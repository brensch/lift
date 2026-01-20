package service

import (
	"context"
	"database/sql"
	"fmt"
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
	RestSuccessSeconds = 6  // Production: 180 (3 min)
	RestFailureSeconds = 10 // Production: 300 (5 min)
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

	// Get or create today's session
	sessionID, sessionStartedAt, err := s.getOrCreateTodaySession(ctx, database)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Calculate plan
	plan, err := s.calculateNextWorkout(database, username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
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

	plan, err := s.calculateNextWorkout(database, username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	sessionID, _, err := s.getOrCreateTodaySession(ctx, database)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
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

func (s *WorkoutService) getOrCreateTodaySession(ctx context.Context, database *sql.DB) (string, time.Time, error) {
	today := time.Now().Truncate(24 * time.Hour)

	var sessionID string
	var startedAt time.Time
	err := database.QueryRowContext(ctx, `
		SELECT id, started_at FROM sessions 
		WHERE started_at >= ? 
		ORDER BY started_at DESC LIMIT 1
	`, today).Scan(&sessionID, &startedAt)

	if err == sql.ErrNoRows {
		// Create new session
		sessionID = fmt.Sprintf("session-%d", time.Now().UnixNano())
		startedAt = time.Now()
		_, err = database.ExecContext(ctx, `
			INSERT INTO sessions (id, started_at) VALUES (?, ?)
		`, sessionID, startedAt)
		if err != nil {
			return "", time.Time{}, err
		}
	} else if err != nil {
		return "", time.Time{}, err
	}

	return sessionID, startedAt, nil
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

func (s *WorkoutService) calculateNextWorkout(database *sql.DB, username string) (*workoutv1.Plan, error) {
	// Get the last workout to determine which exercises to do
	// 5x5 alternates between:
	// Workout A: Squat, Bench, Row
	// Workout B: Squat, OHP, Deadlift

	var lastExercise string
	err := database.QueryRow(`
		SELECT exercise FROM activities 
		WHERE type = 'SET' AND ended_at IS NOT NULL
		ORDER BY ended_at DESC 
		LIMIT 1
	`).Scan(&lastExercise)

	isWorkoutA := true
	if err == nil {
		if lastExercise == "EXERCISE_BENCH" || lastExercise == "EXERCISE_ROW" {
			isWorkoutA = false
		}
	}

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

	var plannedSets []*workoutv1.PlannedSet
	for _, exercise := range exercises {
		weight := s.getTargetWeight(database, exercise)
		reps := int32(5)
		numSets := 5
		if exercise == workoutv1.Exercise_EXERCISE_DEADLIFT {
			numSets = 1
		}
		for setNum := 1; setNum <= numSets; setNum++ {
			plannedSets = append(plannedSets, &workoutv1.PlannedSet{
				Exercise:     exercise,
				TargetWeight: weight,
				TargetReps:   reps,
				SetNumber:    int32(setNum),
			})
		}
	}

	return &workoutv1.Plan{
		UserId: username,
		Sets:   plannedSets,
	}, nil
}

func (s *WorkoutService) getTargetWeight(database *sql.DB, exercise workoutv1.Exercise) float32 {
	exerciseName := exercise.String()

	var lastWeight float64
	var lastReps int
	err := database.QueryRow(`
		SELECT weight, actual_reps FROM activities 
		WHERE exercise = ? AND type = 'SET' AND ended_at IS NOT NULL
		ORDER BY ended_at DESC 
		LIMIT 1
	`, exerciseName).Scan(&lastWeight, &lastReps)

	if err != nil {
		// Starting weights
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

	// If they hit all 5 reps, increase weight
	if lastReps >= 5 {
		if exercise == workoutv1.Exercise_EXERCISE_DEADLIFT {
			return float32(lastWeight + 10)
		}
		return float32(lastWeight + 5)
	}

	return float32(lastWeight)
}
