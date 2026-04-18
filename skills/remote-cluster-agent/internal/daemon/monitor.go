package daemon

import (
	"context"
	"log"
	"sort"
	"sync"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
)

// Monitor runs periodic health checks on connected nodes, tracks latency
// history, detects degradation, and optionally auto-reconnects.
type Monitor struct {
	pool *Pool
	cfg  config.MonitorConfig

	mu      sync.Mutex
	history map[string]*ringBuf // node name → latency samples
	status  map[string]*nodeHealthState
}

type nodeHealthState struct {
	Status        string    // "healthy", "degraded", "reconnecting"
	LastReconnect time.Time
}

// ringBuf is a fixed-size circular buffer of int (latency in ms).
type ringBuf struct {
	data []int
	pos  int
	full bool
}

func newRingBuf(size int) *ringBuf {
	return &ringBuf{data: make([]int, size)}
}

func (r *ringBuf) Add(v int) {
	r.data[r.pos] = v
	r.pos++
	if r.pos >= len(r.data) {
		r.pos = 0
		r.full = true
	}
}

func (r *ringBuf) Len() int {
	if r.full {
		return len(r.data)
	}
	return r.pos
}

func (r *ringBuf) Slice() []int {
	n := r.Len()
	out := make([]int, n)
	if r.full {
		copy(out, r.data[r.pos:])
		copy(out[len(r.data)-r.pos:], r.data[:r.pos])
	} else {
		copy(out, r.data[:r.pos])
	}
	return out
}

func (r *ringBuf) Last() int {
	if r.Len() == 0 {
		return 0
	}
	idx := r.pos - 1
	if idx < 0 {
		idx = len(r.data) - 1
	}
	return r.data[idx]
}

func median(vals []int) int {
	if len(vals) == 0 {
		return 0
	}
	sorted := make([]int, len(vals))
	copy(sorted, vals)
	sort.Ints(sorted)
	mid := len(sorted) / 2
	if len(sorted)%2 == 0 {
		return (sorted[mid-1] + sorted[mid]) / 2
	}
	return sorted[mid]
}

func NewMonitor(pool *Pool, cfg config.MonitorConfig) *Monitor {
	return &Monitor{
		pool:    pool,
		cfg:     cfg,
		history: make(map[string]*ringBuf),
		status:  make(map[string]*nodeHealthState),
	}
}

const ringBufSize = 60 // ~30 minutes at 30s interval

// Start runs the monitoring loop. Blocks until ctx is cancelled.
func (m *Monitor) Start(ctx context.Context) {
	if !m.cfg.Enabled {
		return
	}
	ticker := time.NewTicker(time.Duration(m.cfg.Interval) * time.Second)
	defer ticker.Stop()

	// Run one check immediately on start.
	m.checkOnce()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			m.checkOnce()
		}
	}
}

func (m *Monitor) checkOnce() {
	infos := m.pool.Check(3 * time.Second)

	m.mu.Lock()
	defer m.mu.Unlock()

	for _, info := range infos {
		if info.Status != "connected" {
			continue
		}
		// Ensure ring buffer exists.
		if _, ok := m.history[info.Name]; !ok {
			m.history[info.Name] = newRingBuf(ringBufSize)
		}
		if _, ok := m.status[info.Name]; !ok {
			m.status[info.Name] = &nodeHealthState{Status: "healthy"}
		}

		rb := m.history[info.Name]
		st := m.status[info.Name]
		rb.Add(info.Latency)

		// Anomaly detection: current > absolute threshold AND current > median × multiplier
		med := median(rb.Slice())
		threshold := int(float64(med) * m.cfg.LatencyMultiplier)
		if threshold < m.cfg.LatencyThreshold {
			threshold = m.cfg.LatencyThreshold
		}

		if info.Latency > threshold && rb.Len() >= 3 {
			st.Status = "degraded"
			log.Printf("[monitor] %s degraded: latency=%dms median=%dms threshold=%dms",
				info.Name, info.Latency, med, threshold)

			if m.cfg.AutoReconnect {
				st.Status = "reconnecting"
				go m.reconnect(info.Name)
			}
		} else {
			st.Status = "healthy"
		}
	}
}

func (m *Monitor) reconnect(node string) {
	log.Printf("[monitor] auto-reconnecting %s", node)
	m.pool.Disconnect(node)
	_, err := m.pool.Connect(node)

	m.mu.Lock()
	defer m.mu.Unlock()

	st := m.status[node]
	if st == nil {
		st = &nodeHealthState{}
		m.status[node] = st
	}
	st.LastReconnect = time.Now()

	if err != nil {
		st.Status = "dead"
		log.Printf("[monitor] reconnect %s failed: %v", node, err)
	} else {
		st.Status = "healthy"
		// Reset history after reconnect so old degraded samples don't linger.
		m.history[node] = newRingBuf(ringBufSize)
		log.Printf("[monitor] reconnect %s succeeded", node)
	}
}

// GetHealth returns the current health state of all nodes.
func (m *Monitor) GetHealth() []protocol.NodeHealth {
	m.mu.Lock()
	defer m.mu.Unlock()

	infos := m.pool.ListStatus()
	out := make([]protocol.NodeHealth, 0, len(infos))
	for _, info := range infos {
		h := protocol.NodeHealth{
			Name:   info.Name,
			Status: info.Status, // default to connection status
		}
		if rb, ok := m.history[info.Name]; ok && rb.Len() > 0 {
			h.CurrentLatency = rb.Last()
			h.MedianLatency = median(rb.Slice())
			h.Samples = rb.Len()
		}
		if st, ok := m.status[info.Name]; ok {
			if st.Status == "degraded" || st.Status == "reconnecting" {
				h.Status = st.Status
			}
			if !st.LastReconnect.IsZero() {
				t := st.LastReconnect
				h.LastReconnect = &t
			}
		}
		out = append(out, h)
	}
	return out
}
