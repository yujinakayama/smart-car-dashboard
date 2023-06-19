.PHONY: raspberry-build

.DEFAULT_GOAL := raspberry-build

raspberry-build:
	env GOOS=linux GOARCH=arm GOARM=7 go build -o build/raspivid-adjuster-server
