package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
	"github.com/spf13/cobra"
)

func newConfigCmd(cfgPath *string) *cobra.Command {
	cmd := &cobra.Command{Use: "config", Short: "manage rca config"}
	cmd.AddCommand(
		&cobra.Command{
			Use:   "show",
			Short: "print the current config file",
			RunE: func(_ *cobra.Command, _ []string) error {
				b, err := os.ReadFile(*cfgPath)
				if err != nil {
					return err
				}
				fmt.Print(string(b))
				return nil
			},
		},
		&cobra.Command{
			Use:   "edit",
			Short: "open config in $EDITOR",
			RunE: func(_ *cobra.Command, _ []string) error {
				editor := os.Getenv("EDITOR")
				if editor == "" {
					editor = "vi"
				}
				e := exec.Command(editor, *cfgPath)
				e.Stdin, e.Stdout, e.Stderr = os.Stdin, os.Stdout, os.Stderr
				return e.Run()
			},
		},
		&cobra.Command{
			Use:   "init",
			Short: "initialize config (migrate legacy or generate template)",
			RunE: func(_ *cobra.Command, _ []string) error {
				// If config already exists, do nothing
				if _, err := os.Stat(*cfgPath); err == nil {
					fmt.Printf("config already exists at %s\n", *cfgPath)
					return nil
				}

				home, _ := os.UserHomeDir()
				src := filepath.Join(home, ".config/remote-cluster-agent")
				if _, err := os.Stat(src); err == nil {
					// Migrate from legacy
					if err := config.Migrate(src, *cfgPath); err != nil {
						return err
					}
					fmt.Printf("migrated %s -> %s\n", src, *cfgPath)
					fmt.Println("legacy files left in place for rollback.")
					return nil
				}

				// No legacy config — generate template
				if err := os.MkdirAll(filepath.Dir(*cfgPath), 0755); err != nil {
					return err
				}
				template := `# rca config — edit node SSH commands below
default_node = ""
default_dir = ""
agent_path = ""
log_level = "info"
socket_path = "~/.config/rca/rca.sock"

[ssh]
alive_interval = 30
alive_count_max = 3
max_retries = 3
retry_backoff = [2, 4, 8]

# Add your nodes below. Example:
# [nodes.train]
# ssh = "ssh gpu-train"
#
# [nodes.eval]
# ssh = "ssh -p 2222 user@gpu-eval"
# dir = "/home/user/project"        # optional: override default_dir for this node
# agent_path = "/path/to/agent.py"  # optional: override agent_path for this node
`
				if err := os.WriteFile(*cfgPath, []byte(template), 0644); err != nil {
					return err
				}
				fmt.Printf("created template config at %s\n", *cfgPath)
				fmt.Println("edit the file to add your node SSH commands, then run: rca daemon start")
				return nil
			},
		},
	)
	return cmd
}
