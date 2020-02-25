#ifndef IPAD_CAR_INTEGRATION_GARAGE_H_
#define IPAD_CAR_INTEGRATION_GARAGE_H_

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
  int powerButtonPin; // The brown-yellow wire in the car
  int openButtonPin; // The brown-white wire in the car
  struct hap_accessory* accessory;
  TargetDoorState targetDoorState;
  CurrentDoorState currentDoorState;

  GarageRemote(int powerButtonPin, int openButtonPin);
  void registerHomeKitAccessory();
  void registerHomeKitServicesAndCharacteristics();
};

#endif
