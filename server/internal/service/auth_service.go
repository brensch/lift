package service

import (
	"context"
	"strings"

	"connectrpc.com/connect"
	liftv1 "github.com/brensch/lift/server/gen/lift/v1"
	"github.com/brensch/lift/server/internal/auth"
	"github.com/brensch/lift/server/internal/db"
)

type AuthService struct {
	registry *db.Registry
	userDBs  *db.UserDBManager
}

func NewAuthService(registry *db.Registry, userDBs *db.UserDBManager) *AuthService {
	return &AuthService{registry: registry, userDBs: userDBs}
}

func (s *AuthService) Signup(ctx context.Context, req *connect.Request[liftv1.SignupRequest]) (*connect.Response[liftv1.SignupResponse], error) {
	name := strings.TrimSpace(req.Msg.Name)
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, nil)
	}

	user, err := s.registry.CreateUser(name)
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE constraint") {
			return nil, connect.NewError(connect.CodeAlreadyExists, err)
		}
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Initialize user's SQLite DB
	if _, err := s.userDBs.GetDB(user.ID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	token, err := auth.GenerateToken(user.ID, user.Name)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.SignupResponse{
		Token:  token,
		UserId: user.ID,
		Name:   user.Name,
	}), nil
}

func (s *AuthService) Login(ctx context.Context, req *connect.Request[liftv1.LoginRequest]) (*connect.Response[liftv1.LoginResponse], error) {
	name := strings.TrimSpace(req.Msg.Name)
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, nil)
	}

	user, err := s.registry.GetUserByName(name)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}

	token, err := auth.GenerateToken(user.ID, user.Name)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&liftv1.LoginResponse{
		Token:  token,
		UserId: user.ID,
		Name:   user.Name,
	}), nil
}
