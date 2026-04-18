package agent

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// Find path to cluster-agent/agent.py relative to the repo root.
func agentPath(t *testing.T) string {
	t.Helper()
	// Walk up until we find cluster-agent/agent.py
	wd, _ := os.Getwd()
	for i := 0; i < 6; i++ {
		p := filepath.Join(wd, "cluster-agent", "agent.py")
		if _, err := os.Stat(p); err == nil {
			return p
		}
		wd = filepath.Dir(wd)
	}
	t.Fatalf("cannot locate cluster-agent/agent.py")
	return ""
}

func newLocalConn(t *testing.T) *Connection {
	t.Helper()
	p := agentPath(t)
	c := &Connection{
		CmdArgs: []string{"python3", p},
	}
	if err := c.Connect(5 * time.Second); err != nil {
		t.Fatalf("connect: %v", err)
	}
	return c
}

func TestConnectHandshake(t *testing.T) {
	c := newLocalConn(t)
	defer c.Close()
	if !c.Connected() {
		t.Fatal("not connected")
	}
	if !strings.HasPrefix(c.Version(), "2.") {
		t.Errorf("agent version=%q, want 2.x", c.Version())
	}
}

func TestExecSimple(t *testing.T) {
	c := newLocalConn(t)
	defer c.Close()
	res, err := c.Exec("echo hello", "", 10, nil)
	if err != nil {
		t.Fatal(err)
	}
	if res.ExitCode != 0 {
		t.Errorf("exit=%d", res.ExitCode)
	}
	if strings.TrimSpace(res.Output) != "hello" {
		t.Errorf("output=%q", res.Output)
	}
}

func TestExecWorkdir(t *testing.T) {
	c := newLocalConn(t)
	defer c.Close()
	res, err := c.Exec("pwd", "/tmp", 10, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(strings.TrimSpace(res.Output), "/") {
		t.Errorf("unexpected pwd: %q", res.Output)
	}
}

func TestExecNonZeroExit(t *testing.T) {
	c := newLocalConn(t)
	defer c.Close()
	res, err := c.Exec("exit 7", "", 10, nil)
	if err != nil {
		t.Fatal(err)
	}
	if res.ExitCode != 7 {
		t.Errorf("exit=%d want 7", res.ExitCode)
	}
}

func TestExecConcurrent(t *testing.T) {
	c := newLocalConn(t)
	defer c.Close()
	var wg sync.WaitGroup
	const N = 10
	results := make([]*ExecResult, N)
	errs := make([]error, N)
	for i := 0; i < N; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results[i], errs[i] = c.Exec("echo concurrent", "", 10, nil)
		}(i)
	}
	wg.Wait()
	for i := 0; i < N; i++ {
		if errs[i] != nil {
			t.Errorf("#%d err=%v", i, errs[i])
			continue
		}
		if strings.TrimSpace(results[i].Output) != "concurrent" {
			t.Errorf("#%d output=%q", i, results[i].Output)
		}
	}
}

func TestExecStream(t *testing.T) {
	c := newLocalConn(t)
	defer c.Close()
	var got []string
	cb := func(line string) { got = append(got, line) }
	res, err := c.Exec("for i in 1 2 3; do echo line$i; done", "", 10, cb)
	if err != nil {
		t.Fatal(err)
	}
	if res.ExitCode != 0 {
		t.Errorf("exit=%d", res.ExitCode)
	}
	if len(got) != 3 {
		t.Errorf("stream lines=%d want 3: %v", len(got), got)
	}
}

func TestExecTimeout(t *testing.T) {
	c := newLocalConn(t)
	defer c.Close()
	res, err := c.Exec("sleep 5", "", 1, nil)
	if err != nil {
		t.Fatal(err)
	}
	if res.ExitCode != -1 {
		t.Errorf("exit=%d want -1 (timeout)", res.ExitCode)
	}
	if !strings.Contains(res.Output, "timed out") {
		t.Errorf("output=%q", res.Output)
	}
}

func TestClose(t *testing.T) {
	c := newLocalConn(t)
	c.Close()
	if c.Connected() {
		t.Fatal("still connected after Close")
	}
}
