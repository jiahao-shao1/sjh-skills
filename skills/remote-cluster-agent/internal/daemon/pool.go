package daemon

import (
	"fmt"
	"sync"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/agent"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
)

// Pool manages per-node AgentConnection lifecycle.
// Connections are created lazily on first Get() and reused.
type Pool struct {
	cfg *config.Config

	mu    sync.Mutex
	conns map[string]*agent.Connection
	dead  map[string]bool // nodes marked dead after max retries
}

func NewPool(cfg *config.Config) *Pool {
	return &Pool{
		cfg:   cfg,
		conns: map[string]*agent.Connection{},
		dead:  map[string]bool{},
	}
}

// Get returns a connected agent.Connection for the node. Creates on first call.
// Returns error if node unknown, marked dead, or connect fails after retries.
func (p *Pool) Get(node string) (*agent.Connection, error) {
	nc, ok := p.cfg.Nodes[node]
	if !ok {
		return nil, fmt.Errorf("unknown node %q (check config)", node)
	}

	p.mu.Lock()
	if p.dead[node] {
		p.mu.Unlock()
		return nil, fmt.Errorf("node %q marked dead; run: rca connect %s", node, node)
	}
	if c, ok := p.conns[node]; ok {
		if c.Connected() {
			p.mu.Unlock()
			return c, nil
		}
		delete(p.conns, node)
	}
	p.mu.Unlock()

	// Dial outside the lock (can take seconds).
	c, err := p.dial(node, nc)
	if err != nil {
		return nil, err
	}

	p.mu.Lock()
	// Race guard: another goroutine may have set it.
	if existing, ok := p.conns[node]; ok && existing.Connected() {
		c.Close()
		p.mu.Unlock()
		return existing, nil
	}
	p.conns[node] = c
	p.mu.Unlock()
	return c, nil
}

func (p *Pool) dial(node string, nc config.NodeConfig) (*agent.Connection, error) {
	var lastErr error
	backoff := p.cfg.SSH.RetryBackoff
	for attempt := 0; attempt < p.cfg.SSH.MaxRetries; attempt++ {
		args := agent.BuildSSHCmd(nc.SSH, nc.EffectiveAgentPath(p.cfg.AgentPath), p.cfg.SSH.AliveInterval, p.cfg.SSH.AliveCountMax)
		c := &agent.Connection{CmdArgs: args}
		if err := c.Connect(15 * time.Second); err == nil {
			return c, nil
		} else {
			lastErr = err
		}
		if attempt < len(backoff) {
			time.Sleep(time.Duration(backoff[attempt]) * time.Second)
		}
	}
	// Mark dead after exhausting retries.
	p.mu.Lock()
	p.dead[node] = true
	p.mu.Unlock()
	return nil, fmt.Errorf("connect %s failed after %d attempts: %w", node, p.cfg.SSH.MaxRetries, lastErr)
}

// Disconnect forcibly closes and removes a node's connection. Clears dead flag.
func (p *Pool) Disconnect(node string) {
	p.mu.Lock()
	c := p.conns[node]
	delete(p.conns, node)
	delete(p.dead, node)
	p.mu.Unlock()
	if c != nil {
		c.Close()
	}
}

// Connect is a manual alias for Get that clears the dead flag first.
func (p *Pool) Connect(node string) (*agent.Connection, error) {
	p.mu.Lock()
	delete(p.dead, node)
	p.mu.Unlock()
	return p.Get(node)
}

func (p *Pool) Count() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := 0
	for _, c := range p.conns {
		if c.Connected() {
			n++
		}
	}
	return n
}

// ListStatus returns one NodeInfo per configured node in deterministic order.
func (p *Pool) ListStatus() []protocol.NodeInfo {
	p.mu.Lock()
	defer p.mu.Unlock()
	names := make([]string, 0, len(p.cfg.Nodes))
	for n := range p.cfg.Nodes {
		names = append(names, n)
	}
	// simple sort
	sortStrings(names)
	out := make([]protocol.NodeInfo, 0, len(names))
	for _, n := range names {
		info := protocol.NodeInfo{Name: n, Status: "disconnected"}
		if p.dead[n] {
			info.Status = "dead"
		}
		if c, ok := p.conns[n]; ok && c.Connected() {
			info.Status = "connected"
			info.Agent = c.Version()
		}
		out = append(out, info)
	}
	return out
}

func (p *Pool) CloseAll() {
	p.mu.Lock()
	conns := make([]*agent.Connection, 0, len(p.conns))
	for _, c := range p.conns {
		conns = append(conns, c)
	}
	p.conns = map[string]*agent.Connection{}
	p.mu.Unlock()
	for _, c := range conns {
		c.Close()
	}
}

// Check pings every connected node and returns current latency in NodeInfo.Latency (ms).
func (p *Pool) Check(timeout time.Duration) []protocol.NodeInfo {
	infos := p.ListStatus()
	for i := range infos {
		if infos[i].Status != "connected" {
			continue
		}
		p.mu.Lock()
		c := p.conns[infos[i].Name]
		p.mu.Unlock()
		if c == nil {
			continue
		}
		start := time.Now()
		v, _, err := c.Ping(timeout)
		if err != nil {
			infos[i].Status = "disconnected"
			continue
		}
		infos[i].Latency = int(time.Since(start).Milliseconds())
		infos[i].Agent = v
	}
	return infos
}

func sortStrings(s []string) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1] > s[j]; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}
