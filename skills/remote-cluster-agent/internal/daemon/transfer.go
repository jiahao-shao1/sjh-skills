package daemon

import (
	"fmt"
	"os"
	"strings"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/agent"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
)

// parseRemote extracts (node, path) from "node:/path", or ("", path) for local.
// Empty node with a leading colon means "default node" (":", ":/file").
func parseRemote(s string) (node, path string, isRemote bool) {
	idx := strings.Index(s, ":")
	if idx < 0 {
		return "", s, false
	}
	return s[:idx], s[idx+1:], true
}

// transferViaAgent performs file transfer using the agent channel.
// For upload (local→remote): reads local file, sends via conn.WriteFile.
// For download (remote→local): reads via conn.ReadFile, writes local file.
func transferViaAgent(cfg *config.Config, pool *Pool, src, dst string, recursive bool) (string, int, error) {
	if recursive {
		return "recursive transfer not yet supported; use shared storage (CPFS) for directories", 1, nil
	}

	srcNode, srcPath, srcIsRem := parseRemote(src)
	dstNode, dstPath, dstIsRem := parseRemote(dst)

	if !srcIsRem && !dstIsRem {
		return "", 1, fmt.Errorf("at least one side must specify a node (e.g. node:/path)")
	}
	if srcIsRem && dstIsRem {
		return "", 1, fmt.Errorf("cross-node transfer not supported in one call")
	}

	// Resolve node name
	var node string
	if srcIsRem {
		node = srcNode
	} else {
		node = dstNode
	}
	if node == "" {
		node = cfg.DefaultNode
	}
	if _, ok := cfg.Nodes[node]; !ok {
		return "", 1, fmt.Errorf("unknown node %q", node)
	}

	conn, err := pool.Get(node)
	if err != nil {
		return "", 1, fmt.Errorf("connect to %s: %w", node, err)
	}

	if srcIsRem {
		return downloadFile(conn, srcPath, dstPath)
	}
	return uploadFile(conn, srcPath, dstPath)
}

func uploadFile(conn *agent.Connection, localPath, remotePath string) (string, int, error) {
	data, err := os.ReadFile(localPath)
	if err != nil {
		return "", 1, fmt.Errorf("read local file: %w", err)
	}
	if err := conn.WriteFile(remotePath, data, "0644"); err != nil {
		return "", 1, err
	}
	return fmt.Sprintf("uploaded %s (%d bytes)\n", remotePath, len(data)), 0, nil
}

func downloadFile(conn *agent.Connection, remotePath, localPath string) (string, int, error) {
	data, err := conn.ReadFile(remotePath)
	if err != nil {
		return "", 1, err
	}
	if err := os.WriteFile(localPath, data, 0644); err != nil {
		return "", 1, fmt.Errorf("write local file: %w", err)
	}
	return fmt.Sprintf("downloaded %s (%d bytes)\n", localPath, len(data)), 0, nil
}
