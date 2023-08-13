#ifndef IPAD_CAR_INTEGRATION_ENGINE_H_
#define IPAD_CAR_INTEGRATION_ENGINE_H_

#include <hap.h>
#include <driver/gpio.h>

// https://developer.apple.com/documentation/homekit/hmcharacteristicvaluelockmechanismstate
typedef enum {
  LockMechanismStateUnsecured = 0,
  LockMechanismStateSecured = 1,
  LockMechanismStateJammed = 2,
  LockMechanismStateUnknown = 3,
} LockMechanismState;

class CarSmartKey {
public:
  gpio_num_t powerPin;
  gpio_num_t lockButtonPin;
  gpio_num_t unlockButtonPin;
  gpio_num_t engineStatePin;
  hap_acc_t* accessory;
  hap_acc_cfg_t accessoryConfig;
  hap_char_t* engineOnCharacteristic;

  CarSmartKey(gpio_num_t powerOutputPin, gpio_num_t lockButtonOutputPin, gpio_num_t unlockButtonOutputPin, gpio_num_t engineStateInputPin);
  void registerBridgedHomeKitAccessory();

  bool getEngineState(bool loggingEnabled = true);
  void setEngineState(bool state);

  void lockDoors();
  void unlockDoors();

private:
  void createAccessory();
  void addEngineService();
  void addDoorLockService();
  void addFirmwareUpgradeService();
  void startObservingEngineState();
  void startEngine();
  void stopEngine();
  void activateSmartKey();
  void deactivateSmartKey();
  void pressSmartKeyLockButton(uint32_t durationInMilliseconds);
  void pressSmartKeyUnlockButton(uint32_t durationInMilliseconds);
};

#endif
