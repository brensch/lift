package interceptor

import (
	"context"
	"strings"

	"connectrpc.com/connect"
	"github.com/brensch/lift/server/internal/auth"
)

type contextKey string

const (
	UserIDKey   contextKey = "user_id"
	UserNameKey contextKey = "user_name"
)

func UserIDFromContext(ctx context.Context) string {
	v, _ := ctx.Value(UserIDKey).(string)
	return v
}

func UserNameFromContext(ctx context.Context) string {
	v, _ := ctx.Value(UserNameKey).(string)
	return v
}

var publicProcedures = map[string]bool{
	"/lift.v1.AuthService/Signup": true,
	"/lift.v1.AuthService/Login":  true,
}

type authInterceptor struct{}

func NewAuthInterceptor() connect.Interceptor {
	return &authInterceptor{}
}

func (i *authInterceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		if publicProcedures[req.Spec().Procedure] {
			return next(ctx, req)
		}
		ctx, err := authenticate(ctx, req.Header())
		if err != nil {
			return nil, err
		}
		return next(ctx, req)
	}
}

func (i *authInterceptor) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}

func (i *authInterceptor) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		if publicProcedures[conn.Spec().Procedure] {
			return next(ctx, conn)
		}
		ctx, err := authenticate(ctx, conn.RequestHeader())
		if err != nil {
			return err
		}
		return next(ctx, conn)
	}
}

func authenticate(ctx context.Context, headers interface{ Get(string) string }) (context.Context, error) {
	authHeader := headers.Get("Authorization")
	if authHeader == "" {
		return ctx, connect.NewError(connect.CodeUnauthenticated, nil)
	}
	token := strings.TrimPrefix(authHeader, "Bearer ")
	claims, err := auth.ValidateToken(token)
	if err != nil {
		return ctx, connect.NewError(connect.CodeUnauthenticated, err)
	}
	ctx = context.WithValue(ctx, UserIDKey, claims.UserID)
	ctx = context.WithValue(ctx, UserNameKey, claims.Name)
	return ctx, nil
}
