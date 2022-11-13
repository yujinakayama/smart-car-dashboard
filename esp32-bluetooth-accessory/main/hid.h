#ifndef IPAD_CAR_INTEGRATION_HID_H_
#define IPAD_CAR_INTEGRATION_HID_H_

#include <BLEHIDDevice.h>
#include <BLEServer.h>
#include <BLEService.h>

typedef enum {
  HIDKeyboardModifierKeyNone         = 0,
  HIDKeyboardModifierKeyLeftControl  = 1 << 0,
  HIDKeyboardModifierKeyLeftShift    = 1 << 1,
  HIDKeyboardModifierKeyAlt          = 1 << 2,
  HIDKeyboardModifierKeyLeftCommand  = 1 << 3,
  HIDKeyboardModifierKeyRightControl = 1 << 4,
  HIDKeyboardModifierKeyRightShift   = 1 << 5,
  HIDKeyboardModifierKeyRightAlt     = 1 << 6,
  HIDKeyboardModifierKeyRightCommand = 1 << 7,
} HIDKeyboardModifierKey;

typedef enum {
  HIDKeyboardKeyNone     = 0,

  HIDKeyboardKeyA        = 0x04,
  HIDKeyboardKeyB        = 0x05,
  HIDKeyboardKeyC        = 0x06,
  HIDKeyboardKeyD        = 0x07,
  HIDKeyboardKeyE        = 0x08,
  HIDKeyboardKeyF        = 0x09,
  HIDKeyboardKeyG        = 0x0A,
  HIDKeyboardKeyH        = 0x0B,
  HIDKeyboardKeyI        = 0x0C,
  HIDKeyboardKeyJ        = 0x0D,
  HIDKeyboardKeyK        = 0x0E,
  HIDKeyboardKeyL        = 0x0F,
  HIDKeyboardKeyM        = 0x10,
  HIDKeyboardKeyN        = 0x11,
  HIDKeyboardKeyO        = 0x12,
  HIDKeyboardKeyP        = 0x13,
  HIDKeyboardKeyQ        = 0x14,
  HIDKeyboardKeyR        = 0x15,
  HIDKeyboardKeyS        = 0x16,
  HIDKeyboardKeyT        = 0x17,
  HIDKeyboardKeyU        = 0x18,
  HIDKeyboardKeyV        = 0x19,
  HIDKeyboardKeyW        = 0x1A,
  HIDKeyboardKeyX        = 0x1B,
  HIDKeyboardKeyY        = 0x1C,
  HIDKeyboardKeyZ        = 0x1D,

  HIDKeyboardKey1        = 0x1E,
  HIDKeyboardKey2        = 0x1F,
  HIDKeyboardKey3        = 0x20,
  HIDKeyboardKey4        = 0x21,
  HIDKeyboardKey5        = 0x22,
  HIDKeyboardKey6        = 0x23,
  HIDKeyboardKey7        = 0x24,
  HIDKeyboardKey8        = 0x25,
  HIDKeyboardKey9        = 0x26,
  HIDKeyboardKey0        = 0x27,

  HIDKeyboardKeyCapsLock = 0x39,
} HIDKeyboardKey;

typedef enum {
  HIDConsumerInputNone              = 0,
  HIDConsumerInputHelp              = 1 << 0,
  HIDConsumerInputScanNextTrack     = 1 << 1,
  HIDConsumerInputScanPreviousTrack = 1 << 2,
  HIDConsumerInputPlayPause         = 1 << 3,
  HIDConsumerInputMute              = 1 << 4,
  HIDConsumerInputVolumeIncrement   = 1 << 5,
  HIDConsumerInputVolumeDecrement   = 1 << 6,
  HIDConsumerInputGlobe             = 1 << 7,
} HIDConsumerInput;

class HID {
public:
  BLEServer* server;
  BLEHIDDevice* hidDevice;
  BLECharacteristic* keyboardInputReportCharacteristic;
  BLECharacteristic* consumerInputReportCharacteristic;

  HID(BLEServer* server);
  BLEService* getHIDService();
  void startServices();

  void performKeyboardInput(HIDKeyboardModifierKey modifierKey, HIDKeyboardKey key);
  void pressKeyboardInput(HIDKeyboardModifierKey modifierKey, HIDKeyboardKey key);
  void releaseKeyboardInput();

  void performConsumerInput(HIDConsumerInput code);
  void pressConsumerInput(HIDConsumerInput code);
  void releaseConsumerInput();

private:
  BLEHIDDevice* createHIDDevice();
  void notifyKeyboardInputReport(uint8_t* report, size_t size);
  void notifyConsumerInputReport(uint8_t* report, size_t size);
};

#endif
