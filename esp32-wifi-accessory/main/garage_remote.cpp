#include "log_config.h"
#include "garage_remote.h"

#include <hap_apple_servs.h>
#include <hap_apple_chars.h>
#include <hap_fw_upgrade.h>

#include <iot_button.h>

#include <esp_timer.h>

#include <cstring>

static const char* TAG = "GarageRemote";

/* Reset network credentials if button is pressed for more than 3 seconds and then released */
static const uint32_t kNetworkResetButtonPressDuration = 3;

/* Reset to factory if button is pressed and held for more than 10 seconds */
static const uint32_t kFactoryResetButtonPressDuration = 10;

static esp_timer_handle_t timer;
typedef void (*callback_with_arg_t)(void*);

static void _turnOffOpenButton(void* arg);
static int identifyAccessory(hap_acc_t* ha);
static int readCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int writeTargetDoorState(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv);
static void resetNetworkConfiguration(void* arg);
static void resetToFactory(void* arg);
static void delay(uint32_t ms);
static void performLater(uint32_t milliseconds, callback_with_arg_t callback, void* arg);

GarageRemote::GarageRemote(gpio_num_t powerButtonPin, gpio_num_t openButtonPin, gpio_num_t resetButtonPin) {
  this->powerButtonPin = powerButtonPin;
  this->openButtonPin = openButtonPin;
  this->resetButtonPin = resetButtonPin;

  gpio_set_direction(powerButtonPin, GPIO_MODE_OUTPUT);
  gpio_set_direction(openButtonPin, GPIO_MODE_OUTPUT);

  this->targetDoorState = TargetDoorStateClosed;
  this->currentDoorState = CurrentDoorStateClosed;
}

void GarageRemote::registerHomeKitAccessory() {
  ESP_LOGI(TAG, "registerHomeKitAccessory");

  this->accessory = this->createAccessory();
  this->addGarageDoorOpenerService();
  this->addFirmwareUpgradeService();
  /* Add the Accessory to the HomeKit Database */
  hap_add_accessory(this->accessory);
  this->configureHomeKitSetupCode();

  this->initializeResetButton();
}

void GarageRemote::startHomeKitAccessory() {
  /* After all the initializations are done, start the HAP core */
  hap_start();
}

hap_acc_t* GarageRemote::createAccessory() {
  /* Configure HomeKit core to make the Accessory name (and thus the WAC SSID) unique,
   * instead of the default configuration wherein only the WAC SSID is made unique.
   */
  hap_cfg_t hap_cfg;
  hap_get_config(&hap_cfg);
  hap_cfg.unique_param = UNIQUE_NAME;
  hap_set_config(&hap_cfg);

  /* Initialize the HAP core */
  hap_init(HAP_TRANSPORT_WIFI);

  /* Initialise the mandatory parameters for Accessory which will be added as
   * the mandatory services internally
   */
  hap_acc_cfg_t cfg;
  cfg.name = (char*)"Garage";
  cfg.manufacturer = (char*)"Yuji Nakayama";
  cfg.model = (char*)"Model";
  cfg.serial_num = (char*)"Serial Number";
  cfg.fw_rev = (char*)"Firmware Version";
  cfg.hw_rev = NULL;
  cfg.pv = (char*)"1.1.0";
  cfg.cid = HAP_CID_GARAGE_DOOR_OPENER;
  cfg.identify_routine = identifyAccessory;

  /* Create accessory object */
  hap_acc_t* accessory = hap_acc_create(&cfg);

  /* Add a dummy Product Data */
  uint8_t product_data[] = {'E','S','P','3','2','H','A','P'};
  hap_acc_add_product_data(accessory, product_data, sizeof(product_data));

  return accessory;
}

void GarageRemote::addGarageDoorOpenerService() {
  /* Create the Fan Service. Include the "name" since this is a user visible service  */
  hap_serv_t* service = hap_serv_garage_door_opener_create(this->currentDoorState, this->targetDoorState, false);

  hap_serv_add_char(service, hap_char_name_create((char*)"Garage"));

  /* Set the write callback for the service */
  hap_serv_set_write_cb(service, writeTargetDoorState);

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readCharacteristic);

  // Allow access to GarageRemote instance from the read/write callbals
  hap_serv_set_priv(service, this);

  /* Add the Fan Service to the Accessory Object */
  hap_acc_add_serv(this->accessory, service);
}

/* Create the Firmware Upgrade HomeKit Custom Service.
 * Please refer the FW Upgrade documentation under components/homekit/extras/include/hap_fw_upgrade.h
 * and the top level README for more information.
 */
void GarageRemote::addFirmwareUpgradeService() {
  /*  Required for server verification during OTA, PEM format as string  */
  char server_cert[] = {};

  hap_fw_upgrade_config_t ota_config = {
      .server_cert_pem = server_cert,
  };

  hap_serv_t* service = hap_serv_fw_upgrade_create(&ota_config);

  /* Add the service to the Accessory Object */
  hap_acc_add_serv(accessory, service);
}

void GarageRemote::configureHomeKitSetupCode() {
  /* Unique Setup code of the format xxx-xx-xxx. Default: 111-22-333 */
  hap_set_setup_code(CONFIG_EXAMPLE_SETUP_CODE);
  /* Unique four character Setup Id. Default: ES32 */
  hap_set_setup_id(CONFIG_EXAMPLE_SETUP_ID);
}

/**
 * The Reset button  GPIO initialisation function.
 * Same button will be used for resetting Wi-Fi network as well as for reset to factory based on
 * the time for which the button is pressed.
 */
void GarageRemote::initializeResetButton() {
  button_handle_t button = iot_button_create(this->resetButtonPin, BUTTON_ACTIVE_LOW);
  iot_button_add_on_release_cb(button, kNetworkResetButtonPressDuration, resetNetworkConfiguration, NULL);
  iot_button_add_on_press_cb(button, kFactoryResetButtonPressDuration, resetToFactory, NULL);
}

TargetDoorState GarageRemote::getTargetDoorState() {
  TargetDoorState state = this->targetDoorState;
  ESP_LOGD(TAG, "getTargetDoorState: %i", state);
  return state;
}

void GarageRemote::setTargetDoorState(TargetDoorState state) {
  ESP_LOGD(TAG, "setTargetDoorState: %i", state);

  switch (state) {
  case TargetDoorStateOpen:
    this->open();
    break;
  case TargetDoorStateClosed:
    // We cannot close the garage by ourselves; it closes automatically/
    break;
  }
}

CurrentDoorState GarageRemote::getCurrentDoorState() {
  CurrentDoorState state = this->currentDoorState;
  ESP_LOGD(TAG, "getCurrentDoorState: %i", state);
  return state;
}

void GarageRemote::open() {
  ESP_LOGD(TAG, "open");

  gpio_set_level(this->powerButtonPin, 1);
  delay(100);
  gpio_set_level(this->powerButtonPin, 0);

  delay(100);

  gpio_set_level(this->openButtonPin, 1);
  performLater(3000, _turnOffOpenButton, this);
}

void GarageRemote::turnOffOpenButton() {
  ESP_LOGD(TAG, "turnOffOpenButton");
  gpio_set_level(this->openButtonPin, 0);
}

static void _turnOffOpenButton(void* arg) {
  GarageRemote* garageRemote = (GarageRemote*)arg;
  garageRemote->turnOffOpenButton();
}

/* Mandatory identify routine for the accessory.
 * In a real accessory, something like LED blink should be implemented
 * got visual identification
 */
static int identifyAccessory(hap_acc_t* ha) {
  ESP_LOGI(TAG, "Accessory identified");
  return HAP_SUCCESS;
}

static int readCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv) {
  const char* characteristicUUID = hap_char_get_type_uuid(hc);
  ESP_LOGD(TAG, "readCharacteristic: %s", characteristicUUID);

  GarageRemote* garageRemote = (GarageRemote*)serv_priv;
  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_TARGET_DOOR_STATE) == 0) {
    value.u = garageRemote->getTargetDoorState();
    hap_char_update_val(hc, &value);
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_DOOR_STATE) == 0) {
    value.u = garageRemote->getCurrentDoorState();
    hap_char_update_val(hc, &value);
  }

  *status_code = HAP_STATUS_SUCCESS;

  return HAP_SUCCESS;
}

static int writeTargetDoorState(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv) {
  GarageRemote* garageRemote = (GarageRemote*)serv_priv;

  // TODO: Handle all data
  hap_write_data_t* data = &write_data[0];
  TargetDoorState state = (TargetDoorState)data->val.u;

  garageRemote->setTargetDoorState(state);

  return HAP_SUCCESS;
}

/**
 * @brief The network reset button callback handler.
 * Useful for testing the Wi-Fi re-configuration feature of WAC2
 */
static void resetNetworkConfiguration(void* arg) {
  hap_reset_network();
}

/**
 * @brief The factory reset button callback handler.
 */
static void resetToFactory(void* arg) {
  hap_reset_to_factory();
}

static void delay(uint32_t ms) {
  vTaskDelay(ms / portTICK_PERIOD_MS);
}

static void performLater(uint32_t milliseconds, callback_with_arg_t callback, void* arg) {
  esp_timer_create_args_t config;
  config.arg = reinterpret_cast<void*>(arg);
  config.callback = callback;
  config.dispatch_method = ESP_TIMER_TASK;
  config.name = "Ticker";

  if (timer) {
    esp_timer_stop(timer);
    esp_timer_delete(timer);
  }

  esp_timer_create(&config, &timer);
  esp_timer_start_once(timer, milliseconds * 1000ULL);
}
