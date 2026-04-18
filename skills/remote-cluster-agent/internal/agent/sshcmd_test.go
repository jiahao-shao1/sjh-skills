package agent

import (
	"reflect"
	"testing"
)

func TestBuildSSHCmd(t *testing.T) {
	got := BuildSSHCmd("ssh -p 10001 127.0.0.1", "/shared/.agent/agent.py", 30, 3)
	want := []string{
		"ssh", "-p", "10001", "127.0.0.1",
		"-o", "ServerAliveInterval=30",
		"-o", "ServerAliveCountMax=3",
		"python3 /shared/.agent/agent.py",
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %v want %v", got, want)
	}
}

func TestBuildSSHCmdEmpty(t *testing.T) {
	got := BuildSSHCmd("", "/tmp/agent.py", 30, 3)
	// Empty ssh -> local mode (tests)
	want := []string{"python3", "/tmp/agent.py"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %v want %v", got, want)
	}
}
