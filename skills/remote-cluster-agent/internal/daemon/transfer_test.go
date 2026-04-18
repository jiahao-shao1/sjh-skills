package daemon

import (
	"testing"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
)

func TestParseRemote(t *testing.T) {
	tests := []struct {
		input    string
		wantNode string
		wantPath string
		wantRem  bool
	}{
		{"node1:/tmp/x", "node1", "/tmp/x", true},
		{":/tmp/x", "", "/tmp/x", true},
		{"./local", "", "./local", false},
		{"/abs/path", "", "/abs/path", false},
	}
	for _, tt := range tests {
		node, path, isRem := parseRemote(tt.input)
		if node != tt.wantNode || path != tt.wantPath || isRem != tt.wantRem {
			t.Errorf("parseRemote(%q) = (%q,%q,%v) want (%q,%q,%v)",
				tt.input, node, path, isRem, tt.wantNode, tt.wantPath, tt.wantRem)
		}
	}
}

func TestTransferViaAgent_BothLocal(t *testing.T) {
	cfg := &config.Config{Nodes: map[string]config.NodeConfig{}}
	_, exit, err := transferViaAgent(cfg, nil, "./a", "./b", false)
	if err == nil && exit == 0 {
		t.Fatal("expected error: both local")
	}
}

func TestTransferViaAgent_BothRemote(t *testing.T) {
	cfg := &config.Config{Nodes: map[string]config.NodeConfig{}}
	_, exit, err := transferViaAgent(cfg, nil, "n1:/a", "n2:/b", false)
	if err == nil && exit == 0 {
		t.Fatal("expected error: cross-node")
	}
}

func TestTransferViaAgent_RecursiveUnsupported(t *testing.T) {
	cfg := &config.Config{
		Nodes: map[string]config.NodeConfig{"n1": {SSH: "ssh 127.0.0.1"}},
	}
	out, exit, err := transferViaAgent(cfg, nil, "./dir", "n1:/tmp/dir", true)
	if err != nil {
		t.Fatal(err)
	}
	if exit != 1 {
		t.Errorf("expected exit=1, got %d", exit)
	}
	if out == "" {
		t.Error("expected message about recursive not supported")
	}
}

func TestTransferViaAgent_UnknownNode(t *testing.T) {
	cfg := &config.Config{Nodes: map[string]config.NodeConfig{}}
	_, _, err := transferViaAgent(cfg, nil, "./a", "nope:/b", false)
	if err == nil {
		t.Fatal("expected error for unknown node")
	}
}
