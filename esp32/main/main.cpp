#include "log_config.h" // This needs to be the top
#include "ble_debug.h"
#include "ipad_hid_device.h"
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

static iPadHIDDevice* ipadHIDDevice;
static SteeringRemote* steeringRemote;
static bool isiPadConnected = false;
static bool wasiPadConnected = false;
static unsigned long lastiPadSleepPreventionMillis = 0;

static void startSteeringRemoteInputObservation();
static void startBLEServer();
static void sendBluetoothCommandForSteeringRemoteInput(SteeringRemoteInput steeringRemoteInput);
static void unlockiPad();
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
  startBLEServer();
}

void loop() {
  if (isiPadConnected) {
    if (!wasiPadConnected) {
      // Not sure but this doen't work in ServerCallbacks::onConnect()
      delay(1000);
      unlockiPad();
    }

    keepiPadAwake();
  }

  wasiPadConnected = isiPadConnected;
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

  ipadHIDDevice = new iPadHIDDevice(server);
  ipadHIDDevice->startServices();

  // TODO: Use BLEAdvertisementData::setName() to show the name properly even before unpaired
  BLEAdvertising* advertising = server->getAdvertising();
  advertising->setAppearance(ESP_BLE_APPEARANCE_GENERIC_HID);
  advertising->addServiceUUID(ipadHIDDevice->getHIDService()->getUUID());
  advertising->start();
};

static void sendBluetoothCommandForSteeringRemoteInput(SteeringRemoteInput steeringRemoteInput) {
  iPadHIDDeviceInputCode code = iPadHIDDeviceInputCodeNone;

  switch (steeringRemoteInput) {
    case SteeringRemoteInputNext:
      code = iPadHIDDeviceInputCodeScanNextTrack;
      break;
    case SteeringRemoteInputPrevious:
      code = iPadHIDDeviceInputCodeScanPreviousTrack;
      break;
    case SteeringRemoteInputPlus:
      code = iPadHIDDeviceInputCodeVolumeIncrement;
      break;
    case SteeringRemoteInputMinus:
      code = iPadHIDDeviceInputCodeVolumeDecrement;
      break;
    case SteeringRemoteInputMute:
      code = iPadHIDDeviceInputCodePlayPause;
      break;
    default:
      break;
  }

  if (code == iPadHIDDeviceInputCodeNone) {
    return;
  }

  ipadHIDDevice->sendInputCode(code);
}

static void unlockiPad() {
  ESP_LOGI(TAG, "Unlocking the iPad");
  ipadHIDDevice->sendInputCode(iPadHIDDeviceInputCodeMenu);
  delay(500);
  ipadHIDDevice->sendInputCode(iPadHIDDeviceInputCodeMenu);
}

static void keepiPadAwake() {
  unsigned long currentMillis = millis();

  if (currentMillis > lastiPadSleepPreventionMillis + kiPadSleepPreventionIntervalMillis) {
    ESP_LOGI(TAG, "Sending Help key code to keep the iPad awake");
    ipadHIDDevice->sendInputCode(iPadHIDDeviceInputCodeHelp);
    lastiPadSleepPreventionMillis = currentMillis;
  }
}
