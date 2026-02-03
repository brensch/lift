package hub

import (
	"sync"

	workoutv1 "github.com/brensch/lift/backend/gen/workout/v1"
)

// Channel naming conventions:
// - "user:{username}" - Personal notifications (invites, invite responses)
// - "group:{groupID}" - Group activity (member joins/leaves, set activity)

// Client represents a connected user on a channel
type Client struct {
	ID   string // Unique client identifier (usually username)
	Send chan *workoutv1.WorkoutUpdate
}

// Hub manages all channel subscriptions
type Hub struct {
	mu sync.RWMutex
	// channels maps channel_id -> map of client_id -> client
	channels map[string]map[string]*Client
}

// New creates a new Hub
func New() *Hub {
	return &Hub{
		channels: make(map[string]map[string]*Client),
	}
}

// Subscribe adds a client to a channel and returns the client
// If the client already exists on this channel, closes the old connection
func (h *Hub) Subscribe(channelID, clientID string) *Client {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.channels[channelID] == nil {
		h.channels[channelID] = make(map[string]*Client)
	}

	// If client already has a connection on this channel, close it first
	if existing, ok := h.channels[channelID][clientID]; ok {
		close(existing.Send)
	}

	client := &Client{
		ID:   clientID,
		Send: make(chan *workoutv1.WorkoutUpdate, 10), // buffered channel
	}
	h.channels[channelID][clientID] = client

	return client
}

// Unsubscribe removes a client from a channel
func (h *Hub) Unsubscribe(channelID, clientID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if clients, ok := h.channels[channelID]; ok {
		if client, ok := clients[clientID]; ok {
			close(client.Send)
			delete(clients, clientID)
		}
		// Clean up empty channels
		if len(clients) == 0 {
			delete(h.channels, channelID)
		}
	}
}

// Broadcast sends an update to all clients on a channel except the excluded one
func (h *Hub) Broadcast(channelID string, update *workoutv1.WorkoutUpdate, excludeClientID string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clients, ok := h.channels[channelID]
	if !ok {
		return
	}

	for clientID, client := range clients {
		if clientID == excludeClientID {
			continue
		}
		// Non-blocking send - drop if buffer full
		select {
		case client.Send <- update:
		default:
			// Client's buffer is full, skip this update
		}
	}
}

// BroadcastToAll sends an update to ALL clients on a channel (including sender)
func (h *Hub) BroadcastToAll(channelID string, update *workoutv1.WorkoutUpdate) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clients, ok := h.channels[channelID]
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

// SendToClient sends an update to a specific client on a channel
func (h *Hub) SendToClient(channelID, clientID string, update *workoutv1.WorkoutUpdate) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clients, ok := h.channels[channelID]
	if !ok {
		return false
	}

	client, ok := clients[clientID]
	if !ok {
		return false
	}

	select {
	case client.Send <- update:
		return true
	default:
		return false
	}
}

// GetChannelClients returns all client IDs currently subscribed to a channel
func (h *Hub) GetChannelClients(channelID string) []string {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clients, ok := h.channels[channelID]
	if !ok {
		return nil
	}

	ids := make([]string, 0, len(clients))
	for clientID := range clients {
		ids = append(ids, clientID)
	}
	return ids
}

// Helper functions for channel naming
func UserChannel(username string) string {
	return "user:" + username
}

func GroupChannel(groupID string) string {
	return "group:" + groupID
}
