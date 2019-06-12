#include "Arduino.h"
#include "ipad_hid_device.h"
#include "steering_remote.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEHIDDevice.h>
#include <HIDTypes.h>

// #define DEBUG

static const int kSteeringRemoteInputPinA = 34; // Connect to the brown-yellow wire in the car
static const int kSteeringRemoteInputPinB = 35; // Connect to the brown-white wire in the car

static const int kiPadSleepPreventionIntervalMillis = 30 * 1000;

static const std::string kDeviceName = "Levorg";

static iPadHIDDevice* ipadHIDDevice;
static SteeringRemote* steeringRemote;
static bool isConnected = false;
static bool wasConnected = false;
static unsigned long lastiPadSleepPreventionMillis = 0;

static void sendBluetoothCommandForSteeringRemoteInput(SteeringRemoteInput steeringRemoteInput);

class MyBLEServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) {
    isConnected = true;
  }

  void onDisconnect(BLEServer* server) {
    isConnected = false;
  }
};

class MySteeringRemoteCallbacks : public SteeringRemoteCallbacks {
  void onInputChange(SteeringRemote* steeringRemote, SteeringRemoteInput input) {
    if (isConnected) {
      sendBluetoothCommandForSteeringRemoteInput(input);
    }
  }
};

#ifdef DEBUG
// https://github.com/espressif/esp-idf/blob/v3.2/components/bt/bluedroid/api/include/api/esp_gatts_api.h#L26-L54
static const String kGATTServerEventNames[] = {
  String("REG"),
  String("READ"),
  String("WRITE"),
  String("EXEC_WRITE"),
  String("MTU"),
  String("CONF"),
  String("UNREG"),
  String("CREATE"),
  String("ADD_INCL_SRVC"),
  String("ADD_CHAR"),
  String("ADD_CHAR_DESCR"),
  String("DELETE"),
  String("START"),
  String("STOP"),
  String("CONNECT"),
  String("DISCONNECT"),
  String("OPEN"),
  String("CANCEL_OPEN"),
  String("CLOSE"),
  String("LISTEN"),
  String("CONGEST"),
  String("RESPONSE"),
  String("CREAT_ATTR_TAB"),
  String("SET_ATTR_VAL"),
  String("SEND_SERVICE_CHANGE")
};

void handleBLEServerEvent(esp_gatts_cb_event_t event, esp_gatt_if_t gattc_if, esp_ble_gatts_cb_param_t* param) {
  Serial.print("handleBLEServerEvent: ");
  Serial.println(kGATTServerEventNames[event]);
}
#endif

static void startBLEServer() {
#ifdef DEBUG
  BLEDevice::setCustomGattsHandler(handleBLEServerEvent);
#endif

  BLEDevice::init(kDeviceName);

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
  ipadHIDDevice->sendInputCode(iPadHIDDeviceInputCodeMenu);
  delay(500);
  ipadHIDDevice->sendInputCode(iPadHIDDeviceInputCodeMenu);
}

static void keepiPadAwake() {
  unsigned long currentMillis = millis();

  if (currentMillis > lastiPadSleepPreventionMillis + kiPadSleepPreventionIntervalMillis) {
    #ifdef DEBUG
    Serial.println("Sending Help key code to keep the iPad awake");
    #endif

    ipadHIDDevice->sendInputCode(iPadHIDDeviceInputCodeHelp);
    lastiPadSleepPreventionMillis = currentMillis;
  }
}

void setup() {
  #ifdef DEBUG
  Serial.begin(115200);
  #endif

  steeringRemote = new SteeringRemote(kSteeringRemoteInputPinA, kSteeringRemoteInputPinB);
  steeringRemote->setCallbacks(new MySteeringRemoteCallbacks());
  steeringRemote->startInputObservation();

  startBLEServer();
}

void loop() {
  if (isConnected) {
    if (!wasConnected) {
      // Not sure but this doen't work in ServerCallbacks::onConnect()
      delay(1000);
      unlockiPad();
    }

    keepiPadAwake();
  }

  wasConnected = isConnected;
}
