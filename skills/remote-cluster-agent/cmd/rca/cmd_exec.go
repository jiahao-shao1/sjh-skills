package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
	"github.com/spf13/cobra"
)

func newExecCmd(cfgPath *string) *cobra.Command {
	var (
		node    string
		dir     string
		timeout int
		stdin   bool
		stream  bool
		asJSON  bool
	)
	cmd := &cobra.Command{
		Use:   "exec [cmd]",
		Short: "execute a command on a single node",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cc *cobra.Command, args []string) error {
			var cmdStr string
			if stdin {
				b, err := io.ReadAll(os.Stdin)
				if err != nil {
					return err
				}
				cmdStr = string(b)
			} else {
				if len(args) != 1 {
					return fmt.Errorf("usage: rca exec \"command\"  (or --stdin)")
				}
				cmdStr = args[0]
			}
			c, cfg, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			if node == "" {
				node = cfg.DefaultNode
			}
			// Don't fill dir here; let daemon resolve node-level dir override
			req := protocol.ExecRequest{
				Node: node, Cmd: cmdStr, Dir: dir, Timeout: timeout, Stream: stream,
			}
			if stream {
				exit := 0
				err := c.PostStream("/exec", req, func(line []byte) error {
					var ev protocol.StreamEvent
					if err := json.Unmarshal(line, &ev); err != nil {
						return err
					}
					switch ev.Type {
					case "stream":
						fmt.Print(ev.Data)
					case "result":
						exit = ev.ExitCode
						fmt.Fprintf(os.Stderr, "[exit:%d elapsed:%.2fs]\n", ev.ExitCode, ev.Elapsed)
					}
					return nil
				})
				if err != nil {
					return err
				}
				os.Exit(exit)
				return nil
			}
			var resp protocol.ExecResponse
			if err := c.PostJSON("/exec", req, &resp, time.Duration(timeout+30)*time.Second); err != nil {
				return err
			}
			if asJSON {
				b, _ := json.MarshalIndent(resp, "", "  ")
				fmt.Println(string(b))
			} else {
				fmt.Print(resp.Output)
				if resp.ExitCode != 0 {
					os.Exit(resp.ExitCode)
				}
			}
			return nil
		},
	}
	cmd.Flags().StringVarP(&node, "node", "n", "", "target node (default: config.default_node)")
	cmd.Flags().StringVarP(&dir, "dir", "d", "", "remote working directory")
	cmd.Flags().IntVarP(&timeout, "timeout", "t", 120, "command timeout in seconds")
	cmd.Flags().BoolVar(&stdin, "stdin", false, "read command from stdin (allows heredoc)")
	cmd.Flags().BoolVarP(&stream, "stream", "s", false, "stream output line-by-line")
	cmd.Flags().BoolVar(&asJSON, "json", false, "emit JSON result")
	return cmd
}
