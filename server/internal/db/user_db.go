package db

import (
	"database/sql"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/google/uuid"
	_ "github.com/mattn/go-sqlite3"
)

type UserDBManager struct {
	dataDir string
	mu      sync.Mutex
	dbs     map[string]*sql.DB
}

func NewUserDBManager(dataDir string) *UserDBManager {
	usersDir := dataDir + "/users"
	os.MkdirAll(usersDir, 0755)
	return &UserDBManager{
		dataDir: usersDir,
		dbs:     make(map[string]*sql.DB),
	}
}

func (m *UserDBManager) GetDB(userID string) (*sql.DB, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if db, ok := m.dbs[userID]; ok {
		return db, nil
	}

	dbPath := fmt.Sprintf("%s/%s.db", m.dataDir, userID)
	db, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL")
	if err != nil {
		return nil, fmt.Errorf("open user db: %w", err)
	}
	if _, err := db.Exec(userDBSchema); err != nil {
		return nil, fmt.Errorf("migrate user db: %w", err)
	}
	m.dbs[userID] = db
	return db, nil
}

type WorkoutRow struct {
	ID        string
	StartTime time.Time
	EndTime   *time.Time
}

type ProposedSetRow struct {
	ID           string
	WorkoutID    string
	WorkoutOrder int
	Exercise     int
	TargetReps   int
	TargetWeight float64
	Warmup       bool
}

type CompletedSetRow struct {
	ID            string
	WorkoutID     string
	ProposedSetID string
	ActualReps    int
	ActualWeight  float64
	StartedAt     *time.Time
	EndedAt       *time.Time
	RestUntil     *time.Time
}

func CreateWorkout(db *sql.DB) (*WorkoutRow, error) {
	w := &WorkoutRow{
		ID:        uuid.New().String(),
		StartTime: time.Now(),
	}
	_, err := db.Exec("INSERT INTO workout (id, start_time) VALUES (?, ?)", w.ID, w.StartTime)
	if err != nil {
		return nil, err
	}
	return w, nil
}

func GetWorkout(db *sql.DB, workoutID string) (*WorkoutRow, error) {
	var w WorkoutRow
	err := db.QueryRow("SELECT id, start_time, end_time FROM workout WHERE id = ?", workoutID).Scan(&w.ID, &w.StartTime, &w.EndTime)
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func EndWorkout(db *sql.DB, workoutID string) error {
	now := time.Now()
	_, err := db.Exec("UPDATE workout SET end_time = ? WHERE id = ?", now, workoutID)
	return err
}

func ListWorkouts(db *sql.DB) ([]*WorkoutRow, error) {
	rows, err := db.Query("SELECT id, start_time, end_time FROM workout ORDER BY start_time DESC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var workouts []*WorkoutRow
	for rows.Next() {
		var w WorkoutRow
		if err := rows.Scan(&w.ID, &w.StartTime, &w.EndTime); err != nil {
			return nil, err
		}
		workouts = append(workouts, &w)
	}
	return workouts, nil
}

func ReplaceProposedSets(db *sql.DB, workoutID string, sets []*ProposedSetRow) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec("DELETE FROM proposed_set WHERE workout_id = ?", workoutID)
	if err != nil {
		return err
	}

	for _, s := range sets {
		if s.ID == "" {
			s.ID = uuid.New().String()
		}
		_, err := tx.Exec(
			"INSERT INTO proposed_set (id, workout_id, workout_order, exercise, target_reps, target_weight, warmup) VALUES (?, ?, ?, ?, ?, ?, ?)",
			s.ID, workoutID, s.WorkoutOrder, s.Exercise, s.TargetReps, s.TargetWeight, s.Warmup,
		)
		if err != nil {
			return err
		}
	}
	return tx.Commit()
}

func GetProposedSets(db *sql.DB, workoutID string) ([]*ProposedSetRow, error) {
	rows, err := db.Query("SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup FROM proposed_set WHERE workout_id = ? ORDER BY workout_order", workoutID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var sets []*ProposedSetRow
	for rows.Next() {
		var s ProposedSetRow
		if err := rows.Scan(&s.ID, &s.WorkoutID, &s.WorkoutOrder, &s.Exercise, &s.TargetReps, &s.TargetWeight, &s.Warmup); err != nil {
			return nil, err
		}
		sets = append(sets, &s)
	}
	return sets, nil
}

func StartSet(db *sql.DB, workoutID, proposedSetID string) (*CompletedSetRow, error) {
	now := time.Now()
	c := &CompletedSetRow{
		ID:            uuid.New().String(),
		WorkoutID:     workoutID,
		ProposedSetID: proposedSetID,
		StartedAt:     &now,
	}
	_, err := db.Exec(
		"INSERT INTO completed_set (id, workout_id, proposed_set_id, started_at) VALUES (?, ?, ?, ?)",
		c.ID, c.WorkoutID, c.ProposedSetID, c.StartedAt,
	)
	if err != nil {
		return nil, err
	}
	return c, nil
}

func CompleteSet(db *sql.DB, workoutID, proposedSetID string, actualReps int, actualWeight float64, restSeconds int) error {
	now := time.Now()
	restUntil := now.Add(time.Duration(restSeconds) * time.Second)
	_, err := db.Exec(
		"UPDATE completed_set SET actual_reps = ?, actual_weight = ?, ended_at = ?, rest_until = ? WHERE workout_id = ? AND proposed_set_id = ? AND ended_at IS NULL",
		actualReps, actualWeight, now, restUntil, workoutID, proposedSetID,
	)
	return err
}

func GetCompletedSets(db *sql.DB, workoutID string) ([]*CompletedSetRow, error) {
	rows, err := db.Query("SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until FROM completed_set WHERE workout_id = ? ORDER BY started_at", workoutID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var sets []*CompletedSetRow
	for rows.Next() {
		var s CompletedSetRow
		if err := rows.Scan(&s.ID, &s.WorkoutID, &s.ProposedSetID, &s.ActualReps, &s.ActualWeight, &s.StartedAt, &s.EndedAt, &s.RestUntil); err != nil {
			return nil, err
		}
		sets = append(sets, &s)
	}
	return sets, nil
}
