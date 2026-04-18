package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
	"github.com/spf13/cobra"
)

// absIfLocal returns the absolute form of p when p refers to a local path
// (no "node:" prefix). Remote paths (e.g. "node1:/tmp/x") are returned
// unchanged. The daemon runs with its own cwd, so relative local paths
// from the user's shell would otherwise resolve incorrectly.
func absIfLocal(p string) (string, error) {
	if strings.Contains(p, ":") {
		return p, nil
	}
	return filepath.Abs(p)
}

func newCPCmd(cfgPath *string) *cobra.Command {
	var recursive bool
	cmd := &cobra.Command{
		Use:   "cp <src> <dst>",
		Short: "copy files to/from cluster nodes via agent channel",
		Args:  cobra.ExactArgs(2),
		RunE: func(_ *cobra.Command, args []string) error {
			c, _, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			src, err := absIfLocal(args[0])
			if err != nil {
				return fmt.Errorf("resolve src: %w", err)
			}
			dst, err := absIfLocal(args[1])
			if err != nil {
				return fmt.Errorf("resolve dst: %w", err)
			}
			req := protocol.TransferRequest{
				Source: src, Dest: dst, Recursive: recursive,
			}
			var resp protocol.ExecResponse
			if err := c.PostJSON("/transfer", req, &resp, 0); err != nil {
				return err
			}
			if resp.Output != "" {
				fmt.Print(resp.Output)
			}
			if resp.ExitCode != 0 {
				os.Exit(resp.ExitCode)
			}
			return nil
		},
	}
	cmd.Flags().BoolVarP(&recursive, "recursive", "r", false, "recursive (directories) — not yet supported")
	return cmd
}
