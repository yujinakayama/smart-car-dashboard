#include "Arduino.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEHIDDevice.h>
#include <HIDTypes.h>
#include "usb_hid_definition.h"

// #define DEBUG

static const int kSteeringRemoteInputPinA = 34; // Connect to the brown-yellow wire in the car
static const int kSteeringRemoteInputPinB = 35; // Connect to the brown-white wire in the car

static const int kAnalogInputMaxValue = 4095;

static const int kNonChatterThresholdMillis = 50;

static const int kiPadSleepPreventionIntervalMillis = 30 * 1000;

static const std::string kDeviceName = "Levorg";

static const uint8_t kKeyboardReportID = 1;
static const uint8_t kConsumerReportID = 2;

// http://who-t.blogspot.com/2018/12/understanding-hid-report-descriptors.html
// https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
static const uint8_t kReportMap[] = {
  // We define the root usage page as Consumer device instead of Keyboard
  // because iOS automatically hides the software keyboard when hardware keyboard is connected
  // but we want to avoid that behavior since this is just a sort of remote
  // that cannot replace keyboard.
  USAGE_PAGE(1),        0x0C, // Consumer
  USAGE(1),             0x01, // Consumer Control

  COLLECTION(1),        0x01, // Application Collection

    // Beginning of Keyboard report
    REPORT_ID(1), kKeyboardReportID,

    // Sadly, without root usage Generic Desktop Page (0x01) - Keyboard (0x06)
    // Left GUI (0xE3) and Right GUI (0xE7) don't work as the Command key on iOS :(
    USAGE_PAGE(1),      0x07, // Keyboard/Keypad
    USAGE_MINIMUM(1),   0xE0, // Left Control
    USAGE_MAXIMUM(1),   0xE7, // Right GUI
    REPORT_COUNT(1),       8, // 8 modifier keys
    REPORT_SIZE(1),        1, // 1 bit for each modifier key
    LOGICAL_MINIMUM(1),    0, // Off
    LOGICAL_MAXIMUM(1),    1, // On
    HIDINPUT(1), kUSBHIDReportFlagData |
                 kUSBHIDReportFlagVariable |
                 kUSBHIDReportFlagAbsolute |
                 kUSBHIDReportFlagNoWrap |
                 kUSBHIDReportFlagLinear |
                 kUSBHIDReportFlagPreferredState |
                 kUSBHIDReportFlagNoNullPosition |
                 kUSBHIDReportFlagBitField,

    USAGE_PAGE(1),      0x07, // Keyboard/Keypad
    USAGE_MINIMUM(1),   0x00,
    USAGE_MAXIMUM(1),   0xFF,
    REPORT_COUNT(1),       1, // Only a single key at a time
    REPORT_SIZE(1),        8, // Represents a usage index value with 8 bit (0x00 - 0xFF)
    LOGICAL_MINIMUM(1), 0x00,
    LOGICAL_MAXIMUM(1), 0xFF,
    HIDINPUT(1), kUSBHIDReportFlagData |
                 kUSBHIDReportFlagArray |
                 kUSBHIDReportFlagAbsolute |
                 kUSBHIDReportFlagNoWrap |
                 kUSBHIDReportFlagLinear |
                 kUSBHIDReportFlagPreferredState |
                 kUSBHIDReportFlagNoNullPosition |
                 kUSBHIDReportFlagBitField,

    // End of Keyboard report

    // Beginning of Consumer report
    REPORT_ID(1), kConsumerReportID,

    USAGE_PAGE(1),      0x0C, // Consumer
    USAGE(1),           0x40, // Menu
    USAGE(1),           0x95, // Help
    USAGE(1),           0xB5, // Scan Next Track
    USAGE(1),           0xB6, // Scan Previous Track
    USAGE(1),           0xCD, // Play/Pause
    USAGE(1),           0xE2, // Mute
    USAGE(1),           0xE9, // Volume Increment
    USAGE(1),           0xEA, // Volume Decrement
    REPORT_COUNT(1),       6, // 6 buttons
    REPORT_SIZE(1),        1, // 1 bit for each button
    LOGICAL_MINIMUM(1),    0,
    LOGICAL_MAXIMUM(1),    1,
    HIDINPUT(1), kUSBHIDReportFlagData |
                 kUSBHIDReportFlagVariable |
                 kUSBHIDReportFlagAbsolute |
                 kUSBHIDReportFlagNoWrap |
                 kUSBHIDReportFlagLinear |
                 kUSBHIDReportFlagPreferredState |
                 kUSBHIDReportFlagNoNullPosition |
                 kUSBHIDReportFlagBitField,

    // Padding
    REPORT_COUNT(1),       1,
    REPORT_SIZE(1),        1,
    HIDINPUT(1), kUSBHIDReportFlagConstant,

    // End of Consumer report

  END_COLLECTION(0)
};

typedef enum {
  ConsumerReportCodeNone              = 0,
  ConsumerReportCodeMenu              = 1 << 0,
  ConsumerReportCodeHelp              = 1 << 1,
  ConsumerReportCodeScanNextTrack     = 1 << 2,
  ConsumerReportCodeScanPreviousTrack = 1 << 3,
  ConsumerReportCodePlayPause         = 1 << 4,
  ConsumerReportCodeMute              = 1 << 5,
  ConsumerReportCodeVolumeIncrement   = 1 << 6,
  ConsumerReportCodeVolumeDecrement   = 1 << 7,
} ConsumerReportCode;

typedef enum {
  SteeringRemoteInputUnknown = -1,
  SteeringRemoteInputNone = 0,
  SteeringRemoteInputNext,
  SteeringRemoteInputPrevious,
  SteeringRemoteInputPlus,
  SteeringRemoteInputMinus,
  SteeringRemoteInputMute,
  SteeringRemoteInputSource,
  SteeringRemoteInputAnswerPhone,
  SteeringRemoteInputHangUpPhone,
  SteeringRemoteInputVoiceInput
} SteeringRemoteInput;

static SteeringRemoteInput previousSteeringRemoteInput = SteeringRemoteInputNone;
static BLECharacteristic* inputReportCharacteristic;
static bool isConnected = false;
static bool wasConnected = false;
static unsigned long lastiPadSleepPreventionMillis = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) {
    isConnected = true;
  }

  void onDisconnect(BLEServer* server) {
    isConnected = false;
  }
};

static bool rateIsAbout(float rate, float referenceRate) {
  // The voltage tend to be higher when the buttan is contacting
  return (referenceRate - 0.01) < rate && rate < (referenceRate + 0.06);
}

static SteeringRemoteInput getCurrentSteeringRemoteInput() {
  float inputRateA = (float)analogRead(kSteeringRemoteInputPinA) / kAnalogInputMaxValue;
  float inputRateB = (float)analogRead(kSteeringRemoteInputPinB) / kAnalogInputMaxValue;

  if (rateIsAbout(inputRateA, 1.00) && rateIsAbout(inputRateB, 1.00)) {
    return SteeringRemoteInputNone;
  } else if (rateIsAbout(inputRateA, 0.00)) {
    return SteeringRemoteInputNext;
  } else if (rateIsAbout(inputRateA, 0.09)) {
    return SteeringRemoteInputPrevious;
  } else if (rateIsAbout(inputRateA, 0.28)) {
    return SteeringRemoteInputPlus;
  } else if (rateIsAbout(inputRateA, 0.51)) {
    return SteeringRemoteInputMinus;
  } else if (rateIsAbout(inputRateA, 0.67)) {
    return SteeringRemoteInputMute;
  } else if (rateIsAbout(inputRateB, 0.00)) {
    return SteeringRemoteInputSource;
  } else if (rateIsAbout(inputRateB, 0.09)) {
    return SteeringRemoteInputAnswerPhone;
  } else if (rateIsAbout(inputRateB, 0.28)) {
    return SteeringRemoteInputHangUpPhone;
  } else if (rateIsAbout(inputRateB, 0.51)) {
    return SteeringRemoteInputVoiceInput;
  } else {
    #ifdef DEBUG
    Serial.print("Unknown Steering Remote Input: ");
    Serial.print(inputRateA);
    Serial.print(" ");
    Serial.print(inputRateB);
    Serial.println();
    #endif
    return SteeringRemoteInputUnknown;
  }
}

SteeringRemoteInput getSteeringRemoteInputWithoutChatter() {
  SteeringRemoteInput initialInput = getCurrentSteeringRemoteInput();

  if (initialInput <= 0) {
    return SteeringRemoteInputNone;
  }

  unsigned long initialInputMillis = millis();

  while (getCurrentSteeringRemoteInput() == initialInput) {
    if (millis() > initialInputMillis + kNonChatterThresholdMillis) {
      return initialInput;
    }
  }

  return SteeringRemoteInputNone;
}

static void startBLEServer() {
    BLEDevice::init(kDeviceName);

    BLEServer* server = BLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());

    BLEHIDDevice* hidDevice = new BLEHIDDevice(server);
    hidDevice->reportMap((uint8_t*)kReportMap, sizeof(kReportMap));
    hidDevice->pnp(2, 0x05AC, 0x0255, 0);
    // inputReport() is defined as BLEHIDDevice::inputReport(uint8_t reportID)
    // but using each input report for report ID 1 and 2 does not work for some reason.
    // Anyway we can indicate report ID with the first byte of notification data.
    inputReportCharacteristic = hidDevice->inputReport(1);

    hidDevice->startServices();

    // TODO: Use BLEAdvertisementData::setName() to show the name properly even before unpaired
    BLEAdvertising* advertising = server->getAdvertising();
    advertising->setAppearance(ESP_BLE_APPEARANCE_GENERIC_HID);
    advertising->addServiceUUID(hidDevice->hidService()->getUUID());
    advertising->start();
};

static void notifyInputReport(uint8_t* report, uint8_t size) {
  inputReportCharacteristic->setValue(report, size);
  inputReportCharacteristic->notify(true);
}

static void sendConsumerReportCode(ConsumerReportCode code) {
  uint8_t keyPressedReport[] = {kConsumerReportID, code};
  notifyInputReport(keyPressedReport, sizeof(keyPressedReport));

  uint8_t keyUnpressedReport[] = {kConsumerReportID, ConsumerReportCodeNone};
  notifyInputReport(keyUnpressedReport, sizeof(keyUnpressedReport));
}

static void sendBluetoothCommandForSteeringRemoteInput(SteeringRemoteInput steeringRemoteInput) {
  ConsumerReportCode code = ConsumerReportCodeNone;

  switch (steeringRemoteInput) {
    case SteeringRemoteInputNext:
      code = ConsumerReportCodeScanNextTrack;
      break;
    case SteeringRemoteInputPrevious:
      code = ConsumerReportCodeScanPreviousTrack;
      break;
    case SteeringRemoteInputPlus:
      code = ConsumerReportCodeVolumeIncrement;
      break;
    case SteeringRemoteInputMinus:
      code = ConsumerReportCodeVolumeDecrement;
      break;
    case SteeringRemoteInputMute:
      code = ConsumerReportCodePlayPause;
      break;
  }

  if (code == ConsumerReportCodeNone) {
    return;
  }

  sendConsumerReportCode(code);
}

static void handleSteeringRemoteInput() {
  SteeringRemoteInput currentSteeringRemoteInput = getSteeringRemoteInputWithoutChatter();

  if (currentSteeringRemoteInput != previousSteeringRemoteInput) {
    sendBluetoothCommandForSteeringRemoteInput(currentSteeringRemoteInput);
    #ifdef DEBUG
    Serial.println(currentSteeringRemoteInput);
    #endif
  }

  previousSteeringRemoteInput = currentSteeringRemoteInput;
}

static void unlockiPad() {
  sendConsumerReportCode(ConsumerReportCodeMenu);
  delay(500);
  sendConsumerReportCode(ConsumerReportCodeMenu);
}

static void keepiPadAwake() {
  unsigned long currentMillis = millis();

  if (currentMillis > lastiPadSleepPreventionMillis + kiPadSleepPreventionIntervalMillis) {
    #ifdef DEBUG
    Serial.println("Sending Help key code to keep the iPad awake");
    #endif

    sendConsumerReportCode(ConsumerReportCodeHelp);
    lastiPadSleepPreventionMillis = currentMillis;
  }
}

void setup() {
  #ifdef DEBUG
  Serial.begin(115200);
  #endif

  startBLEServer();
}

void loop() {
  if (isConnected) {
    if (!wasConnected) {
      // Not sure but this doen't work in ServerCallbacks::onConnect()
      delay(1000);
      unlockiPad();
    }

    handleSteeringRemoteInput();

    keepiPadAwake();
  }

  wasConnected = isConnected;
}
