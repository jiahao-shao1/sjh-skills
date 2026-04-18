// Package config loads and validates the rca TOML configuration.
package config

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
)

type Config struct {
	DefaultNode string                 `toml:"default_node"`
	DefaultDir  string                 `toml:"default_dir"`
	AgentPath   string                 `toml:"agent_path"`
	LogLevel    string                 `toml:"log_level"`
	SocketPath  string                 `toml:"socket_path"`
	SSH         SSHConfig              `toml:"ssh"`
	Monitor     MonitorConfig          `toml:"monitor"`
	Nodes       map[string]NodeConfig  `toml:"nodes"`
	Projects    map[string]ProjectConf `toml:"projects"`
}

type MonitorConfig struct {
	Enabled          bool    `toml:"enabled"`
	Interval         int     `toml:"interval"`          // ping interval in seconds
	LatencyThreshold int     `toml:"latency_threshold"` // absolute threshold in ms
	LatencyMultiplier float64 `toml:"latency_multiplier"` // relative threshold: median × N
	AutoReconnect    bool    `toml:"auto_reconnect"`
}

type SSHConfig struct {
	AliveInterval int   `toml:"alive_interval"`
	AliveCountMax int   `toml:"alive_count_max"`
	MaxRetries    int   `toml:"max_retries"`
	RetryBackoff  []int `toml:"retry_backoff"`
}

type NodeConfig struct {
	SSH       string `toml:"ssh"`
	Dir       string `toml:"dir"`
	AgentPath string `toml:"agent_path"`
}

// EffectiveAgentPath returns the node-level agent_path if set, otherwise the global one.
func (nc NodeConfig) EffectiveAgentPath(global string) string {
	if nc.AgentPath != "" {
		return nc.AgentPath
	}
	return global
}

// EffectiveDir returns the node-level dir if set, otherwise the global one.
func (nc NodeConfig) EffectiveDir(global string) string {
	if nc.Dir != "" {
		return nc.Dir
	}
	return global
}

type ProjectConf struct {
	Dir         string `toml:"dir"`
	DefaultNode string `toml:"default_node"`
}

func DefaultPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config/rca/config.toml")
}

func ExpandHome(p string) string {
	if !strings.HasPrefix(p, "~/") {
		return p
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, p[2:])
}

func Load(path string) (*Config, error) {
	var c Config
	if _, err := toml.DecodeFile(path, &c); err != nil {
		return nil, err
	}
	// Defaults
	if c.SSH.AliveInterval == 0 {
		c.SSH.AliveInterval = 30
	}
	if c.SSH.AliveCountMax == 0 {
		c.SSH.AliveCountMax = 3
	}
	if c.SSH.MaxRetries == 0 {
		c.SSH.MaxRetries = 3
	}
	if len(c.SSH.RetryBackoff) == 0 {
		c.SSH.RetryBackoff = []int{2, 4, 8}
	}
	if c.Monitor.Interval == 0 {
		c.Monitor.Enabled = true
		c.Monitor.Interval = 30
		c.Monitor.LatencyThreshold = 200
		c.Monitor.LatencyMultiplier = 3.0
		c.Monitor.AutoReconnect = true
	}
	if c.SocketPath == "" {
		c.SocketPath = "~/.config/rca/rca.sock"
	}
	if c.LogLevel == "" {
		c.LogLevel = "info"
	}
	c.SocketPath = ExpandHome(c.SocketPath)
	c.AgentPath = ExpandHome(c.AgentPath)
	return &c, nil
}
