#ifndef IPAD_CAR_INTEGRATION_ENGINE_H_
#define IPAD_CAR_INTEGRATION_ENGINE_H_

#include <hap.h>
#include <driver/gpio.h>

class Engine {
public:
  gpio_num_t smartKeyPowerPin;
  gpio_num_t smartKeyLockButtonPin;
  gpio_num_t engineStatePin;
  hap_acc_t* accessory;
  hap_acc_cfg_t accessoryConfig;
  hap_char_t* onCharacteristic;

  Engine(gpio_num_t smartKeyPowerOutputPin, gpio_num_t smartKeyLockButtonOutputPin, gpio_num_t engineStateInputPin);
  void registerBridgedHomeKitAccessory();

  bool isOn(bool loggingEnabled = true);
  void setOn(bool newOn);

private:
  void createAccessory();
  void addSwitchService();
  void addFirmwareUpgradeService();
  void startObservingEngineState();
  void startEngine();
  void stopEngine();
  void activateSmartKey();
  void deactivateSmartKey();
  void pressSmartKeyLockButton(uint32_t durationInMilliseconds);
};

#endif
