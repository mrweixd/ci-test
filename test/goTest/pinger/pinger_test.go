package pinger

import (
	"os/exec"
	"testing"
)

func TestPinger(t *testing.T) {
	err := Pinger("8.8.8.8", "ens33")
	if err != nil {
		t.Errorf("Pinger failed: %v", err)
	}
}

func TestNoReplies(t *testing.T) {
	for _, tc := range []struct {
		name    string
		command string
		want    bool
	}{
		{"reachable", "exit 0", false},
		{"no replies", "exit 1", true},
		{"ping error", "exit 2", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := exec.Command("sh", "-c", tc.command).Run()
			if got := NoReplies(err); got != tc.want {
				t.Errorf("NoReplies(%v) = %v, want %v", err, got, tc.want)
			}
		})
	}
	if NoReplies(exec.ErrNotFound) {
		t.Error("missing ping treated as no replies")
	}
}
