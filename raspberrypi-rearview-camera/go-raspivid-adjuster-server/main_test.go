package main

import (
	"testing"

	"github.com/samber/lo"
	"github.com/stretchr/testify/require"
)

func TestRaspividOptions(t *testing.T) {
	options := &RaspividOptions{
		Sharpness: lo.ToPtr(100),
		ISO:       lo.ToPtr(200),
		Exposure:  lo.ToPtr("auto"),
		Hflip:     lo.ToPtr(true),
	}

	require.Equal(t, []string{"--sharpness", "100", "--ISO", "200", "--exposure", "auto", "--hflip"}, options.ToCLIArgs())
}
