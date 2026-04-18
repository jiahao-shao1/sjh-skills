package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const legacyContextMD = `# context.local.md

default_node: node1
default_dir: /home/user/project
agent_path: /shared/.agent/agent.py

## Nodes

- name: node1
  ssh: ssh -p 10001 127.0.0.1
- name: node3
  ssh: ssh -p 10003 127.0.0.1
`

const legacyProjectMD = `# my_project.md

dir: /home/user/project
default_node: node3
`

func TestMigrate(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	os.MkdirAll(src, 0755)
	os.WriteFile(filepath.Join(src, "context.local.md"), []byte(legacyContextMD), 0644)
	os.WriteFile(filepath.Join(src, "my_project.md"), []byte(legacyProjectMD), 0644)

	out := filepath.Join(dir, "config.toml")
	if err := Migrate(src, out); err != nil {
		t.Fatal(err)
	}
	c, err := Load(out)
	if err != nil {
		t.Fatal(err)
	}
	if c.DefaultNode != "node1" {
		t.Errorf("default_node=%q", c.DefaultNode)
	}
	if c.Nodes["node1"].SSH != "ssh -p 10001 127.0.0.1" {
		t.Errorf("node1.ssh=%q", c.Nodes["node1"].SSH)
	}
	if _, ok := c.Projects["my_project"]; !ok {
		t.Fatal("missing project my_project")
	}
	if c.Projects["my_project"].DefaultNode != "node3" {
		t.Errorf("proj default_node=%q", c.Projects["my_project"].DefaultNode)
	}
	// File should contain readable comments
	b, _ := os.ReadFile(out)
	if !strings.Contains(string(b), "# migrated from") {
		t.Errorf("missing migration banner: %s", string(b))
	}
}
