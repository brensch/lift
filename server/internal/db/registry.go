package db

import (
	"database/sql"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	_ "github.com/mattn/go-sqlite3"
)

type Registry struct {
	db *sql.DB
}

type User struct {
	ID        string
	Name      string
	CreatedAt time.Time
}

func NewRegistry(dataDir string) (*Registry, error) {
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}
	dbPath := dataDir + "/registry.db"
	db, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL")
	if err != nil {
		return nil, fmt.Errorf("open registry db: %w", err)
	}
	if _, err := db.Exec(registryDBSchema); err != nil {
		return nil, fmt.Errorf("migrate registry db: %w", err)
	}
	return &Registry{db: db}, nil
}

func (r *Registry) CreateUser(name string) (*User, error) {
	id := uuid.New().String()
	now := time.Now()
	_, err := r.db.Exec("INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)", id, name, now)
	if err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}
	return &User{ID: id, Name: name, CreatedAt: now}, nil
}

func (r *Registry) GetUserByName(name string) (*User, error) {
	var u User
	err := r.db.QueryRow("SELECT id, name, created_at FROM users WHERE name = ?", name).Scan(&u.ID, &u.Name, &u.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *Registry) GetUserByID(id string) (*User, error) {
	var u User
	err := r.db.QueryRow("SELECT id, name, created_at FROM users WHERE id = ?", id).Scan(&u.ID, &u.Name, &u.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *Registry) ListUsers() ([]*User, error) {
	rows, err := r.db.Query("SELECT id, name, created_at FROM users ORDER BY name")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var users []*User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Name, &u.CreatedAt); err != nil {
			return nil, err
		}
		users = append(users, &u)
	}
	return users, nil
}
