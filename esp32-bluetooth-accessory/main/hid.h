#ifndef IPAD_CAR_INTEGRATION_HID_H_
#define IPAD_CAR_INTEGRATION_HID_H_

#include <BLEHIDDevice.h>
#include <BLEServer.h>
#include <BLEService.h>

typedef enum {
  HIDInputCodeNone              = 0,
  HIDInputCodeMenu              = 1 << 0,
  HIDInputCodeHelp              = 1 << 1,
  HIDInputCodeScanNextTrack     = 1 << 2,
  HIDInputCodeScanPreviousTrack = 1 << 3,
  HIDInputCodePlayPause         = 1 << 4,
  HIDInputCodeMute              = 1 << 5,
  HIDInputCodeVolumeIncrement   = 1 << 6,
  HIDInputCodeVolumeDecrement   = 1 << 7,
} HIDInputCode;

class HID {
public:
  BLEServer* server;
  BLEHIDDevice* hidDevice;
  BLECharacteristic* inputReportCharacteristic;

  HID(BLEServer* server);
  BLEService* getHIDService();
  void startServices();
  void sendInputCode(HIDInputCode code);

private:
  BLEHIDDevice* createHIDDevice();
  void notifyInputReport(uint8_t* report, size_t size);
};

#endif
