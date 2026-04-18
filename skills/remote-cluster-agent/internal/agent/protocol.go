// Package agent implements the Go port of the Python AgentConnection class:
// long-lived SSH subprocess driving the cluster-side Python agent.py over
// JSON-Lines, with a background reader routing responses by request ID.
package agent

// Exec request sent to the agent.
type execReq struct {
	ID      string `json:"id"`
	Cmd     string `json:"cmd"`
	Workdir string `json:"workdir,omitempty"`
	Timeout int    `json:"timeout,omitempty"`
	Stream  bool   `json:"stream,omitempty"`
}

type pingReq struct {
	Type string `json:"type"`
}

type cancelReq struct {
	Type string `json:"type"`
	ID   string `json:"id"`
}

type writeFileReq struct {
	Type string `json:"type"` // "write_file"
	ID   string `json:"id"`
	Path string `json:"path"`
	Data string `json:"data"` // base64
	Mode string `json:"mode,omitempty"`
}

type readFileReq struct {
	Type string `json:"type"` // "read_file"
	ID   string `json:"id"`
	Path string `json:"path"`
}

// Message is the umbrella type for any message received from the agent.
// Only one of the fields is populated depending on Type.
type Message struct {
	Type     string  `json:"type,omitempty"` // "ready" | "stream" | "result" | "cancelled" | "pong" | "file_data"
	ID       string  `json:"id,omitempty"`
	Data     string  `json:"data,omitempty"`      // stream / file_data (base64)
	ExitCode int     `json:"exit_code,omitempty"` // result only
	Output   string  `json:"output,omitempty"`    // result only
	Elapsed  float64 `json:"elapsed,omitempty"`
	Version  string  `json:"version,omitempty"` // ready / pong
	PID      int     `json:"pid,omitempty"`     // ready / pong
	Uptime   float64 `json:"uptime,omitempty"`  // pong
	Size     int     `json:"size,omitempty"`    // file_data
}
