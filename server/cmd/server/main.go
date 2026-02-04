package main

import (
	"log"
	"net/http"
	"os"

	"connectrpc.com/connect"
	"github.com/brensch/lift/server/gen/lift/v1/liftv1connect"
	"github.com/brensch/lift/server/internal/db"
	"github.com/brensch/lift/server/internal/hub"
	"github.com/brensch/lift/server/internal/interceptor"
	"github.com/brensch/lift/server/internal/service"
	"github.com/rs/cors"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

func main() {
	dataDir := "data"
	if d := os.Getenv("DATA_DIR"); d != "" {
		dataDir = d
	}
	addr := ":8080"
	if a := os.Getenv("ADDR"); a != "" {
		addr = a
	}

	registry, err := db.NewRegistry(dataDir)
	if err != nil {
		log.Fatalf("failed to init registry: %v", err)
	}

	groupDB, err := db.NewGroupDB(dataDir)
	if err != nil {
		log.Fatalf("failed to init group db: %v", err)
	}

	userDBs := db.NewUserDBManager(dataDir)
	pubsub := hub.New()

	authService := service.NewAuthService(registry, userDBs)
	workoutService := service.NewWorkoutService(userDBs, pubsub)
	groupService := service.NewGroupService(registry, groupDB, userDBs, pubsub)

	opts := connect.WithInterceptors(interceptor.NewAuthInterceptor())

	mux := http.NewServeMux()

	authPath, authHandler := liftv1connect.NewAuthServiceHandler(authService, opts)
	mux.Handle(authPath, authHandler)

	workoutPath, workoutHandler := liftv1connect.NewWorkoutServiceHandler(workoutService, opts)
	mux.Handle(workoutPath, workoutHandler)

	groupPath, groupHandler := liftv1connect.NewGroupServiceHandler(groupService, opts)
	mux.Handle(groupPath, groupHandler)

	corsHandler := cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{
			http.MethodGet,
			http.MethodPost,
			http.MethodOptions,
		},
		AllowedHeaders: []string{
			"Accept",
			"Authorization",
			"Connect-Protocol-Version",
			"Connect-Timeout-Ms",
			"Content-Type",
			"Grpc-Timeout",
			"X-Grpc-Web",
			"X-User-Agent",
		},
		ExposedHeaders: []string{
			"Grpc-Status",
			"Grpc-Message",
			"Grpc-Status-Details-Bin",
		},
	}).Handler(mux)

	log.Printf("Server starting on %s", addr)
	if err := http.ListenAndServe(addr, h2c.NewHandler(corsHandler, &http2.Server{})); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
