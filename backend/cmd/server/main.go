package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"

	"connectrpc.com/connect"
	"github.com/rs/cors"

	"github.com/brensch/lift/backend/gen/workout/v1/workoutv1connect"
	"github.com/brensch/lift/backend/internal/db"
	"github.com/brensch/lift/backend/internal/interceptor"
	"github.com/brensch/lift/backend/internal/service"
)

func main() {
	// Get data path from env or use default
	dataPath := os.Getenv("DATA_PATH")
	if dataPath == "" {
		// Default to ../data relative to the binary for development
		execPath, _ := os.Executable()
		dataPath = filepath.Join(filepath.Dir(execPath), "..", "data")
		// For `go run`, use project root
		if _, err := os.Stat(dataPath); os.IsNotExist(err) {
			dataPath = "data"
		}
	}

	// Initialize database manager
	dbManager, err := db.NewManager(dataPath)
	if err != nil {
		log.Fatalf("Failed to initialize database manager: %v", err)
	}
	defer dbManager.Close()

	// Create service
	workoutService := service.NewWorkoutService(dbManager)

	// Create interceptors
	interceptors := connect.WithInterceptors(
		interceptor.UsernameInterceptor(dbManager),
	)

	// Create handler
	mux := http.NewServeMux()
	path, handler := workoutv1connect.NewWorkoutServiceHandler(
		workoutService,
		interceptors,
	)
	mux.Handle(path, handler)

	// Add CORS for frontend
	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://localhost:5173", "http://localhost:3000"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		ExposedHeaders:   []string{"*"},
		AllowCredentials: true,
	}).Handler(mux)

	// Start server
	addr := ":8080"
	if port := os.Getenv("PORT"); port != "" {
		addr = ":" + port
	}

	log.Printf("Starting server on %s", addr)
	log.Printf("Data path: %s", dataPath)

	if err := http.ListenAndServe(addr, corsHandler); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
