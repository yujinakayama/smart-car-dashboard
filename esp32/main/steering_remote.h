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

class SteeringRemote {
public:
  int inputPinA; // The brown-yellow wire in the car
  int inputPinB; // The brown-white wire in the car

  SteeringRemote(int inputPinA, int inputPinB);
  SteeringRemoteInput getDebouncedCurrentInput();
  SteeringRemoteInput getCurrentInput();
};
