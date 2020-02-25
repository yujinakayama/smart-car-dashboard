#include "log_config.h"
#include "garage_remote.h"
#include <hap.h>
#include <esp_wifi.h>
#include <esp_event_loop.h>
#include <nvs_flash.h>
#include <string.h>

#define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))

static const char* TAG = "GarageRemote";

static void hapObjectInit(void* context);
static void* readTargetDoorState(void* context);
static void writeTargetDoorState(void* context, void* value, int length);
static void* readCurrentDoorState(void* context);
static void writeCurrentDoorState(void* context, void* value, int length);

GarageRemote::GarageRemote(int powerButtonPin, int openButtonPin) {
  this->powerButtonPin = powerButtonPin;
  this->openButtonPin = openButtonPin;

  this->targetDoorState = TargetDoorStateClosed;
  this->currentDoorState = CurrentDoorStateClosed;
}

void GarageRemote::registerHomeKitAccessory() {
  ESP_LOGI(TAG, "registerHomeKitAccessory");

  hap_init();

  uint8_t mac[6];
  esp_wifi_get_mac(ESP_IF_WIFI_STA, mac);
  char accessoryID[32] = {0};
  sprintf(accessoryID, "%02X:%02X:%02X:%02X:%02X:%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

  hap_accessory_callback_t callback;
  callback.hap_object_init = hapObjectInit;

  this->accessory = (hap_accessory*)hap_accessory_register(
    (char*)"Garage",
    accessoryID,
    (char*)"053-58-197",
    (char*)"Yuji Nakayama",
    HAP_ACCESSORY_CATEGORY_OTHER,
    811,
    1,
    this,
    &callback
  );
}

void hapObjectInit(void* context) {
  ESP_LOGI(TAG, "hapObjectInit");
  GarageRemote* garageRemote = (GarageRemote*)context;
  garageRemote->registerHomeKitServicesAndCharacteristics();
}

void GarageRemote::registerHomeKitServicesAndCharacteristics() {
  ESP_LOGI(TAG, "registerHomeKitServicesAndCharacteristics");

  void* accessoryObject = hap_accessory_add(this->accessory);

  struct hap_characteristic accessoryInformationCharacteristics[] = {
    {HAP_CHARACTER_IDENTIFY, (void*)true, NULL, NULL, NULL, NULL},
    {HAP_CHARACTER_MANUFACTURER, (void*)"Yuji Nakayama", NULL, NULL, NULL, NULL},
    {HAP_CHARACTER_MODEL, (void*)"Model", NULL, NULL, NULL, NULL},
    {HAP_CHARACTER_NAME, (void*)"Garage", NULL, NULL, NULL, NULL},
    {HAP_CHARACTER_SERIAL_NUMBER, (void*)"Serial Number", NULL, NULL, NULL, NULL},
    {HAP_CHARACTER_FIRMWARE_REVISION, (void*)"Firmware Version", NULL, NULL, NULL, NULL},
  };

  hap_service_and_characteristics_add(
    this->accessory,
    accessoryObject,
    HAP_SERVICE_ACCESSORY_INFORMATION,
    accessoryInformationCharacteristics,
    ARRAY_SIZE(accessoryInformationCharacteristics)
  );

  struct hap_characteristic garageDoorOpenerCharacteristics[] = {
    {HAP_CHARACTER_TARGET_DOORSTATE, (void*)&(this->targetDoorState), this, readTargetDoorState, writeTargetDoorState, NULL},
    {HAP_CHARACTER_CURRENT_DOOR_STATE, (void*)&(this->currentDoorState), this, readCurrentDoorState, NULL, NULL},
  };

  hap_service_and_characteristics_add(
    this->accessory,
    accessoryObject,
    HAP_SERVICE_GARAGE_DOOR_OPENER,
    garageDoorOpenerCharacteristics,
    ARRAY_SIZE(garageDoorOpenerCharacteristics)
  );
}

static void* readTargetDoorState(void* context) {
  GarageRemote* garageRemote = (GarageRemote*)context;
  ESP_LOGD(TAG, "readTargetDoorState");
  return (void*)garageRemote->targetDoorState;
}

static void writeTargetDoorState(void* context, void* value, int length) {
  GarageRemote* garageRemote = (GarageRemote*)context;
  TargetDoorState state;
  memcpy(&state, &value, sizeof(state));
  ESP_LOGD(TAG, "writeTargetDoorState %i", state);
  // FIXME
}

static void* readCurrentDoorState(void* context) {
  GarageRemote* garageRemote = (GarageRemote*)context;
  ESP_LOGD(TAG, "readCurrentDoorState");
  return (void*)garageRemote->currentDoorState;
}
