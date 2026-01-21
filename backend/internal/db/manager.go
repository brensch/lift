package db

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	_ "github.com/mattn/go-sqlite3"
)

// Manager handles per-user SQLite database connections
type Manager struct {
	mu       sync.RWMutex
	dbs      map[string]*sql.DB
	dataPath string
}

// NewManager creates a new database manager
func NewManager(dataPath string) (*Manager, error) {
	// Ensure data directory exists
	if err := os.MkdirAll(dataPath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %w", err)
	}

	return &Manager{
		dbs:      make(map[string]*sql.DB),
		dataPath: dataPath,
	}, nil
}

// GetDB returns a database connection for the given user, creating it if needed
func (m *Manager) GetDB(username string) (*sql.DB, error) {
	// Check if we already have a connection
	m.mu.RLock()
	db, exists := m.dbs[username]
	m.mu.RUnlock()

	if exists {
		return db, nil
	}

	// Need to create the connection
	m.mu.Lock()
	defer m.mu.Unlock()

	// Double-check after acquiring write lock
	if db, exists = m.dbs[username]; exists {
		return db, nil
	}

	// Create or open the database
	dbPath := filepath.Join(m.dataPath, username+".db")
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database for user %s: %w", username, err)
	}

	// Run migrations
	if err := m.migrate(db); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to run migrations for user %s: %w", username, err)
	}

	m.dbs[username] = db
	return db, nil
}

// migrate runs the initial schema setup
func (m *Manager) migrate(db *sql.DB) error {
	schema := `
CREATE TABLE IF NOT EXISTS sessions (
id TEXT PRIMARY KEY,
started_at DATETIME NOT NULL,
completed_at DATETIME,
workout_type TEXT DEFAULT 'A'
);

CREATE TABLE IF NOT EXISTS planned_sets (
id TEXT PRIMARY KEY,
session_id TEXT NOT NULL,
exercise TEXT NOT NULL,
set_number INTEGER NOT NULL,
target_weight REAL NOT NULL,
target_reps INTEGER NOT NULL,
FOREIGN KEY (session_id) REFERENCES sessions(id),
UNIQUE(session_id, exercise, set_number)
);

CREATE INDEX IF NOT EXISTS idx_planned_sets_session ON planned_sets(session_id);

CREATE TABLE IF NOT EXISTS activities (
id TEXT PRIMARY KEY,
session_id TEXT NOT NULL,
type TEXT NOT NULL,
started_at DATETIME NOT NULL,
ended_at DATETIME,
exercise TEXT,
set_number INTEGER,
weight REAL,
target_reps INTEGER,
actual_reps INTEGER,
planned_duration_seconds INTEGER,
FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_activities_session ON activities(session_id);
CREATE INDEX IF NOT EXISTS idx_activities_started ON activities(started_at);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(type);

-- Legacy sets table for backwards compatibility
CREATE TABLE IF NOT EXISTS sets (
id TEXT PRIMARY KEY,
session_id TEXT,
exercise_type TEXT NOT NULL,
weight REAL NOT NULL,
reps INTEGER NOT NULL,
rpe INTEGER,
completed_at DATETIME,
FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_sets_exercise ON sets(exercise_type);
CREATE INDEX IF NOT EXISTS idx_sets_session ON sets(session_id);
CREATE INDEX IF NOT EXISTS idx_sets_completed ON sets(completed_at);
`

	_, err := db.Exec(schema)
	if err != nil {
		return err
	}

	// Migration: Add workout_type column to existing sessions table if it doesn't exist
	// SQLite doesn't support IF NOT EXISTS for columns, so we try and ignore errors
	db.Exec(`ALTER TABLE sessions ADD COLUMN workout_type TEXT DEFAULT 'A'`)
	
	// Migration: Add exercise_order column to sessions table for custom exercise ordering
	db.Exec(`ALTER TABLE sessions ADD COLUMN exercise_order TEXT DEFAULT ''`)

	return nil
}

// Close closes all database connections
func (m *Manager) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	var lastErr error
	for _, db := range m.dbs {
		if err := db.Close(); err != nil {
			lastErr = err
		}
	}
	m.dbs = make(map[string]*sql.DB)
	return lastErr
}
