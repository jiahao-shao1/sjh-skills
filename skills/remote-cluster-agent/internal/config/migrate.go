package config

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Migrate reads legacy markdown config files from srcDir and writes a TOML
// config to outPath. The output includes comments describing what came from
// which file. Legacy files are left in place.
func Migrate(srcDir, outPath string) error {
	ctxPath := filepath.Join(srcDir, "context.local.md")
	globals := map[string]string{}
	nodes := map[string]string{} // node name -> ssh cmd
	if _, err := os.Stat(ctxPath); err == nil {
		g, n, err := parseLegacyContext(ctxPath)
		if err != nil {
			return fmt.Errorf("parse %s: %w", ctxPath, err)
		}
		globals = g
		nodes = n
	}
	projects := map[string]map[string]string{}
	entries, _ := os.ReadDir(srcDir)
	for _, e := range entries {
		if e.IsDir() || e.Name() == "context.local.md" || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		name := strings.TrimSuffix(e.Name(), ".md")
		p, err := parseLegacyProject(filepath.Join(srcDir, e.Name()))
		if err != nil {
			continue
		}
		projects[name] = p
	}

	if err := os.MkdirAll(filepath.Dir(outPath), 0755); err != nil {
		return err
	}
	f, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer f.Close()

	fmt.Fprintf(f, "# rca config\n")
	fmt.Fprintf(f, "# migrated from %s on %s\n\n", srcDir, time.Now().Format("2006-01-02"))

	writeKV(f, "default_node", globals["default_node"], "train")
	writeKV(f, "default_dir", globals["default_dir"], "/home/user/project")
	writeKV(f, "agent_path", globals["agent_path"], "/shared/.agent/agent.py")
	writeKV(f, "log_level", globals["log_level"], "info")
	writeKV(f, "socket_path", globals["socket_path"], "~/.config/rca/rca.sock")
	fmt.Fprintln(f)
	fmt.Fprintln(f, "[ssh]")
	fmt.Fprintln(f, "alive_interval = 30")
	fmt.Fprintln(f, "alive_count_max = 3")
	fmt.Fprintln(f, "max_retries = 3")
	fmt.Fprintln(f, "retry_backoff = [2, 4, 8]")
	fmt.Fprintln(f)

	// Deterministic order
	ns := make([]string, 0, len(nodes))
	for n := range nodes {
		ns = append(ns, n)
	}
	sortStrings(ns)
	for _, n := range ns {
		fmt.Fprintf(f, "[nodes.%s]\n", n)
		fmt.Fprintf(f, "ssh = %q\n\n", nodes[n])
	}

	ps := make([]string, 0, len(projects))
	for p := range projects {
		ps = append(ps, p)
	}
	sortStrings(ps)
	for _, p := range ps {
		fmt.Fprintf(f, "[projects.%s]\n", p)
		if d, ok := projects[p]["dir"]; ok {
			fmt.Fprintf(f, "dir = %q\n", d)
		}
		if n, ok := projects[p]["default_node"]; ok {
			fmt.Fprintf(f, "default_node = %q\n", n)
		}
		fmt.Fprintln(f)
	}
	return nil
}

func writeKV(w *os.File, key, val, fallback string) {
	v := val
	if v == "" {
		v = fallback
	}
	fmt.Fprintf(w, "%s = %q\n", key, v)
}

// parseLegacyContext parses keys from front matter + a `## Nodes` section.
func parseLegacyContext(path string) (globals, nodes map[string]string, _ error) {
	globals = map[string]string{}
	nodes = map[string]string{}
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	inNodes := false
	var curNode string
	for sc.Scan() {
		line := sc.Text()
		t := strings.TrimSpace(line)
		if t == "" {
			continue
		}
		if strings.HasPrefix(t, "##") {
			inNodes = strings.Contains(strings.ToLower(t), "nodes")
			continue
		}
		if inNodes {
			// "- name: nodeX"  or  "  ssh: ssh -p ..."
			if strings.HasPrefix(t, "- ") {
				t = strings.TrimPrefix(t, "- ")
			}
			k, v := splitKV(t)
			switch k {
			case "name":
				curNode = v
			case "ssh":
				if curNode != "" {
					nodes[curNode] = v
				}
			}
		} else {
			k, v := splitKV(t)
			if k != "" {
				globals[k] = v
			}
		}
	}
	return globals, nodes, nil
}

func parseLegacyProject(path string) (map[string]string, error) {
	out := map[string]string{}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		k, v := splitKV(strings.TrimSpace(sc.Text()))
		if k != "" {
			out[k] = v
		}
	}
	return out, nil
}

// splitKV splits "k: v" or "k = v".
func splitKV(s string) (string, string) {
	sep := ""
	if strings.Contains(s, ":") {
		sep = ":"
	} else if strings.Contains(s, "=") {
		sep = "="
	}
	if sep == "" {
		return "", ""
	}
	idx := strings.Index(s, sep)
	k := strings.TrimSpace(s[:idx])
	v := strings.TrimSpace(s[idx+1:])
	v = strings.Trim(v, "\"'")
	// Reject markdown-ish lines (start with # etc.)
	if strings.HasPrefix(k, "#") {
		return "", ""
	}
	return k, v
}

// sortStrings: local copy to avoid import of daemon package.
func sortStrings(s []string) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1] > s[j]; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}
