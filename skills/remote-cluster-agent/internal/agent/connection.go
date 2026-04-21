package agent

import (
	"bufio"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"sync"
	"time"
)

// ExecResult is what Exec returns to callers.
type ExecResult struct {
	ExitCode int
	Output   string
	Elapsed  float64
}

// StreamCallback receives one decoded stdout line (including trailing \n).
type StreamCallback func(line string)

// Connection is a long-lived subprocess + JSON-Lines client.
// CmdArgs is the full argv (e.g. ["ssh","-p","10001","127.0.0.1","python3","/path/agent.py"]
// or for tests ["python3","/path/agent.py"]).
type Connection struct {
	CmdArgs []string

	mu        sync.Mutex // guards connected / proc / queues
	connected bool
	proc      *exec.Cmd
	stdin     io.WriteCloser
	stdout    io.ReadCloser
	writeMu   sync.Mutex // guards stdin writes
	version   string
	pid       int

	queuesMu sync.Mutex
	queues   map[string]chan *Message
}

func (c *Connection) Connected() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.connected
}

func (c *Connection) Version() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.version
}

// Connect spawns the agent subprocess and waits for the "ready" handshake.
func (c *Connection) Connect(handshakeTimeout time.Duration) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.connected {
		return errors.New("already connected")
	}
	if len(c.CmdArgs) == 0 {
		return errors.New("empty CmdArgs")
	}
	proc := exec.Command(c.CmdArgs[0], c.CmdArgs[1:]...)
	stdin, err := proc.StdinPipe()
	if err != nil {
		return err
	}
	stdout, err := proc.StdoutPipe()
	if err != nil {
		return err
	}
	proc.Stderr = nil // discard agent stderr
	if err := proc.Start(); err != nil {
		return err
	}
	c.proc = proc
	c.stdin = stdin
	c.stdout = stdout
	c.queues = make(map[string]chan *Message)

	// Read ready line synchronously with timeout
	reader := bufio.NewReader(stdout)
	readyCh := make(chan *Message, 1)
	readyErr := make(chan error, 1)
	go func() {
		line, err := reader.ReadBytes('\n')
		if err != nil {
			readyErr <- err
			return
		}
		var m Message
		if err := json.Unmarshal(line, &m); err != nil {
			readyErr <- fmt.Errorf("bad ready line: %w", err)
			return
		}
		readyCh <- &m
	}()
	select {
	case <-time.After(handshakeTimeout):
		_ = proc.Process.Kill()
		_, _ = proc.Process.Wait()
		return errors.New("agent handshake timeout")
	case err := <-readyErr:
		_ = proc.Process.Kill()
		_, _ = proc.Process.Wait()
		return fmt.Errorf("read ready: %w", err)
	case m := <-readyCh:
		if m.Type != "ready" {
			_ = proc.Process.Kill()
			_, _ = proc.Process.Wait()
			return fmt.Errorf("unexpected handshake: %+v", m)
		}
		c.version = m.Version
		c.pid = m.PID
	}

	c.connected = true
	go c.readerLoop(reader)
	return nil
}

// Close terminates the subprocess and unblocks all pending requests.
func (c *Connection) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.closeLocked()
}

func (c *Connection) closeLocked() {
	if !c.connected {
		return
	}
	c.connected = false
	if c.stdin != nil {
		_ = c.stdin.Close()
	}
	if c.proc != nil && c.proc.Process != nil {
		_ = c.proc.Process.Kill()
		_, _ = c.proc.Process.Wait()
	}
	// Unblock all waiters
	c.queuesMu.Lock()
	for _, q := range c.queues {
		close(q)
	}
	c.queues = map[string]chan *Message{}
	c.queuesMu.Unlock()
}

// readerLoop routes incoming JSON messages to per-request channels.
func (c *Connection) readerLoop(reader *bufio.Reader) {
	for {
		line, err := reader.ReadBytes('\n')
		if err != nil {
			c.mu.Lock()
			if c.connected {
				c.closeLocked()
			}
			c.mu.Unlock()
			return
		}
		var m Message
		if err := json.Unmarshal(line, &m); err != nil {
			// Malformed line; skip.
			continue
		}
		reqID := m.ID
		if m.Type == "pong" {
			reqID = "__ping__"
		}
		c.queuesMu.Lock()
		q, ok := c.queues[reqID]
		c.queuesMu.Unlock()
		if ok {
			select {
			case q <- &m:
			default:
				// Channel buffered 64; drop if full.
			}
		}
	}
}

func (c *Connection) registerQueue(id string) chan *Message {
	q := make(chan *Message, 64)
	c.queuesMu.Lock()
	c.queues[id] = q
	c.queuesMu.Unlock()
	return q
}

func (c *Connection) unregisterQueue(id string) {
	c.queuesMu.Lock()
	delete(c.queues, id)
	c.queuesMu.Unlock()
}

func (c *Connection) writeLine(v any) error {
	buf, err := json.Marshal(v)
	if err != nil {
		return err
	}
	buf = append(buf, '\n')
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_, err = c.stdin.Write(buf)
	return err
}

func newReqID() string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// Exec runs a command. If cb != nil the agent streams line by line and cb
// is invoked for each stream event; otherwise the full output is returned
// in one result.
func (c *Connection) Exec(cmd, workdir string, timeoutSecs int, cb StreamCallback) (*ExecResult, error) {
	if !c.Connected() {
		return nil, errors.New("agent not connected")
	}
	id := newReqID()
	q := c.registerQueue(id)
	defer c.unregisterQueue(id)

	req := execReq{
		ID:      id,
		Cmd:     cmd,
		Workdir: workdir,
		Timeout: timeoutSecs,
		Stream:  cb != nil,
	}
	if err := c.writeLine(req); err != nil {
		return nil, err
	}

	// Overall guard: agent will enforce its own timeout; add a small buffer.
	deadline := time.After(time.Duration(timeoutSecs+10) * time.Second)
	for {
		select {
		case m, ok := <-q:
			if !ok {
				return nil, errors.New("connection closed")
			}
			switch m.Type {
			case "stream":
				if cb != nil {
					cb(m.Data)
				}
			case "result":
				return &ExecResult{ExitCode: m.ExitCode, Output: m.Output, Elapsed: m.Elapsed}, nil
			case "cancelled":
				return &ExecResult{ExitCode: -1, Output: "cancelled", Elapsed: m.Elapsed}, nil
			}
		case <-deadline:
			return nil, fmt.Errorf("exec timeout (%ds)", timeoutSecs+10)
		}
	}
}

// Ping returns (version, uptime, error). Useful for `rca nodes --check`.
func (c *Connection) Ping(timeout time.Duration) (string, float64, error) {
	if !c.Connected() {
		return "", 0, errors.New("not connected")
	}
	q := c.registerQueue("__ping__")
	defer c.unregisterQueue("__ping__")
	if err := c.writeLine(pingReq{Type: "ping"}); err != nil {
		return "", 0, err
	}
	select {
	case m, ok := <-q:
		if !ok {
			return "", 0, errors.New("closed")
		}
		return m.Version, m.Uptime, nil
	case <-time.After(timeout):
		return "", 0, errors.New("ping timeout")
	}
}

// WriteFile sends data to the agent which writes it to path on the remote host.
func (c *Connection) WriteFile(path string, data []byte, mode string) error {
	if !c.Connected() {
		return errors.New("agent not connected")
	}
	if mode == "" {
		mode = "0644"
	}
	id := newReqID()
	q := c.registerQueue(id)
	defer c.unregisterQueue(id)

	req := writeFileReq{
		Type: "write_file",
		ID:   id,
		Path: path,
		Data: base64.StdEncoding.EncodeToString(data),
		Mode: mode,
	}
	if err := c.writeLine(req); err != nil {
		return err
	}

	deadline := time.After(60 * time.Second)
	for {
		select {
		case m, ok := <-q:
			if !ok {
				return errors.New("connection closed")
			}
			if m.Type == "result" {
				if m.ExitCode != 0 {
					return fmt.Errorf("write_file failed: %s", m.Output)
				}
				return nil
			}
		case <-deadline:
			return errors.New("write_file timeout")
		}
	}
}

// ReadFile reads a file from the remote host via the agent channel.
func (c *Connection) ReadFile(path string) ([]byte, error) {
	if !c.Connected() {
		return nil, errors.New("agent not connected")
	}
	id := newReqID()
	q := c.registerQueue(id)
	defer c.unregisterQueue(id)

	req := readFileReq{
		Type: "read_file",
		ID:   id,
		Path: path,
	}
	if err := c.writeLine(req); err != nil {
		return nil, err
	}

	deadline := time.After(60 * time.Second)
	for {
		select {
		case m, ok := <-q:
			if !ok {
				return nil, errors.New("connection closed")
			}
			switch m.Type {
			case "file_data":
				return base64.StdEncoding.DecodeString(m.Data)
			case "result":
				return nil, fmt.Errorf("read_file failed: %s", m.Output)
			}
		case <-deadline:
			return nil, errors.New("read_file timeout")
		}
	}
}
