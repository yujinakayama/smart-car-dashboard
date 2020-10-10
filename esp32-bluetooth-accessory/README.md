## Requirements

### Hardware

* [ESP32-DevKitC](https://www.espressif.com/en/products/hardware/esp32-devkitc/overview)

### Software

* [ESP-IDF](https://github.com/espressif/esp-idf) v3.2 (not v3.2.x)
    * Check the version with `(cd "$IDF_PATH" && git describe --tags --dirty)`
* [Arduino core for the ESP32](https://github.com/espressif/arduino-esp32) v1.0.4
    * Managed with git submodule under `components/arduino`

## Project Configuration

[ESP-IDF project using arduino-esp32 as a component](https://github.com/espressif/arduino-esp32/blob/master/docs/esp-idf_component.md)

* Run `make flash monitor` to build the project, upload to the ESP32-DevKitC, and open the serial monitor

## Schematic

TODO
