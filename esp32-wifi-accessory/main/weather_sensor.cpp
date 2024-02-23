#include "log_config.h"
#include "weather_sensor.h"

#include <hap_apple_servs.h>
#include <hap_apple_chars.h>
#include <hap_fw_upgrade.h>

#include "hap_custom_servs.h"
#include "hap_custom_chars.h"

#include <cstring>
#include <freertos/semphr.h>

extern "C" {
  #include "math.h"
  #include "util.h"
}

static const char* TAG = "WeatherSensor";

static const char* kSetupID = "WTHR"; // This must be unique

static const char* kTemperatureSensorServiceName = "Temperature Sensor";
static const char* kHumiditySensorServiceName = "Humidity Sensor";
static const char* kAirPressureSensorServiceName = "Air Pressure Sensor";

static int identifyAccessory(hap_acc_t* ha);
void monitoringTask(void* arg);
static int readTemperatureSensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int readHumiditySensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int readAirPressureSensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);

bmp280_t* initBMP280(gpio_num_t sdaPin, gpio_num_t sdlPin) {
  ESP_ERROR_CHECK(i2cdev_init());

  bmp280_t* bmp280 = (bmp280_t*)malloc(sizeof(bmp280_t));
  memset(bmp280, 0, sizeof(bmp280_t));
  ESP_ERROR_CHECK(bmp280_init_desc(bmp280, BMP280_I2C_ADDRESS_0, I2C_NUM_0, sdaPin, sdlPin));

  // https://community.bosch-sensortec.com/t5/Knowledge-base/BME280-Sensor-Data-Interpretation/ta-p/13912
  bmp280_params_t params = {
    .mode = BMP280_MODE_NORMAL,
    .filter = BMP280_FILTER_4, // coefficient X means: currentValue = (prevValue * (X - 1) + sensorData) / X
    .oversampling_pressure = BMP280_HIGH_RES,
    .oversampling_temperature = BMP280_HIGH_RES,
    .oversampling_humidity = BMP280_HIGH_RES,
    .standby = BMP280_STANDBY_250
  };

  if (bmp280_init(bmp280, &params) == ESP_OK) {
    // Sensor found
    return bmp280;
  } else {
    ESP_LOGE(TAG, "bmp280_init() failed. WeatherSensor cannot be used.");
    // Sensor not found
    return NULL;
  }
}

WeatherSensor::WeatherSensor(gpio_num_t sdaPin, gpio_num_t sdlPin, float temperatureCalidation) {
  this->bmp280 = initBMP280(sdaPin, sdlPin);
  this->temperatureCalidation = temperatureCalidation;
  memset(&this->lastData, 0, sizeof(SensorData));
  this->lastDataMutex = xSemaphoreCreateMutex();
}

bool WeatherSensor::isFound() {
  return this->bmp280 != NULL;
}

void WeatherSensor::registerBridgedHomeKitAccessory() {
  ESP_LOGI(TAG, "registerBridgedHomeKitAccessory");

  this->createAccessory();
  this->addTemperatureSensorService();
  this->addHumiditySensorService();
  this->addAirPressureSensorService();
  this->addFirmwareUpgradeService();
  /* Add the Accessory to the HomeKit Database */
  hap_add_bridged_accessory(this->accessory, hap_get_unique_aid(kSetupID));
}

void WeatherSensor::createAccessory() {
  /* Initialise the mandatory parameters for Accessory which will be added as
   * the mandatory services internally
   */
  hap_acc_cfg_t config = {
    .name = (char*)"Weather Sensor",
    .model = (char*)"Model",
    .manufacturer = (char*)"Yuji Nakayama",
    .serial_num = (char*)"Serial Number",
    .fw_rev = (char*)"Firmware Version",
    .hw_rev = NULL,
    .pv = (char*)"1.0.0",
    .cid = HAP_CID_SENSOR,
    .identify_routine = identifyAccessory,
  };

  /* Create accessory object */
  this->accessory = hap_acc_create(&config);

  /* Add a dummy Product Data */
  uint8_t product_data[] = {'E','S','P','3','2','H','A','P'};
  hap_acc_add_product_data(accessory, product_data, sizeof(product_data));
}

void WeatherSensor::addTemperatureSensorService() {
  /*
    Create a temperature sensor service with initial temperature value.
    Include the "name" since this is a user visible service.
   */
  hap_serv_t* service = hap_serv_temperature_sensor_with_negative_value_create(0);

  hap_serv_add_char(service, hap_char_name_create(strdup(kTemperatureSensorServiceName)));

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readTemperatureSensorCharacteristic);

  // Allow access to WeatherSensor instance from the read/write callbacks
  hap_serv_set_priv(service, this);

  /* Add the sensor service to the accessory object */
  hap_acc_add_serv(this->accessory, service);

  this->temperatureCharacteristic = hap_serv_get_char_by_uuid(service, HAP_CHAR_UUID_CURRENT_TEMPERATURE);
}

void WeatherSensor::addHumiditySensorService() {
  /*
    Create a temperature sensor service with initial humidity value.
    Include the "name" since this is a user visible service.
   */
  hap_serv_t* service = hap_serv_humidity_sensor_create(0);

  hap_serv_add_char(service, hap_char_name_create(strdup(kHumiditySensorServiceName)));

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readHumiditySensorCharacteristic);

  // Allow access to WeatherSensor instance from the read/write callbacks
  hap_serv_set_priv(service, this);

  /* Add the sensor service to the accessory object */
  hap_acc_add_serv(this->accessory, service);

  this->relativeHumidityCharacteristic = hap_serv_get_char_by_uuid(service, HAP_CHAR_UUID_CURRENT_RELATIVE_HUMIDITY);
}

void WeatherSensor::addAirPressureSensorService() {
  /*
    Create a temperature sensor service with initial humidity value.
    Include the "name" since this is a user visible service.
   */
  hap_serv_t* service = hap_serv_air_pressure_sensor_create(0);

  hap_serv_add_char(service, hap_char_name_create(strdup(kAirPressureSensorServiceName)));

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readAirPressureSensorCharacteristic);

  // Allow access to WeatherSensor instance from the read/write callbacks
  hap_serv_set_priv(service, this);

  /* Add the sensor service to the accessory object */
  hap_acc_add_serv(this->accessory, service);

  this->airPressureCharacteristic = hap_serv_get_char_by_uuid(service, HAP_CHAR_UUID_CURRENT_AIR_PRESSURE);
}

/* Create the Firmware Upgrade HomeKit Custom Service.
 * Please refer the FW Upgrade documentation under components/homekit/extras/include/hap_fw_upgrade.h
 * and the top level README for more information.
 */
void WeatherSensor::addFirmwareUpgradeService() {
  /*  Required for server verification during OTA, PEM format as string  */
  char server_cert[] = {};

  hap_fw_upgrade_config_t ota_config = {
      .server_cert_pem = server_cert,
  };

  hap_serv_t* service = hap_serv_fw_upgrade_create(&ota_config);

  /* Add the service to the Accessory Object */
  hap_acc_add_serv(accessory, service);
}

void WeatherSensor::startMonitoringSensor() {
  esp_timer_create_args_t args = {
    .callback = &monitoringTask,
    .arg = this,
    .name = "updateData" // name is optional, but may help identify the timer when debugging
  };

  esp_timer_handle_t timer;
  ESP_ERROR_CHECK(esp_timer_create(&args, &timer));
  ESP_ERROR_CHECK(esp_timer_start_periodic(timer, 1 * 1000 * 1000)); // every second
}

void monitoringTask(void* arg) {
  WeatherSensor* sensor = (WeatherSensor*)arg;
  sensor->updateCharacteristicValues();
}

void WeatherSensor::updateCharacteristicValues() {
  SensorData data = this->getSensorData();
  this->updateTemperatureCharacteristicValue(data);
  this->updateRelativeHumidityCharacteristicValue(data);
  this->updateAirPressureCharacteristicValue(data);
}

void WeatherSensor::updateTemperatureCharacteristicValue(SensorData data) {
  hap_val_t value;
  // Round value with 0.5 step so that small changes won't be notified in HomeKit
  // to prevent wasteful Wi-Fi communication.
  // https://github.com/espressif/esp-homekit-sdk/blob/bd236e710c658d3bea47bbcc0fb0ce6c80171527/components/homekit/esp_hap_core/src/esp_hap_char.c#L195-L200
  value.f = round(data.temperature * 2) / 2;
  hap_char_update_val(this->temperatureCharacteristic, &value);
}

void WeatherSensor::updateRelativeHumidityCharacteristicValue(SensorData data) {
  hap_val_t value;
  value.f = round(data.humidity);
  hap_char_update_val(this->relativeHumidityCharacteristic, &value);
}

void WeatherSensor::updateAirPressureCharacteristicValue(SensorData data) {
  hap_val_t value;
  // Round to hPa
  value.f = round(data.pressure / 100) * 100;
  hap_char_update_val(this->airPressureCharacteristic, &value);
}

SensorData WeatherSensor::getSensorData() {
  xSemaphoreTake(this->lastDataMutex, 100 / portTICK_PERIOD_MS);
  if (!this->hasValidLastSensorData()) {
    this->lastData = this->readSensorData();
  }

  SensorData calibratedData = this->lastData;
  xSemaphoreGive(this->lastDataMutex);
  calibratedData.temperature += this->temperatureCalidation;
  return calibratedData;
}

bool WeatherSensor::hasValidLastSensorData() {
  if (this->lastData.time == 0) {
    return false;
  }

  unsigned long elapsedTime = millis() - this->lastData.time;
  return elapsedTime <= 100;
}

SensorData WeatherSensor::readSensorData() {
  SensorData data;
  esp_err_t code = bmp280_read_float(this->bmp280, &data.temperature, &data.pressure, &data.humidity);
  if (code == ESP_OK) {
    data.time = millis();
    ESP_LOGI(TAG, "temperature: %f, pressure: %f, humidity: %f", data.temperature, data.pressure, data.humidity);
  } else {
    ESP_LOGW(TAG, "Failed reading sensor: %s", esp_err_to_name(code));
  }
  return data;
}

/* Mandatory identify routine for the accessory.
 * In a real accessory, something like LED blink should be implemented
 * got visual identification
 */
static int identifyAccessory(hap_acc_t* ha) {
  ESP_LOGI(TAG, "Accessory identified");
  return HAP_SUCCESS;
}

static int readTemperatureSensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv) {
  const char* characteristicUUID = hap_char_get_type_uuid(hc);
  ESP_LOGD(TAG, "readTemperatureSensorCharacteristic: %s", characteristicUUID);

  int entireResult = HAP_SUCCESS;

  WeatherSensor* sensor = (WeatherSensor*)serv_priv;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_TEMPERATURE) == 0) {
    sensor->updateTemperatureCharacteristicValue(sensor->getSensorData());
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
    hap_val_t value;
    value.s = strdup(kTemperatureSensorServiceName);
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else {
    ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
    *status_code = HAP_STATUS_RES_ABSENT;
    entireResult = HAP_FAIL;
  }

  return entireResult;
}

static int readHumiditySensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv) {
  const char* characteristicUUID = hap_char_get_type_uuid(hc);
  ESP_LOGD(TAG, "readHumiditySensorCharacteristic: %s", characteristicUUID);

  int entireResult = HAP_SUCCESS;

  WeatherSensor* sensor = (WeatherSensor*)serv_priv;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_RELATIVE_HUMIDITY) == 0) {
    sensor->updateRelativeHumidityCharacteristicValue(sensor->getSensorData());
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
    hap_val_t value;
    value.s = strdup(kHumiditySensorServiceName);
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else {
    ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
    *status_code = HAP_STATUS_RES_ABSENT;
    entireResult = HAP_FAIL;
  }

  return entireResult;
}

static int readAirPressureSensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv) {
  const char* characteristicUUID = hap_char_get_type_uuid(hc);
  ESP_LOGD(TAG, "readHumiditySensorCharacteristic: %s", characteristicUUID);

  int entireResult = HAP_SUCCESS;

  WeatherSensor* sensor = (WeatherSensor*)serv_priv;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_AIR_PRESSURE) == 0) {
    sensor->updateAirPressureCharacteristicValue(sensor->getSensorData());
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
    hap_val_t value;
    value.s = strdup(kHumiditySensorServiceName);
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else {
    ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
    *status_code = HAP_STATUS_RES_ABSENT;
    entireResult = HAP_FAIL;
  }

  return entireResult;
}
