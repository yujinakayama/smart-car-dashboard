#ifndef IPAD_CAR_INTEGRATION_STEERING_REMOTE_H_
#define IPAD_CAR_INTEGRATION_STEERING_REMOTE_H_

typedef enum {
  SteeringRemoteInputUnknown = -1,
  SteeringRemoteInputNone = 0,
  SteeringRemoteInputNext,
  SteeringRemoteInputPrevious,
  SteeringRemoteInputPlus,
  SteeringRemoteInputMinus,
  SteeringRemoteInputMute,
  SteeringRemoteInputSource,
  SteeringRemoteInputAnswerPhone,
  SteeringRemoteInputHangUpPhone,
  SteeringRemoteInputVoiceInput
} SteeringRemoteInput;

class SteeringRemoteCallbacks;

class SteeringRemote {
public:
  int inputPinA; // The brown-yellow wire in the car
  int inputPinB; // The brown-white wire in the car
  SteeringRemoteCallbacks* callbacks;

  SteeringRemote(int inputPinA, int inputPinB);
  void setCallbacks(SteeringRemoteCallbacks* callbacks);
  void startInputObservation();
  SteeringRemoteInput getDebouncedCurrentInput();
  SteeringRemoteInput getCurrentInput();
  uint16_t getRawInputA();
  uint16_t getRawInputB();
};

class SteeringRemoteCallbacks {
public:
	virtual void onInputChange(SteeringRemote* steeringRemote, SteeringRemoteInput input);
};

#endif
