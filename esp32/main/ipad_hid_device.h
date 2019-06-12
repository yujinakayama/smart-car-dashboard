#include <BLEHIDDevice.h>
#include <BLEServer.h>
#include <BLEService.h>

typedef enum {
  iPadHIDDeviceInputCodeNone              = 0,
  iPadHIDDeviceInputCodeMenu              = 1 << 0,
  iPadHIDDeviceInputCodeHelp              = 1 << 1,
  iPadHIDDeviceInputCodeScanNextTrack     = 1 << 2,
  iPadHIDDeviceInputCodeScanPreviousTrack = 1 << 3,
  iPadHIDDeviceInputCodePlayPause         = 1 << 4,
  iPadHIDDeviceInputCodeMute              = 1 << 5,
  iPadHIDDeviceInputCodeVolumeIncrement   = 1 << 6,
  iPadHIDDeviceInputCodeVolumeDecrement   = 1 << 7,
} iPadHIDDeviceInputCode;

class iPadHIDDevice {
public:
  BLEServer* server;
  BLEHIDDevice* hidDevice;
  BLECharacteristic* inputReportCharacteristic;

  iPadHIDDevice(BLEServer* server);
  BLEService* getHIDService();
  void startServices();
  void sendInputCode(iPadHIDDeviceInputCode code);

private:
  BLEHIDDevice* createHIDDevice();
  void notifyInputReport(uint8_t* report, size_t size);
};
