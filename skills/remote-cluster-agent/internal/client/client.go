// Package client wraps HTTP-over-Unix-socket calls from the rca CLI
// to the rca daemon.
package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

type Client struct {
	sockPath    string
	http        *http.Client
	onDialFail  func() error // optional: called once on connection failure, then retried
}

// New creates a client for the given Unix socket path.
// onDialFail is called when a request fails due to a connection error;
// after it returns the request is retried once. Pass nil to disable auto-spawn.
func New(sockPath string, onDialFail func() error) *Client {
	tr := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", sockPath)
		},
	}
	return &Client{
		sockPath:   sockPath,
		http:       &http.Client{Transport: tr, Timeout: 0},
		onDialFail: onDialFail,
	}
}

// GetJSON issues a GET and decodes JSON into out.
func (c *Client) GetJSON(path string, out any) error {
	return c.do("GET", path, nil, out, 0)
}

// PostJSON sends body as JSON and decodes response into out. timeout=0 means no timeout.
func (c *Client) PostJSON(path string, body any, out any, timeout time.Duration) error {
	return c.do("POST", path, body, out, timeout)
}

// PostStream POSTs body and streams the response body to cb line by line.
func (c *Client) PostStream(path string, body any, cb func(line []byte) error) error {
	buf, err := json.Marshal(body)
	if err != nil {
		return err
	}
	resp, err := c.postStreamOnce(path, buf)
	if err != nil {
		if c.onDialFail != nil && isConnErr(err) {
			if spawnErr := c.onDialFail(); spawnErr != nil {
				return fmt.Errorf("auto-spawn failed: %w", spawnErr)
			}
			resp, err = c.postStreamOnce(path, buf)
		}
		if err != nil {
			return fmt.Errorf("daemon request failed (is rca daemon running? try: rca daemon start): %w", err)
		}
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("daemon returned %d: %s", resp.StatusCode, string(b))
	}
	dec := json.NewDecoder(resp.Body)
	for {
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}
		if err := cb(raw); err != nil {
			return err
		}
	}
}

func (c *Client) postStreamOnce(path string, buf []byte) (*http.Response, error) {
	req, err := http.NewRequest("POST", "http://unix"+path, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	return c.http.Do(req)
}

func (c *Client) do(method, path string, body any, out any, timeout time.Duration) error {
	var buf []byte
	if body != nil {
		var err error
		buf, err = json.Marshal(body)
		if err != nil {
			return err
		}
	}
	resp, err := c.doOnce(method, path, buf, timeout)
	if err != nil {
		if c.onDialFail != nil && isConnErr(err) {
			if spawnErr := c.onDialFail(); spawnErr != nil {
				return fmt.Errorf("auto-spawn failed: %w", spawnErr)
			}
			resp, err = c.doOnce(method, path, buf, timeout)
		}
		if err != nil {
			return fmt.Errorf("daemon request failed (is rca daemon running? try: rca daemon start): %w", err)
		}
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return fmt.Errorf("daemon returned %d: %s", resp.StatusCode, string(raw))
	}
	if out != nil {
		return json.Unmarshal(raw, out)
	}
	return nil
}

func (c *Client) doOnce(method, path string, buf []byte, timeout time.Duration) (*http.Response, error) {
	var rdr io.Reader
	if buf != nil {
		rdr = bytes.NewReader(buf)
	}
	ctx := context.Background()
	if timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, timeout)
		defer cancel()
	}
	req, err := http.NewRequestWithContext(ctx, method, "http://unix"+path, rdr)
	if err != nil {
		return nil, err
	}
	if buf != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return c.http.Do(req)
}

// isConnErr returns true for socket-level connection errors (daemon not running).
func isConnErr(err error) bool {
	if err == nil {
		return false
	}
	s := err.Error()
	return strings.Contains(s, "connection refused") ||
		strings.Contains(s, "no such file or directory") ||
		strings.Contains(s, "connect: no such file")
}
