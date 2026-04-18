package daemon

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
)

func TestStatusHandler(t *testing.T) {
	ap := findAgentPath(t)
	srv := New(testCfg(t, ap), "0.6.0")
	srv.startTime = time.Now().Add(-5 * time.Second)
	req := httptest.NewRequest("GET", "/status", nil)
	w := httptest.NewRecorder()
	srv.handleStatus(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("status=%d", w.Code)
	}
	var resp protocol.StatusResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Status != "running" {
		t.Errorf("status=%q", resp.Status)
	}
	if resp.Uptime < 4.5 || resp.Uptime > 10 {
		t.Errorf("uptime=%v", resp.Uptime)
	}
	if resp.Version != "0.6.0" {
		t.Errorf("version=%q", resp.Version)
	}
}

func TestExecHandler(t *testing.T) {
	ap := findAgentPath(t)
	srv := New(testCfg(t, ap), "test")
	defer srv.pool.CloseAll()

	req := httptest.NewRequest("POST", "/exec",
		strings.NewReader(`{"node":"local1","cmd":"echo hello","timeout":10}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	srv.handleExec(w, req)
	if w.Code != 200 {
		t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
	}
	var resp protocol.ExecResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.ExitCode != 0 || strings.TrimSpace(resp.Output) != "hello" {
		t.Errorf("got %+v", resp)
	}
}

func TestBatchHandler(t *testing.T) {
	ap := findAgentPath(t)
	srv := New(testCfg(t, ap), "test")
	defer srv.pool.CloseAll()

	req := httptest.NewRequest("POST", "/batch",
		strings.NewReader(`{"nodes":["local1","local2"],"cmd":"echo hi","timeout":10}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	srv.handleBatch(w, req)
	if w.Code != 200 {
		t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
	}
	var resp protocol.BatchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Results) != 2 {
		t.Fatalf("results=%d", len(resp.Results))
	}
	for _, r := range resp.Results {
		if r.ExitCode != 0 || strings.TrimSpace(r.Output) != "hi" {
			t.Errorf("bad result %+v", r)
		}
	}
}

func TestNodesHandler(t *testing.T) {
	ap := findAgentPath(t)
	srv := New(testCfg(t, ap), "test")
	defer srv.pool.CloseAll()
	_, _ = srv.pool.Get("local1")

	req := httptest.NewRequest("GET", "/nodes", nil)
	w := httptest.NewRecorder()
	srv.handleNodes(w, req)
	if w.Code != 200 {
		t.Fatalf("status=%d", w.Code)
	}
	var infos []protocol.NodeInfo
	_ = json.Unmarshal(w.Body.Bytes(), &infos)
	if len(infos) != 2 {
		t.Fatalf("infos=%d", len(infos))
	}
}
