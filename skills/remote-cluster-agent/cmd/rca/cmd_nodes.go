package main

import (
	"encoding/json"
	"fmt"
	"os"
	"text/tabwriter"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/client"
	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
	"github.com/spf13/cobra"
)

func newNodesCmd(cfgPath *string) *cobra.Command {
	var check bool
	var health bool
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "nodes",
		Short: "list configured nodes and connection status",
		RunE: func(_ *cobra.Command, _ []string) error {
			c, _, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			if health {
				return showHealth(c, asJSON)
			}
			path := "/nodes"
			if check {
				path = "/nodes?check=true"
			}
			var infos []protocol.NodeInfo
			if err := c.GetJSON(path, &infos); err != nil {
				return err
			}
			if asJSON {
				b, _ := json.MarshalIndent(infos, "", "  ")
				fmt.Println(string(b))
				return nil
			}
			tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
			fmt.Fprintln(tw, "NAME\tSTATUS\tAGENT\tLATENCY")
			for _, i := range infos {
				lat := "-"
				if i.Latency > 0 {
					lat = fmt.Sprintf("%dms", i.Latency)
				}
				agent := i.Agent
				if agent == "" {
					agent = "-"
				}
				fmt.Fprintf(tw, "%s\t%s\t%s\t%s\n", i.Name, i.Status, agent, lat)
			}
			return tw.Flush()
		},
	}
	cmd.Flags().BoolVar(&check, "check", false, "ping each connected agent")
	cmd.Flags().BoolVar(&health, "health", false, "show monitor health stats (latency history)")
	cmd.Flags().BoolVar(&asJSON, "json", false, "emit JSON result")
	return cmd
}

func showHealth(c *client.Client, asJSON bool) error {
	var items []protocol.NodeHealth
	if err := c.GetJSON("/nodes/health", &items); err != nil {
		return err
	}
	if asJSON {
		b, _ := json.MarshalIndent(items, "", "  ")
		fmt.Println(string(b))
		return nil
	}
	tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(tw, "NAME\tSTATUS\tLATENCY\tMEDIAN\tSAMPLES\tNOTE")
	for _, h := range items {
		lat := "-"
		if h.CurrentLatency > 0 {
			lat = fmt.Sprintf("%dms", h.CurrentLatency)
		}
		med := "-"
		if h.MedianLatency > 0 {
			med = fmt.Sprintf("%dms", h.MedianLatency)
		}
		samples := "-"
		if h.Samples > 0 {
			samples = fmt.Sprintf("%d", h.Samples)
		}
		note := ""
		if h.LastReconnect != nil {
			ago := time.Since(*h.LastReconnect).Truncate(time.Second)
			note = fmt.Sprintf("reconnected %s ago", ago)
		}
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\t%s\n", h.Name, h.Status, lat, med, samples, note)
	}
	return tw.Flush()
}
