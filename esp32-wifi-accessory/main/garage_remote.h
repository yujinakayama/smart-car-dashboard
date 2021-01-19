#ifndef IPAD_CAR_INTEGRATION_GARAGE_REMOTE_H_
#define IPAD_CAR_INTEGRATION_GARAGE_REMOTE_H_

#include <hap.h>
#include <driver/gpio.h>

typedef enum {
  CurrentDoorStateOpen = 0,
  CurrentDoorStateClosed,
  CurrentDoorStateOpening,
  CurrentDoorStateClosing,
  CurrentDoorStateStopped
} CurrentDoorState;

typedef enum {
  TargetDoorStateOpen = 0,
  TargetDoorStateClosed
} TargetDoorState;

class GarageRemote {
public:
  gpio_num_t powerButtonPin;
  gpio_num_t openButtonPin;
  hap_acc_t* accessory;
  hap_acc_cfg_t accessoryConfig;
  TargetDoorState targetDoorState;
  CurrentDoorState currentDoorState;

  GarageRemote(gpio_num_t powerButtonPin, gpio_num_t openButtonPin);
  void registerBridgedHomeKitAccessory();

  TargetDoorState getTargetDoorState();
  void setTargetDoorState(TargetDoorState state);

  CurrentDoorState getCurrentDoorState();

  void turnOffOpenButton();

private:
  void createAccessory();
  void addGarageDoorOpenerService();
  void addFirmwareUpgradeService();
  void open();
};

#endif
