#ifndef IPAD_CAR_INTEGRATION_HID_H_
#define IPAD_CAR_INTEGRATION_HID_H_

#include <BLEHIDDevice.h>
#include <BLEServer.h>
#include <BLEService.h>

typedef enum {
  HIDConsumerInputNone              = 0,
  HIDConsumerInputMenu              = 1 << 0,
  HIDConsumerInputHelp              = 1 << 1,
  HIDConsumerInputScanNextTrack     = 1 << 2,
  HIDConsumerInputScanPreviousTrack = 1 << 3,
  HIDConsumerInputPlayPause         = 1 << 4,
  HIDConsumerInputMute              = 1 << 5,
  HIDConsumerInputVolumeIncrement   = 1 << 6,
  HIDConsumerInputVolumeDecrement   = 1 << 7,
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
  void sendConsumerInput(HIDConsumerInput code);

private:
  BLEHIDDevice* createHIDDevice();
  void notifyConsumerInputReport(uint8_t* report, size_t size);
};

#endif
