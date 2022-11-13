#include "log_config.h" // This needs to be the top
#include "ble_debug.h"
#include "hid.h"
#include "serial_ble_bridge.h"
#include "steering_remote.h"
#include "Arduino.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEHIDDevice.h>
#include <HIDTypes.h>

static const char* TAG = "main";
static const std::string kBLEDeviceName = "Levorg";
static const int kSteeringRemoteInputPinA = 34; // Connect to the brown-yellow wire in the car
static const int kSteeringRemoteInputPinB = 35; // Connect to the brown-white wire in the car
static const int kiPadSleepPreventionIntervalMillis = 30 * 1000;

// 16 pin for RX
// 17 pin for TX
// https://github.com/espressif/arduino-esp32/blob/1.0.4/cores/esp32/HardwareSerial.cpp#L17-L53
static HardwareSerial* etcDeviceSerial = &Serial2;

static HID* hid;
static SerialBLEBridge* serialBLEBridge;
static SteeringRemote* steeringRemote;
static bool isiPadConnected = false;
static unsigned long lastiPadSleepPreventionMillis = 0;

static void startSteeringRemoteInputObservation();
static void startBLEServer();
static void sendBluetoothCommandForSteeringRemoteInput(SteeringRemoteInput steeringRemoteInput);
static void keepiPadAwake();

class MySteeringRemoteCallbacks : public SteeringRemoteCallbacks {
  void onInputChange(SteeringRemote* steeringRemote, SteeringRemoteInput input) {
    if (isiPadConnected) {
      sendBluetoothCommandForSteeringRemoteInput(input);
    }
  }
};

class MyBLEServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) {
    isiPadConnected = true;
  }

  void onDisconnect(BLEServer* server) {
    isiPadConnected = false;
  }
};

void setup() {
  setupLogLevel();
  enableBLEServerEventLogging();
  startSteeringRemoteInputObservation();
  etcDeviceSerial->begin(19200, SERIAL_8E1);
  startBLEServer();
}

void loop() {
  if (isiPadConnected) {
    keepiPadAwake();
  }
}

static void startSteeringRemoteInputObservation() {
  steeringRemote = new SteeringRemote(kSteeringRemoteInputPinA, kSteeringRemoteInputPinB);
  steeringRemote->setCallbacks(new MySteeringRemoteCallbacks());
  steeringRemote->startInputObservation();
}

static void startBLEServer() {
  BLEDevice::init(kBLEDeviceName);

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new MyBLEServerCallbacks());

  hid = new HID(server);
  hid->startServices();

  serialBLEBridge = new SerialBLEBridge(etcDeviceSerial, server);
  serialBLEBridge->start();

  // TODO: Use BLEAdvertisementData::setName() to show the name properly even before unpaired
  BLEAdvertising* advertising = server->getAdvertising();
  advertising->setAppearance(ESP_BLE_APPEARANCE_GENERIC_HID);
  advertising->addServiceUUID(hid->getHIDService()->getUUID());
  advertising->addServiceUUID(serialBLEBridge->uart->getService()->getUUID());
  advertising->start();
};

static void sendBluetoothCommandForSteeringRemoteInput(SteeringRemoteInput steeringRemoteInput) {
  switch (steeringRemoteInput) {
    case SteeringRemoteInputNext:
      hid->performConsumerInput(HIDConsumerInputScanNextTrack);
      break;
    case SteeringRemoteInputPrevious:
      hid->performConsumerInput(HIDConsumerInputScanPreviousTrack);
      break;
    case SteeringRemoteInputPlus:
      hid->performConsumerInput(HIDConsumerInputVolumeIncrement);
      break;
    case SteeringRemoteInputMinus:
      hid->performConsumerInput(HIDConsumerInputVolumeDecrement);
      break;
    case SteeringRemoteInputMute:
      hid->performConsumerInput(HIDConsumerInputPlayPause);
      break;
    case SteeringRemoteInputVoiceInput:
      // Siri (Globe + S)
      hid->pressConsumerInput(HIDConsumerInputGlobe);
      hid->performKeyboardInput(HIDKeyboardModifierKeyNone, HIDKeyboardKeyS);
      hid->releaseConsumerInput();
      break;
    default:
      break;
  }
}

static void keepiPadAwake() {
  unsigned long currentMillis = millis();

  if (currentMillis > lastiPadSleepPreventionMillis + kiPadSleepPreventionIntervalMillis) {
    ESP_LOGI(TAG, "Sending Help key code to keep the iPad awake");
    hid->performConsumerInput(HIDConsumerInputHelp);
    lastiPadSleepPreventionMillis = currentMillis;
  }
}
