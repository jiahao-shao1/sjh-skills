package protocol

import (
	"encoding/json"
	"testing"
)

func TestExecRequestJSON(t *testing.T) {
	r := ExecRequest{Node: "node3", Cmd: "ls", Dir: "/tmp", Timeout: 60, Stream: false}
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	var got ExecRequest
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatal(err)
	}
	if got != r {
		t.Fatalf("roundtrip mismatch: %+v != %+v", got, r)
	}
}

func TestExecResponseJSON(t *testing.T) {
	r := ExecResponse{Node: "node3", ExitCode: 0, Output: "ok", Elapsed: 0.08}
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	var got ExecResponse
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatal(err)
	}
	if got != r {
		t.Fatalf("roundtrip mismatch: %+v != %+v", got, r)
	}
}
