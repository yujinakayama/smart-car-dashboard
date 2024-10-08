#include "log_config.h"
#include "garage_remote.h"

#include <hap_apple_servs.h>
#include <hap_apple_chars.h>
#include <hap_fw_upgrade.h>
#include <esp_timer.h>
#include <cstring>
#include "util.h"

static const char* TAG = "GarageRemote";

static const char* kSetupID = "GRGR"; // This must be unique

static const char* kServiceName = "Garage";

static esp_timer_handle_t timer;
typedef void (*callback_with_arg_t)(void*);

static void _turnOffOpenButton(void* arg);
static int identifyAccessory(hap_acc_t* ha);
static int readCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int writeTargetDoorState(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv);
static void performLater(uint32_t milliseconds, callback_with_arg_t callback, void* arg);

GarageRemote::GarageRemote(gpio_num_t powerButtonPin, gpio_num_t openButtonPin) {
  this->powerButtonPin = powerButtonPin;
  this->openButtonPin = openButtonPin;

  gpio_set_direction(powerButtonPin, GPIO_MODE_OUTPUT);
  gpio_set_direction(openButtonPin, GPIO_MODE_OUTPUT);

  this->targetDoorState = TargetDoorStateClosed;
  this->currentDoorState = CurrentDoorStateClosed;
}

void GarageRemote::registerBridgedHomeKitAccessory() {
  ESP_LOGI(TAG, "registerBridgedHomeKitAccessory");

  this->createAccessory();
  this->addGarageDoorOpenerService();
  this->addFirmwareUpgradeService();
  /* Add the Accessory to the HomeKit Database */
  hap_add_bridged_accessory(this->accessory, hap_get_unique_aid(kSetupID));
}

void GarageRemote::createAccessory() {
  /* Initialise the mandatory parameters for Accessory which will be added as
   * the mandatory services internally
   */
  hap_acc_cfg_t config = {
    .name = (char*)"Garage",
    .model = (char*)"Model",
    .manufacturer = (char*)"Yuji Nakayama",
    .serial_num = (char*)"Serial Number",
    .fw_rev = (char*)"Firmware Version",
    .hw_rev = NULL,
    .pv = (char*)"1.1.0",
    .cid = HAP_CID_GARAGE_DOOR_OPENER,
    .identify_routine = identifyAccessory,
  };

  /* Create accessory object */
  this->accessory = hap_acc_create(&config);

  /* Add a dummy Product Data */
  uint8_t product_data[] = {'E','S','P','3','2','H','A','P'};
  hap_acc_add_product_data(accessory, product_data, sizeof(product_data));
}

void GarageRemote::addGarageDoorOpenerService() {
  /* Create the Fan Service. Include the "name" since this is a user visible service  */
  hap_serv_t* service = hap_serv_garage_door_opener_create(this->currentDoorState, this->targetDoorState, false);

  hap_serv_add_char(service, hap_char_name_create(strdup(kServiceName)));

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

  int entireResult = HAP_SUCCESS;

  GarageRemote* garageRemote = (GarageRemote*)serv_priv;
  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_TARGET_DOOR_STATE) == 0) {
    value.u = garageRemote->getTargetDoorState();
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_CURRENT_DOOR_STATE) == 0) {
    value.u = garageRemote->getCurrentDoorState();
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_OBSTRUCTION_DETECTED) == 0) {
    value.b = false;
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
    value.s = strdup(kServiceName);
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else {
    ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
    *status_code = HAP_STATUS_RES_ABSENT;
    entireResult = HAP_FAIL;
  }

  return entireResult;
}

static int writeTargetDoorState(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv) {
  int entireResult = HAP_SUCCESS;
  GarageRemote *garageRemote = (GarageRemote *)serv_priv;

  for (int i = 0; i < count; i++) {
    hap_write_data_t *data = &write_data[i];
    const char* characteristicUUID = hap_char_get_type_uuid(data->hc);

    if (strcmp(characteristicUUID, HAP_CHAR_UUID_TARGET_DOOR_STATE) == 0) {
      TargetDoorState state = (TargetDoorState)data->val.u;
      garageRemote->setTargetDoorState(state);
      *(data->status) = HAP_STATUS_SUCCESS;
    } else {
      ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
      *(data->status) = HAP_STATUS_RES_ABSENT;
      entireResult = HAP_FAIL;
    }
  }

  return entireResult;
}

static void performLater(uint32_t milliseconds, callback_with_arg_t callback, void* arg) {
  esp_timer_create_args_t config = {
    .callback = callback,
    .arg = reinterpret_cast<void*>(arg),
    .dispatch_method = ESP_TIMER_TASK,
    .name = "Ticker",
  };

  if (timer) {
    esp_timer_stop(timer);
    esp_timer_delete(timer);
  }

  esp_timer_create(&config, &timer);
  esp_timer_start_once(timer, milliseconds * 1000ULL);
}
