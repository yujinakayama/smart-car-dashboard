#include "log_config.h"
#include "hid.h"
#include "usb_hid_definition.h"
#include "Arduino.h"
#include <HIDTypes.h>

static const char* TAG = "HID";

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

HID::HID(BLEServer* server) {
  this->server = server;
  hidDevice = createHIDDevice();
  // inputReport() is defined as BLEHIDDevice::inputReport(uint8_t reportID)
  // but using each input report for report ID 1 and 2 does not work for some reason.
  // Anyway we can indicate report ID with the first byte of notification data.
  inputReportCharacteristic = hidDevice->inputReport(1);
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

void HID::sendInputCode(HIDInputCode code) {
  uint8_t keyPressedReport[] = {kConsumerReportID, code};
  notifyInputReport(keyPressedReport, sizeof(keyPressedReport));

  uint8_t keyUnpressedReport[] = {kConsumerReportID, HIDInputCodeNone};
  notifyInputReport(keyUnpressedReport, sizeof(keyUnpressedReport));
}

void HID::notifyInputReport(uint8_t* report, size_t size) {
  inputReportCharacteristic->setValue(report, size);
  inputReportCharacteristic->notify(true);
}
