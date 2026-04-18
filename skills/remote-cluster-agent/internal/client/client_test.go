package client

import (
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
)

func TestClientGetJSON(t *testing.T) {
	dir := t.TempDir()
	sock := filepath.Join(dir, "test.sock")
	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	defer os.Remove(sock)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /status", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(protocol.StatusResponse{Status: "running", Version: "test"})
	})
	srv := &http.Server{Handler: mux}
	go srv.Serve(ln)
	defer srv.Close()

	c := New(sock, nil)
	var resp protocol.StatusResponse
	if err := c.GetJSON("/status", &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Status != "running" || resp.Version != "test" {
		t.Errorf("got %+v", resp)
	}
}
