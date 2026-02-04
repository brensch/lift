package db

const userDBSchema = `
CREATE TABLE IF NOT EXISTS workout (
	id TEXT PRIMARY KEY,
	start_time DATETIME NOT NULL,
	end_time DATETIME
);

CREATE TABLE IF NOT EXISTS proposed_set (
	id TEXT PRIMARY KEY,
	workout_id TEXT NOT NULL,
	workout_order INTEGER NOT NULL,
	exercise INTEGER NOT NULL,
	target_reps INTEGER NOT NULL DEFAULT 0,
	target_weight REAL NOT NULL DEFAULT 0,
	warmup BOOLEAN NOT NULL DEFAULT 0,
	FOREIGN KEY (workout_id) REFERENCES workout(id)
);

CREATE TABLE IF NOT EXISTS completed_set (
	id TEXT PRIMARY KEY,
	workout_id TEXT NOT NULL,
	proposed_set_id TEXT NOT NULL,
	actual_reps INTEGER NOT NULL DEFAULT 0,
	actual_weight REAL NOT NULL DEFAULT 0,
	started_at DATETIME,
	ended_at DATETIME,
	rest_until DATETIME,
	FOREIGN KEY (workout_id) REFERENCES workout(id),
	FOREIGN KEY (proposed_set_id) REFERENCES proposed_set(id)
);
`

const registryDBSchema = `
CREATE TABLE IF NOT EXISTS users (
	id TEXT PRIMARY KEY,
	name TEXT UNIQUE NOT NULL,
	created_at DATETIME NOT NULL
);
`

const groupDBSchema = `
CREATE TABLE IF NOT EXISTS group_workout (
	id TEXT PRIMARY KEY,
	started_at DATETIME NOT NULL,
	ended_at DATETIME
);

CREATE TABLE IF NOT EXISTS group_workout_participant (
	user_id TEXT NOT NULL,
	group_workout_id TEXT NOT NULL,
	workout_id TEXT,
	joined_at DATETIME NOT NULL,
	left_at DATETIME,
	PRIMARY KEY (user_id, group_workout_id),
	FOREIGN KEY (group_workout_id) REFERENCES group_workout(id)
);

CREATE TABLE IF NOT EXISTS exercise_selection (
	user_id TEXT NOT NULL,
	group_workout_id TEXT NOT NULL,
	exercise INTEGER NOT NULL,
	ready BOOLEAN NOT NULL DEFAULT 0,
	PRIMARY KEY (user_id, group_workout_id, exercise),
	FOREIGN KEY (group_workout_id) REFERENCES group_workout(id)
);
`
