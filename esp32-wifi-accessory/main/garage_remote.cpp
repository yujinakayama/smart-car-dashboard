#include "log_config.h"
#include "garage_remote.h"
#include <hap.h>
#include <esp_wifi.h>
#include <esp_event_loop.h>
#include <nvs_flash.h>
#include <string.h>
#include <Arduino.h>

#define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))

static const char* TAG = "GarageRemote";

static void hapObjectInit(void* context);
static void* readTargetDoorState(void* context);
static void writeTargetDoorState(void* context, void* value, int length);
static void* readCurrentDoorState(void* context);

GarageRemote::GarageRemote(int powerButtonPin, int openButtonPin) {
  this->powerButtonPin = powerButtonPin;
  this->openButtonPin = openButtonPin;

  pinMode(powerButtonPin, OUTPUT);
  pinMode(openButtonPin, OUTPUT);

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

  digitalWrite(this->powerButtonPin, HIGH);
  delay(100);
  digitalWrite(this->powerButtonPin, LOW);

  delay(100);

  digitalWrite(this->openButtonPin, HIGH);
  delay(3000);
  digitalWrite(this->openButtonPin, LOW);
}

static void* readTargetDoorState(void* context) {
  GarageRemote* garageRemote = (GarageRemote*)context;
  return (void*)garageRemote->getTargetDoorState();
}

static void writeTargetDoorState(void* context, void* value, int length) {
  GarageRemote* garageRemote = (GarageRemote*)context;

  TargetDoorState state;
  memcpy(&state, &value, sizeof(state));

  garageRemote->setTargetDoorState(state);
}

static void* readCurrentDoorState(void* context) {
  GarageRemote* garageRemote = (GarageRemote*)context;
  return (void*)garageRemote->getCurrentDoorState();
}
