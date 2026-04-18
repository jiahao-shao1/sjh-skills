package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
	"github.com/spf13/cobra"
)

func newBatchCmd(cfgPath *string) *cobra.Command {
	var (
		nodesStr    string
		all         bool
		dir         string
		timeout     int
		concurrency int
		asJSON      bool
	)
	cmd := &cobra.Command{
		Use:   "batch [cmd]",
		Short: "execute a command on multiple nodes in parallel",
		Args:  cobra.ExactArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			c, cfg, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			var nodes []string
			if nodesStr != "" {
				nodes = splitAndTrim(nodesStr, ",")
			} else if all {
				for n := range cfg.Nodes {
					nodes = append(nodes, n)
				}
			}
			// Don't fill dir here; let daemon resolve node-level dir override
			req := protocol.BatchRequest{
				Nodes: nodes, Cmd: args[0], Dir: dir, Timeout: timeout, Concurrency: concurrency,
			}
			var resp protocol.BatchResponse
			if err := c.PostJSON("/batch", req, &resp, time.Duration(timeout+60)*time.Second); err != nil {
				return err
			}
			if asJSON {
				b, _ := json.MarshalIndent(resp, "", "  ")
				fmt.Println(string(b))
				return nil
			}
			ok, failed := 0, 0
			for _, r := range resp.Results {
				if r.ExitCode == 0 && r.Error == "" {
					fmt.Fprintf(os.Stdout, "=== %s [ok %.2fs] ===\n%s\n", r.Node, r.Elapsed, r.Output)
					ok++
				} else {
					status := fmt.Sprintf("FAIL exit:%d", r.ExitCode)
					if r.Error != "" {
						status = fmt.Sprintf("ERROR %s", r.Error)
					}
					fmt.Fprintf(os.Stdout, "=== %s [%s %.2fs] ===\n%s\n", r.Node, status, r.Elapsed, r.Output)
					failed++
				}
			}
			fmt.Fprintf(os.Stdout, "Summary: %d/%d ok, %d failed (%.2fs total)\n",
				ok, ok+failed, failed, resp.TotalElapsed)
			if failed > 0 {
				os.Exit(1)
			}
			return nil
		},
	}
	cmd.Flags().StringVarP(&nodesStr, "nodes", "n", "", "comma-separated node names (default: all)")
	cmd.Flags().BoolVar(&all, "all", false, "explicitly target all nodes")
	cmd.Flags().StringVarP(&dir, "dir", "d", "", "remote working directory")
	cmd.Flags().IntVarP(&timeout, "timeout", "t", 120, "per-node timeout")
	cmd.Flags().IntVarP(&concurrency, "concurrency", "c", 0, "concurrent nodes (0=all)")
	cmd.Flags().BoolVar(&asJSON, "json", false, "emit JSON result")
	return cmd
}

func splitAndTrim(s, sep string) []string {
	parts := strings.Split(s, sep)
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
