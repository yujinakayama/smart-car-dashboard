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
  SemaphoreHandle_t lastDataMutex;

  WeatherSensor(gpio_num_t sdaPin, gpio_num_t sdlPin, float temperatureCalidation);
  bool isFound();
  void registerBridgedHomeKitAccessory();

  void startMonitoringSensor();
  void updateCharacteristicValues();
  void updateTemperatureCharacteristicValue(SensorData data);
  void updateRelativeHumidityCharacteristicValue(SensorData data);
  void updateAirPressureCharacteristicValue(SensorData data);
  SensorData getSensorData();

private:
  hap_char_t* temperatureCharacteristic;
  hap_char_t* relativeHumidityCharacteristic;
  hap_char_t* airPressureCharacteristic;

  void createAccessory();
  void addTemperatureSensorService();
  void addHumiditySensorService();
  void addAirPressureSensorService();
  void addFirmwareUpgradeService();
  bool hasValidLastSensorData();
  SensorData readSensorData();
};

