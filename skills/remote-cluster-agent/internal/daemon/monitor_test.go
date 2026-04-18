package daemon

import (
	"sort"
	"testing"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
)

func TestRingBuf(t *testing.T) {
	rb := newRingBuf(3)
	if rb.Len() != 0 {
		t.Fatalf("empty len=%d", rb.Len())
	}

	rb.Add(10)
	rb.Add(20)
	if rb.Len() != 2 {
		t.Fatalf("len=%d want 2", rb.Len())
	}
	if rb.Last() != 20 {
		t.Fatalf("last=%d want 20", rb.Last())
	}

	// Fill and wrap
	rb.Add(30)
	rb.Add(40) // wraps: [40, 20, 30] with pos=1
	if rb.Len() != 3 {
		t.Fatalf("len=%d want 3", rb.Len())
	}
	if rb.Last() != 40 {
		t.Fatalf("last=%d want 40", rb.Last())
	}

	s := rb.Slice()
	sort.Ints(s)
	want := []int{20, 30, 40}
	for i, v := range want {
		if s[i] != v {
			t.Fatalf("slice[%d]=%d want %d", i, s[i], v)
		}
	}
}

func TestMedian(t *testing.T) {
	tests := []struct {
		in   []int
		want int
	}{
		{nil, 0},
		{[]int{5}, 5},
		{[]int{1, 3}, 2},
		{[]int{1, 3, 5}, 3},
		{[]int{1, 2, 3, 4}, 2},
		{[]int{100, 95, 90, 105, 98}, 98},
	}
	for _, tt := range tests {
		got := median(tt.in)
		if got != tt.want {
			t.Errorf("median(%v)=%d want %d", tt.in, got, tt.want)
		}
	}
}

func TestMonitorCheckOnce(t *testing.T) {
	ap := findAgentPath(t)
	cfg := testCfg(t, ap)
	pool := NewPool(cfg)
	defer pool.CloseAll()

	// Connect a node first
	if _, err := pool.Get("local1"); err != nil {
		t.Fatal(err)
	}

	mon := NewMonitor(pool, config.MonitorConfig{
		Enabled:           true,
		Interval:          30,
		LatencyThreshold:  200,
		LatencyMultiplier: 3.0,
		AutoReconnect:     false, // don't auto-reconnect in tests
	})

	// Run a check
	mon.checkOnce()

	health := mon.GetHealth()
	if len(health) != 2 {
		t.Fatalf("health items=%d want 2", len(health))
	}

	// Find local1
	var found bool
	for _, h := range health {
		if h.Name == "local1" {
			found = true
			if h.Samples != 1 {
				t.Errorf("samples=%d want 1", h.Samples)
			}
			if h.CurrentLatency <= 0 {
				t.Errorf("latency=%d want >0", h.CurrentLatency)
			}
			// Local agent should be fast → healthy
			if h.Status != "connected" && h.Status != "healthy" {
				t.Errorf("status=%q want healthy/connected", h.Status)
			}
		}
	}
	if !found {
		t.Error("local1 not in health output")
	}
}

func TestMonitorMultipleSamples(t *testing.T) {
	ap := findAgentPath(t)
	cfg := testCfg(t, ap)
	pool := NewPool(cfg)
	defer pool.CloseAll()

	if _, err := pool.Get("local1"); err != nil {
		t.Fatal(err)
	}

	mon := NewMonitor(pool, config.MonitorConfig{
		Enabled:           true,
		Interval:          30,
		LatencyThreshold:  200,
		LatencyMultiplier: 3.0,
		AutoReconnect:     false,
	})

	// Run multiple checks to build history
	for i := 0; i < 5; i++ {
		mon.checkOnce()
	}

	health := mon.GetHealth()
	for _, h := range health {
		if h.Name == "local1" {
			if h.Samples != 5 {
				t.Errorf("samples=%d want 5", h.Samples)
			}
			if h.MedianLatency < 0 {
				t.Errorf("median=%d want >=0", h.MedianLatency)
			}
		}
	}
}
