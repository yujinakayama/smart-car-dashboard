#include "log_config.h"
#include "hid.h"
#include "usb_hid_definition.h"
#include "Arduino.h"
#include <HIDTypes.h>

static const char* TAG = "HID";

static const uint8_t kKeyboardReportID = 1;
static const uint8_t kConsumerReportID = 2;

// http://who-t.blogspot.com/2018/12/understanding-hid-report-descriptors.html
// https://github.com/T-vK/ESP32-BLE-Keyboard/blob/f8dd4852113a722a6b8dc8af987e94cf84d73ad5/BleKeyboard.cpp
// https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
static const uint8_t kReportMap[] = {
  // We define the root usage page as "Generic Desktop Controls" - "Keypad" device rather than
  // "Generic Desktop Controls" - "Keyboard" or "Consumer" - "Consumer Control" because:
  // * With "Generic Desk Controls" - "Keyboard", iOS hides software keyboard
  // * With "Consumer" - "Consumer Control", modifier keys (e.g. command key) does not work
  USAGE_PAGE(1),        0x01, // Generic Desktop Controls
  USAGE(1),             0x07, // Keypad

  COLLECTION(1),        0x01, // Application Collection

    // Beginning of Keyboard report
    REPORT_ID(1), kKeyboardReportID,

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
    REPORT_COUNT(1),       8, // 8 buttons
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

    // No padding is needed since the the report is already aligned with 8 bit.
    // REPORT_COUNT(1),       1,
    // REPORT_SIZE(1),        1,
    // HIDINPUT(1), kUSBHIDReportFlagConstant,

    // End of Consumer report

  END_COLLECTION(0)
};

HID::HID(BLEServer* server) {
  this->server = server;
  hidDevice = createHIDDevice();
  consumerInputReportCharacteristic = hidDevice->inputReport(kConsumerReportID);
}

BLEHIDDevice* HID::createHIDDevice() {
  BLEHIDDevice* hidDevice = new BLEHIDDevice(server);
  hidDevice->reportMap((uint8_t*)kReportMap, sizeof(kReportMap));
  hidDevice->pnp(2, 0x05AC, 0x0255, 0);
  return hidDevice;
};

BLEService* HID::getHIDService() {
  return hidDevice->hidService();
}

void HID::startServices() {
  hidDevice->startServices();
};

void HID::sendConsumerInput(HIDConsumerInput input) {
  uint8_t keyPressedReport[] = {input};
  notifyConsumerInputReport(keyPressedReport, sizeof(keyPressedReport));

  uint8_t keyUnpressedReport[] = {HIDConsumerInputNone};
  notifyConsumerInputReport(keyUnpressedReport, sizeof(keyUnpressedReport));
}

void HID::notifyConsumerInputReport(uint8_t* report, size_t size) {
  consumerInputReportCharacteristic->setValue(report, size);
  consumerInputReportCharacteristic->notify(true);
}
