#ifndef IPAD_CAR_INTEGRATION_ENGINE_H_
#define IPAD_CAR_INTEGRATION_ENGINE_H_

#include <hap.h>
#include <driver/gpio.h>

class Engine {
public:
  gpio_num_t smartKeyPowerPin;
  gpio_num_t smartKeyLockButtonPin;
  hap_acc_t* accessory;
  hap_acc_cfg_t accessoryConfig;
  bool on;

  Engine(gpio_num_t smartKeyPowerPin, gpio_num_t smartKeyLockButtonPin);
  void registerHomeKitAccessory();
  void printSetupQRCode();

  bool isOn();
  void setOn(bool newOn);

private:
  void createAccessory();
  void addSwitchService();
  void addFirmwareUpgradeService();
  void configureHomeKitSetupCode();
  void startEngine();
  void stopEngine();
  void activateSmartKey();
  void deactivateSmartKey();
  void pressSmartKeyLockButton(uint32_t durationInMilliseconds);
};

#endif
