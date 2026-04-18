package daemon

import (
	"context"
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/agent"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
)

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, protocol.ErrorResponse{Error: msg})
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	resp := protocol.StatusResponse{
		Status:      "running",
		Uptime:      time.Since(s.startTime).Seconds(),
		Connections: s.pool.Count(),
		Version:     s.version,
		Nodes:       s.pool.ListStatus(),
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) handleExec(w http.ResponseWriter, r *http.Request) {
	var req protocol.ExecRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	node := req.Node
	if node == "" {
		node = s.cfg.DefaultNode
	}
	dir := req.Dir
	if dir == "" {
		if nc, ok := s.cfg.Nodes[node]; ok {
			dir = nc.EffectiveDir(s.cfg.DefaultDir)
		} else {
			dir = s.cfg.DefaultDir
		}
	}
	timeout := req.Timeout
	if timeout == 0 {
		timeout = 120
	}
	conn, err := s.pool.Get(node)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	if req.Stream {
		s.handleExecStream(w, conn, req.Cmd, dir, timeout)
		return
	}
	res, err := conn.Exec(req.Cmd, dir, timeout, nil)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, protocol.ExecResponse{
		Node: node, ExitCode: res.ExitCode, Output: res.Output, Elapsed: res.Elapsed,
	})
}

func (s *Server) handleExecStream(w http.ResponseWriter, conn *agent.Connection, cmd, dir string, timeout int) {
	w.Header().Set("Content-Type", "application/x-ndjson")
	flusher, _ := w.(http.Flusher)
	enc := json.NewEncoder(w)
	cb := func(line string) {
		_ = enc.Encode(protocol.StreamEvent{Type: "stream", Data: line})
		if flusher != nil {
			flusher.Flush()
		}
	}
	res, err := conn.Exec(cmd, dir, timeout, cb)
	if err != nil {
		_ = enc.Encode(protocol.StreamEvent{Type: "result", ExitCode: -1, Data: err.Error()})
		if flusher != nil {
			flusher.Flush()
		}
		return
	}
	_ = enc.Encode(protocol.StreamEvent{Type: "result", ExitCode: res.ExitCode, Elapsed: res.Elapsed})
	if flusher != nil {
		flusher.Flush()
	}
}

func (s *Server) handleBatch(w http.ResponseWriter, r *http.Request) {
	var req protocol.BatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	nodes := req.Nodes
	if len(nodes) == 0 {
		for n := range s.cfg.Nodes {
			nodes = append(nodes, n)
		}
		sortStrings(nodes)
	}
	baseDir := req.Dir
	timeout := req.Timeout
	if timeout == 0 {
		timeout = 120
	}
	concurrency := req.Concurrency
	if concurrency <= 0 || concurrency > len(nodes) {
		concurrency = len(nodes)
	}

	ctx, cancel := context.WithTimeout(r.Context(), time.Duration(timeout+30)*time.Second)
	defer cancel()

	start := time.Now()
	results := make([]protocol.NodeResult, len(nodes))
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup
	for i, n := range nodes {
		wg.Add(1)
		sem <- struct{}{}
		go func(i int, n string) {
			defer wg.Done()
			defer func() { <-sem }()
			if ctx.Err() != nil {
				results[i] = protocol.NodeResult{Node: n, ExitCode: -1, Error: "cancelled"}
				return
			}
			conn, err := s.pool.Get(n)
			if err != nil {
				results[i] = protocol.NodeResult{Node: n, ExitCode: -1, Error: err.Error()}
				return
			}
			dir := baseDir
			if dir == "" {
				if nc, ok := s.cfg.Nodes[n]; ok {
					dir = nc.EffectiveDir(s.cfg.DefaultDir)
				} else {
					dir = s.cfg.DefaultDir
				}
			}
			res, err := conn.Exec(req.Cmd, dir, timeout, nil)
			if err != nil {
				results[i] = protocol.NodeResult{Node: n, ExitCode: -1, Error: err.Error()}
				return
			}
			results[i] = protocol.NodeResult{Node: n, ExitCode: res.ExitCode, Output: res.Output, Elapsed: res.Elapsed}
		}(i, n)
	}
	wg.Wait()
	writeJSON(w, http.StatusOK, protocol.BatchResponse{
		Results: results, TotalElapsed: time.Since(start).Seconds(),
	})
}

func (s *Server) handleNodes(w http.ResponseWriter, r *http.Request) {
	check := r.URL.Query().Get("check") == "true"
	var infos []protocol.NodeInfo
	if check {
		infos = s.pool.Check(3 * time.Second)
	} else {
		infos = s.pool.ListStatus()
	}
	writeJSON(w, http.StatusOK, infos)
}

func (s *Server) handleConnect(w http.ResponseWriter, r *http.Request) {
	var req protocol.ConnectRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := s.pool.Connect(req.Node); err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"node": req.Node, "status": "connected"})
}

func (s *Server) handleDisconnect(w http.ResponseWriter, r *http.Request) {
	var req protocol.ConnectRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	s.pool.Disconnect(req.Node)
	writeJSON(w, http.StatusOK, map[string]string{"node": req.Node, "status": "disconnected"})
}

func (s *Server) handleNodesHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, s.monitor.GetHealth())
}

func (s *Server) handleTransfer(w http.ResponseWriter, r *http.Request) {
	var req protocol.TransferRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	out, exit, err := transferViaAgent(s.cfg, s.pool, req.Source, req.Dest, req.Recursive)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, protocol.ExecResponse{
		Node: "", ExitCode: exit, Output: out, Elapsed: 0,
	})
}
