#include "log_config.h"
#include "car_smart_key.h"

#include <hap_apple_servs.h>
#include <hap_apple_chars.h>
#include <hap_fw_upgrade.h>

#include <cstring>

extern "C" {
  #include "util.h"
}

static const char* TAG = "CarSmartKey";

static const char* kSetupID = "SKEY"; // This must be unique

static const char* kEngineServiceName = "Engine";
static const char* kDoorLockServiceName = "Door Lock";

static int identifyAccessory(hap_acc_t* ha);
static int readEngineServiceCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int writeEngineServiceCharacteristic(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv);
static void onEngineStateChange(void* arg);
static int readDoorLockServiceCharacteristic(hap_char_t *hc, hap_status_t *status_code, void *serv_priv, void *read_priv);
static int writeDoorLockServiceCharacteristic(hap_write_data_t write_data[], int count, void *serv_priv, void *write_priv);
static void notifyLockStateUpdate(hap_acc_t* characteristic, LockMechanismState state);

CarSmartKey::CarSmartKey(gpio_num_t powerOutputPin, gpio_num_t lockButtonOutputPin, gpio_num_t unlockButtonOutputPin, gpio_num_t engineStateInputPin) {
  this->powerPin = powerOutputPin;
  this->lockButtonPin = lockButtonOutputPin;
  this->unlockButtonPin = unlockButtonOutputPin;
  this->engineStatePin = engineStateInputPin;

  gpio_set_direction(this->powerPin, GPIO_MODE_OUTPUT);
  gpio_set_direction(this->lockButtonPin, GPIO_MODE_OUTPUT);
  gpio_set_direction(this->unlockButtonPin, GPIO_MODE_OUTPUT);
  gpio_set_direction(this->engineStatePin, GPIO_MODE_INPUT);

  // Ensure the smart key power is off for security
  this->deactivateSmartKey();

  this->lastTargetDoorLockState = LockMechanismStateUnknown;
}

void CarSmartKey::registerBridgedHomeKitAccessory() {
  ESP_LOGI(TAG, "registerBridgedHomeKitAccessory");

  this->createAccessory();
  this->addEngineService();
  this->addDoorLockService();
  this->addFirmwareUpgradeService();
  /* Add the Accessory to the HomeKit Database */
  hap_add_bridged_accessory(this->accessory, hap_get_unique_aid(kSetupID));

  this->startObservingEngineState();
}

void CarSmartKey::createAccessory() {
  /* Initialise the mandatory parameters for Accessory which will be added as
   * the mandatory services internally
   */
  this->accessoryConfig.name = (char*)"Car Smart Key";
  this->accessoryConfig.manufacturer = (char*)"Yuji Nakayama";
  this->accessoryConfig.model = (char*)"Model";
  this->accessoryConfig.serial_num = (char*)"Serial Number";
  this->accessoryConfig.fw_rev = (char*)"Firmware Version";
  this->accessoryConfig.hw_rev = NULL;
  this->accessoryConfig.pv = (char*)"1.0.0";
  this->accessoryConfig.cid = HAP_CID_BRIDGE;
  this->accessoryConfig.identify_routine = identifyAccessory;

  /* Create accessory object */
  this->accessory = hap_acc_create(&this->accessoryConfig);

  /* Add a dummy Product Data */
  uint8_t product_data[] = {'E','S','P','3','2','H','A','P'};
  hap_acc_add_product_data(accessory, product_data, sizeof(product_data));
}

void CarSmartKey::addEngineService() {
  /* Create the Switch Service. Include the "name" since this is a user visible service  */
  hap_serv_t* service = hap_serv_switch_create(false);

  hap_serv_add_char(service, hap_char_name_create(strdup(kEngineServiceName)));

  /* Set the write callback for the service */
  hap_serv_set_write_cb(service, writeEngineServiceCharacteristic);

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readEngineServiceCharacteristic);

  // Allow access to CarSmartKey instance from the read/write callbals
  hap_serv_set_priv(service, this);

  /* Add the Switch Service to the Accessory Object */
  hap_acc_add_serv(this->accessory, service);

  this->engineOnCharacteristic = hap_serv_get_char_by_uuid(service, HAP_CHAR_UUID_ON);
}

void CarSmartKey::addDoorLockService() {
  /* Create a Lock Mechanism service. Include the "name" since this is a user visible service  */
  hap_serv_t* service = hap_serv_lock_mechanism_create(LockMechanismStateUnknown, LockMechanismStateUnsecured);

  hap_serv_add_char(service, hap_char_name_create(strdup(kDoorLockServiceName)));

  /* Set the write callback for the service */
  hap_serv_set_write_cb(service, writeDoorLockServiceCharacteristic);

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readDoorLockServiceCharacteristic);

  // Allow access to CarSmartKey instance from the read/write callbals
  hap_serv_set_priv(service, this);

  /* Add the Lock Mechanism service to the accessory object */
  hap_acc_add_serv(this->accessory, service);

  this->currentDoorLockStateCharacteristic = hap_serv_get_char_by_uuid(service, HAP_CHAR_UUID_LOCK_CURRENT_STATE);
  this->targetDoorLockStateCharacteristic = hap_serv_get_char_by_uuid(service, HAP_CHAR_UUID_LOCK_TARGET_STATE);
}

/* Create the Firmware Upgrade HomeKit Custom Service.
 * Please refer the FW Upgrade documentation under components/homekit/extras/include/hap_fw_upgrade.h
 * and the top level README for more information.
 */
void CarSmartKey::addFirmwareUpgradeService() {
  /*  Required for server verification during OTA, PEM format as string  */
  char server_cert[] = {};

  hap_fw_upgrade_config_t ota_config = {
      .server_cert_pem = server_cert,
  };

  hap_serv_t* service = hap_serv_fw_upgrade_create(&ota_config);

  /* Add the service to the Accessory Object */
  hap_acc_add_serv(accessory, service);
}

void CarSmartKey::startObservingEngineState() {
  gpio_config_t config;
  config.pin_bit_mask = (1 << this->engineStatePin);
  config.mode = GPIO_MODE_INPUT;
  config.intr_type = GPIO_INTR_ANYEDGE;
  ESP_ERROR_CHECK(gpio_config(&config));

  gpio_isr_handler_add(this->engineStatePin, onEngineStateChange, this);
}

bool CarSmartKey::getEngineState(bool loggingEnabled) {
  bool state = gpio_get_level(this->engineStatePin) == 1;

  if (loggingEnabled) {
    ESP_LOGD(TAG, "getEngineState: %i", state);
  }

  return state;
}

void CarSmartKey::setEngineState(bool newState) {
  ESP_LOGD(TAG, "setEngineState: %i", newState);

  if (newState && !this->getEngineState()) {
    this->startEngine();
  } else if (!newState && this->getEngineState()) {
    this->stopEngine();
  }
}


LockMechanismState CarSmartKey::getCurrentDoorLockState() {
  // TODO: Fetch real current state from the vehicle
  return this->lastTargetDoorLockState;
}

LockMechanismState CarSmartKey::getTargetDoorLockState() {
  return this->lastTargetDoorLockState;
}

void CarSmartKey::setDoorLockState(LockMechanismState newTargetState) {
  if (newTargetState != LockMechanismStateUnsecured && newTargetState != LockMechanismStateSecured) {
    ESP_LOGE(TAG, "unsupported target lock mechanism state %i", newTargetState);
    return;
  }

  this->lastTargetDoorLockState = newTargetState;

  switch (newTargetState) {
  case LockMechanismStateSecured:
    this->lockDoors();
    break;
  case LockMechanismStateUnsecured:
    this->unlockDoors();
    break;
  default:
    break;
  }
}

void CarSmartKey::startEngine() {
  ESP_LOGD(TAG, "startEngine");

  this->activateSmartKey();

  this->pressSmartKeyLockButton(150);
  delay(400);
  this->pressSmartKeyLockButton(150);
  delay(400);
  this->pressSmartKeyLockButton(3000);

  this->deactivateSmartKey();

  delay(1000); // Wait for the engine to actually start
}

void CarSmartKey::stopEngine() {
  ESP_LOGD(TAG, "stopEngine");

  this->activateSmartKey();
  this->pressSmartKeyLockButton(2000);
  this->deactivateSmartKey();

  delay(500); // Wait for the engine to actually stop
}

void CarSmartKey::lockDoors() {
  ESP_LOGD(TAG, "lockDoors");

  this->activateSmartKey();
  // For some reason pressing for 150ms does not work (maybe to avoid unintentional unlock by mistake?)
  this->pressSmartKeyLockButton(500);
  this->deactivateSmartKey();
}

void CarSmartKey::unlockDoors() {
  ESP_LOGD(TAG, "unlockDoors");

  this->activateSmartKey();
  // For some reason pressing for 150ms does not work (maybe to avoid unintentional unlock by mistake?)
  this->pressSmartKeyUnlockButton(500);
  this->deactivateSmartKey();
}

void CarSmartKey::activateSmartKey() {
  ESP_LOGV(TAG, "activateSmartKey");
  gpio_set_level(this->powerPin, 1);
  // It seems the smart key has some capacitors inside
  // and they need some time to be charged to generate radio waves
  // especially for long press of the lock button.
  // 500ms doesn't work.
  delay(1000);
}

void CarSmartKey::deactivateSmartKey() {
  ESP_LOGV(TAG, "deactivateSmartKey");
  gpio_set_level(this->powerPin, 0);
}

void CarSmartKey::pressSmartKeyLockButton(uint32_t durationInMilliseconds) {
  ESP_LOGV(TAG, "pressSmartKeyLockButton on");

  notifyLockStateUpdate(this->targetDoorLockStateCharacteristic, LockMechanismStateSecured);

  gpio_set_level(this->lockButtonPin, 1);

  delay(durationInMilliseconds);

  ESP_LOGV(TAG, "pressSmartKeyLockButton off");
  gpio_set_level(this->lockButtonPin, 0);

  notifyLockStateUpdate(this->currentDoorLockStateCharacteristic, LockMechanismStateSecured);
}

void CarSmartKey::pressSmartKeyUnlockButton(uint32_t durationInMilliseconds) {
  ESP_LOGV(TAG, "pressSmartKeyUnlockButton on");

  notifyLockStateUpdate(this->targetDoorLockStateCharacteristic, LockMechanismStateUnsecured);

  gpio_set_level(this->unlockButtonPin, 1);

  delay(durationInMilliseconds);

  ESP_LOGV(TAG, "pressSmartKeyUnlockButton off");
  gpio_set_level(this->unlockButtonPin, 0);

  notifyLockStateUpdate(this->currentDoorLockStateCharacteristic, LockMechanismStateUnsecured);
}

/* Mandatory identify routine for the accessory.
 * In a real accessory, something like LED blink should be implemented
 * got visual identification
 */
static int identifyAccessory(hap_acc_t* ha) {
  ESP_LOGI(TAG, "Accessory identified");
  return HAP_SUCCESS;
}

static int readEngineServiceCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv) {
  const char* characteristicUUID = hap_char_get_type_uuid(hc);
  ESP_LOGD(TAG, "readEngineServiceCharacteristic: %s", characteristicUUID);

  int entireResult = HAP_SUCCESS;

  CarSmartKey* smartKey = (CarSmartKey*)serv_priv;
  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_ON) == 0) {
    value.b = smartKey->getEngineState();
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
    value.s = strdup(kEngineServiceName);
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else {
    ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
    *status_code = HAP_STATUS_RES_ABSENT;
    entireResult = HAP_FAIL;
  }

  return entireResult;
}

static int writeEngineServiceCharacteristic(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv) {
  int entireResult = HAP_SUCCESS;
  CarSmartKey *smartKey = (CarSmartKey *)serv_priv;

  for (int i = 0; i < count; i++) {
    hap_write_data_t* data = &write_data[i];
    const char *characteristicUUID = hap_char_get_type_uuid(data->hc);

    if (strcmp(characteristicUUID, HAP_CHAR_UUID_ON) == 0) {
      bool newState = data->val.b;
      smartKey->setEngineState(newState);

      if (smartKey->getEngineState() == newState) {
        *(data->status) = HAP_STATUS_SUCCESS;
      } else {
        *(data->status) = HAP_STATUS_COMM_ERR;
        entireResult = HAP_FAIL;
      }
    } else {
      ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
      *(data->status) = HAP_STATUS_RES_ABSENT;
      entireResult = HAP_FAIL;
    }
  }

  return entireResult;
}

static void onEngineStateChange(void* arg) {
  // We cannot use log functions in this interrupt handler.
  // > This function or these macros should not be used from an interrupt.
  // https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/system/log.html#_CPPv413esp_log_write15esp_log_level_tPKcPKcz
  // https://esp32.com/viewtopic.php?f=13&t=3748&p=17131
  CarSmartKey* smartKey = (CarSmartKey*)arg;
  bool state = smartKey->getEngineState(false);

  ets_printf("onEngineStateChange %d\n", state);

  hap_val_t value;
  value.b = state;
  hap_char_update_val(smartKey->engineOnCharacteristic, &value);
}

static int readDoorLockServiceCharacteristic(hap_char_t *hc, hap_status_t *status_code, void *serv_priv, void *read_priv) {
  const char* characteristicUUID = hap_char_get_type_uuid(hc);
  ESP_LOGD(TAG, "readDoorLockServiceCharacteristic: %s", characteristicUUID);

  int entireResult = HAP_SUCCESS;
  CarSmartKey* smartKey = (CarSmartKey*)serv_priv;

  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_LOCK_CURRENT_STATE) == 0) {
    value.u = smartKey->getCurrentDoorLockState();
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_LOCK_TARGET_STATE) == 0) {
    value.u = smartKey->getTargetDoorLockState();
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else if (strcmp(characteristicUUID, HAP_CHAR_UUID_NAME) == 0) {
    value.s = strdup(kDoorLockServiceName);
    hap_char_update_val(hc, &value);
    *status_code = HAP_STATUS_SUCCESS;
  } else {
    ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
    *status_code = HAP_STATUS_RES_ABSENT;
    entireResult = HAP_FAIL;
  }

  return entireResult;
}

static int writeDoorLockServiceCharacteristic(hap_write_data_t write_data[], int count, void *serv_priv, void *write_priv) {
  int entireResult = HAP_SUCCESS;
  CarSmartKey* smartKey = (CarSmartKey*)serv_priv;

  for (int i = 0; i < count; i++) {
    hap_write_data_t* data = &write_data[i];
    const char* characteristicUUID = hap_char_get_type_uuid(data->hc);

    if (strcmp(characteristicUUID, HAP_CHAR_UUID_LOCK_TARGET_STATE) == 0) {
      LockMechanismState newState = (LockMechanismState)data->val.u;

      if (newState == LockMechanismStateUnsecured || newState == LockMechanismStateSecured) {
        smartKey->setDoorLockState(newState);
        *(data->status) = HAP_STATUS_SUCCESS;
      } else {
        ESP_LOGE(TAG, "unsupported target lock mechanism state %i", newState);
        *(data->status) = HAP_STATUS_VAL_INVALID;
      }
    } else {
      ESP_LOGE(TAG, "unsupported characteristic %s", characteristicUUID);
      *(data->status) = HAP_STATUS_RES_ABSENT;
      entireResult = HAP_FAIL;
    }
  }

  return entireResult;
}

static void notifyLockStateUpdate(hap_acc_t* characteristic, LockMechanismState state) {
  hap_val_t value;
  value.u = state;
  hap_char_update_val(characteristic, &value);
}
