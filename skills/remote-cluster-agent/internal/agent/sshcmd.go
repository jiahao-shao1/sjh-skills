package agent

import (
	"fmt"
	"strings"
)

// BuildSSHCmd returns the argv to spawn the agent.
// If sshCmd is empty, returns a local-mode command for tests.
func BuildSSHCmd(sshCmd, agentPath string, aliveInterval, aliveCountMax int) []string {
	agentInvoke := fmt.Sprintf("python3 %s", agentPath)
	if sshCmd == "" {
		return []string{"python3", agentPath}
	}
	parts := strings.Fields(sshCmd)
	parts = append(parts,
		"-o", fmt.Sprintf("ServerAliveInterval=%d", aliveInterval),
		"-o", fmt.Sprintf("ServerAliveCountMax=%d", aliveCountMax),
		agentInvoke,
	)
	return parts
}
