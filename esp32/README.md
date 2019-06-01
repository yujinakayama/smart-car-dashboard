## Requirements

* [ESP-IDF](https://github.com/espressif/esp-idf) v3.2
    * `(cd "$IDF_PATH" && git describe --tags --dirty)`
* [Arduino core for the ESP32](https://github.com/espressif/arduino-esp32) v1.0.2
    * Managed with git submodule

## Project Configuration

[ESP-IDF project using arduino-esp32 as a component](https://github.com/espressif/arduino-esp32/blob/master/docs/esp-idf_component.md)

* Run `make flash monitor` to build project, upload to device, and open serial monitor
