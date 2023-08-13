#ifndef IPAD_CAR_INTEGRATION_ENGINE_H_
#define IPAD_CAR_INTEGRATION_ENGINE_H_

#include <hap.h>
#include <driver/gpio.h>

class CarSmartKey {
public:
  gpio_num_t powerPin;
  gpio_num_t lockButtonPin;
  gpio_num_t engineStatePin;
  hap_acc_t* accessory;
  hap_acc_cfg_t accessoryConfig;
  hap_char_t* engineOnCharacteristic;

  CarSmartKey(gpio_num_t powerOutputPin, gpio_num_t lockButtonOutputPin, gpio_num_t engineStateInputPin);
  void registerBridgedHomeKitAccessory();

  bool getEngineState(bool loggingEnabled = true);
  void setEngineState(bool state);

private:
  void createAccessory();
  void addEngineService();
  void addFirmwareUpgradeService();
  void startObservingEngineState();
  void startEngine();
  void stopEngine();
  void activateSmartKey();
  void deactivateSmartKey();
  void pressSmartKeyLockButton(uint32_t durationInMilliseconds);
};

#endif
