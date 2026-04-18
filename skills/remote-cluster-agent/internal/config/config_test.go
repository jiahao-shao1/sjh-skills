package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadMinimal(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.toml")
	os.WriteFile(path, []byte(`
default_node = "node1"
default_dir = "/home/user/project"
agent_path = "/shared/.agent/agent.py"
log_level = "info"
socket_path = "~/.config/rca/rca.sock"

[ssh]
alive_interval = 30
alive_count_max = 3
max_retries = 3
retry_backoff = [2, 4, 8]

[nodes.node1]
ssh = "ssh -p 10001 127.0.0.1"

[nodes.node2]
ssh = "ssh -p 10002 127.0.0.1"
`), 0644)

	c, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if c.DefaultNode != "node1" {
		t.Errorf("default_node=%s", c.DefaultNode)
	}
	if c.SSH.AliveInterval != 30 {
		t.Errorf("alive_interval=%d", c.SSH.AliveInterval)
	}
	if len(c.Nodes) != 2 {
		t.Errorf("nodes=%d, want 2", len(c.Nodes))
	}
	if c.Nodes["node1"].SSH != "ssh -p 10001 127.0.0.1" {
		t.Errorf("node1.ssh=%q", c.Nodes["node1"].SSH)
	}
	if len(c.SSH.RetryBackoff) != 3 || c.SSH.RetryBackoff[2] != 8 {
		t.Errorf("retry_backoff=%v", c.SSH.RetryBackoff)
	}
}

func TestExpandHome(t *testing.T) {
	home, _ := os.UserHomeDir()
	got := ExpandHome("~/foo/bar")
	want := filepath.Join(home, "foo/bar")
	if got != want {
		t.Errorf("ExpandHome=%q, want %q", got, want)
	}
}

func TestDefaultPath(t *testing.T) {
	p := DefaultPath()
	home, _ := os.UserHomeDir()
	want := filepath.Join(home, ".config/rca/config.toml")
	if p != want {
		t.Errorf("DefaultPath=%q, want %q", p, want)
	}
}
