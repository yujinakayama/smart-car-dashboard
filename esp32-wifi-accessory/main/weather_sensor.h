#pragma once

#include <hap.h>
#include <driver/gpio.h>
#include "bmp280.h"

typedef struct {
  unsigned long time; // In milliseconds
  float temperature;
  float humidity;
  float pressure; // In Pa (pascal)
} SensorData;

class WeatherSensor {
public:
  bmp280_t* bmp280;
  hap_acc_t* accessory;
  float temperatureCalidation;
  SensorData lastData;

  WeatherSensor(gpio_num_t sdaPin, gpio_num_t sdlPin, float temperatureCalidation);
  void registerBridgedHomeKitAccessory();

  SensorData getData();

private:
  void createAccessory();
  void addTemperatureSensorService();
  void addHumiditySensorService();
  void addFirmwareUpgradeService();
  bool hasValidLastData();
  SensorData readData();
};

