package interceptor

import (
	"context"
	"errors"

	"connectrpc.com/connect"
	"github.com/brensch/lift/backend/internal/db"
)

// UsernameKey is the context key for storing the username
type UsernameKey struct{}

// ErrNoUsername is returned when the X-Username header is missing
var ErrNoUsername = errors.New("X-Username header is required")

// UsernameInterceptor extracts the X-Username header and adds it to the context
func UsernameInterceptor(dbManager *db.Manager) connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			username := req.Header().Get("X-Username")
			if username == "" {
				return nil, connect.NewError(connect.CodeUnauthenticated, ErrNoUsername)
			}

			// Ensure the user's database exists (creates it if not)
			_, err := dbManager.GetDB(username)
			if err != nil {
				return nil, connect.NewError(connect.CodeInternal, err)
			}

			// Add username to context
			ctx = context.WithValue(ctx, UsernameKey{}, username)
			return next(ctx, req)
		}
	}
}

// GetUsername extracts the username from context
func GetUsername(ctx context.Context) (string, bool) {
	username, ok := ctx.Value(UsernameKey{}).(string)
	return username, ok
}
