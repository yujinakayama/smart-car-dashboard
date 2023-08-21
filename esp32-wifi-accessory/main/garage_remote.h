#pragma once

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
