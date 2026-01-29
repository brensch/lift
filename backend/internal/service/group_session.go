package service

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"time"

	"connectrpc.com/connect"
	"github.com/google/uuid"

	workoutv1 "github.com/brensch/lift/backend/gen/workout/v1"
	"github.com/brensch/lift/backend/internal/hub"
	"github.com/brensch/lift/backend/internal/interceptor"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// CreateGroupSession creates a new group workout session and invites someone
func (s *WorkoutService) CreateGroupSession(
	ctx context.Context,
	req *connect.Request[workoutv1.CreateGroupSessionRequest],
) (*connect.Response[workoutv1.CreateGroupSessionResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	// Validate invited user exists
	if !s.dbManager.UserExists(req.Msg.InviteUsername) {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("user '%s' does not exist", req.Msg.InviteUsername))
	}

	// Create a new group session
	sessionID := uuid.New().String()
	groupDB, err := s.groupManager.CreateSession(sessionID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to create group session: %w", err))
	}

	now := time.Now()

	// Insert session info
	_, err = groupDB.ExecContext(ctx, `
		INSERT INTO session_info (id, created_by, created_at, status)
		VALUES (?, ?, ?, 'planning')
	`, sessionID, username, now)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Add creator as first member
	_, err = groupDB.ExecContext(ctx, `
		INSERT INTO members (user_id, joined_at, status, is_connected)
		VALUES (?, ?, 'planning', 0)
	`, username, now)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Load creator's proposed workout and add to user_plans
	userDB, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	creatorPlan := s.loadUserProposedPlan(ctx, userDB, username)
	for _, ex := range creatorPlan.Exercises {
		groupDB.ExecContext(ctx, `
			INSERT INTO user_plans (user_id, exercise, target_weight, target_sets, target_reps)
			VALUES (?, ?, ?, ?, ?)
		`, username, ex.Exercise.String(), ex.TargetWeight, ex.TargetSets, ex.TargetReps)
	}

	// Create invite for the other user
	inviteID := uuid.New().String()
	invitedUserDB, err := s.dbManager.GetDB(req.Msg.InviteUsername)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Store invite in invited user's database
	_, err = invitedUserDB.ExecContext(ctx, `
		INSERT INTO group_invites (id, group_id, from_user, to_user, status, created_at)
		VALUES (?, ?, ?, ?, 'pending', ?)
	`, inviteID, sessionID, username, req.Msg.InviteUsername, now)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Store reference in creator's database
	userDB.ExecContext(ctx, `
		INSERT INTO group_invites (id, group_id, from_user, to_user, status, created_at)
		VALUES (?, ?, ?, ?, 'pending', ?)
	`, inviteID, sessionID, username, req.Msg.InviteUsername, now)

	// Update creator's session reference
	userDB.ExecContext(ctx, `
		INSERT OR REPLACE INTO active_group_session (id, session_id, updated_at)
		VALUES (1, ?, ?)
	`, sessionID, now)

	// Build session response
	session := s.buildGroupSession(ctx, groupDB, sessionID)

	invite := &workoutv1.GroupInvite{
		Id:        inviteID,
		SessionId: sessionID,
		FromUser:  username,
		ToUser:    req.Msg.InviteUsername,
		Status:    "pending",
		CreatedAt: timestamppb.New(now),
		Session:   session,
	}

	// Notify invited user
	s.hub.BroadcastToAll(hub.UserChannel(req.Msg.InviteUsername), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_INVITE_RECEIVED,
		UserId:    username,
		Invite:    invite,
		Session:   session,
		Timestamp: timestamppb.Now(),
	})

	// Subscribe creator to session channel
	s.hub.BroadcastToAll(hub.UserChannel(username), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED,
		UserId:    username,
		Session:   session,
		GroupId:   sessionID,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.CreateGroupSessionResponse{
		Session: session,
		Invite:  invite,
	}), nil
}

// JoinGroupSession accepts an invite and joins a group session
func (s *WorkoutService) JoinGroupSession(
	ctx context.Context,
	req *connect.Request[workoutv1.JoinGroupSessionRequest],
) (*connect.Response[workoutv1.JoinGroupSessionResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	userDB, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get the invite
	var sessionID, fromUser string
	err = userDB.QueryRowContext(ctx, `
		SELECT group_id, from_user FROM group_invites
		WHERE id = ? AND to_user = ? AND status = 'pending'
	`, req.Msg.InviteId, username).Scan(&sessionID, &fromUser)
	if err == sql.ErrNoRows {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("invite not found"))
	}
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Update invite status
	userDB.ExecContext(ctx, `UPDATE group_invites SET status = 'accepted' WHERE id = ?`, req.Msg.InviteId)

	// Also update in inviter's DB
	inviterDB, _ := s.dbManager.GetDB(fromUser)
	if inviterDB != nil {
		inviterDB.ExecContext(ctx, `UPDATE group_invites SET status = 'accepted' WHERE id = ?`, req.Msg.InviteId)
	}

	// Get group session DB
	groupDB, err := s.groupManager.GetSession(sessionID)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group session not found"))
	}

	now := time.Now()

	// Add user as member
	_, err = groupDB.ExecContext(ctx, `
		INSERT OR REPLACE INTO members (user_id, joined_at, status, is_connected)
		VALUES (?, ?, 'planning', 0)
	`, username, now)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Load user's proposed workout and add to user_plans
	// First, clear any old entries for this user (in case of re-join or stale data)
	groupDB.ExecContext(ctx, `DELETE FROM user_plans WHERE user_id = ?`, username)

	userPlan := s.loadUserProposedPlan(ctx, userDB, username)
	for _, ex := range userPlan.Exercises {
		groupDB.ExecContext(ctx, `
			INSERT INTO user_plans (user_id, exercise, target_weight, target_sets, target_reps)
			VALUES (?, ?, ?, ?, ?)
		`, username, ex.Exercise.String(), ex.TargetWeight, ex.TargetSets, ex.TargetReps)
	}

	// Store session reference in user's DB
	userDB.ExecContext(ctx, `
		INSERT OR REPLACE INTO active_group_session (id, session_id, updated_at)
		VALUES (1, ?, ?)
	`, sessionID, now)

	// Build session response
	session := s.buildGroupSession(ctx, groupDB, sessionID)

	// Notify everyone in the session
	s.hub.BroadcastToAll(hub.GroupChannel(sessionID), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED,
		UserId:    username,
		Session:   session,
		GroupId:   sessionID,
		Timestamp: timestamppb.Now(),
	})

	// Notify the joining user to subscribe to session channel
	s.hub.BroadcastToAll(hub.UserChannel(username), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED,
		UserId:    username,
		Session:   session,
		GroupId:   sessionID,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.JoinGroupSessionResponse{
		Session: session,
	}), nil
}

// GetGroupSession returns the current state of a group session
func (s *WorkoutService) GetGroupSession(
	ctx context.Context,
	req *connect.Request[workoutv1.GetGroupSessionRequest],
) (*connect.Response[workoutv1.GetGroupSessionResponse], error) {
	groupDB, err := s.groupManager.GetSession(req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group session not found"))
	}

	session := s.buildGroupSession(ctx, groupDB, req.Msg.SessionId)

	return connect.NewResponse(&workoutv1.GetGroupSessionResponse{
		Session: session,
	}), nil
}

// UpdateMyPlan updates the user's plan for the session
func (s *WorkoutService) UpdateMyPlan(
	ctx context.Context,
	req *connect.Request[workoutv1.UpdateMyPlanRequest],
) (*connect.Response[workoutv1.UpdateMyPlanResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	groupDB, err := s.groupManager.GetSession(req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group session not found"))
	}

	// Check session is still in planning
	var status string
	groupDB.QueryRowContext(ctx, `SELECT status FROM session_info WHERE id = ?`, req.Msg.SessionId).Scan(&status)
	if status != "planning" {
		return nil, connect.NewError(connect.CodeFailedPrecondition, fmt.Errorf("session is no longer in planning phase"))
	}

	// Clear existing plan entries for this user, then insert fresh
	_, err = groupDB.ExecContext(ctx, `DELETE FROM user_plans WHERE user_id = ?`, username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Insert new plan
	for _, ex := range req.Msg.Exercises {
		_, err = groupDB.ExecContext(ctx, `
			INSERT INTO user_plans (user_id, exercise, target_weight, target_sets, target_reps)
			VALUES (?, ?, ?, ?, ?)
		`, username, ex.Exercise.String(), ex.TargetWeight, ex.TargetSets, ex.TargetReps)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
	}

	// User modified their plan, so mark them as not ready
	groupDB.ExecContext(ctx, `UPDATE members SET status = 'planning' WHERE user_id = ?`, username)

	// Build updated session
	session := s.buildGroupSession(ctx, groupDB, req.Msg.SessionId)

	// Broadcast update to all
	s.hub.BroadcastToAll(hub.GroupChannel(req.Msg.SessionId), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_PLAN_UPDATED,
		UserId:    username,
		Session:   session,
		GroupId:   req.Msg.SessionId,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.UpdateMyPlanResponse{
		Session: session,
	}), nil
}

// SetReady marks a user as ready to start the workout
func (s *WorkoutService) SetReady(
	ctx context.Context,
	req *connect.Request[workoutv1.SetReadyRequest],
) (*connect.Response[workoutv1.SetReadyResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	groupDB, err := s.groupManager.GetSession(req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group session not found"))
	}

	status := "planning"
	if req.Msg.Ready {
		status = "ready"
	}

	_, err = groupDB.ExecContext(ctx, `UPDATE members SET status = ? WHERE user_id = ?`, status, username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Build updated session
	session := s.buildGroupSession(ctx, groupDB, req.Msg.SessionId)

	// Broadcast update
	updateType := workoutv1.UpdateType_UPDATE_TYPE_USER_READY
	if !req.Msg.Ready {
		updateType = workoutv1.UpdateType_UPDATE_TYPE_USER_NOT_READY
	}

	s.hub.BroadcastToAll(hub.GroupChannel(req.Msg.SessionId), &workoutv1.WorkoutUpdate{
		Type:      updateType,
		UserId:    username,
		Session:   session,
		GroupId:   req.Msg.SessionId,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.SetReadyResponse{
		Session: session,
	}), nil
}

// StartGroupWorkout starts the group workout once all are ready
func (s *WorkoutService) StartGroupWorkout(
	ctx context.Context,
	req *connect.Request[workoutv1.StartGroupWorkoutRequest],
) (*connect.Response[workoutv1.StartGroupWorkoutResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	groupDB, err := s.groupManager.GetSession(req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group session not found"))
	}

	// Check all members are ready
	var notReadyCount int
	groupDB.QueryRowContext(ctx, `SELECT COUNT(*) FROM members WHERE status != 'ready'`).Scan(&notReadyCount)
	if notReadyCount > 0 {
		return nil, connect.NewError(connect.CodeFailedPrecondition, fmt.Errorf("not all members are ready"))
	}

	// Update session status to active
	_, err = groupDB.ExecContext(ctx, `UPDATE session_info SET status = 'active' WHERE id = ?`, req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Update each user's personal database with their agreed plan
	rows, _ := groupDB.QueryContext(ctx, `SELECT DISTINCT user_id FROM members`)
	defer rows.Close()
	for rows.Next() {
		var memberUsername string
		rows.Scan(&memberUsername)
		s.applyGroupPlanToUser(ctx, groupDB, memberUsername, req.Msg.SessionId)
	}

	// Build updated session
	session := s.buildGroupSession(ctx, groupDB, req.Msg.SessionId)

	// Broadcast workout started
	s.hub.BroadcastToAll(hub.GroupChannel(req.Msg.SessionId), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_WORKOUT_STARTED,
		UserId:    username,
		Session:   session,
		GroupId:   req.Msg.SessionId,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.StartGroupWorkoutResponse{
		Session: session,
	}), nil
}

// LeaveGroupSession removes a user from a group session
func (s *WorkoutService) LeaveGroupSession(
	ctx context.Context,
	req *connect.Request[workoutv1.LeaveGroupSessionRequest],
) (*connect.Response[workoutv1.LeaveGroupSessionResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	groupDB, err := s.groupManager.GetSession(req.Msg.SessionId)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group session not found"))
	}

	// Remove member
	groupDB.ExecContext(ctx, `DELETE FROM members WHERE user_id = ?`, username)
	groupDB.ExecContext(ctx, `DELETE FROM user_plans WHERE user_id = ?`, username)

	// Clear session reference from user's DB
	userDB, _ := s.dbManager.GetDB(username)
	if userDB != nil {
		userDB.ExecContext(ctx, `DELETE FROM active_group_session WHERE id = 1`)
	}

	// Build updated session
	session := s.buildGroupSession(ctx, groupDB, req.Msg.SessionId)

	// Broadcast user left
	s.hub.BroadcastToAll(hub.GroupChannel(req.Msg.SessionId), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_LEFT,
		UserId:    username,
		Session:   session,
		GroupId:   req.Msg.SessionId,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.LeaveGroupSessionResponse{
		Success: true,
	}), nil
}

// Helper: Build full GroupSession from database
func (s *WorkoutService) buildGroupSession(ctx context.Context, groupDB *sql.DB, sessionID string) *workoutv1.GroupSession {
	session := &workoutv1.GroupSession{
		Id:       sessionID,
		Members:  []*workoutv1.GroupSessionMember{},
		Timeline: []*workoutv1.GroupActivity{},
	}

	// Get session info
	var createdBy, status string
	var createdAt time.Time
	err := groupDB.QueryRowContext(ctx, `
		SELECT created_by, created_at, status FROM session_info WHERE id = ?
	`, sessionID).Scan(&createdBy, &createdAt, &status)
	if err != nil {
		return session
	}
	session.CreatedBy = createdBy
	session.CreatedAt = timestamppb.New(createdAt)
	session.Status = status

	// Get members
	memberRows, err := groupDB.QueryContext(ctx, `
		SELECT user_id, joined_at, status, is_connected FROM members
	`)
	if err != nil {
		return session
	}
	defer memberRows.Close()

	allReady := true
	for memberRows.Next() {
		var userID, memberStatus string
		var joinedAt time.Time
		var isConnected bool
		memberRows.Scan(&userID, &joinedAt, &memberStatus, &isConnected)

		member := &workoutv1.GroupSessionMember{
			UserId:      userID,
			Status:      memberStatus,
			IsConnected: isConnected,
		}

		if memberStatus != "ready" {
			allReady = false
		}

		// Load user's plan
		member.ProposedPlan = s.loadUserPlanFromGroup(ctx, groupDB, userID)

		// Load current activity if workout is active
		if status == "active" {
			member.CurrentActivity = s.loadUserCurrentActivity(ctx, groupDB, userID)
			// Load remaining and completed sets from user's personal DB
			member.RemainingSets, member.CompletedSets = s.loadUserSetsFromPersonalDB(ctx, userID)
		}

		session.Members = append(session.Members, member)
	}

	// Build group plan
	session.Plan = s.buildGroupPlan(ctx, groupDB, session.Members)
	if session.Plan != nil {
		session.Plan.AllReady = allReady && len(session.Members) > 0
	}

	// Load timeline (all activities from all users) if workout is active
	if status == "active" {
		session.Timeline = s.loadGroupTimeline(ctx, groupDB)
		session.NextUp = s.calculateNextUp(ctx, session)
	}

	return session
}

// Helper: Load remaining and completed sets from user's personal database
func (s *WorkoutService) loadUserSetsFromPersonalDB(ctx context.Context, username string) ([]*workoutv1.PlannedSet, []*workoutv1.PlannedSet) {
	userDB, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, nil
	}

	activeState, err := s.getActiveWorkout(ctx, userDB)
	if err != nil || activeState == nil {
		return nil, nil
	}

	// Get completed sets from timeline
	var completedSets []*workoutv1.PlannedSet
	for _, activity := range activeState.Timeline {
		if activity.Type == workoutv1.ActivityType_ACTIVITY_TYPE_SET {
			completedSets = append(completedSets, &workoutv1.PlannedSet{
				Exercise:     activity.Exercise,
				TargetWeight: activity.Weight,
				TargetReps:   activity.ActualReps, // Use actual reps for completed
				SetNumber:    activity.SetNumber,
			})
		}
	}

	return activeState.RemainingSets, completedSets
}

// Helper: Load all activities from group timeline
func (s *WorkoutService) loadGroupTimeline(ctx context.Context, groupDB *sql.DB) []*workoutv1.GroupActivity {
	timeline := []*workoutv1.GroupActivity{}

	rows, err := groupDB.QueryContext(ctx, `
		SELECT id, user_id, type, exercise, set_number, weight, target_reps, actual_reps, planned_rest_seconds, started_at, ended_at
		FROM activity_log
		ORDER BY started_at ASC
	`)
	if err != nil {
		return timeline
	}
	defer rows.Close()

	for rows.Next() {
		var id, userID, actType string
		var exerciseStr sql.NullString
		var setNumber sql.NullInt64
		var weight sql.NullFloat64
		var targetReps, actualReps, plannedRest sql.NullInt64
		var startedAt time.Time
		var endedAt sql.NullTime

		rows.Scan(&id, &userID, &actType, &exerciseStr, &setNumber, &weight, &targetReps, &actualReps, &plannedRest, &startedAt, &endedAt)

		activity := &workoutv1.GroupActivity{
			Id:        id,
			UserId:    userID,
			Type:      actType,
			StartedAt: timestamppb.New(startedAt),
		}

		if exerciseStr.Valid {
			activity.Exercise = parseExercise(exerciseStr.String)
		}
		if setNumber.Valid {
			activity.SetNumber = int32(setNumber.Int64)
		}
		if weight.Valid {
			activity.Weight = float32(weight.Float64)
		}
		if targetReps.Valid {
			activity.TargetReps = int32(targetReps.Int64)
		}
		if actualReps.Valid {
			activity.ActualReps = int32(actualReps.Int64)
		}
		if plannedRest.Valid {
			activity.PlannedRestSeconds = int32(plannedRest.Int64)
		}
		if endedAt.Valid {
			activity.EndedAt = timestamppb.New(endedAt.Time)
		}

		timeline = append(timeline, activity)
	}

	return timeline
}

// Helper: Calculate who should go next in the group
func (s *WorkoutService) calculateNextUp(ctx context.Context, session *workoutv1.GroupSession) *workoutv1.NextUp {
	now := time.Now()
	var bestCandidate *workoutv1.NextUp
	var bestReadyTime time.Time

	// For each member, check what their ACTUAL next set is (respects their personal exercise order)
	for _, member := range session.Members {
		if len(member.RemainingSets) == 0 {
			continue // User has no sets remaining
		}

		// Their next set is the first in their remaining sets (already ordered by their exercise_order)
		nextSet := member.RemainingSets[0]

		// Calculate when this user will be ready
		var readyTime time.Time
		var secondsUntilReady int32 = 0
		var restStartedAt *timestamppb.Timestamp
		var plannedRestSeconds int32 = 0

		if member.CurrentActivity == nil {
			// User is idle/ready now
			readyTime = now
		} else if member.CurrentActivity.Type == "set" {
			// User is in a set - they won't be ready for a while
			// Skip them as "next up" candidate since they're actively lifting
			readyTime = now.Add(300 * time.Second)
			secondsUntilReady = 300
		} else if member.CurrentActivity.Type == "rest" {
			// User is resting - calculate from their rest start time
			restStartedAt = member.CurrentActivity.StartedAt
			// Get planned rest from the activity or default to 180
			plannedRestSeconds = 180 // Default 3 minutes
			if member.CurrentActivity.RestSecondsRemaining > 0 {
				// RestSecondsRemaining was calculated at query time, work backwards
				if restStartedAt != nil {
					elapsed := now.Sub(restStartedAt.AsTime()).Seconds()
					plannedRestSeconds = member.CurrentActivity.RestSecondsRemaining + int32(elapsed)
				}
			}

			if restStartedAt != nil {
				elapsed := now.Sub(restStartedAt.AsTime()).Seconds()
				remaining := float64(plannedRestSeconds) - elapsed
				if remaining > 0 {
					secondsUntilReady = int32(remaining)
					readyTime = now.Add(time.Duration(secondsUntilReady) * time.Second)
				} else {
					// Rest is complete
					readyTime = now
					secondsUntilReady = 0
				}
			} else {
				readyTime = now
			}
		}

		// Track best candidate (earliest ready time)
		if bestCandidate == nil || readyTime.Before(bestReadyTime) {
			bestReadyTime = readyTime
			bestCandidate = &workoutv1.NextUp{
				UserId:             member.UserId,
				Exercise:           nextSet.Exercise,
				Weight:             nextSet.TargetWeight,
				SetNumber:          nextSet.SetNumber,
				SecondsUntilReady:  secondsUntilReady,
				RestStartedAt:      restStartedAt,
				PlannedRestSeconds: plannedRestSeconds,
			}
		}
	}

	return bestCandidate
}

// Helper: Load a user's plan from the group session database
func (s *WorkoutService) loadUserPlanFromGroup(ctx context.Context, groupDB *sql.DB, userID string) *workoutv1.UserPlan {
	plan := &workoutv1.UserPlan{
		UserId:    userID,
		Exercises: []*workoutv1.UserExercisePlan{},
	}

	rows, err := groupDB.QueryContext(ctx, `
		SELECT exercise, target_weight, target_sets, target_reps
		FROM user_plans WHERE user_id = ?
	`, userID)
	if err != nil {
		return plan
	}
	defer rows.Close()

	for rows.Next() {
		var exerciseStr string
		var weight float32
		var sets, reps int32
		rows.Scan(&exerciseStr, &weight, &sets, &reps)

		plan.Exercises = append(plan.Exercises, &workoutv1.UserExercisePlan{
			Exercise:     parseExercise(exerciseStr),
			TargetWeight: weight,
			TargetSets:   sets,
			TargetReps:   reps,
		})
	}

	return plan
}

// Helper: Load a user's current or proposed plan from their personal database
// If they have an active workout, use that (remaining sets). Otherwise, use their next proposed workout.
func (s *WorkoutService) loadUserProposedPlan(ctx context.Context, userDB *sql.DB, username string) *workoutv1.UserPlan {
	plan := &workoutv1.UserPlan{
		UserId:    username,
		Exercises: []*workoutv1.UserExercisePlan{},
	}

	// First, check if user has an active workout - use that instead of proposed
	activeState, err := s.getActiveWorkout(ctx, userDB)
	if err == nil && activeState != nil && len(activeState.RemainingSets) > 0 {
		// User has an active workout - use their remaining sets
		exerciseMap := make(map[workoutv1.Exercise]*workoutv1.UserExercisePlan)
		for _, set := range activeState.RemainingSets {
			if _, ok := exerciseMap[set.Exercise]; !ok {
				exerciseMap[set.Exercise] = &workoutv1.UserExercisePlan{
					Exercise:     set.Exercise,
					TargetWeight: set.TargetWeight,
					TargetSets:   0,
					TargetReps:   set.TargetReps,
				}
			}
			exerciseMap[set.Exercise].TargetSets++
		}

		for _, ep := range exerciseMap {
			plan.Exercises = append(plan.Exercises, ep)
		}
		return plan
	}

	// No active workout - get their CURRENT proposed workout (not next)
	// Use the same logic as GetUpcomingWorkouts to get the first upcoming workout
	lastType := s.getLastWorkoutType(userDB)
	// The first upcoming workout alternates from lastType
	nextType := "A"
	if lastType == "A" {
		nextType = "B"
	}

	// Generate their proposed sets
	sets := s.generateWorkoutSets(userDB, nextType)

	// Group by exercise
	exerciseMap := make(map[workoutv1.Exercise]*workoutv1.UserExercisePlan)
	for _, set := range sets {
		if _, ok := exerciseMap[set.Exercise]; !ok {
			exerciseMap[set.Exercise] = &workoutv1.UserExercisePlan{
				Exercise:     set.Exercise,
				TargetWeight: set.TargetWeight,
				TargetSets:   0,
				TargetReps:   set.TargetReps,
			}
		}
		exerciseMap[set.Exercise].TargetSets++
	}

	for _, ep := range exerciseMap {
		plan.Exercises = append(plan.Exercises, ep)
	}

	return plan
}

// Helper: Load user's current activity from activity log
func (s *WorkoutService) loadUserCurrentActivity(ctx context.Context, groupDB *sql.DB, userID string) *workoutv1.UserActivity {
	var activityID, actType string
	var exerciseStr sql.NullString
	var setNumber sql.NullInt64
	var weight sql.NullFloat64
	var targetReps, actualReps, plannedRest sql.NullInt64
	var startedAt time.Time
	var endedAt sql.NullTime

	err := groupDB.QueryRowContext(ctx, `
		SELECT id, type, exercise, set_number, weight, target_reps, actual_reps, planned_rest_seconds, started_at, ended_at
		FROM activity_log
		WHERE user_id = ?
		ORDER BY started_at DESC
		LIMIT 1
	`, userID).Scan(&activityID, &actType, &exerciseStr, &setNumber, &weight, &targetReps, &actualReps, &plannedRest, &startedAt, &endedAt)

	if err != nil {
		return nil
	}

	// If activity is complete (has ended_at), return nil
	if endedAt.Valid {
		return nil
	}

	activity := &workoutv1.UserActivity{
		ActivityId: activityID,
		Type:       actType,
		StartedAt:  timestamppb.New(startedAt),
	}

	// Set exercise fields if present (not set for REST activities)
	if exerciseStr.Valid {
		activity.Exercise = parseExercise(exerciseStr.String)
	}
	if setNumber.Valid {
		activity.SetNumber = int32(setNumber.Int64)
	}
	if weight.Valid {
		activity.Weight = float32(weight.Float64)
	}
	if targetReps.Valid {
		activity.TargetReps = int32(targetReps.Int64)
	}

	// Calculate rest remaining if it's a rest activity
	if actType == "rest" && plannedRest.Valid {
		elapsed := time.Since(startedAt).Seconds()
		remaining := int32(plannedRest.Int64) - int32(elapsed)
		activity.RestSecondsRemaining = remaining
	}

	return activity
}

// Helper: Build the group plan from all members' plans
func (s *WorkoutService) buildGroupPlan(ctx context.Context, groupDB *sql.DB, members []*workoutv1.GroupSessionMember) *workoutv1.GroupPlan {
	plan := &workoutv1.GroupPlan{
		Exercises: []*workoutv1.GroupExercisePlan{},
	}

	// Collect all exercises and user weights
	exerciseUsers := make(map[workoutv1.Exercise][]userWeightInfo)

	for _, member := range members {
		if member.ProposedPlan == nil {
			continue
		}
		for _, ex := range member.ProposedPlan.Exercises {
			exerciseUsers[ex.Exercise] = append(exerciseUsers[ex.Exercise], userWeightInfo{
				userID: member.UserId,
				weight: ex.TargetWeight,
				sets:   ex.TargetSets,
				reps:   ex.TargetReps,
			})
		}
	}

	// Build group plan for each exercise
	position := 1
	exercises := make([]workoutv1.Exercise, 0, len(exerciseUsers))
	for ex := range exerciseUsers {
		exercises = append(exercises, ex)
	}
	// Sort exercises by enum value for consistent ordering
	sort.Slice(exercises, func(i, j int) bool {
		return exercises[i] < exercises[j]
	})

	for _, exercise := range exercises {
		users := exerciseUsers[exercise]

		// Sort users by weight (ascending - less plate changes)
		sort.Slice(users, func(i, j int) bool {
			return users[i].weight < users[j].weight
		})

		groupEx := &workoutv1.GroupExercisePlan{
			Exercise:  exercise,
			Position:  int32(position),
			UserSlots: []*workoutv1.UserExerciseSlot{},
		}

		var prevWeight float32 = 0
		for _, u := range users {
			plateChange := ""
			if prevWeight > 0 {
				plateChange = calculatePlateChange(prevWeight, u.weight)
			}

			groupEx.UserSlots = append(groupEx.UserSlots, &workoutv1.UserExerciseSlot{
				UserId:      u.userID,
				Weight:      u.weight,
				Sets:        u.sets,
				Reps:        u.reps,
				PlateChange: plateChange,
			})

			prevWeight = u.weight
		}

		plan.Exercises = append(plan.Exercises, groupEx)
		position++
	}

	return plan
}

// Helper: Apply the group plan to a user's personal database
// If user already has an active workout, link it to the group. Otherwise create a new session.
func (s *WorkoutService) applyGroupPlanToUser(ctx context.Context, groupDB *sql.DB, username string, sessionID string) error {
	userDB, err := s.dbManager.GetDB(username)
	if err != nil {
		return err
	}

	now := time.Now()

	// Check if user already has an active workout
	activeState, _ := s.getActiveWorkout(ctx, userDB)
	if activeState != nil {
		// User has an active workout - just link it to the group
		userDB.ExecContext(ctx, `UPDATE sessions SET group_id = ? WHERE id = ?`, sessionID, activeState.SessionId)

		// Update active group session reference
		userDB.ExecContext(ctx, `
			INSERT OR REPLACE INTO active_group_session (id, session_id, updated_at)
			VALUES (1, ?, ?)
		`, sessionID, now)

		return nil
	}

	// No active workout - create a new session from their group plan
	rows, err := groupDB.QueryContext(ctx, `
		SELECT exercise, target_weight, target_sets, target_reps
		FROM user_plans WHERE user_id = ?
	`, username)
	if err != nil {
		return err
	}
	defer rows.Close()

	// Create a new session in user's DB
	userSessionID := fmt.Sprintf("session-%d", now.UnixNano())

	// Determine workout type based on exercises
	workoutType := "A"

	_, err = userDB.ExecContext(ctx, `
		INSERT INTO sessions (id, started_at, workout_started_at, workout_type, group_id)
		VALUES (?, ?, ?, ?, ?)
	`, userSessionID, now, now, workoutType, sessionID)
	if err != nil {
		return err
	}

	// Insert planned sets from group plan - set numbers restart at 1 for each exercise
	for rows.Next() {
		var exerciseStr string
		var weight float32
		var sets, reps int32
		rows.Scan(&exerciseStr, &weight, &sets, &reps)

		// Each exercise gets sets numbered 1 to N
		for setNum := int32(1); setNum <= sets; setNum++ {
			setID := uuid.New().String()
			userDB.ExecContext(ctx, `
				INSERT INTO planned_sets (id, session_id, exercise, set_number, target_weight, target_reps)
				VALUES (?, ?, ?, ?, ?, ?)
			`, setID, userSessionID, exerciseStr, setNum, weight, reps)
		}
	}

	// Update active group session reference
	userDB.ExecContext(ctx, `
		INSERT OR REPLACE INTO active_group_session (id, session_id, updated_at)
		VALUES (1, ?, ?)
	`, sessionID, now)

	return nil
}

// Helper: Parse exercise string to enum
func parseExercise(s string) workoutv1.Exercise {
	switch s {
	case "EXERCISE_SQUAT":
		return workoutv1.Exercise_EXERCISE_SQUAT
	case "EXERCISE_BENCH":
		return workoutv1.Exercise_EXERCISE_BENCH
	case "EXERCISE_DEADLIFT":
		return workoutv1.Exercise_EXERCISE_DEADLIFT
	case "EXERCISE_OHP":
		return workoutv1.Exercise_EXERCISE_OHP
	case "EXERCISE_ROW":
		return workoutv1.Exercise_EXERCISE_ROW
	default:
		return workoutv1.Exercise_EXERCISE_UNSPECIFIED
	}
}
