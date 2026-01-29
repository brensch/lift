package db

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	_ "github.com/mattn/go-sqlite3"
)

// GroupManager handles group session SQLite database connections
// Each group workout session gets its own database file
type GroupManager struct {
	mu       sync.RWMutex
	dbs      map[string]*sql.DB
	dataPath string
}

// NewGroupManager creates a new group database manager
func NewGroupManager(dataPath string) (*GroupManager, error) {
	groupPath := filepath.Join(dataPath, "groups")
	if err := os.MkdirAll(groupPath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create groups directory: %w", err)
	}

	return &GroupManager{
		dbs:      make(map[string]*sql.DB),
		dataPath: groupPath,
	}, nil
}

// CreateSession creates a new group session database and returns its ID
func (m *GroupManager) CreateSession(sessionID string) (*sql.DB, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Create the database file with WAL mode
	dbPath := filepath.Join(m.dataPath, sessionID+".db")
	dsn := fmt.Sprintf("%s?_journal_mode=WAL&_busy_timeout=100&_synchronous=NORMAL", dbPath)
	db, err := sql.Open("sqlite3", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to create group session database: %w", err)
	}

	// Run schema
	if err := m.migrate(db); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to run group schema: %w", err)
	}

	m.dbs[sessionID] = db
	return db, nil
}

// GetSession returns a database connection for an existing group session
func (m *GroupManager) GetSession(sessionID string) (*sql.DB, error) {
	m.mu.RLock()
	db, exists := m.dbs[sessionID]
	m.mu.RUnlock()

	if exists {
		return db, nil
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	// Double-check after acquiring write lock
	if db, exists = m.dbs[sessionID]; exists {
		return db, nil
	}

	// Open existing database with WAL mode
	dbPath := filepath.Join(m.dataPath, sessionID+".db")
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("group session %s does not exist", sessionID)
	}

	dsn := fmt.Sprintf("%s?_journal_mode=WAL&_busy_timeout=100&_synchronous=NORMAL", dbPath)
	db, err := sql.Open("sqlite3", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open group session database: %w", err)
	}

	m.dbs[sessionID] = db
	return db, nil
}

// SessionExists checks if a group session database exists
func (m *GroupManager) SessionExists(sessionID string) bool {
	dbPath := filepath.Join(m.dataPath, sessionID+".db")
	_, err := os.Stat(dbPath)
	return err == nil
}

// migrate creates the schema for a group session database
func (m *GroupManager) migrate(db *sql.DB) error {
	schema := `
-- Group session metadata
CREATE TABLE IF NOT EXISTS session_info (
    id TEXT PRIMARY KEY,
    created_by TEXT NOT NULL,
    created_at DATETIME NOT NULL,
    status TEXT DEFAULT 'planning'  -- planning, active, completed
);

-- Members of this group session
CREATE TABLE IF NOT EXISTS members (
    user_id TEXT PRIMARY KEY,
    joined_at DATETIME NOT NULL,
    status TEXT DEFAULT 'planning',  -- planning, ready
    is_connected BOOLEAN DEFAULT 0
);

-- Exercise order for the group (agreed upon)
CREATE TABLE IF NOT EXISTS group_exercises (
    exercise TEXT PRIMARY KEY,
    position INTEGER NOT NULL
);

-- Each user's plan for each exercise
CREATE TABLE IF NOT EXISTS user_plans (
    user_id TEXT NOT NULL,
    exercise TEXT NOT NULL,
    target_weight REAL NOT NULL,
    target_sets INTEGER DEFAULT 5,
    target_reps INTEGER DEFAULT 5,
    PRIMARY KEY (user_id, exercise)
);

-- Real-time activity log for the session
CREATE TABLE IF NOT EXISTS activity_log (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL,  -- set_started, set_completed, rest_started, rest_ended
    exercise TEXT,
    set_number INTEGER,
    weight REAL,
    target_reps INTEGER,
    actual_reps INTEGER,
    planned_rest_seconds INTEGER,
    started_at DATETIME NOT NULL,
    ended_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_activity_user ON activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_time ON activity_log(started_at);
`
	_, err := db.Exec(schema)
	return err
}

// Close closes all group session database connections
func (m *GroupManager) Close() error {
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
