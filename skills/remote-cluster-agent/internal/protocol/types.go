// Package protocol defines the HTTP request/response types exchanged
// between the rca CLI and the rca daemon over the Unix socket.
package protocol

import "time"

type ExecRequest struct {
	Node    string `json:"node"`
	Cmd     string `json:"cmd"`
	Dir     string `json:"dir,omitempty"`
	Timeout int    `json:"timeout,omitempty"`
	Stream  bool   `json:"stream,omitempty"`
}

type ExecResponse struct {
	Node     string  `json:"node"`
	ExitCode int     `json:"exit_code"`
	Output   string  `json:"output"`
	Elapsed  float64 `json:"elapsed"`
}

type BatchRequest struct {
	Nodes       []string `json:"nodes"`
	Cmd         string   `json:"cmd"`
	Dir         string   `json:"dir,omitempty"`
	Timeout     int      `json:"timeout,omitempty"`
	Concurrency int      `json:"concurrency,omitempty"`
}

type NodeResult struct {
	Node     string  `json:"node"`
	ExitCode int     `json:"exit_code"`
	Output   string  `json:"output"`
	Elapsed  float64 `json:"elapsed"`
	Error    string  `json:"error,omitempty"`
}

type BatchResponse struct {
	Results      []NodeResult `json:"results"`
	TotalElapsed float64      `json:"total_elapsed"`
}

type NodeInfo struct {
	Name    string `json:"name"`
	Status  string `json:"status"`  // connected, disconnected, dead, unknown
	Agent   string `json:"agent"`   // version string or empty
	Latency int    `json:"latency"` // ms, 0 if not checked
}

type NodeHealth struct {
	Name           string     `json:"name"`
	Status         string     `json:"status"`                    // healthy, degraded, reconnecting, disconnected, dead
	CurrentLatency int        `json:"current_latency"`
	MedianLatency  int        `json:"median_latency"`
	Samples        int        `json:"samples"`
	LastReconnect  *time.Time `json:"last_reconnect,omitempty"`
}

type StatusResponse struct {
	Status      string     `json:"status"` // running
	Uptime      float64    `json:"uptime"` // seconds
	Connections int        `json:"connections"`
	Version     string     `json:"version"`
	Nodes       []NodeInfo `json:"nodes,omitempty"`
}

type ConnectRequest struct {
	Node string `json:"node"`
}

type TransferRequest struct {
	Source    string `json:"source"`
	Dest      string `json:"dest"`
	Recursive bool   `json:"recursive,omitempty"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

// Streaming events (chunked responses)
type StreamEvent struct {
	Type     string  `json:"type"` // "stream" | "result"
	Data     string  `json:"data,omitempty"`
	ExitCode int     `json:"exit_code,omitempty"`
	Elapsed  float64 `json:"elapsed,omitempty"`
}
