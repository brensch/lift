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
	"github.com/brensch/lift/backend/internal/hub"
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
	dbManager    *db.Manager
	groupManager *db.GroupManager
	hub          *hub.Hub
}

// NewWorkoutService creates a new workout service
func NewWorkoutService(dbManager *db.Manager, groupManager *db.GroupManager, h *hub.Hub) *WorkoutService {
	return &WorkoutService{
		dbManager:    dbManager,
		groupManager: groupManager,
		hub:          h,
	}
}

// GetUpcomingWorkouts returns the next 5 proposed workouts and any active workout
func (s *WorkoutService) GetUpcomingWorkouts(
	ctx context.Context,
	req *connect.Request[workoutv1.GetUpcomingWorkoutsRequest],
) (*connect.Response[workoutv1.GetUpcomingWorkoutsResponse], error) {
	start := time.Now()
	logStep := func(step string) {
		elapsed := time.Since(start)
		if elapsed > 100*time.Millisecond {
			fmt.Printf("[TIMING] %s: %v (total: %v)\n", step, elapsed, time.Since(start))
		}
	}
	defer func() {
		elapsed := time.Since(start)
		if elapsed > 500*time.Millisecond {
			fmt.Printf("[SLOW] GetUpcomingWorkouts total: %v\n", elapsed)
		}
	}()

	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}
	logStep("got username")

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	logStep("got database")

	// Check for active workout (started but not complete)
	var activeWorkout *workoutv1.WorkoutState
	activeState, err := s.getActiveWorkout(ctx, database)
	if err == nil && activeState != nil {
		activeWorkout = activeState
	}
	logStep("got active workout")

	// Get user preferences for workout days
	preferences := s.getUserPreferences(database)
	logStep("got preferences")

	// Get last completed workout type to determine next type
	lastWorkoutType := s.getLastWorkoutType(database)
	logStep("got last workout type")

	// Calculate target dates for upcoming workouts
	targetDates := s.calculateTargetDates(preferences.WorkoutDays, 5)
	logStep("calculated target dates")

	// Generate 5 upcoming workouts
	workouts := make([]*workoutv1.ProposedWorkout, 5)
	currentType := lastWorkoutType
	for i := 0; i < 5; i++ {
		// Alternate workout type
		if currentType == "A" {
			currentType = "B"
		} else {
			currentType = "A"
		}

		sets := s.generateWorkoutSets(database, currentType)
		workouts[i] = &workoutv1.ProposedWorkout{
			Sequence:    int32(i + 1),
			WorkoutType: currentType,
			Sets:        sets,
			TargetDate:  timestamppb.New(targetDates[i]),
		}
	}
	logStep("generated workouts")

	// Get pending invites and active group (legacy system)
	pendingInvites := s.getPendingInvites(ctx, database, username)
	logStep("got pending invites")

	activeGroup := s.getActiveGroup(ctx, database, username)
	logStep("got active group")

	// Check for active group session (new system)
	var activeSession *workoutv1.GroupSession
	var sessionID sql.NullString
	database.QueryRowContext(ctx, `SELECT session_id FROM active_group_session WHERE id = 1`).Scan(&sessionID)
	logStep("queried active group session")

	if sessionID.Valid && sessionID.String != "" {
		groupDB, err := s.groupManager.GetSession(sessionID.String)
		logStep("got group db")
		if err == nil {
			activeSession = s.buildGroupSession(ctx, groupDB, sessionID.String)
			logStep("built group session")
		}
	}

	return connect.NewResponse(&workoutv1.GetUpcomingWorkoutsResponse{
		Workouts:      workouts,
		ActiveWorkout: activeWorkout,
		RestConfig: &workoutv1.RestConfig{
			SuccessSeconds: RestSuccessSeconds,
			FailureSeconds: RestFailureSeconds,
		},
		Preferences:    preferences,
		PendingInvites: pendingInvites,
		ActiveGroup:    activeGroup,
		ActiveSession:  activeSession,
	}), nil
}

// GetUserPreferences returns the user's preferences
func (s *WorkoutService) GetUserPreferences(
	ctx context.Context,
	req *connect.Request[workoutv1.GetUserPreferencesRequest],
) (*connect.Response[workoutv1.GetUserPreferencesResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	preferences := s.getUserPreferences(database)

	return connect.NewResponse(&workoutv1.GetUserPreferencesResponse{
		Preferences: preferences,
	}), nil
}

// UpdateUserPreferences updates the user's preferences
func (s *WorkoutService) UpdateUserPreferences(
	ctx context.Context,
	req *connect.Request[workoutv1.UpdateUserPreferencesRequest],
) (*connect.Response[workoutv1.UpdateUserPreferencesResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Convert workout days to comma-separated string
	days := make([]string, len(req.Msg.Preferences.WorkoutDays))
	for i, day := range req.Msg.Preferences.WorkoutDays {
		days[i] = fmt.Sprintf("%d", day)
	}
	daysStr := strings.Join(days, ",")

	// Update preferences
	_, err = database.ExecContext(ctx, `
		UPDATE user_preferences SET workout_days = ?, updated_at = CURRENT_TIMESTAMP WHERE id = 1
	`, daysStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&workoutv1.UpdateUserPreferencesResponse{
		Preferences: req.Msg.Preferences,
	}), nil
}

// getUserPreferences retrieves user preferences from the database
func (s *WorkoutService) getUserPreferences(database *sql.DB) *workoutv1.UserPreferences {
	var daysStr string
	err := database.QueryRow(`SELECT workout_days FROM user_preferences WHERE id = 1`).Scan(&daysStr)
	if err != nil {
		// Return default Mon/Wed/Fri
		return &workoutv1.UserPreferences{WorkoutDays: []int32{1, 3, 5}}
	}

	// Parse comma-separated days
	dayStrs := strings.Split(daysStr, ",")
	days := make([]int32, 0, len(dayStrs))
	for _, d := range dayStrs {
		d = strings.TrimSpace(d)
		if d == "" {
			continue
		}
		var day int
		if _, err := fmt.Sscanf(d, "%d", &day); err == nil && day >= 1 && day <= 7 {
			days = append(days, int32(day))
		}
	}

	if len(days) == 0 {
		return &workoutv1.UserPreferences{WorkoutDays: []int32{1, 3, 5}}
	}

	return &workoutv1.UserPreferences{WorkoutDays: days}
}

// calculateTargetDates calculates the next N workout dates based on workout days
func (s *WorkoutService) calculateTargetDates(workoutDays []int32, count int) []time.Time {
	dates := make([]time.Time, 0, count)
	today := time.Now()

	// Convert workout days to a set for quick lookup
	daySet := make(map[int]bool)
	for _, d := range workoutDays {
		// time.Weekday: Sunday=0, Monday=1, etc.
		// Our format: Monday=1, Sunday=7
		// Convert: our 1 (Mon) -> Go's 1 (Mon), our 7 (Sun) -> Go's 0 (Sun)
		goDay := int(d) % 7 // 1->1, 2->2, ..., 7->0
		daySet[goDay] = true
	}

	// If no days set, default to every day
	if len(daySet) == 0 {
		for i := 0; i < count; i++ {
			dates = append(dates, today.AddDate(0, 0, i))
		}
		return dates
	}

	// Find next workout days starting from today
	current := today
	for len(dates) < count {
		weekday := int(current.Weekday())
		if daySet[weekday] {
			// Normalize to start of day
			dates = append(dates, time.Date(current.Year(), current.Month(), current.Day(), 0, 0, 0, 0, current.Location()))
		}
		current = current.AddDate(0, 0, 1)

		// Safety: don't loop forever
		if current.Sub(today) > 365*24*time.Hour {
			break
		}
	}

	return dates
}

// getActiveWorkout returns the current in-progress workout, if any
func (s *WorkoutService) getActiveWorkout(ctx context.Context, database *sql.DB) (*workoutv1.WorkoutState, error) {
	// Find a session that has been started (workout_started_at set) but not completed
	var sessionID string
	var sessionStartedAt time.Time
	var workoutStartedAt sql.NullTime

	err := database.QueryRowContext(ctx, `
		SELECT id, started_at, workout_started_at FROM sessions
		WHERE workout_started_at IS NOT NULL
		ORDER BY started_at DESC LIMIT 1
	`).Scan(&sessionID, &sessionStartedAt, &workoutStartedAt)

	if err == sql.ErrNoRows {
		return nil, nil // No active workout
	}
	if err != nil {
		return nil, err
	}

	// Get activities and check if complete
	timeline, err := s.getSessionActivities(ctx, database, sessionID)
	if err != nil {
		return nil, err
	}

	plannedSets, err := s.getPlannedSets(ctx, database, sessionID)
	if err != nil {
		return nil, err
	}

	completedSets := s.countCompletedSets(timeline)
	remainingSets := s.calculateRemainingSets(plannedSets, completedSets)

	// If complete, return nil
	if len(remainingSets) == 0 {
		return nil, nil
	}

	// Find current activity
	var currentActivity *workoutv1.Activity
	for _, a := range timeline {
		if a.EndedAt == nil || a.EndedAt.AsTime().IsZero() {
			currentActivity = a
			break
		}
	}

	var nextSet *workoutv1.PlannedSet
	if len(remainingSets) > 0 {
		nextSet = remainingSets[0]
	}

	state := &workoutv1.WorkoutState{
		SessionId:        sessionID,
		SessionStartedAt: timestamppb.New(sessionStartedAt),
		Timeline:         timeline,
		CurrentActivity:  currentActivity,
		NextSet:          nextSet,
		RemainingSets:    remainingSets,
		IsComplete:       false,
	}
	if workoutStartedAt.Valid {
		state.WorkoutStartedAt = timestamppb.New(workoutStartedAt.Time)
	}

	return state, nil
}

// getLastWorkoutType returns the workout type of the last completed session
func (s *WorkoutService) getLastWorkoutType(database *sql.DB) string {
	var workoutType string
	err := database.QueryRow(`
		SELECT COALESCE(workout_type, 'A') FROM sessions
		ORDER BY started_at DESC LIMIT 1
	`).Scan(&workoutType)
	if err != nil {
		return "B" // Default so next will be A
	}
	return workoutType
}

// generateWorkoutSets creates the planned sets for a workout type
func (s *WorkoutService) generateWorkoutSets(database *sql.DB, workoutType string) []*workoutv1.PlannedSet {
	var exercises []workoutv1.Exercise
	if workoutType == "A" {
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

	var sets []*workoutv1.PlannedSet
	for _, exercise := range exercises {
		weight := s.getTargetWeight(database, exercise)
		reps := int32(5)
		numSets := 5
		if exercise == workoutv1.Exercise_EXERCISE_DEADLIFT {
			numSets = 1
		}

		for setNum := 1; setNum <= numSets; setNum++ {
			sets = append(sets, &workoutv1.PlannedSet{
				Exercise:     exercise,
				SetNumber:    int32(setNum),
				TargetWeight: weight,
				TargetReps:   reps,
			})
		}
	}

	return sets
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
	sessionID, sessionStartedAt, workoutStartedAt, _, err := s.getOrCreateTodaySession(ctx, database, req.Msg.StartNewSession)
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
	if workoutStartedAt.Valid {
		state.WorkoutStartedAt = timestamppb.New(workoutStartedAt.Time)
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

// StartWorkout creates a new session with the provided plan
func (s *WorkoutService) StartWorkout(
	ctx context.Context,
	req *connect.Request[workoutv1.StartWorkoutRequest],
) (*connect.Response[workoutv1.StartWorkoutResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	now := time.Now()
	sessionID := fmt.Sprintf("session-%d", now.UnixNano())

	// Create the session with workout_started_at set immediately
	_, err = database.ExecContext(ctx, `
		INSERT INTO sessions (id, started_at, workout_started_at, workout_type)
		VALUES (?, ?, ?, ?)
	`, sessionID, now, now, req.Msg.WorkoutType)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to create session: %w", err))
	}

	// Insert the planned sets
	for _, set := range req.Msg.Sets {
		setID := uuid.New().String()
		_, err = database.ExecContext(ctx, `
			INSERT INTO planned_sets (id, session_id, exercise, set_number, target_weight, target_reps)
			VALUES (?, ?, ?, ?, ?, ?)
		`, setID, sessionID, set.Exercise.String(), set.SetNumber, set.TargetWeight, set.TargetReps)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to insert planned set: %w", err))
		}
	}

	// Return the new workout state
	state := &workoutv1.WorkoutState{
		SessionId:        sessionID,
		SessionStartedAt: timestamppb.New(now),
		WorkoutStartedAt: timestamppb.New(now),
		Timeline:         []*workoutv1.Activity{},
		RemainingSets:    req.Msg.Sets,
		IsComplete:       false,
	}
	if len(req.Msg.Sets) > 0 {
		state.NextSet = req.Msg.Sets[0]
	}

	return connect.NewResponse(&workoutv1.StartWorkoutResponse{
		State: state,
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

	// Check for group (legacy system - sessions.group_id)
	var groupID sql.NullString
	database.QueryRowContext(ctx, `SELECT group_id FROM sessions WHERE id = ?`, req.Msg.SessionId).Scan(&groupID)
	if groupID.Valid && groupID.String != "" {
		s.hub.BroadcastToAll(hub.GroupChannel(groupID.String), &workoutv1.WorkoutUpdate{
			Type:      workoutv1.UpdateType_UPDATE_TYPE_SET_STARTED,
			UserId:    username,
			Activity:  activity,
			GroupId:   groupID.String,
			Timestamp: timestamppb.New(now),
		})
	}

	// Check for active group session (new system)
	var groupSessionID sql.NullString
	database.QueryRowContext(ctx, `SELECT session_id FROM active_group_session WHERE id = 1`).Scan(&groupSessionID)
	if groupSessionID.Valid && groupSessionID.String != "" {
		// Write to group session activity_log
		groupDB, err := s.groupManager.GetSession(groupSessionID.String)
		if err == nil {
			groupDB.ExecContext(ctx, `
				INSERT INTO activity_log (id, user_id, type, exercise, set_number, weight, target_reps, started_at)
				VALUES (?, ?, 'set', ?, ?, ?, ?, ?)
			`, activityID, username, req.Msg.Exercise.String(), req.Msg.SetNumber, req.Msg.Weight, req.Msg.TargetReps, now)

			// Build updated session (recalculates next_up)
			session := s.buildGroupSession(ctx, groupDB, groupSessionID.String)

			// Broadcast to group session channel with updated session
			s.hub.BroadcastToAll(hub.GroupChannel(groupSessionID.String), &workoutv1.WorkoutUpdate{
				Type:      workoutv1.UpdateType_UPDATE_TYPE_SET_STARTED,
				UserId:    username,
				Activity:  activity,
				Session:   session,
				GroupId:   groupSessionID.String,
				Timestamp: timestamppb.New(now),
			})
		}
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

	// Broadcast update to group if in one
	var updateType workoutv1.UpdateType
	if typeStr == "SET" {
		updateType = workoutv1.UpdateType_UPDATE_TYPE_SET_COMPLETED
	} else {
		updateType = workoutv1.UpdateType_UPDATE_TYPE_REST_SKIPPED
	}

	// Check if session has a group (legacy) - broadcast to group channel if so
	var groupID sql.NullString
	database.QueryRowContext(ctx, `SELECT group_id FROM sessions WHERE id = ?`, req.Msg.SessionId).Scan(&groupID)
	if groupID.Valid && groupID.String != "" {
		s.hub.BroadcastToAll(hub.GroupChannel(groupID.String), &workoutv1.WorkoutUpdate{
			Type:      updateType,
			UserId:    username,
			Activity:  finishedActivity,
			State:     stateResp.Msg.State,
			GroupId:   groupID.String,
			Timestamp: timestamppb.Now(),
		})
	}

	// Check for active group session (new system)
	var groupSessionID sql.NullString
	database.QueryRowContext(ctx, `SELECT session_id FROM active_group_session WHERE id = 1`).Scan(&groupSessionID)
	if groupSessionID.Valid && groupSessionID.String != "" {
		// Update activity_log in group session DB
		groupDB, err := s.groupManager.GetSession(groupSessionID.String)
		if err == nil {
			if typeStr == "SET" {
				// Update the set activity with completion info
				groupDB.ExecContext(ctx, `
					UPDATE activity_log SET ended_at = ?, actual_reps = ? WHERE id = ?
				`, now, req.Msg.ActualReps, req.Msg.ActivityId)

				// Create rest activity
				if nextActivity != nil {
					groupDB.ExecContext(ctx, `
						INSERT INTO activity_log (id, user_id, type, planned_rest_seconds, started_at)
						VALUES (?, ?, 'rest', ?, ?)
					`, nextActivity.Id, username, nextActivity.PlannedDurationSeconds, now)
				}
			} else {
				// Finishing REST - just update ended_at
				groupDB.ExecContext(ctx, `UPDATE activity_log SET ended_at = ? WHERE id = ?`, now, req.Msg.ActivityId)
			}

			// Build updated session (recalculates next_up)
			session := s.buildGroupSession(ctx, groupDB, groupSessionID.String)

			// Broadcast to group session channel with updated session
			s.hub.BroadcastToAll(hub.GroupChannel(groupSessionID.String), &workoutv1.WorkoutUpdate{
				Type:      updateType,
				UserId:    username,
				Activity:  finishedActivity,
				State:     stateResp.Msg.State,
				Session:   session,
				GroupId:   groupSessionID.String,
				Timestamp: timestamppb.Now(),
			})
		}
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

	sessionID, _, _, _, err := s.getOrCreateTodaySession(ctx, database, false)
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

func (s *WorkoutService) getOrCreateTodaySession(ctx context.Context, database *sql.DB, startNewSession bool) (string, time.Time, sql.NullTime, string, error) {
	today := time.Now().Truncate(24 * time.Hour)

	var sessionID string
	var startedAt time.Time
	var workoutStartedAt sql.NullTime
	var workoutType string
	err := database.QueryRowContext(ctx, `
		SELECT id, started_at, workout_started_at, COALESCE(workout_type, 'A') FROM sessions
		WHERE started_at >= ?
		ORDER BY started_at DESC LIMIT 1
	`, today).Scan(&sessionID, &startedAt, &workoutStartedAt, &workoutType)

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
			return "", time.Time{}, sql.NullTime{}, "", err
		}

		// Populate planned_sets for this new session
		if err := s.populatePlannedSets(ctx, database, sessionID, workoutType); err != nil {
			return "", time.Time{}, sql.NullTime{}, "", err
		}
		// New session - workoutStartedAt is not set yet
		workoutStartedAt = sql.NullTime{}
	} else if err != nil {
		return "", time.Time{}, sql.NullTime{}, "", err
	}

	return sessionID, startedAt, workoutStartedAt, workoutType, nil
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

	// If user is in a group session, broadcast the update so next_up gets recalculated for everyone
	var groupSessionID sql.NullString
	database.QueryRowContext(ctx, `SELECT session_id FROM active_group_session WHERE id = 1`).Scan(&groupSessionID)
	if groupSessionID.Valid && groupSessionID.String != "" {
		if groupDB, err := s.groupManager.GetSession(groupSessionID.String); err == nil {
			// Build updated session (this recalculates next_up)
			session := s.buildGroupSession(ctx, groupDB, groupSessionID.String)
			// Broadcast to all group members
			s.hub.BroadcastToAll(hub.GroupChannel(groupSessionID.String), &workoutv1.WorkoutUpdate{
				Type:      workoutv1.UpdateType_UPDATE_TYPE_SESSION_UPDATED,
				UserId:    username,
				Session:   session,
				GroupId:   groupSessionID.String,
				Timestamp: timestamppb.Now(),
			})
		}
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

// FinishWorkoutEarly ends the current workout before all sets are completed
func (s *WorkoutService) FinishWorkoutEarly(
	ctx context.Context,
	req *connect.Request[workoutv1.FinishWorkoutEarlyRequest],
) (*connect.Response[workoutv1.FinishWorkoutEarlyResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	now := time.Now()

	// End any current activity (like a REST that's still open)
	_, err = database.ExecContext(ctx, `
		UPDATE activities SET ended_at = ?
		WHERE session_id = ? AND ended_at IS NULL
	`, now, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Delete all remaining planned sets for this session
	_, err = database.ExecContext(ctx, `
		DELETE FROM planned_sets WHERE session_id = ? AND NOT EXISTS (
			SELECT 1 FROM activities
			WHERE activities.session_id = planned_sets.session_id
			AND activities.exercise = planned_sets.exercise
			AND activities.set_number = planned_sets.set_number
			AND activities.type = 'SET'
			AND activities.ended_at IS NOT NULL
		)
	`, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get the final workout state
	timeline, err := s.getSessionActivities(ctx, database, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	var sessionStartedAt time.Time
	var workoutStartedAt sql.NullTime
	database.QueryRowContext(ctx, `
		SELECT started_at, workout_started_at FROM sessions WHERE id = ?
	`, req.Msg.SessionId).Scan(&sessionStartedAt, &workoutStartedAt)

	state := &workoutv1.WorkoutState{
		SessionId:        req.Msg.SessionId,
		SessionStartedAt: timestamppb.New(sessionStartedAt),
		Timeline:         timeline,
		CurrentActivity:  nil,
		NextSet:          nil,
		RemainingSets:    []*workoutv1.PlannedSet{},
		IsComplete:       true,
	}
	if workoutStartedAt.Valid {
		state.WorkoutStartedAt = timestamppb.New(workoutStartedAt.Time)
	}

	// If user is in a group session, leave it
	var groupSessionID sql.NullString
	database.QueryRowContext(ctx, `SELECT session_id FROM active_group_session WHERE id = 1`).Scan(&groupSessionID)
	if groupSessionID.Valid && groupSessionID.String != "" {
		// Clear the active group session reference
		database.ExecContext(ctx, `UPDATE active_group_session SET session_id = NULL WHERE id = 1`)

		// Notify group that user left
		if groupDB, err := s.groupManager.GetSession(groupSessionID.String); err == nil {
			session := s.buildGroupSession(ctx, groupDB, groupSessionID.String)
			s.hub.BroadcastToAll(hub.GroupChannel(groupSessionID.String), &workoutv1.WorkoutUpdate{
				Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_LEFT,
				UserId:    username,
				Session:   session,
				GroupId:   groupSessionID.String,
				Timestamp: timestamppb.Now(),
			})
		}
	}

	return connect.NewResponse(&workoutv1.FinishWorkoutEarlyResponse{
		State: state,
	}), nil
}

// WatchNotifications streams real-time notifications for a user
// This is the main streaming endpoint - connect on login to receive all updates
func (s *WorkoutService) WatchNotifications(
	ctx context.Context,
	req *connect.Request[workoutv1.WatchNotificationsRequest],
	stream *connect.ServerStream[workoutv1.WorkoutUpdate],
) error {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	// Create a merged channel for all updates
	updates := make(chan *workoutv1.WorkoutUpdate, 20)
	done := make(chan struct{})
	defer close(done)

	// Subscribe to the user's personal notification channel
	userChannel := hub.UserChannel(username)
	userClient := s.hub.Subscribe(userChannel, username)
	defer s.hub.Unsubscribe(userChannel, username)

	// Forward user channel updates to merged channel
	go func() {
		for {
			select {
			case <-done:
				return
			case update, ok := <-userClient.Send:
				if !ok {
					return
				}
				select {
				case updates <- update:
				case <-done:
					return
				}
			}
		}
	}()

	// Check if user has an active workout with a group
	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return connect.NewError(connect.CodeInternal, err)
	}

	// Track current group subscription
	var currentGroupID string
	var groupDone chan struct{}

	// Helper to subscribe to group channel
	subscribeToGroup := func(groupID string) {
		if groupID == currentGroupID {
			return
		}
		// Stop forwarding from old group
		if groupDone != nil {
			close(groupDone)
			groupDone = nil
		}
		// Unsubscribe from old group
		if currentGroupID != "" {
			s.hub.Unsubscribe(hub.GroupChannel(currentGroupID), username)
		}
		currentGroupID = groupID
		// Subscribe to new group and forward updates
		if groupID != "" {
			groupClient := s.hub.Subscribe(hub.GroupChannel(groupID), username)
			groupDone = make(chan struct{})
			go func(gd chan struct{}) {
				for {
					select {
					case <-done:
						return
					case <-gd:
						return
					case update, ok := <-groupClient.Send:
						if !ok {
							return
						}
						select {
						case updates <- update:
						case <-done:
							return
						case <-gd:
							return
						}
					}
				}
			}(groupDone)
		}
	}

	// Check for active group session (new system) or active workout group (legacy)
	// First check new system - active_group_session table
	var sessionID sql.NullString
	database.QueryRowContext(ctx, `SELECT session_id FROM active_group_session WHERE id = 1`).Scan(&sessionID)
	if sessionID.Valid && sessionID.String != "" {
		// Check if this session exists in group manager
		if s.groupManager.SessionExists(sessionID.String) {
			subscribeToGroup(sessionID.String)
		}
	}
	// Also check legacy system - group_id in sessions
	activeState, _ := s.getActiveWorkout(ctx, database)
	if activeState != nil && currentGroupID == "" {
		var gid sql.NullString
		database.QueryRowContext(ctx, `SELECT group_id FROM sessions WHERE id = ?`, activeState.SessionId).Scan(&gid)
		if gid.Valid && gid.String != "" {
			subscribeToGroup(gid.String)
		}
	}

	// Cleanup on exit
	defer func() {
		if groupDone != nil {
			close(groupDone)
		}
		if currentGroupID != "" {
			s.hub.Unsubscribe(hub.GroupChannel(currentGroupID), username)
		}
	}()

	// Send heartbeat every 30 seconds to keep connection alive
	heartbeat := time.NewTicker(30 * time.Second)
	defer heartbeat.Stop()

	// Stream updates to the client
	for {
		select {
		case <-ctx.Done():
			return nil

		case <-heartbeat.C:
			// Send a heartbeat to keep the connection alive
			if err := stream.Send(&workoutv1.WorkoutUpdate{
				Type:      workoutv1.UpdateType_UPDATE_TYPE_HEARTBEAT,
				Timestamp: timestamppb.Now(),
			}); err != nil {
				return err
			}

		case update, ok := <-updates:
			if !ok {
				return nil
			}
			if err := stream.Send(update); err != nil {
				return err
			}
			// If this update indicates joining a group, subscribe to that group
			if update.GroupId != "" && (update.Type == workoutv1.UpdateType_UPDATE_TYPE_INVITE_ACCEPTED ||
				update.Type == workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED) {
				subscribeToGroup(update.GroupId)
			}
		}
	}
}

// WatchWorkout streams real-time updates for a workout session (deprecated - use WatchNotifications)
func (s *WorkoutService) WatchWorkout(
	ctx context.Context,
	req *connect.Request[workoutv1.WatchWorkoutRequest],
	stream *connect.ServerStream[workoutv1.WorkoutUpdate],
) error {
	userID := req.Msg.UserId
	sessionID := req.Msg.SessionId

	if userID == "" || sessionID == "" {
		return connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("user_id and session_id are required"))
	}

	// Subscribe to updates for this session
	client := s.hub.Subscribe(sessionID, userID)
	defer s.hub.Unsubscribe(sessionID, userID)

	// Check if this session belongs to a group - if so, also subscribe to group updates
	var groupID string
	if db, err := s.dbManager.GetDB(userID); err == nil {
		var gid sql.NullString
		db.QueryRowContext(ctx, `SELECT group_id FROM sessions WHERE id = ?`, sessionID).Scan(&gid)
		if gid.Valid && gid.String != "" {
			groupID = gid.String
			// Subscribe to group channel for group-wide notifications
			groupClient := s.hub.Subscribe(groupID, userID)
			defer s.hub.Unsubscribe(groupID, userID)
			// Forward group updates to the main client channel
			go func() {
				for update := range groupClient.Send {
					select {
					case client.Send <- update:
					default:
						// Buffer full, skip
					}
				}
			}()
		}
	}

	// Notify others that this user joined
	s.hub.Broadcast(sessionID, &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED,
		UserId:    userID,
		Timestamp: timestamppb.Now(),
	}, userID)

	// Send updates to the client until they disconnect
	for {
		select {
		case <-ctx.Done():
			// Client disconnected - notify others
			s.hub.Broadcast(sessionID, &workoutv1.WorkoutUpdate{
				Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_LEFT,
				UserId:    userID,
				Timestamp: timestamppb.Now(),
			}, userID)
			return nil

		case update, ok := <-client.Send:
			if !ok {
				// Channel closed (user reconnected elsewhere)
				return nil
			}
			if err := stream.Send(update); err != nil {
				return err
			}
		}
	}
}
