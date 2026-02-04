package hub

import (
	"sync"
)

type Hub struct {
	mu          sync.RWMutex
	subscribers map[string]map[chan struct{}]struct{}
}

func New() *Hub {
	return &Hub{
		subscribers: make(map[string]map[chan struct{}]struct{}),
	}
}

func (h *Hub) Subscribe(channel string) chan struct{} {
	h.mu.Lock()
	defer h.mu.Unlock()

	ch := make(chan struct{}, 1)
	if _, ok := h.subscribers[channel]; !ok {
		h.subscribers[channel] = make(map[chan struct{}]struct{})
	}
	h.subscribers[channel][ch] = struct{}{}
	return ch
}

func (h *Hub) Unsubscribe(channel string, ch chan struct{}) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if subs, ok := h.subscribers[channel]; ok {
		delete(subs, ch)
		if len(subs) == 0 {
			delete(h.subscribers, channel)
		}
	}
}

func (h *Hub) Publish(channel string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if subs, ok := h.subscribers[channel]; ok {
		for ch := range subs {
			select {
			case ch <- struct{}{}:
			default:
			}
		}
	}
}
