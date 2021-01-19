#include "log_config.h"
#include "engine.h"

#include <hap_apple_servs.h>
#include <hap_apple_chars.h>
#include <hap_fw_upgrade.h>

#include <cstring>

static const char* TAG = "Engine";

static const char* kSetupID = "ENGN"; // This must be unique

static int identifyAccessory(hap_acc_t* ha);
static int readCharacteristic(hap_char_t* hc, hap_status_t* status_code, void* serv_priv, void* read_priv);
static int writeCharacteristic(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv);
static void delay(uint32_t ms);

Engine::Engine(gpio_num_t smartKeyPowerPin, gpio_num_t smartKeyLockButtonPin) {
  this->smartKeyPowerPin = smartKeyPowerPin;
  this->smartKeyLockButtonPin = smartKeyLockButtonPin;

  gpio_set_direction(smartKeyPowerPin, GPIO_MODE_OUTPUT);
  gpio_set_direction(smartKeyLockButtonPin, GPIO_MODE_OUTPUT);

  this->on = false; // FIXME: Observe the real engine state

  // Ensure the smart key power is off for security
  this->deactivateSmartKey();
}

void Engine::registerBridgedHomeKitAccessory() {
  ESP_LOGI(TAG, "registerBridgedHomeKitAccessory");

  this->createAccessory();
  this->addSwitchService();
  this->addFirmwareUpgradeService();
  /* Add the Accessory to the HomeKit Database */
  hap_add_bridged_accessory(this->accessory, hap_get_unique_aid(kSetupID));
}

void Engine::createAccessory() {
  /* Initialise the mandatory parameters for Accessory which will be added as
   * the mandatory services internally
   */
  this->accessoryConfig.name = (char*)"Engine";
  this->accessoryConfig.manufacturer = (char*)"Yuji Nakayama";
  this->accessoryConfig.model = (char*)"Model";
  this->accessoryConfig.serial_num = (char*)"Serial Number";
  this->accessoryConfig.fw_rev = (char*)"Firmware Version";
  this->accessoryConfig.hw_rev = NULL;
  this->accessoryConfig.pv = (char*)"1.0.0";
  this->accessoryConfig.cid = HAP_CID_SWITCH;
  this->accessoryConfig.identify_routine = identifyAccessory;

  /* Create accessory object */
  this->accessory = hap_acc_create(&this->accessoryConfig);

  /* Add a dummy Product Data */
  uint8_t product_data[] = {'E','S','P','3','2','H','A','P'};
  hap_acc_add_product_data(accessory, product_data, sizeof(product_data));
}

void Engine::addSwitchService() {
  /* Create the Switch Service. Include the "name" since this is a user visible service  */
  hap_serv_t* service = hap_serv_switch_create(false);

  hap_serv_add_char(service, hap_char_name_create((char*)"Engine"));

  /* Set the write callback for the service */
  hap_serv_set_write_cb(service, writeCharacteristic);

  /* Set the read callback for the service (optional) */
  hap_serv_set_read_cb(service, readCharacteristic);

  // Allow access to Engine instance from the read/write callbals
  hap_serv_set_priv(service, this);

  /* Add the Switch Service to the Accessory Object */
  hap_acc_add_serv(this->accessory, service);
}

/* Create the Firmware Upgrade HomeKit Custom Service.
 * Please refer the FW Upgrade documentation under components/homekit/extras/include/hap_fw_upgrade.h
 * and the top level README for more information.
 */
void Engine::addFirmwareUpgradeService() {
  /*  Required for server verification during OTA, PEM format as string  */
  char server_cert[] = {};

  hap_fw_upgrade_config_t ota_config = {
      .server_cert_pem = server_cert,
  };

  hap_serv_t* service = hap_serv_fw_upgrade_create(&ota_config);

  /* Add the service to the Accessory Object */
  hap_acc_add_serv(accessory, service);
}

bool Engine::isOn() {
  bool on = this->on;
  ESP_LOGD(TAG, "isOn: %i", on);
  return on;
}

void Engine::setOn(bool newOn) {
  ESP_LOGD(TAG, "setOn: %i", newOn);

  if (newOn && !this->isOn()) {
    this->startEngine();
  } else if (!newOn && this->isOn()) {
    this->stopEngine();
  }

  this->on = newOn;
}

void Engine::startEngine() {
  ESP_LOGD(TAG, "startEngine");

  this->activateSmartKey();

  this->pressSmartKeyLockButton(100);
  delay(400);
  this->pressSmartKeyLockButton(100);
  delay(400);
  this->pressSmartKeyLockButton(3000);

  this->deactivateSmartKey();
}

void Engine::stopEngine() {
  ESP_LOGD(TAG, "stopEngine");

  this->activateSmartKey();
  this->pressSmartKeyLockButton(2000);
  this->deactivateSmartKey();
}

void Engine::activateSmartKey() {
  ESP_LOGV(TAG, "activateSmartKey");
  gpio_set_level(this->smartKeyPowerPin, 1);
  delay(100);
}

void Engine::deactivateSmartKey() {
  ESP_LOGV(TAG, "deactivateSmartKey");
  gpio_set_level(this->smartKeyPowerPin, 0);
}

void Engine::pressSmartKeyLockButton(uint32_t durationInMilliseconds) {
  ESP_LOGV(TAG, "pressSmartKeyLockButton on");
  gpio_set_level(this->smartKeyLockButtonPin, 1);

  delay(durationInMilliseconds);

  ESP_LOGV(TAG, "pressSmartKeyLockButton off");
  gpio_set_level(this->smartKeyLockButtonPin, 0);
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

  Engine* engine = (Engine*)serv_priv;
  hap_val_t value;

  if (strcmp(characteristicUUID, HAP_CHAR_UUID_ON) == 0) {
    value.b = engine->isOn();
    hap_char_update_val(hc, &value);
  }

  *status_code = HAP_STATUS_SUCCESS;

  return HAP_SUCCESS;
}

static int writeCharacteristic(hap_write_data_t write_data[], int count, void* serv_priv, void* write_priv) {
  Engine* engine = (Engine*)serv_priv;

  // TODO: Handle all data
  hap_write_data_t* data = &write_data[0];
  bool newOn = data->val.b;

  engine->setOn(newOn);

  return HAP_SUCCESS;
}

static void delay(uint32_t ms) {
  vTaskDelay(ms / portTICK_PERIOD_MS);
}
