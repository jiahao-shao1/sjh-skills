package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/client"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
	"github.com/spf13/cobra"
)

// Timeouts for the SSH fallback path. Without these the subprocess hangs
// indefinitely when the SSH tunnel wedges, blocking deploy on other nodes.
const (
	sshMkdirTimeout = 30 * time.Second
	sshWriteTimeout = 60 * time.Second
)

func newAgentCmd(cfgPath *string) *cobra.Command {
	cmd := &cobra.Command{Use: "agent", Short: "manage cluster-side agent"}

	cmd.AddCommand(&cobra.Command{
		Use:   "check",
		Short: "check agent health on every node",
		RunE: func(_ *cobra.Command, _ []string) error {
			c, _, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			var infos []protocol.NodeInfo
			if err := c.GetJSON("/nodes?check=true", &infos); err != nil {
				return err
			}
			for _, i := range infos {
				fmt.Printf("%-10s %-12s agent=%s latency=%dms\n", i.Name, i.Status, i.Agent, i.Latency)
			}
			return nil
		},
	})

	var force bool
	deploy := &cobra.Command{
		Use:   "deploy",
		Short: "upload agent.py to all nodes under agent_path",
		RunE: func(_ *cobra.Command, _ []string) error {
			c, cfg, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			localAgent := findLocalAgentPath()
			if localAgent == "" {
				return fmt.Errorf("cannot locate cluster-agent/agent.py locally; re-install remote-cluster-agent")
			}
			for node, nc := range cfg.Nodes {
				// Probe the agent via /exec. If this succeeds the node is reachable
				// through the daemon's agent channel; if it fails the agent is either
				// absent or the node is dead and we must fall back to direct SSH.
				checkCmd := protocol.ExecRequest{
					Node:    node,
					Cmd:     fmt.Sprintf("test -f %s && grep -o 'v[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+' %s | head -1", cfg.AgentPath, cfg.AgentPath),
					Timeout: 5,
				}
				var check protocol.ExecResponse
				checkErr := c.PostJSON("/exec", checkCmd, &check, 15*time.Second)

				if !force && checkErr == nil && check.ExitCode == 0 {
					fmt.Printf("%s: agent present (%s); skip (use --force)\n", node, filepath.Base(cfg.AgentPath))
					continue
				}

				// Agent reachable — upload through the daemon/agent channel.
				// Fast path: reuses the existing agent connection, no SSH subprocess,
				// no tunnel hang.
				if checkErr == nil {
					if err := deployViaAgentChannel(c, node, localAgent, cfg.AgentPath); err == nil {
						fmt.Printf("%s: deployed %s (agent channel)\n", node, cfg.AgentPath)
						continue
					} else {
						fmt.Fprintf(os.Stderr, "%s: agent-channel deploy failed: %v; falling back to SSH\n", node, err)
					}
				}

				// SSH fallback for brand-new nodes where the Python agent has never
				// run. Always bounded by context timeout so dead/wedged nodes can't
				// block the rest of the deploy.
				if err := sshMkdirParent(nc, cfg.AgentPath); err != nil {
					fmt.Fprintf(os.Stderr, "%s: mkdir failed: %v\n", node, err)
					continue
				}
				if err := sshWriteFile(nc, localAgent, cfg.AgentPath); err != nil {
					fmt.Fprintf(os.Stderr, "%s: deploy failed: %v\n", node, err)
					continue
				}
				fmt.Printf("%s: deployed %s (ssh)\n", node, cfg.AgentPath)
			}
			return nil
		},
	}
	deploy.Flags().BoolVar(&force, "force", false, "overwrite existing agent")
	cmd.AddCommand(deploy)

	return cmd
}

// deployViaAgentChannel uploads localPath to remotePath on the given node
// through the daemon's agent channel (mkdir via /exec, upload via /transfer,
// chmod +x via /exec). All daemon calls have explicit timeouts so this
// returns promptly on failure instead of hanging.
func deployViaAgentChannel(c *client.Client, node, localPath, remotePath string) error {
	mkReq := protocol.ExecRequest{
		Node:    node,
		Cmd:     fmt.Sprintf("mkdir -p %s", filepath.Dir(remotePath)),
		Timeout: 5,
	}
	var mkResp protocol.ExecResponse
	if err := c.PostJSON("/exec", mkReq, &mkResp, 15*time.Second); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}
	if mkResp.ExitCode != 0 {
		return fmt.Errorf("mkdir exit %d: %s", mkResp.ExitCode, strings.TrimSpace(mkResp.Output))
	}

	tr := protocol.TransferRequest{Source: localPath, Dest: node + ":" + remotePath}
	var trResp protocol.ExecResponse
	if err := c.PostJSON("/transfer", tr, &trResp, 60*time.Second); err != nil {
		return fmt.Errorf("upload: %w", err)
	}
	if trResp.ExitCode != 0 {
		return fmt.Errorf("upload exit %d: %s", trResp.ExitCode, strings.TrimSpace(trResp.Output))
	}

	chReq := protocol.ExecRequest{
		Node:    node,
		Cmd:     fmt.Sprintf("chmod +x %s", remotePath),
		Timeout: 5,
	}
	var chResp protocol.ExecResponse
	if err := c.PostJSON("/exec", chReq, &chResp, 15*time.Second); err != nil {
		return fmt.Errorf("chmod: %w", err)
	}
	if chResp.ExitCode != 0 {
		return fmt.Errorf("chmod exit %d: %s", chResp.ExitCode, strings.TrimSpace(chResp.Output))
	}
	return nil
}

// sshMkdirParent runs `ssh <node> mkdir -p <dir>` via a one-shot subprocess.
// Bounded by sshMkdirTimeout so a wedged tunnel can't hang deploy.
func sshMkdirParent(nc config.NodeConfig, agentPath string) error {
	parts := strings.Fields(nc.SSH)
	if len(parts) == 0 {
		return fmt.Errorf("empty ssh command")
	}
	ctx, cancel := context.WithTimeout(context.Background(), sshMkdirTimeout)
	defer cancel()
	args := append(parts[1:], fmt.Sprintf("mkdir -p %s", filepath.Dir(agentPath)))
	c := exec.CommandContext(ctx, parts[0], args...)
	out, err := c.CombinedOutput()
	if ctx.Err() == context.DeadlineExceeded {
		return fmt.Errorf("ssh mkdir timed out after %s", sshMkdirTimeout)
	}
	if err != nil {
		return fmt.Errorf("%w (%s)", err, strings.TrimSpace(string(out)))
	}
	return nil
}

// sshWriteFile pipes a local file to the remote host via SSH stdin.
// Bounded by sshWriteTimeout.
func sshWriteFile(nc config.NodeConfig, localPath, remotePath string) error {
	data, err := os.ReadFile(localPath)
	if err != nil {
		return err
	}
	parts := strings.Fields(nc.SSH)
	if len(parts) == 0 {
		return fmt.Errorf("empty ssh command")
	}
	ctx, cancel := context.WithTimeout(context.Background(), sshWriteTimeout)
	defer cancel()
	args := append(parts[1:], fmt.Sprintf("cat > %s && chmod +x %s", remotePath, remotePath))
	cmd := exec.CommandContext(ctx, parts[0], args...)
	cmd.Stdin = strings.NewReader(string(data))
	out, err := cmd.CombinedOutput()
	if ctx.Err() == context.DeadlineExceeded {
		return fmt.Errorf("ssh write timed out after %s", sshWriteTimeout)
	}
	if err != nil {
		return fmt.Errorf("%w (%s)", err, strings.TrimSpace(string(out)))
	}
	return nil
}

// findLocalAgentPath walks through candidate paths looking for cluster-agent/agent.py.
func findLocalAgentPath() string {
	home, _ := os.UserHomeDir()
	candidates := []string{
		filepath.Join(home, "workspace/sjh-skills/skills/remote-cluster-agent/cluster-agent/agent.py"),
		filepath.Join(home, ".agents/skills/remote-cluster-agent/cluster-agent/agent.py"),
		filepath.Join(home, ".claude/skills/remote-cluster-agent/cluster-agent/agent.py"),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return ""
}
