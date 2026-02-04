package service

import (
	"context"
	"database/sql"

	"connectrpc.com/connect"
	liftv1 "github.com/brensch/lift/server/gen/lift/v1"
	"github.com/brensch/lift/server/internal/db"
	"github.com/brensch/lift/server/internal/hub"
	"github.com/brensch/lift/server/internal/interceptor"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type WorkoutService struct {
	userDBs *db.UserDBManager
	hub     *hub.Hub
}

func NewWorkoutService(userDBs *db.UserDBManager, hub *hub.Hub) *WorkoutService {
	return &WorkoutService{userDBs: userDBs, hub: hub}
}

func (s *WorkoutService) StartWorkout(ctx context.Context, req *connect.Request[liftv1.StartWorkoutRequest]) (*connect.Response[liftv1.StartWorkoutResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)
	udb, err := s.userDBs.GetDB(userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	w, err := db.CreateWorkout(udb)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	state, err := BuildWorkoutState(udb, w.ID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.StartWorkoutResponse{State: state}), nil
}

func (s *WorkoutService) GetWorkout(ctx context.Context, req *connect.Request[liftv1.GetWorkoutRequest]) (*connect.Response[liftv1.GetWorkoutResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)
	udb, err := s.userDBs.GetDB(userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	state, err := BuildWorkoutState(udb, req.Msg.WorkoutId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.GetWorkoutResponse{State: state}), nil
}

func (s *WorkoutService) ModifyProposedSets(ctx context.Context, req *connect.Request[liftv1.ModifyProposedSetsRequest]) (*connect.Response[liftv1.ModifyProposedSetsResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)
	udb, err := s.userDBs.GetDB(userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	var rows []*db.ProposedSetRow
	for _, ps := range req.Msg.ProposedSets {
		rows = append(rows, &db.ProposedSetRow{
			ID:           ps.Id,
			WorkoutID:    req.Msg.WorkoutId,
			WorkoutOrder: int(ps.WorkoutOrder),
			Exercise:     int(ps.Exercise),
			TargetReps:   int(ps.TargetReps),
			TargetWeight: ps.TargetWeight,
			Warmup:       ps.Warmup,
		})
	}

	if err := db.ReplaceProposedSets(udb, req.Msg.WorkoutId, rows); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	s.hub.Publish("workout:" + userID)

	state, err := BuildWorkoutState(udb, req.Msg.WorkoutId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.ModifyProposedSetsResponse{State: state}), nil
}

func (s *WorkoutService) StartSet(ctx context.Context, req *connect.Request[liftv1.StartSetRequest]) (*connect.Response[liftv1.StartSetResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)
	udb, err := s.userDBs.GetDB(userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	if _, err := db.StartSet(udb, req.Msg.WorkoutId, req.Msg.ProposedSetId); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	s.hub.Publish("workout:" + userID)

	state, err := BuildWorkoutState(udb, req.Msg.WorkoutId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.StartSetResponse{State: state}), nil
}

func (s *WorkoutService) CompleteSet(ctx context.Context, req *connect.Request[liftv1.CompleteSetRequest]) (*connect.Response[liftv1.CompleteSetResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)
	udb, err := s.userDBs.GetDB(userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	if err := db.CompleteSet(udb, req.Msg.WorkoutId, req.Msg.ProposedSetId, int(req.Msg.ActualReps), req.Msg.ActualWeight, int(req.Msg.RestSeconds)); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	s.hub.Publish("workout:" + userID)

	state, err := BuildWorkoutState(udb, req.Msg.WorkoutId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.CompleteSetResponse{State: state}), nil
}

func (s *WorkoutService) EndWorkout(ctx context.Context, req *connect.Request[liftv1.EndWorkoutRequest]) (*connect.Response[liftv1.EndWorkoutResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)
	udb, err := s.userDBs.GetDB(userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	if err := db.EndWorkout(udb, req.Msg.WorkoutId); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	s.hub.Publish("workout:" + userID)

	state, err := BuildWorkoutState(udb, req.Msg.WorkoutId)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.EndWorkoutResponse{State: state}), nil
}

func (s *WorkoutService) ListWorkouts(ctx context.Context, req *connect.Request[liftv1.ListWorkoutsRequest]) (*connect.Response[liftv1.ListWorkoutsResponse], error) {
	userID := interceptor.UserIDFromContext(ctx)
	udb, err := s.userDBs.GetDB(userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	workouts, err := db.ListWorkouts(udb)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	var states []*liftv1.WorkoutState
	for _, w := range workouts {
		state, err := BuildWorkoutState(udb, w.ID)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
		states = append(states, state)
	}

	return connect.NewResponse(&liftv1.ListWorkoutsResponse{Workouts: states}), nil
}

func BuildWorkoutState(udb *sql.DB, workoutID string) (*liftv1.WorkoutState, error) {
	w, err := db.GetWorkout(udb, workoutID)
	if err != nil {
		return nil, err
	}

	proposedSets, err := db.GetProposedSets(udb, workoutID)
	if err != nil {
		return nil, err
	}

	completedSets, err := db.GetCompletedSets(udb, workoutID)
	if err != nil {
		return nil, err
	}

	workout := &liftv1.Workout{
		Id:        w.ID,
		StartTime: timestamppb.New(w.StartTime),
	}
	if w.EndTime != nil {
		workout.EndTime = timestamppb.New(*w.EndTime)
	}

	var pbProposed []*liftv1.ProposedSet
	for _, ps := range proposedSets {
		pbProposed = append(pbProposed, &liftv1.ProposedSet{
			Id:           ps.ID,
			WorkoutId:    ps.WorkoutID,
			WorkoutOrder: int32(ps.WorkoutOrder),
			Exercise:     liftv1.Exercise(ps.Exercise),
			TargetReps:   int32(ps.TargetReps),
			TargetWeight: ps.TargetWeight,
			Warmup:       ps.Warmup,
		})
	}

	var pbCompleted []*liftv1.CompletedSet
	for _, cs := range completedSets {
		c := &liftv1.CompletedSet{
			Id:            cs.ID,
			WorkoutId:     cs.WorkoutID,
			ProposedSetId: cs.ProposedSetID,
			ActualReps:    int32(cs.ActualReps),
			ActualWeight:  cs.ActualWeight,
		}
		if cs.StartedAt != nil {
			c.StartedAt = timestamppb.New(*cs.StartedAt)
		}
		if cs.EndedAt != nil {
			c.EndedAt = timestamppb.New(*cs.EndedAt)
		}
		if cs.RestUntil != nil {
			c.RestUntil = timestamppb.New(*cs.RestUntil)
		}
		pbCompleted = append(pbCompleted, c)
	}

	return &liftv1.WorkoutState{
		Workout:       workout,
		ProposedSets:  pbProposed,
		CompletedSets: pbCompleted,
	}, nil
}
