// Package daemon implements the rca daemon HTTP server over Unix domain socket.
package daemon

import (
	"context"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/jiahao-shao1/sjh-skills/skills/remote-cluster-agent/internal/config"
)

type Server struct {
	cfg       *config.Config
	version   string
	startTime time.Time
	pool      *Pool
	monitor   *Monitor
	httpSrv   *http.Server
	listener  net.Listener
}

func New(cfg *config.Config, version string) *Server {
	pool := NewPool(cfg)
	return &Server{
		cfg:       cfg,
		version:   version,
		startTime: time.Now(),
		pool:      pool,
		monitor:   NewMonitor(pool, cfg.Monitor),
	}
}

func (s *Server) routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /status", s.handleStatus)
	mux.HandleFunc("POST /exec", s.handleExec)
	mux.HandleFunc("POST /batch", s.handleBatch)
	mux.HandleFunc("GET /nodes", s.handleNodes)
	mux.HandleFunc("POST /connect", s.handleConnect)
	mux.HandleFunc("POST /disconnect", s.handleDisconnect)
	mux.HandleFunc("POST /transfer", s.handleTransfer)
	mux.HandleFunc("GET /nodes/health", s.handleNodesHealth)
	return mux
}

// Serve starts the HTTP server on the Unix socket specified in config.
// Blocks until ctx is cancelled.
func (s *Server) Serve(ctx context.Context) error {
	sockPath := s.cfg.SocketPath
	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(sockPath), 0755); err != nil {
		return err
	}
	// Remove stale socket
	if _, err := os.Stat(sockPath); err == nil {
		if err := os.Remove(sockPath); err != nil {
			return err
		}
	}
	ln, err := net.Listen("unix", sockPath)
	if err != nil {
		return err
	}
	s.listener = ln
	if err := os.Chmod(sockPath, 0600); err != nil {
		return err
	}

	s.httpSrv = &http.Server{Handler: s.routes()}

	go s.monitor.Start(ctx)

	errCh := make(chan error, 1)
	go func() { errCh <- s.httpSrv.Serve(ln) }()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = s.httpSrv.Shutdown(shutdownCtx)
		s.pool.CloseAll()
		_ = os.Remove(sockPath)
		return nil
	case err := <-errCh:
		if err == http.ErrServerClosed {
			return nil
		}
		return err
	}
}
