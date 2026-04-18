// Command rca is the CLI for the rca daemon.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/client"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/daemon"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
	"github.com/spf13/cobra"
)

var Version = "0.4.1"

func main() {
	cfgPath := config.DefaultPath()
	root := &cobra.Command{
		Use:     "rca",
		Short:   "RCA cluster CLI",
		Version: Version,
	}
	root.PersistentFlags().StringVar(&cfgPath, "config", cfgPath, "path to config.toml")

	root.AddCommand(newDaemonCmd(&cfgPath))
	root.AddCommand(newExecCmd(&cfgPath))
	root.AddCommand(newBatchCmd(&cfgPath))
	root.AddCommand(newNodesCmd(&cfgPath))
	root.AddCommand(newConnectCmd(&cfgPath))
	root.AddCommand(newDisconnectCmd(&cfgPath))
	root.AddCommand(newConfigCmd(&cfgPath))
	root.AddCommand(newCPCmd(&cfgPath))
	root.AddCommand(newAgentCmd(&cfgPath))

	if err := root.Execute(); err != nil {
		os.Exit(1)
	}
}

// newClient builds a client; autoSpawn=true injects a spawn callback.
// Daemon sub-commands pass autoSpawn=false to avoid recursive spawn.
func newClient(cfgPath string, autoSpawn bool) (*client.Client, *config.Config, error) {
	cfg, err := config.Load(cfgPath)
	if err != nil {
		return nil, nil, fmt.Errorf("load config %s: %w", cfgPath, err)
	}
	var spawn func() error
	if autoSpawn {
		sockPath := cfg.SocketPath
		spawn = func() error {
			logDir := filepath.Join(os.Getenv("HOME"), "Library", "Logs", "rca")
			return runDaemonStart(cfgPath, sockPath, logDir)
		}
	}
	return client.New(cfg.SocketPath, spawn), cfg, nil
}

// defaultLogDir returns ~/Library/Logs/rca.
func defaultLogDir() string {
	return filepath.Join(os.Getenv("HOME"), "Library", "Logs", "rca")
}

// runDaemonStart spawns the daemon as a detached process (fork+setsid),
// then polls the socket for up to 3s.
func runDaemonStart(cfgPath, sockPath, logDir string) error {
	// Check if already running.
	if conn, err := net.DialTimeout("unix", sockPath, 500*time.Millisecond); err == nil {
		conn.Close()
		fmt.Println("daemon already running")
		return nil
	}

	exe, err := os.Executable()
	if err != nil {
		return fmt.Errorf("resolve executable: %w", err)
	}

	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("mkdir log dir: %w", err)
	}
	logFile, err := os.OpenFile(filepath.Join(logDir, "daemon.log"),
		os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		return fmt.Errorf("open log file: %w", err)
	}
	defer logFile.Close()

	attr := &os.ProcAttr{
		Files: []*os.File{nil, logFile, logFile},
		Sys:   &syscall.SysProcAttr{Setsid: true},
	}
	args := []string{exe, "daemon", "run", "--config", cfgPath}
	proc, err := os.StartProcess(exe, args, attr)
	if err != nil {
		return fmt.Errorf("start daemon process: %w", err)
	}
	pid := proc.Pid
	_ = proc.Release()

	// Poll up to 3s for socket to appear.
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if conn, err := net.DialTimeout("unix", sockPath, 200*time.Millisecond); err == nil {
			conn.Close()
			fmt.Printf("daemon started (pid %d)\n", pid)
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("daemon did not become ready in 3s; check %s", filepath.Join(logDir, "daemon.log"))
}

// runDaemonStop sends SIGTERM to the daemon via pid file and waits up to 5s.
func runDaemonStop(sockPath string) error {
	pidFile := sockPath + ".pid"
	pidBytes, err := os.ReadFile(pidFile)
	if err != nil {
		return fmt.Errorf("read pid file %s: %w (daemon may not be running)", pidFile, err)
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(pidBytes)))
	if err != nil {
		return fmt.Errorf("parse pid: %w", err)
	}

	if err := syscall.Kill(pid, syscall.SIGTERM); err != nil {
		if err == syscall.ESRCH {
			fmt.Println("daemon not running (stale pid file)")
			_ = os.Remove(pidFile)
			return nil
		}
		return fmt.Errorf("kill pid %d: %w", pid, err)
	}

	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if err := syscall.Kill(pid, 0); err == syscall.ESRCH {
			fmt.Printf("daemon stopped (pid %d)\n", pid)
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("daemon (pid %d) did not stop within 5s", pid)
}

func newDaemonCmd(cfgPath *string) *cobra.Command {
	cmd := &cobra.Command{Use: "daemon", Short: "manage the rca daemon"}

	// run: foreground daemon entry point (used internally by start)
	runCmd := &cobra.Command{
		Use:   "run",
		Short: "run daemon in foreground (used internally by start; you usually want 'start')",
		RunE: func(_ *cobra.Command, _ []string) error {
			cfg, err := config.Load(*cfgPath)
			if err != nil {
				return fmt.Errorf("load config: %w", err)
			}

			// Single-instance check via socket probe.
			if conn, err := net.DialTimeout("unix", cfg.SocketPath, 500*time.Millisecond); err == nil {
				conn.Close()
				fmt.Printf("daemon already running at %s\n", cfg.SocketPath)
				return nil
			}
			// Remove stale socket file if present.
			_ = os.Remove(cfg.SocketPath)

			// Write pid file.
			pidFile := cfg.SocketPath + ".pid"
			_ = os.WriteFile(pidFile, []byte(strconv.Itoa(os.Getpid())), 0644)
			defer os.Remove(pidFile)

			srv := daemon.New(cfg, Version)
			ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
			defer cancel()

			if err := srv.Serve(ctx); err != nil {
				return fmt.Errorf("serve: %w", err)
			}
			return nil
		},
	}

	// status: query daemon via HTTP
	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "show daemon status",
		RunE: func(_ *cobra.Command, _ []string) error {
			c, _, err := newClient(*cfgPath, false)
			if err != nil {
				return err
			}
			var resp protocol.StatusResponse
			if err := c.GetJSON("/status", &resp); err != nil {
				return err
			}
			b, _ := json.MarshalIndent(resp, "", "  ")
			fmt.Println(string(b))
			return nil
		},
	}

	// start: fork+setsid daemon
	startCmd := &cobra.Command{
		Use:   "start",
		Short: "start the daemon in the background",
		RunE: func(_ *cobra.Command, _ []string) error {
			cfg, err := config.Load(*cfgPath)
			if err != nil {
				return fmt.Errorf("load config: %w", err)
			}
			return runDaemonStart(*cfgPath, cfg.SocketPath, defaultLogDir())
		},
	}

	// stop: send SIGTERM via pid file
	stopCmd := &cobra.Command{
		Use:   "stop",
		Short: "stop the daemon",
		RunE: func(_ *cobra.Command, _ []string) error {
			cfg, err := config.Load(*cfgPath)
			if err != nil {
				return fmt.Errorf("load config: %w", err)
			}
			return runDaemonStop(cfg.SocketPath)
		},
	}

	// restart: stop then start
	restartCmd := &cobra.Command{
		Use:   "restart",
		Short: "restart the daemon",
		RunE: func(_ *cobra.Command, _ []string) error {
			cfg, err := config.Load(*cfgPath)
			if err != nil {
				return fmt.Errorf("load config: %w", err)
			}
			_ = runDaemonStop(cfg.SocketPath)
			return runDaemonStart(*cfgPath, cfg.SocketPath, defaultLogDir())
		},
	}

	// logs: tail the daemon log file
	logsCmd := func() *cobra.Command {
		var follow bool
		c := &cobra.Command{
			Use:   "logs",
			Short: "print daemon log",
			RunE: func(_ *cobra.Command, _ []string) error {
				logPath := filepath.Join(defaultLogDir(), "daemon.log")
				args := []string{}
				if follow {
					args = append(args, "-f")
				}
				args = append(args, logPath)
				e := exec.Command("tail", args...)
				e.Stdin, e.Stdout, e.Stderr = os.Stdin, os.Stdout, os.Stderr
				return e.Run()
			},
		}
		c.Flags().BoolVarP(&follow, "follow", "f", false, "follow log output")
		return c
	}()

	cmd.AddCommand(runCmd, statusCmd, startCmd, stopCmd, restartCmd, logsCmd)
	cmd.AddCommand(newRegisterCmd(cfgPath), newUnregisterCmd(cfgPath))
	return cmd
}
