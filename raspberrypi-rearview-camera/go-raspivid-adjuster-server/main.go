package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"reflect"
	"strings"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/raspivid-options", func(response http.ResponseWriter, request *http.Request) {
		if request.Method != "PUT" {
			response.WriteHeader(404)
			return
		}

		options, err := parseRequest(request)
		if err != nil {
			response.WriteHeader(400)
			return
		}

		if err := updateScriptIfNeeded(options); err != nil {
			response.WriteHeader(500)
			return
		}

		response.WriteHeader(204)
	})

	err := http.ListenAndServe(":5002", mux)
	log.Fatal(err)
}

func parseRequest(request *http.Request) (*RaspividOptions, error) {
	var options RaspividOptions
	decoder := json.NewDecoder(request.Body)
	if err := decoder.Decode(&options); err != nil {
		return nil, err
	}
	return &options, nil
}

func updateScriptIfNeeded(options *RaspividOptions) error {
	script := generateScript(options)
	scriptPath := getEnv("RASPIVID_SCRIPT_PATH", "/opt/bin/raspivid-server")

	shouldUpdateScript, err := shouldUpdateScript(scriptPath, script)
	if err != nil {
		return err
	}
	if !shouldUpdateScript {
		return nil
	}

	return os.WriteFile(scriptPath, []byte(script), 0755)
}

func generateScript(options *RaspividOptions) string {
	defaultArgs := []string{"--nopreview", "--output", "tcp://0.0.0.0:5001", "--listen", "--timeout", "0", "--flush"}
	allArgs := append(defaultArgs, options.ToCLIArgs()...)

	lines := []string{
		"#!/bin/sh",
		"",
		fmt.Sprintf("raspivid %s", strings.Join(allArgs, " ")),
	}

	return strings.Join(lines, "\n")
}

func getEnv(key string, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	} else {
		return value
	}
}

func shouldUpdateScript(path string, newContent string) (bool, error) {
	if !fileExists(path) {
		return true, nil
	}

	oldContent, err := os.ReadFile(path)
	if err != nil {
		return false, err
	}

	return newContent != string(oldContent), nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// TODO: Validate values
type RaspividOptions struct {
	Sharpness   *int     `json:"sharpness"`
	Contrast    *int     `json:"contrast"`
	Brightness  *int     `json:"brightness"`
	Saturation  *int     `json:"saturation"`
	ISO         *int     `json:"ISO"`
	Vstab       *bool    `json:"vstab"`
	Ev          *int     `json:"ev"`
	Exposure    *string  `json:"exposure"`
	Flicker     *string  `json:"flicker"`
	Awb         *string  `json:"awb"`
	Imxfx       *string  `json:"imxfx"`
	Colfx       *string  `json:"colfx"`
	Metering    *string  `json:"metering"`
	Rotation    *int     `json:"rotation"`
	Hflip       *bool    `json:"hflip"`
	Vflip       *bool    `json:"vflip"`
	Roi         *string  `json:"roi"`
	Shutter     *int     `json:"shutter"`
	Drc         *string  `json:"drc"`
	Stats       *bool    `json:"stats"`
	Awbgains    *string  `json:"awbgains"`
	Analoggain  *float64 `json:"analoggain"`
	Digitalgain *float64 `json:"digitalgain"`
	Mode        *int     `json:"mode"`
	Width       *int     `json:"width"`
	Height      *int     `json:"height"`
	Bitrate     *int     `json:"bitrate"`
	Framerate   *int     `json:"framerate"`
	Intra       *int     `json:"intra"`
	Qp          *int     `json:"qp"`
	Profile     *string  `json:"profile"`
	Level       *string  `json:"level"`
	Irefresh    *string  `json:"irefresh"`
	Inline      *bool    `json:"inline"`
	Spstimings  *bool    `json:"spstimings"`
}

func (options RaspividOptions) ToCLIArgs() []string {
	args := []string{}

	typeReflection := reflect.TypeOf(options)
	instanceReflection := reflect.ValueOf(options)

	for i := 0; i < instanceReflection.NumField(); i++ {
		fieldValuePointer := instanceReflection.Field(i)

		if fieldValuePointer.IsNil() {
			continue
		}

		fieldValue := fieldValuePointer.Elem().Interface()
		fieldName := typeReflection.Field(i).Tag.Get("json")

		if fieldValue == true {
			args = append(args, fmt.Sprintf("--%s", fieldName))
		} else {
			args = append(args, fmt.Sprintf("--%s", fieldName), fmt.Sprintf("%v", fieldValue))
		}
	}

	return args
}
