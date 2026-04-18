# RCA daemon Makefile
GOPATH_BIN := $(shell go env GOPATH)/bin
LOG_DIR := $(HOME)/Library/Logs/rca
CONFIG_DIR := $(HOME)/.config/rca

.PHONY: all build install uninstall test clean

all: build

build:
	go build -o $(GOPATH_BIN)/rca ./cmd/rca

test:
	go test ./...

install: build
	mkdir -p $(LOG_DIR) $(CONFIG_DIR)
	@echo "Installed:"
	@echo "  rca -> $(GOPATH_BIN)/rca"
	@echo "  logs  -> $(LOG_DIR)/daemon.log"
	@echo ""
	@echo "Start daemon:    rca daemon start"
	@echo "Auto-start:      rca daemon register  (optional, requires App Management permission)"
	@echo "Check status:    rca daemon status"

uninstall:
	rm -f $(GOPATH_BIN)/rca

clean:
	rm -f rca
