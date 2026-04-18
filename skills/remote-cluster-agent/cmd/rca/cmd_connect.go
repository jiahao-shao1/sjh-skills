package main

import (
	"fmt"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/protocol"
	"github.com/spf13/cobra"
)

func newConnectCmd(cfgPath *string) *cobra.Command {
	return &cobra.Command{
		Use:   "connect <node>",
		Short: "manually (re)connect a node (clears dead marker)",
		Args:  cobra.ExactArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			c, _, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			var resp map[string]string
			if err := c.PostJSON("/connect", protocol.ConnectRequest{Node: args[0]}, &resp, 0); err != nil {
				return err
			}
			fmt.Printf("%s: %s\n", resp["node"], resp["status"])
			return nil
		},
	}
}

func newDisconnectCmd(cfgPath *string) *cobra.Command {
	return &cobra.Command{
		Use:   "disconnect <node>",
		Short: "force close the connection to a node",
		Args:  cobra.ExactArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			c, _, err := newClient(*cfgPath, true)
			if err != nil {
				return err
			}
			var resp map[string]string
			if err := c.PostJSON("/disconnect", protocol.ConnectRequest{Node: args[0]}, &resp, 0); err != nil {
				return err
			}
			fmt.Printf("%s: %s\n", resp["node"], resp["status"])
			return nil
		},
	}
}
