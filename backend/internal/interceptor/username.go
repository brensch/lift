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

// usernameInterceptor implements connect.Interceptor for both unary and streaming
type usernameInterceptor struct {
	dbManager *db.Manager
}

// NewUsernameInterceptor creates an interceptor that extracts the X-Username header
func NewUsernameInterceptor(dbManager *db.Manager) connect.Interceptor {
	return &usernameInterceptor{dbManager: dbManager}
}

func (i *usernameInterceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		username := req.Header().Get("X-Username")
		if username == "" {
			return nil, connect.NewError(connect.CodeUnauthenticated, ErrNoUsername)
		}

		// Ensure the user's database exists (creates it if not)
		_, err := i.dbManager.GetDB(username)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}

		// Add username to context
		ctx = context.WithValue(ctx, UsernameKey{}, username)
		return next(ctx, req)
	}
}

func (i *usernameInterceptor) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	// Client-side streaming - not used on server, just pass through
	return next
}

func (i *usernameInterceptor) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		username := conn.RequestHeader().Get("X-Username")
		if username == "" {
			return connect.NewError(connect.CodeUnauthenticated, ErrNoUsername)
		}

		// Ensure the user's database exists (creates it if not)
		_, err := i.dbManager.GetDB(username)
		if err != nil {
			return connect.NewError(connect.CodeInternal, err)
		}

		// Add username to context
		ctx = context.WithValue(ctx, UsernameKey{}, username)
		return next(ctx, conn)
	}
}

// GetUsername extracts the username from context
func GetUsername(ctx context.Context) (string, bool) {
	username, ok := ctx.Value(UsernameKey{}).(string)
	return username, ok
}

// Legacy: UsernameInterceptor for backwards compatibility (unary only)
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
