## Requirements

### Hardware

* [ESP32-DevKitC](https://www.espressif.com/en/products/hardware/esp32-devkitc/overview)

### Software

* [ESP-IDF](https://github.com/espressif/esp-idf) master (`v4.3-dev-1197-g8bc19ba89-dirty`)
    * Check the version with `(cd "$IDF_PATH" && git describe --tags --dirty)`

## Project Configuration

[ESP-IDF project using arduino-esp32 as a component](https://github.com/espressif/arduino-esp32/blob/master/docs/esp-idf_component.md)

* Run `idf.py --port /dev/cu.SLAB_USBtoUART flash monitor` to build the project, upload to the ESP32-DevKitC, and open the serial monitor

## Schematic

TODO
