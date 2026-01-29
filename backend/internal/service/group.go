package service

import (
	"context"
	"database/sql"
	"fmt"
	"math"
	"sort"
	"time"

	"connectrpc.com/connect"
	"github.com/google/uuid"

	workoutv1 "github.com/brensch/lift/backend/gen/workout/v1"
	"github.com/brensch/lift/backend/internal/hub"
	"github.com/brensch/lift/backend/internal/interceptor"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// InviteToGroup invites a user to join the current workout group
func (s *WorkoutService) InviteToGroup(
	ctx context.Context,
	req *connect.Request[workoutv1.InviteToGroupRequest],
) (*connect.Response[workoutv1.InviteToGroupResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get or create a group for this user's active session
	activeState, err := s.getActiveWorkout(ctx, database)
	if err != nil || activeState == nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, fmt.Errorf("no active workout to invite to"))
	}

	// Validate that the invited user exists (has a database)
	if !s.dbManager.UserExists(req.Msg.Username) {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("user '%s' does not exist", req.Msg.Username))
	}

	// Check if session already has a group
	var groupID sql.NullString
	err = database.QueryRowContext(ctx, `SELECT group_id FROM sessions WHERE id = ?`, activeState.SessionId).Scan(&groupID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Create group if needed
	if !groupID.Valid || groupID.String == "" {
		newGroupID := uuid.New().String()
		_, err = database.ExecContext(ctx, `
			INSERT INTO workout_groups (id, created_by, created_at, is_active)
			VALUES (?, ?, ?, 1)
		`, newGroupID, username, time.Now())
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to create group: %w", err))
		}

		// Update session with group ID
		_, err = database.ExecContext(ctx, `UPDATE sessions SET group_id = ? WHERE id = ?`, newGroupID, activeState.SessionId)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
		groupID.String = newGroupID
		groupID.Valid = true
	}

	// Get the invited user's database - we need to store the invite there
	// so they can find it when querying for pending invites
	invitedUserDB, err := s.dbManager.GetDB(req.Msg.Username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to get invited user database: %w", err))
	}

	// Create the invite in BOTH databases:
	// - Invitee's DB: so they can see pending invites
	// - Inviter's DB: so we can track who accepted and build the group
	inviteID := uuid.New().String()
	now := time.Now()

	// Store in invitee's database (for getPendingInvites)
	_, err = invitedUserDB.ExecContext(ctx, `
		INSERT INTO group_invites (id, group_id, from_user, to_user, status, created_at)
		VALUES (?, ?, ?, ?, 'pending', ?)
	`, inviteID, groupID.String, username, req.Msg.Username, now)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to create invite in invitee db: %w", err))
	}

	// Store in inviter's database (for buildWorkoutGroup to track members)
	_, err = database.ExecContext(ctx, `
		INSERT INTO group_invites (id, group_id, from_user, to_user, status, created_at)
		VALUES (?, ?, ?, ?, 'pending', ?)
	`, inviteID, groupID.String, username, req.Msg.Username, now)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to create invite in inviter db: %w", err))
	}

	// Build the group with current members
	group := s.buildWorkoutGroup(ctx, database, groupID.String, username)

	// Build a preview of the group workout plan (invitedUserDB already fetched above)
	plan := s.buildGroupWorkoutPlan(ctx, database, invitedUserDB, group, username, req.Msg.Username)

	invite := &workoutv1.GroupInvite{
		Id:        inviteID,
		SessionId: groupID.String,
		FromUser:  username,
		ToUser:    req.Msg.Username,
		Status:    "pending",
		CreatedAt: timestamppb.Now(),
	}

	// Notify the invited user via their personal channel
	s.hub.BroadcastToAll(hub.UserChannel(req.Msg.Username), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_INVITE_RECEIVED,
		UserId:    username,
		Invite:    invite,
		GroupId:   groupID.String,
		Timestamp: timestamppb.Now(),
	})

	// Notify the inviter so they subscribe to the group channel
	s.hub.BroadcastToAll(hub.UserChannel(username), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED,
		UserId:    username,
		Group:     group,
		GroupId:   groupID.String,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.InviteToGroupResponse{
		Invite: invite,
		Plan:   plan,
	}), nil
}

// RespondToInvite accepts or declines a group invite
func (s *WorkoutService) RespondToInvite(
	ctx context.Context,
	req *connect.Request[workoutv1.RespondToInviteRequest],
) (*connect.Response[workoutv1.RespondToInviteResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get the invite
	var groupID, fromUser string
	err = database.QueryRowContext(ctx, `
		SELECT group_id, from_user FROM group_invites WHERE id = ? AND to_user = ? AND status = 'pending'
	`, req.Msg.InviteId, username).Scan(&groupID, &fromUser)
	if err == sql.ErrNoRows {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("invite not found or already responded"))
	}
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	status := "declined"
	if req.Msg.Accept {
		status = "accepted"
	}

	// Update invite status in responder's database
	_, err = database.ExecContext(ctx, `UPDATE group_invites SET status = ? WHERE id = ?`, status, req.Msg.InviteId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Also update in inviter's database (so buildWorkoutGroup can find accepted members)
	inviterDB, err := s.dbManager.GetDB(fromUser)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to get inviter database: %w", err))
	}
	_, err = inviterDB.ExecContext(ctx, `UPDATE group_invites SET status = ? WHERE id = ?`, status, req.Msg.InviteId)
	if err != nil {
		// Log but don't fail - inviter's copy is for tracking only
	}

	if !req.Msg.Accept {
		return connect.NewResponse(&workoutv1.RespondToInviteResponse{}), nil
	}

	// Copy the workout_groups entry to the accepting user's database
	// (so buildWorkoutGroup can find it later when querying their DB)
	var createdAt time.Time
	inviterDB.QueryRowContext(ctx, `SELECT created_at FROM workout_groups WHERE id = ?`, groupID).Scan(&createdAt)
	database.ExecContext(ctx, `
		INSERT OR REPLACE INTO workout_groups (id, created_by, created_at, is_active)
		VALUES (?, ?, ?, 1)
	`, groupID, fromUser, createdAt)

	// User accepted - check if they have an active workout
	activeState, _ := s.getActiveWorkout(ctx, database)

	// If no active workout, start one with their next proposed workout
	if activeState == nil {
		// Get their upcoming workouts
		preferences := s.getUserPreferences(database)
		lastWorkoutType := s.getLastWorkoutType(database)
		nextType := "A"
		if lastWorkoutType == "A" {
			nextType = "B"
		}
		sets := s.generateWorkoutSets(database, nextType)
		targetDates := s.calculateTargetDates(preferences.WorkoutDays, 1)

		// Start the workout
		now := time.Now()
		sessionID := fmt.Sprintf("session-%d", now.UnixNano())
		_, err = database.ExecContext(ctx, `
			INSERT INTO sessions (id, started_at, workout_started_at, workout_type, group_id)
			VALUES (?, ?, ?, ?, ?)
		`, sessionID, now, now, nextType, groupID)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}

		// Insert planned sets
		for _, set := range sets {
			setID := uuid.New().String()
			database.ExecContext(ctx, `
				INSERT INTO planned_sets (id, session_id, exercise, set_number, target_weight, target_reps)
				VALUES (?, ?, ?, ?, ?, ?)
			`, setID, sessionID, set.Exercise.String(), set.SetNumber, set.TargetWeight, set.TargetReps)
		}

		activeState = &workoutv1.WorkoutState{
			SessionId:        sessionID,
			SessionStartedAt: timestamppb.New(now),
			WorkoutStartedAt: timestamppb.New(now),
			Timeline:         []*workoutv1.Activity{},
			RemainingSets:    sets,
			IsComplete:       false,
		}
		if len(sets) > 0 {
			activeState.NextSet = sets[0]
		}
		if len(targetDates) > 0 {
			// Note: targetDate not used in state, but calculated
		}
	} else {
		// Update existing session with group ID
		_, err = database.ExecContext(ctx, `UPDATE sessions SET group_id = ? WHERE id = ?`, groupID, activeState.SessionId)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
	}

	// Build group with all members (inviterDB already fetched above)
	group := s.buildWorkoutGroup(ctx, inviterDB, groupID, fromUser)

	// Build the workout plan
	plan := s.buildGroupWorkoutPlan(ctx, inviterDB, database, group, fromUser, username)

	// Notify the inviter that their invite was accepted
	s.hub.BroadcastToAll(hub.UserChannel(fromUser), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_INVITE_ACCEPTED,
		UserId:    username,
		Group:     group,
		GroupId:   groupID,
		Timestamp: timestamppb.Now(),
	})

	// Notify the accepting user so they subscribe to the group channel
	s.hub.BroadcastToAll(hub.UserChannel(username), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED,
		UserId:    username,
		State:     activeState,
		Group:     group,
		GroupId:   groupID,
		Timestamp: timestamppb.Now(),
	})

	// Broadcast to the group channel that someone joined
	s.hub.BroadcastToAll(hub.GroupChannel(groupID), &workoutv1.WorkoutUpdate{
		Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_JOINED,
		UserId:    username,
		State:     activeState,
		Group:     group,
		GroupId:   groupID,
		Timestamp: timestamppb.Now(),
	})

	return connect.NewResponse(&workoutv1.RespondToInviteResponse{
		Group: group,
		Plan:  plan,
		State: activeState,
	}), nil
}

// GetGroup returns the current group state
func (s *WorkoutService) GetGroup(
	ctx context.Context,
	req *connect.Request[workoutv1.GetGroupRequest],
) (*connect.Response[workoutv1.GetGroupResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	group := s.buildWorkoutGroup(ctx, database, req.Msg.GroupId, username)
	if group == nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group not found"))
	}

	// Build workout plan
	plan := s.buildGroupWorkoutPlanFromGroup(ctx, group)

	return connect.NewResponse(&workoutv1.GetGroupResponse{
		Group: group,
		Plan:  plan,
	}), nil
}

// LeaveGroup removes the user from their current group
func (s *WorkoutService) LeaveGroup(
	ctx context.Context,
	req *connect.Request[workoutv1.LeaveGroupRequest],
) (*connect.Response[workoutv1.LeaveGroupResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Get active workout and its group
	activeState, err := s.getActiveWorkout(ctx, database)
	if err != nil || activeState == nil {
		return connect.NewResponse(&workoutv1.LeaveGroupResponse{Success: true}), nil
	}

	var groupID sql.NullString
	database.QueryRowContext(ctx, `SELECT group_id FROM sessions WHERE id = ?`, activeState.SessionId).Scan(&groupID)

	if groupID.Valid && groupID.String != "" {
		// Remove group from session
		database.ExecContext(ctx, `UPDATE sessions SET group_id = NULL WHERE id = ?`, activeState.SessionId)

		// Broadcast that user left to the group channel
		s.hub.Broadcast(hub.GroupChannel(groupID.String), &workoutv1.WorkoutUpdate{
			Type:      workoutv1.UpdateType_UPDATE_TYPE_USER_LEFT,
			UserId:    username,
			GroupId:   groupID.String,
			Timestamp: timestamppb.Now(),
		}, username)
	}

	return connect.NewResponse(&workoutv1.LeaveGroupResponse{Success: true}), nil
}

// GetGroupWorkoutPlan returns the optimal workout order for the group
func (s *WorkoutService) GetGroupWorkoutPlan(
	ctx context.Context,
	req *connect.Request[workoutv1.GetGroupWorkoutPlanRequest],
) (*connect.Response[workoutv1.GetGroupWorkoutPlanResponse], error) {
	username, ok := interceptor.GetUsername(ctx)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no username in context"))
	}

	database, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	group := s.buildWorkoutGroup(ctx, database, req.Msg.GroupId, username)
	if group == nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("group not found"))
	}

	plan := s.buildGroupWorkoutPlanFromGroup(ctx, group)

	return connect.NewResponse(&workoutv1.GetGroupWorkoutPlanResponse{
		Plan: plan,
	}), nil
}

// Helper: Build the workout group with all members
func (s *WorkoutService) buildWorkoutGroup(ctx context.Context, database *sql.DB, groupID string, currentUser string) *workoutv1.WorkoutGroup {
	var createdBy string
	var createdAt time.Time
	err := database.QueryRowContext(ctx, `
		SELECT created_by, created_at FROM workout_groups WHERE id = ?
	`, groupID).Scan(&createdBy, &createdAt)
	if err != nil {
		return nil
	}

	group := &workoutv1.WorkoutGroup{
		Id:        groupID,
		CreatedBy: createdBy,
		CreatedAt: timestamppb.New(createdAt),
		Members:   []*workoutv1.GroupMember{},
	}

	// Find all sessions with this group ID by checking invites
	// First, add the creator
	creatorState, _ := s.getActiveWorkoutForUser(ctx, createdBy)
	if creatorState != nil {
		restRemaining := s.calculateRestRemaining(creatorState)
		group.Members = append(group.Members, &workoutv1.GroupMember{
			UserId:               createdBy,
			State:                creatorState,
			IsActive:             true,
			RestSecondsRemaining: restRemaining,
		})
	}

	// Get accepted invites for this group
	rows, err := database.QueryContext(ctx, `
		SELECT to_user FROM group_invites WHERE group_id = ? AND status = 'accepted'
	`, groupID)
	if err != nil {
		return group
	}
	defer rows.Close()

	for rows.Next() {
		var toUser string
		if err := rows.Scan(&toUser); err != nil {
			continue
		}
		if toUser == createdBy {
			continue // Already added
		}
		memberState, _ := s.getActiveWorkoutForUser(ctx, toUser)
		restRemaining := int32(0)
		if memberState != nil {
			restRemaining = s.calculateRestRemaining(memberState)
		}
		group.Members = append(group.Members, &workoutv1.GroupMember{
			UserId:               toUser,
			State:                memberState,
			IsActive:             memberState != nil,
			RestSecondsRemaining: restRemaining,
		})
	}

	return group
}

// Helper: Get active workout for a specific user
func (s *WorkoutService) getActiveWorkoutForUser(ctx context.Context, username string) (*workoutv1.WorkoutState, error) {
	userDB, err := s.dbManager.GetDB(username)
	if err != nil {
		return nil, err
	}
	return s.getActiveWorkout(ctx, userDB)
}

// Helper: Calculate rest seconds remaining
func (s *WorkoutService) calculateRestRemaining(state *workoutv1.WorkoutState) int32 {
	if state.CurrentActivity == nil || state.CurrentActivity.Type != workoutv1.ActivityType_ACTIVITY_TYPE_REST {
		return 0
	}
	activity := state.CurrentActivity
	restStarted := activity.StartedAt.AsTime()
	restDuration := time.Duration(activity.PlannedDurationSeconds) * time.Second
	restEnds := restStarted.Add(restDuration)
	remaining := restEnds.Sub(time.Now())
	if remaining < 0 {
		return int32(remaining.Seconds()) // Negative = overdue
	}
	return int32(remaining.Seconds())
}

// Helper: Build group workout plan from two databases (inviter and invitee)
func (s *WorkoutService) buildGroupWorkoutPlan(ctx context.Context, inviterDB, inviteeDB *sql.DB, group *workoutv1.WorkoutGroup, inviter, invitee string) *workoutv1.GroupWorkoutPlan {
	plan := &workoutv1.GroupWorkoutPlan{
		Members:   group.Members,
		Exercises: []*workoutv1.ExerciseOrder{},
	}

	// Collect all exercises from all members' remaining sets
	exerciseWeights := make(map[workoutv1.Exercise][]userWeightInfo)

	for _, member := range group.Members {
		if member.State == nil {
			continue
		}
		for _, set := range member.State.RemainingSets {
			exerciseWeights[set.Exercise] = append(exerciseWeights[set.Exercise], userWeightInfo{
				userID: member.UserId,
				weight: set.TargetWeight,
			})
		}
	}

	// Also add the invitee's proposed sets (they might not have a state yet)
	if inviteeDB != nil {
		inviteeState, _ := s.getActiveWorkout(ctx, inviteeDB)
		if inviteeState == nil {
			// Get their proposed workout
			lastType := s.getLastWorkoutType(inviteeDB)
			nextType := "A"
			if lastType == "A" {
				nextType = "B"
			}
			sets := s.generateWorkoutSets(inviteeDB, nextType)
			for _, set := range sets {
				found := false
				for _, uw := range exerciseWeights[set.Exercise] {
					if uw.userID == invitee {
						found = true
						break
					}
				}
				if !found {
					exerciseWeights[set.Exercise] = append(exerciseWeights[set.Exercise], userWeightInfo{
						userID: invitee,
						weight: set.TargetWeight,
					})
				}
			}
		}
	}

	// Build exercise order for each exercise
	for exercise, weights := range exerciseWeights {
		// Sort by weight ascending (optimal for adding plates)
		sort.Slice(weights, func(i, j int) bool {
			return weights[i].weight < weights[j].weight
		})

		// Remove duplicates (same user might appear multiple times)
		seen := make(map[string]bool)
		uniqueWeights := []userWeightInfo{}
		for _, w := range weights {
			if !seen[w.userID] {
				seen[w.userID] = true
				uniqueWeights = append(uniqueWeights, w)
			}
		}

		exerciseOrder := &workoutv1.ExerciseOrder{
			Exercise:  exercise,
			UserOrder: []*workoutv1.UserWeight{},
		}

		var prevWeight float32 = 0
		for _, uw := range uniqueWeights {
			plateChange := ""
			if prevWeight > 0 {
				plateChange = calculatePlateChange(prevWeight, uw.weight)
			}
			exerciseOrder.UserOrder = append(exerciseOrder.UserOrder, &workoutv1.UserWeight{
				UserId:      uw.userID,
				Weight:      uw.weight,
				PlateChange: plateChange,
			})
			prevWeight = uw.weight
		}

		plan.Exercises = append(plan.Exercises, exerciseOrder)
	}

	// Sort exercises by enum value for consistent ordering
	sort.Slice(plan.Exercises, func(i, j int) bool {
		return plan.Exercises[i].Exercise < plan.Exercises[j].Exercise
	})

	return plan
}

// Helper: Build workout plan from group alone
func (s *WorkoutService) buildGroupWorkoutPlanFromGroup(ctx context.Context, group *workoutv1.WorkoutGroup) *workoutv1.GroupWorkoutPlan {
	plan := &workoutv1.GroupWorkoutPlan{
		Members:   group.Members,
		Exercises: []*workoutv1.ExerciseOrder{},
	}

	exerciseWeights := make(map[workoutv1.Exercise][]userWeightInfo)

	for _, member := range group.Members {
		if member.State == nil {
			continue
		}
		for _, set := range member.State.RemainingSets {
			exerciseWeights[set.Exercise] = append(exerciseWeights[set.Exercise], userWeightInfo{
				userID: member.UserId,
				weight: set.TargetWeight,
			})
		}
	}

	for exercise, weights := range exerciseWeights {
		sort.Slice(weights, func(i, j int) bool {
			return weights[i].weight < weights[j].weight
		})

		seen := make(map[string]bool)
		uniqueWeights := []userWeightInfo{}
		for _, w := range weights {
			if !seen[w.userID] {
				seen[w.userID] = true
				uniqueWeights = append(uniqueWeights, w)
			}
		}

		exerciseOrder := &workoutv1.ExerciseOrder{
			Exercise:  exercise,
			UserOrder: []*workoutv1.UserWeight{},
		}

		var prevWeight float32 = 0
		for _, uw := range uniqueWeights {
			plateChange := ""
			if prevWeight > 0 {
				plateChange = calculatePlateChange(prevWeight, uw.weight)
			}
			exerciseOrder.UserOrder = append(exerciseOrder.UserOrder, &workoutv1.UserWeight{
				UserId:      uw.userID,
				Weight:      uw.weight,
				PlateChange: plateChange,
			})
			prevWeight = uw.weight
		}

		plan.Exercises = append(plan.Exercises, exerciseOrder)
	}

	sort.Slice(plan.Exercises, func(i, j int) bool {
		return plan.Exercises[i].Exercise < plan.Exercises[j].Exercise
	})

	return plan
}

type userWeightInfo struct {
	userID string
	weight float32
	sets   int32
	reps   int32
}

// calculatePlateChange calculates the plate change description between two weights
func calculatePlateChange(from, to float32) string {
	diff := to - from
	if diff == 0 {
		return ""
	}

	if diff > 0 {
		// Adding weight
		return formatPlateChange(diff, "+")
	} else {
		// Removing weight
		return formatPlateChange(-diff, "-")
	}
}

func formatPlateChange(totalPerSide float32, prefix string) string {
	// totalPerSide is the total change, but we need per-side (divide by 2)
	perSide := totalPerSide / 2
	availablePlates := []float32{45, 35, 25, 10, 5, 2.5}

	result := ""
	for _, plate := range availablePlates {
		count := int(math.Floor(float64(perSide / plate)))
		if count > 0 {
			perSide -= float32(count) * plate
			if result != "" {
				result += ", "
			}
			result += fmt.Sprintf("%s%dx%.0f", prefix, count, plate)
			if plate == 2.5 {
				result = result[:len(result)-1] + ".5" // Fix 2.5 formatting
			}
		}
	}

	if result == "" && totalPerSide != 0 {
		// Small change that doesn't fit standard plates
		result = fmt.Sprintf("%s%.1f lbs", prefix, totalPerSide)
	}

	return result
}

// getPendingInvites returns pending invites for a user
func (s *WorkoutService) getPendingInvites(ctx context.Context, database *sql.DB, username string) []*workoutv1.GroupInvite {
	invites := []*workoutv1.GroupInvite{}

	rows, err := database.QueryContext(ctx, `
		SELECT id, group_id, from_user, created_at
		FROM group_invites
		WHERE to_user = ? AND status = 'pending'
		ORDER BY created_at DESC
	`, username)
	if err != nil {
		return invites
	}
	defer rows.Close()

	for rows.Next() {
		var id, groupID, fromUser string
		var createdAt time.Time
		if err := rows.Scan(&id, &groupID, &fromUser, &createdAt); err != nil {
			continue
		}

		invites = append(invites, &workoutv1.GroupInvite{
			Id:        id,
			SessionId: groupID,
			FromUser:  fromUser,
			ToUser:    username,
			Status:    "pending",
			CreatedAt: timestamppb.New(createdAt),
		})
	}

	return invites
}

// getActiveGroup returns the group for the user's active workout
func (s *WorkoutService) getActiveGroup(ctx context.Context, database *sql.DB, username string) *workoutv1.WorkoutGroup {
	activeState, err := s.getActiveWorkout(ctx, database)
	if err != nil || activeState == nil {
		return nil
	}

	var groupID sql.NullString
	database.QueryRowContext(ctx, `SELECT group_id FROM sessions WHERE id = ?`, activeState.SessionId).Scan(&groupID)

	if !groupID.Valid || groupID.String == "" {
		return nil
	}

	// Get the group creator from the local workout_groups table
	var createdBy string
	err = database.QueryRowContext(ctx, `SELECT created_by FROM workout_groups WHERE id = ?`, groupID.String).Scan(&createdBy)
	if err != nil {
		return nil
	}

	// Build the group from the creator's database (which has all the invites)
	creatorDB, err := s.dbManager.GetDB(createdBy)
	if err != nil {
		return nil
	}

	return s.buildWorkoutGroup(ctx, creatorDB, groupID.String, createdBy)
}
