package db

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	_ "github.com/mattn/go-sqlite3"
)

type GroupDB struct {
	db *sql.DB
}

type GroupWorkoutRow struct {
	ID        string
	StartedAt time.Time
	EndedAt   *time.Time
}

type GroupParticipantRow struct {
	UserID         string
	GroupWorkoutID string
	WorkoutID      string
	JoinedAt       time.Time
	LeftAt         *time.Time
}

type ExerciseSelectionRow struct {
	UserID         string
	GroupWorkoutID string
	Exercise       int
	Ready          bool
}

func NewGroupDB(dataDir string) (*GroupDB, error) {
	dbPath := dataDir + "/group.db"
	db, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_busy_timeout=5000&_synchronous=NORMAL&_cache_size=-20000&_foreign_keys=ON")
	if err != nil {
		return nil, fmt.Errorf("open group db: %w", err)
	}
	if _, err := db.Exec(groupDBSchema); err != nil {
		return nil, fmt.Errorf("migrate group db: %w", err)
	}
	return &GroupDB{db: db}, nil
}

func (g *GroupDB) CreateGroupWorkout() (*GroupWorkoutRow, error) {
	gw := &GroupWorkoutRow{
		ID:        uuid.New().String(),
		StartedAt: time.Now(),
	}
	_, err := g.db.Exec("INSERT INTO group_workout (id, started_at) VALUES (?, ?)", gw.ID, gw.StartedAt)
	if err != nil {
		return nil, err
	}
	return gw, nil
}

func (g *GroupDB) GetGroupWorkout(id string) (*GroupWorkoutRow, error) {
	var gw GroupWorkoutRow
	err := g.db.QueryRow("SELECT id, started_at, ended_at FROM group_workout WHERE id = ?", id).Scan(&gw.ID, &gw.StartedAt, &gw.EndedAt)
	if err != nil {
		return nil, err
	}
	return &gw, nil
}

func (g *GroupDB) AddParticipant(userID, groupWorkoutID string) error {
	now := time.Now()
	_, err := g.db.Exec(
		"INSERT OR IGNORE INTO group_workout_participant (user_id, group_workout_id, joined_at) VALUES (?, ?, ?)",
		userID, groupWorkoutID, now,
	)
	return err
}

func (g *GroupDB) SetParticipantWorkout(userID, groupWorkoutID, workoutID string) error {
	_, err := g.db.Exec(
		"UPDATE group_workout_participant SET workout_id = ? WHERE user_id = ? AND group_workout_id = ?",
		workoutID, userID, groupWorkoutID,
	)
	return err
}

func (g *GroupDB) GetParticipants(groupWorkoutID string) ([]*GroupParticipantRow, error) {
	rows, err := g.db.Query(
		"SELECT user_id, group_workout_id, COALESCE(workout_id, ''), joined_at, left_at FROM group_workout_participant WHERE group_workout_id = ?",
		groupWorkoutID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var participants []*GroupParticipantRow
	for rows.Next() {
		var p GroupParticipantRow
		if err := rows.Scan(&p.UserID, &p.GroupWorkoutID, &p.WorkoutID, &p.JoinedAt, &p.LeftAt); err != nil {
			return nil, err
		}
		participants = append(participants, &p)
	}
	return participants, nil
}

func (g *GroupDB) SetExerciseSelection(userID, groupWorkoutID string, exercises []int, ready bool) error {
	tx, err := g.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec("DELETE FROM exercise_selection WHERE user_id = ? AND group_workout_id = ?", userID, groupWorkoutID)
	if err != nil {
		return err
	}

	for _, ex := range exercises {
		_, err := tx.Exec(
			"INSERT INTO exercise_selection (user_id, group_workout_id, exercise, ready) VALUES (?, ?, ?, ?)",
			userID, groupWorkoutID, ex, ready,
		)
		if err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (g *GroupDB) GetExerciseSelections(groupWorkoutID string) (map[string]*SelectionState, error) {
	rows, err := g.db.Query(
		"SELECT user_id, exercise, ready FROM exercise_selection WHERE group_workout_id = ?",
		groupWorkoutID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[string]*SelectionState)
	for rows.Next() {
		var userID string
		var exercise int
		var ready bool
		if err := rows.Scan(&userID, &exercise, &ready); err != nil {
			return nil, err
		}
		if _, ok := result[userID]; !ok {
			result[userID] = &SelectionState{Ready: ready}
		}
		result[userID].Exercises = append(result[userID].Exercises, exercise)
		result[userID].Ready = ready
	}
	return result, nil
}

type SelectionState struct {
	Exercises []int
	Ready     bool
}

func (g *GroupDB) GetActiveGroupForUser(userID string) (*GroupParticipantRow, error) {
	var p GroupParticipantRow
	err := g.db.QueryRow(
		`SELECT gp.user_id, gp.group_workout_id, COALESCE(gp.workout_id, ''), gp.joined_at, gp.left_at
		 FROM group_workout_participant gp
		 JOIN group_workout gw ON gw.id = gp.group_workout_id
		 WHERE gp.user_id = ? AND gw.ended_at IS NULL AND gp.left_at IS NULL
		 ORDER BY gp.joined_at DESC LIMIT 1`,
		userID,
	).Scan(&p.UserID, &p.GroupWorkoutID, &p.WorkoutID, &p.JoinedAt, &p.LeftAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}
