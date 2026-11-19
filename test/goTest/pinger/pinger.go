package pinger

import (
	"errors"
	"fmt"
	"os/exec"
)

func Pinger(dstIP string, nic string) error {
	cmd := exec.Command("ping", "-I", nic, "-c", "3", "-s", "300", dstIP)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ping failed: %w, output: %s", err, output)
	}

	return nil
}

// NoReplies distinguishes an iputils ping with zero replies (exit 1) from
// local execution errors such as an invalid interface or missing binary.
func NoReplies(err error) bool {
	var status *exec.ExitError
	return errors.As(err, &status) && status.ExitCode() == 1
}
