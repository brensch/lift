package hub

import (
	"sync"

	workoutv1 "github.com/brensch/lift/backend/gen/workout/v1"
)

// Client represents a connected user watching a session
type Client struct {
	UserID string
	Send   chan *workoutv1.WorkoutUpdate
}

// Hub manages all active workout session subscriptions
type Hub struct {
	mu sync.RWMutex
	// sessions maps session_id -> map of user_id -> client
	sessions map[string]map[string]*Client
}

// New creates a new Hub
func New() *Hub {
	return &Hub{
		sessions: make(map[string]map[string]*Client),
	}
}

// Subscribe adds a client to a session and returns the client
func (h *Hub) Subscribe(sessionID, userID string) *Client {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.sessions[sessionID] == nil {
		h.sessions[sessionID] = make(map[string]*Client)
	}

	// If user already has a connection, close it first
	if existing, ok := h.sessions[sessionID][userID]; ok {
		close(existing.Send)
	}

	client := &Client{
		UserID: userID,
		Send:   make(chan *workoutv1.WorkoutUpdate, 10), // buffered channel
	}
	h.sessions[sessionID][userID] = client

	return client
}

// Unsubscribe removes a client from a session
func (h *Hub) Unsubscribe(sessionID, userID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if clients, ok := h.sessions[sessionID]; ok {
		if client, ok := clients[userID]; ok {
			close(client.Send)
			delete(clients, userID)
		}
		// Clean up empty sessions
		if len(clients) == 0 {
			delete(h.sessions, sessionID)
		}
	}
}

// Broadcast sends an update to all clients in a session except the sender
func (h *Hub) Broadcast(sessionID string, update *workoutv1.WorkoutUpdate, excludeUserID string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clients, ok := h.sessions[sessionID]
	if !ok {
		return
	}

	for userID, client := range clients {
		if userID == excludeUserID {
			continue // don't send to the user who triggered the update
		}
		// Non-blocking send - drop if buffer full
		select {
		case client.Send <- update:
		default:
			// Client's buffer is full, skip this update
		}
	}
}

// BroadcastToAll sends an update to ALL clients in a session (including sender)
func (h *Hub) BroadcastToAll(sessionID string, update *workoutv1.WorkoutUpdate) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clients, ok := h.sessions[sessionID]
	if !ok {
		return
	}

	for _, client := range clients {
		select {
		case client.Send <- update:
		default:
		}
	}
}

// GetSessionUsers returns all user IDs currently watching a session
func (h *Hub) GetSessionUsers(sessionID string) []string {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clients, ok := h.sessions[sessionID]
	if !ok {
		return nil
	}

	users := make([]string, 0, len(clients))
	for userID := range clients {
		users = append(users, userID)
	}
	return users
}
