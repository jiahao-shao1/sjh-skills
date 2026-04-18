package daemon

import (
	"testing"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/agent"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
)

// Test pool uses local agent (empty SSH cmd).
func testCfg(t *testing.T, agentPath string) *config.Config {
	t.Helper()
	return &config.Config{
		AgentPath: agentPath,
		SSH: config.SSHConfig{
			AliveInterval: 30, AliveCountMax: 3, MaxRetries: 3, RetryBackoff: []int{1, 2, 4},
		},
		Nodes: map[string]config.NodeConfig{
			"local1": {SSH: ""}, // empty → local python3 agent.py
			"local2": {SSH: ""},
		},
	}
}

func TestPoolLazyConnect(t *testing.T) {
	ap := findAgentPath(t)
	p := NewPool(testCfg(t, ap))
	defer p.CloseAll()
	if p.Count() != 0 {
		t.Fatalf("initial count=%d", p.Count())
	}
	// First call creates connection
	c, err := p.Get("local1")
	if err != nil {
		t.Fatal(err)
	}
	if c == nil || !c.Connected() {
		t.Fatal("not connected")
	}
	if p.Count() != 1 {
		t.Fatalf("count=%d", p.Count())
	}
	// Second call reuses
	c2, err := p.Get("local1")
	if err != nil {
		t.Fatal(err)
	}
	if c != c2 {
		t.Fatal("pool did not reuse connection")
	}
	if p.Count() != 1 {
		t.Fatalf("count=%d", p.Count())
	}
}

func TestPoolUnknownNode(t *testing.T) {
	ap := findAgentPath(t)
	p := NewPool(testCfg(t, ap))
	defer p.CloseAll()
	_, err := p.Get("does-not-exist")
	if err == nil {
		t.Fatal("expected error for unknown node")
	}
}

func TestPoolDisconnect(t *testing.T) {
	ap := findAgentPath(t)
	p := NewPool(testCfg(t, ap))
	defer p.CloseAll()
	if _, err := p.Get("local1"); err != nil {
		t.Fatal(err)
	}
	p.Disconnect("local1")
	if p.Count() != 0 {
		t.Fatalf("count=%d after disconnect", p.Count())
	}
}

func TestPoolListStatus(t *testing.T) {
	ap := findAgentPath(t)
	p := NewPool(testCfg(t, ap))
	defer p.CloseAll()
	if _, err := p.Get("local1"); err != nil {
		t.Fatal(err)
	}
	// Let the agent stabilize
	time.Sleep(50 * time.Millisecond)
	infos := p.ListStatus()
	if len(infos) != 2 {
		t.Fatalf("infos=%d want 2", len(infos))
	}
	var got1, got2 string
	for _, i := range infos {
		if i.Name == "local1" {
			got1 = i.Status
		}
		if i.Name == "local2" {
			got2 = i.Status
		}
	}
	if got1 != "connected" {
		t.Errorf("local1 status=%q", got1)
	}
	if got2 != "disconnected" {
		t.Errorf("local2 status=%q", got2)
	}
}

// Find cluster-agent/agent.py for tests.
func findAgentPath(t *testing.T) string {
	t.Helper()
	for _, p := range []string{
		"../../cluster-agent/agent.py",
		"../../../cluster-agent/agent.py",
	} {
		c := agent.Connection{CmdArgs: []string{"python3", p}}
		if err := c.Connect(3 * time.Second); err == nil {
			c.Close()
			return p
		}
	}
	t.Fatal("cannot locate cluster-agent/agent.py")
	return ""
}
