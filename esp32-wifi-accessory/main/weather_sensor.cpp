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
  #include "util.h"
}

static const char* TAG = "WeatherSensor";

static const char* kSetupID = "WTHR"; // This must be unique

static const char* kTemperatureSensorServiceName = "Temperature Sensor";
static const char* kHumiditySensorServiceName = "Humidity Sensor";
static const char* kAirPressureSensorServiceName = "Air Pressure Sensor";

static int identifyAccessory(hap_acc_t* ha);
static int readTemperatureSensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int readHumiditySensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int readAirPressureSensorCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);

bmp280_t* initBMP280(gpio_num_t sdaPin, gpio_num_t sdlPin) {
  ESP_ERROR_CHECK(i2cdev_init());

  bmp280_t* bmp280 = (bmp280_t*)malloc(sizeof(bmp280_t));
  memset(bmp280, 0, sizeof(bmp280_t));
  ESP_ERROR_CHECK(bmp280_init_desc(bmp280, BMP280_I2C_ADDRESS_0, I2C_NUM_0, sdaPin, sdlPin));

  bmp280_params_t params = {
    .mode = BMP280_MODE_FORCED,
    .filter = BMP280_FILTER_OFF,
    .oversampling_pressure = BMP280_HIGH_RES,
    .oversampling_temperature = BMP280_HIGH_RES,
    .oversampling_humidity = BMP280_HIGH_RES,
    .standby = BMP280_STANDBY_05 // No effect for forced mode; just to suppress warning for `missing initializer for member`
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
}

bool WeatherSensor::isFound() {
  return this->bmp280 != NULL;
}

void WeatherSensor::registerBridgedHomeKitAccessory() {
  ESP_LOGI(TAG, "registerBridgedHomeKitAccessory");

  this->createAccessory();
  this->addTemperatureSensorService();
  this->addHumiditySensorService();
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
  hap_serv_t* service = hap_serv_temperature_sensor_create(0);

  hap_serv_add_char(service, hap_char_name_create(strdup(kTemperatureSensorServiceName)));

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readTemperatureSensorCharacteristic);

  // Allow access to WeatherSensor instance from the read/write callbacks
  hap_serv_set_priv(service, this);

  /* Add the sensor service to the accessory object */
  hap_acc_add_serv(this->accessory, service);
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

SensorData WeatherSensor::getData() {
  if (!this->hasValidLastData()) {
    this->lastData = this->readData();
  }

  SensorData calibratedData = this->lastData;
  calibratedData.temperature += this->temperatureCalidation;
  return calibratedData;
}

bool WeatherSensor::hasValidLastData() {
  if (this->lastData.time == 0) {
    return false;
  }

  unsigned long elapsedTime = millis() - this->lastData.time;
  return elapsedTime <= 3000;
}

SensorData WeatherSensor::readData() {
  ESP_LOGD(TAG, "Reading sensor...");

  // 3.3.3 Forced mode
  // In forced mode, a single measurement is performed in accordance to the selected measurement and filter options.
  // When the measurement is finished,
  // the sensor returns to sleep mode and the measurement results can be obtained from the data registers.
  // For a next measurement, forced mode needs to be selected again.
  // This is similar to BMP180 operation.
  // Using forced mode is recommended for applications which require low sampling rate or host-based synchronization.
  //
  // https://www.mouser.com/datasheet/2/783/BST-BME280-DS002-1509607.pdf
  ESP_ERROR_CHECK(bmp280_force_measurement(this->bmp280));

  bool isMeasuring;
  do {
    vTaskDelay(pdMS_TO_TICKS(1));
    bmp280_is_measuring(this->bmp280, &isMeasuring);
  } while (isMeasuring);

  SensorData data;
  ESP_ERROR_CHECK(bmp280_read_float(this->bmp280, &data.temperature, &data.pressure, &data.humidity));
  data.time = millis();
  ESP_LOGI(TAG, "temperature: %f, pressure: %f, humidity: %f", data.temperature, data.pressure, data.humidity);
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
  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_TEMPERATURE) == 0) {
    SensorData data = sensor->getData();
    value.f = data.temperature;
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
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
  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_RELATIVE_HUMIDITY) == 0) {
    SensorData data = sensor->getData();
    value.f = data.humidity;
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
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
  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_AIR_PRESSURE) == 0) {
    SensorData data = sensor->getData();
    value.f = data.pressure;
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
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
