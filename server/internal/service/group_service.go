package service

import (
	"context"
	"fmt"
	"log"

	"connectrpc.com/connect"
	liftv1 "github.com/brensch/lift/server/gen/lift/v1"
	"github.com/brensch/lift/server/internal/db"
	"github.com/brensch/lift/server/internal/hub"
	"github.com/brensch/lift/server/internal/interceptor"
)

type GroupService struct {
	registry *db.Registry
	groupDB  *db.GroupDB
	userDBs  *db.UserDBManager
	hub      *hub.Hub
}

func NewGroupService(registry *db.Registry, groupDB *db.GroupDB, userDBs *db.UserDBManager, hub *hub.Hub) *GroupService {
	return &GroupService{
		registry: registry,
		groupDB:  groupDB,
		userDBs:  userDBs,
		hub:      hub,
	}
}

func (s *GroupService) InviteUser(ctx context.Context, req *connect.Request[liftv1.InviteUserRequest]) (*connect.Response[liftv1.InviteUserResponse], error) {
	inviterID := interceptor.UserIDFromContext(ctx)
	inviterName := interceptor.UserNameFromContext(ctx)
	targetUserID := req.Msg.TargetUserId

	// Check if inviter already has an active group workout
	existing, err := s.groupDB.GetActiveGroupForUser(inviterID)
	var groupWorkoutID string
	if err != nil {
		// No active group, create one
		gw, err := s.groupDB.CreateGroupWorkout()
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
		groupWorkoutID = gw.ID
		// Add inviter as participant
		if err := s.groupDB.AddParticipant(inviterID, groupWorkoutID); err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
	} else {
		groupWorkoutID = existing.GroupWorkoutID
	}

	// Add target user as participant
	if err := s.groupDB.AddParticipant(targetUserID, groupWorkoutID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Notify target user
	s.hub.Publish(fmt.Sprintf("invite:%s", targetUserID))
	log.Printf("User %s invited %s to group workout %s", inviterName, targetUserID, groupWorkoutID)

	return connect.NewResponse(&liftv1.InviteUserResponse{}), nil
}

func (s *GroupService) ListenToInvites(ctx context.Context, req *connect.Request[liftv1.ListenToInvitesRequest], stream *connect.ServerStream[liftv1.InviteEvent]) error {
	userID := interceptor.UserIDFromContext(ctx)
	channel := fmt.Sprintf("invite:%s", userID)
	ch := s.hub.Subscribe(channel)
	defer s.hub.Unsubscribe(channel, ch)

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ch:
			// Check for active group
			participant, err := s.groupDB.GetActiveGroupForUser(userID)
			if err != nil {
				continue
			}

			// Find who invited (look for other participants)
			participants, err := s.groupDB.GetParticipants(participant.GroupWorkoutID)
			if err != nil {
				continue
			}

			var inviterID, inviterName string
			for _, p := range participants {
				if p.UserID != userID {
					inviterID = p.UserID
					user, err := s.registry.GetUserByID(p.UserID)
					if err == nil {
						inviterName = user.Name
					}
					break
				}
			}

			if err := stream.Send(&liftv1.InviteEvent{
				GroupWorkoutId: participant.GroupWorkoutID,
				InviterUserId:  inviterID,
				InviterName:    inviterName,
			}); err != nil {
				return err
			}
		}
	}
}

func (s *GroupService) SubmitExerciseSelection(ctx context.Context, req *connect.Request[liftv1.SubmitExerciseSelectionRequest]) (*connect.Response[liftv1.SubmitExerciseSelectionResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)

	var exercises []int
	for _, ex := range req.Msg.Exercises {
		exercises = append(exercises, int(ex))
	}

	if err := s.groupDB.SetExerciseSelection(userID, req.Msg.GroupWorkoutId, exercises, req.Msg.Ready); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	s.hub.Publish(fmt.Sprintf("proposals:%s", req.Msg.GroupWorkoutId))

	return connect.NewResponse(&liftv1.SubmitExerciseSelectionResponse{}), nil
}

func (s *GroupService) GroupWorkoutProposals(ctx context.Context, req *connect.Request[liftv1.GroupWorkoutProposalsRequest], stream *connect.ServerStream[liftv1.GroupWorkoutProposalsEvent]) error {
	groupWorkoutID := req.Msg.GroupWorkoutId
	channel := fmt.Sprintf("proposals:%s", groupWorkoutID)
	ch := s.hub.Subscribe(channel)
	defer s.hub.Unsubscribe(channel, ch)

	// Send initial state
	if err := s.sendProposalsState(groupWorkoutID, stream); err != nil {
		return err
	}

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ch:
			if err := s.sendProposalsState(groupWorkoutID, stream); err != nil {
				return err
			}
		}
	}
}

func (s *GroupService) sendProposalsState(groupWorkoutID string, stream *connect.ServerStream[liftv1.GroupWorkoutProposalsEvent]) error {
	participants, err := s.groupDB.GetParticipants(groupWorkoutID)
	if err != nil {
		return err
	}

	selections, err := s.groupDB.GetExerciseSelections(groupWorkoutID)
	if err != nil {
		return err
	}

	var pbSelections []*liftv1.ExerciseSelection
	allReady := len(participants) > 0

	for _, p := range participants {
		user, err := s.registry.GetUserByID(p.UserID)
		userName := p.UserID
		if err == nil {
			userName = user.Name
		}

		sel := &liftv1.ExerciseSelection{
			UserId:   p.UserID,
			UserName: userName,
		}

		if state, ok := selections[p.UserID]; ok {
			for _, ex := range state.Exercises {
				sel.Exercises = append(sel.Exercises, liftv1.Exercise(ex))
			}
			sel.Ready = state.Ready
		}

		if !sel.Ready {
			allReady = false
		}

		pbSelections = append(pbSelections, sel)
	}

	return stream.Send(&liftv1.GroupWorkoutProposalsEvent{
		GroupWorkoutId: groupWorkoutID,
		Selections:     pbSelections,
		AllReady:        allReady,
	})
}

func (s *GroupService) ConnectToWorkout(ctx context.Context, req *connect.Request[liftv1.ConnectToWorkoutRequest], stream *connect.ServerStream[liftv1.WorkoutEvent]) error {
	groupWorkoutID := req.Msg.GroupWorkoutId
	channel := fmt.Sprintf("group:%s", groupWorkoutID)

	// Subscribe to individual workout channels for all participants
	participants, err := s.groupDB.GetParticipants(groupWorkoutID)
	if err != nil {
		return connect.NewError(connect.CodeInternal, err)
	}

	// Subscribe to group channel + all participant workout channels
	groupCh := s.hub.Subscribe(channel)
	defer s.hub.Unsubscribe(channel, groupCh)

	var workoutChannels []chan struct{}
	for _, p := range participants {
		wCh := s.hub.Subscribe("workout:" + p.UserID)
		workoutChannels = append(workoutChannels, wCh)
		defer s.hub.Unsubscribe("workout:"+p.UserID, wCh)
	}

	// Send initial state
	if err := s.sendWorkoutState(groupWorkoutID, stream); err != nil {
		return err
	}

	// Merge all channels into one
	merged := make(chan struct{}, 1)
	done := ctx.Done()

	go func() {
		for {
			select {
			case <-done:
				return
			case <-groupCh:
				select {
				case merged <- struct{}{}:
				default:
				}
			}
		}
	}()

	for _, wCh := range workoutChannels {
		wCh := wCh
		go func() {
			for {
				select {
				case <-done:
					return
				case <-wCh:
					select {
					case merged <- struct{}{}:
					default:
					}
				}
			}
		}()
	}

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-merged:
			if err := s.sendWorkoutState(groupWorkoutID, stream); err != nil {
				return err
			}
		}
	}
}

func (s *GroupService) sendWorkoutState(groupWorkoutID string, stream *connect.ServerStream[liftv1.WorkoutEvent]) error {
	participants, err := s.groupDB.GetParticipants(groupWorkoutID)
	if err != nil {
		return err
	}

	var pbParticipants []*liftv1.ParticipantWorkoutState
	for _, p := range participants {
		if p.WorkoutID == "" {
			continue
		}

		user, err := s.registry.GetUserByID(p.UserID)
		userName := p.UserID
		if err == nil {
			userName = user.Name
		}

		udb, err := s.userDBs.GetDB(p.UserID)
		if err != nil {
			continue
		}

		state, err := BuildWorkoutState(udb, p.WorkoutID)
		if err != nil {
			continue
		}

		pbParticipants = append(pbParticipants, &liftv1.ParticipantWorkoutState{
			UserId:       p.UserID,
			UserName:     userName,
			WorkoutState: state,
		})
	}

	return stream.Send(&liftv1.WorkoutEvent{
		GroupWorkoutId: groupWorkoutID,
		Participants:   pbParticipants,
	})
}

func (s *GroupService) ListUsers(ctx context.Context, req *connect.Request[liftv1.ListUsersRequest]) (*connect.Response[liftv1.ListUsersResponse], error) {
	users, err := s.registry.ListUsers()
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	var pbUsers []*liftv1.UserInfo
	for _, u := range users {
		pbUsers = append(pbUsers, &liftv1.UserInfo{
			Id:   u.ID,
			Name: u.Name,
		})
	}

	return connect.NewResponse(&liftv1.ListUsersResponse{Users: pbUsers}), nil
}
