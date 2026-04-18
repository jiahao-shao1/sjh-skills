package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

// plistTemplate is the launchd plist template for com.rca.daemon.
// __PROGRAM_ARGS__ is replaced with <string> elements at register time.
// __LOG_DIR__ is replaced with the log directory path.
const plistTemplate = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rca.daemon</string>

    <key>ProgramArguments</key>
    <array>
        __PROGRAM_ARGS__
    </array>

    <key>KeepAlive</key>
    <true/>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>__LOG_DIR__/daemon.log</string>

    <key>StandardErrorPath</key>
    <string>__LOG_DIR__/daemon.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
`

func newRegisterCmd(cfgPath *string) *cobra.Command {
	return &cobra.Command{
		Use:   "register",
		Short: "register daemon with launchd for auto-start on login (optional)",
		RunE: func(_ *cobra.Command, _ []string) error {
			exe, err := os.Executable()
			if err != nil {
				return fmt.Errorf("resolve executable: %w", err)
			}

			logDir := defaultLogDir()

			// Build <string> elements for ProgramArguments.
			programArgs := strings.Join([]string{
				fmt.Sprintf("<string>%s</string>", exe),
				"<string>daemon</string>",
				"<string>run</string>",
				"<string>--config</string>",
				fmt.Sprintf("<string>%s</string>", *cfgPath),
			}, "\n        ")

			plist := strings.ReplaceAll(plistTemplate, "__PROGRAM_ARGS__", programArgs)
			plist = strings.ReplaceAll(plist, "__LOG_DIR__", logDir)

			home, _ := os.UserHomeDir()
			plistPath := filepath.Join(home, "Library", "LaunchAgents", "com.rca.daemon.plist")
			if err := os.WriteFile(plistPath, []byte(plist), 0644); err != nil {
				if os.IsPermission(err) {
					fmt.Fprintf(os.Stderr, "failed to write %s: Operation not permitted.\n", plistPath)
					fmt.Fprintf(os.Stderr, "Grant App Management permission to your terminal in:\n")
					fmt.Fprintf(os.Stderr, "  System Settings → Privacy & Security → App Management\n")
					fmt.Fprintf(os.Stderr, "Or skip launchd and just use 'rca daemon start' to run the daemon manually.\n")
					return fmt.Errorf("permission denied")
				}
				return fmt.Errorf("write plist: %w", err)
			}

			cmd := exec.Command("launchctl", "load", "-w", plistPath)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				return fmt.Errorf("launchctl load: %w", err)
			}
			fmt.Printf("registered: %s\n", plistPath)
			fmt.Printf("logs: %s/daemon.log\n", logDir)
			return nil
		},
	}
}

func newUnregisterCmd(cfgPath *string) *cobra.Command {
	return &cobra.Command{
		Use:   "unregister",
		Short: "unregister daemon from launchd",
		RunE: func(_ *cobra.Command, _ []string) error {
			home, _ := os.UserHomeDir()
			plistPath := filepath.Join(home, "Library", "LaunchAgents", "com.rca.daemon.plist")

			cmd := exec.Command("launchctl", "unload", "-w", plistPath)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			_ = cmd.Run() // best-effort

			if err := os.Remove(plistPath); err != nil && !os.IsNotExist(err) {
				return fmt.Errorf("remove plist: %w", err)
			}
			fmt.Printf("unregistered: %s\n", plistPath)
			return nil
		},
	}
}
