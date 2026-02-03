# Project Spec: Social 5x5 Workout Tracker

## 1. High-Level Concept
A minimalist, high-performance workout tracker that uses a "Local-First" feel with a cloud backend.
- **Core Loop:** Users track 5x5 powerlifting workouts (Squat, Bench, Deadlift, OHP, Row).
- **Data Model:** 1 SQLite database per user (backend-managed).
- **Protocol:** Protobufs used for FE/BE communication and data structures.
- **The "Killer Feature":** Multiplayer workouts. Users can lobby up; the system calculates an optimized joint plan, and updates all user ledgers simultaneously. users can see what their friends are doing in a workout.

## 2. Tech Stack Constraints
- **Frontend:** React + Vite + Tailwind CSS + shadcn/ui.
- **Network:** Connect-RPC (Connect-Go for BE, Connect-Web for FE). This handles Protobuf service definitions over HTTP/1.1 or HTTP/2.
- **Backend:** Go (Standard Library preferred for simple logic).
- **Database:** SQLite (mattn/go-sqlite3).
  - Architecture: `data/{username}.db`.
  - The backend maintains a map of open DB connections: `map[string]*sql.DB`.
- **Auth:** "Honor System" Auth.
  - User sends `X-Username` header.
  - Backend checks if `data/{x-username}.db` exists. If not, create it.

## 3. Data Architecture (Protobufs)
*Source of Truth: `/proto/workout/v1/workout.proto`*

### Core Objects
1.  **User**: `string username`.
2.  **Exercise**: `enum` (SQUAT, BENCH, DEADLIFT, OHP, ROW).
3.  **Set**: `float weight`, `int32 reps`, `int32 rpe`, `google.protobuf.Timestamp completed_at`.
4.  **Session**: Represents a completed workout. Contains list of `Set`s.

### Service Definition (`WorkoutService`)
- `GetNextWorkout(User)` -> Returns `Plan` (e.g., "Squat 5x5 @ 225").
- `StartLobby(HostID)` -> Returns `LobbyID`.
- `JoinLobby(LobbyID, UserID)` -> Stream updates of lobby status.
- `LogSets(Session)` -> Writes to the user's SQLite DB.

## 4. "The Algorithm" (Group Logic)
When multiple users join a lobby:
1.  Fetch `NextWorkout` for all users.
2.  **Intersection:** Find exercises everyone has in common (e.g., everyone is Squatting today).
3.  **Interleaving:** For distinct exercises (User A needs Bench, User B needs OHP), schedule them in the same time block (e.g., "Block 2: A does Bench, B does OHP").
4.  **Sync:** When User A completes a set, it broadcasts to User B's UI as "Partner completed Set 1".

## 5. Development Roadmap (Checklist)

### Phase 1: The Foundation (Solo Mode)
- [ ] **Proto Setup:** Initialize `buf` project. Define `User`, `Workout`, `Set` messages. Generate Go and TS code.
- [ ] **Backend Skeleton:** Create Go server with Connect-RPC. Implement `X-Username` interceptor.
- [ ] **DB Manager:** Implement the `GetDB(username)` function in Go that opens/creates the specific SQLite file.
- [ ] **Migration System:** Simple SQL string execution on DB creation (create tables: `sets`, `sessions`).
- [ ] **Frontend Scaffold:** Vite + React + Tailwind. Generate Connect-Web client.

### Phase 2: The 5x5 Logic
- [ ] **Ledger:** Create `LogSet` endpoint. Store sets in SQLite.
- [ ] **Progression Engine:** When a user starts a workout, figure out their progression from their last set based on time since last workout, success, etc. look up the science around this. have a page that explains the algorithm used for the progression.

### Phase 3: Multiplayer (The Differentiator)
- [ ] **Lobby State:** In-memory Go struct `Lobby { Users []string, ActivePlan Plan }`.
- [ ] **Stream:** Use Connect-RPC Server Streaming for `JoinLobby`. Push updates when a user joins.
- [ ] **Merger:** Implement the "Intersection/Interleaving" algorithm described in Section 4.
- [ ] **Multi-Write:** When the workout ends, the backend iterates through `Lobby.Users` and writes the session to *each* user's individual SQLite file.

## 6. Implementation Details
### Database Schema (SQLite)
```sql
CREATE TABLE sets (
    id TEXT PRIMARY KEY,
    exercise_type TEXT,
    weight REAL,
    reps INTEGER,
    completed_at DATETIME
);