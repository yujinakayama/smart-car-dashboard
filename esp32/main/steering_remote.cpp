#include "steering_remote.h"
#include "Arduino.h"

static const int kAnalogInputMaxValue = 4095;

static const int kDebounceThresholdMillis = 50;

static bool rateIsAbout(float rate, float referenceRate) {
  // The voltage tend to be higher when the buttan is contacting
  return (referenceRate - 0.01) < rate && rate < (referenceRate + 0.06);
}

SteeringRemote::SteeringRemote(int inputPinA, int inputPinB) {
  this->inputPinA = inputPinA;
  this->inputPinB = inputPinB;
}

SteeringRemoteInput SteeringRemote::getDebouncedCurrentInput() {
  SteeringRemoteInput initialInput = getCurrentInput();

  if (initialInput == SteeringRemoteInputNone || initialInput == SteeringRemoteInputUnknown) {
    return SteeringRemoteInputNone;
  }

  unsigned long initialInputMillis = millis();

  while (getCurrentInput() == initialInput) {
    if (millis() > initialInputMillis + kDebounceThresholdMillis) {
      return initialInput;
    }
  }

  return SteeringRemoteInputNone;
}

SteeringRemoteInput SteeringRemote::getCurrentInput() {
  float inputRateA = (float)analogRead(inputPinA) / kAnalogInputMaxValue;
  float inputRateB = (float)analogRead(inputPinB) / kAnalogInputMaxValue;

  if (rateIsAbout(inputRateA, 1.00) && rateIsAbout(inputRateB, 1.00)) {
    return SteeringRemoteInputNone;
  } else if (rateIsAbout(inputRateA, 0.00)) {
    return SteeringRemoteInputNext;
  } else if (rateIsAbout(inputRateA, 0.09)) {
    return SteeringRemoteInputPrevious;
  } else if (rateIsAbout(inputRateA, 0.28)) {
    return SteeringRemoteInputPlus;
  } else if (rateIsAbout(inputRateA, 0.51)) {
    return SteeringRemoteInputMinus;
  } else if (rateIsAbout(inputRateA, 0.67)) {
    return SteeringRemoteInputMute;
  } else if (rateIsAbout(inputRateB, 0.00)) {
    return SteeringRemoteInputSource;
  } else if (rateIsAbout(inputRateB, 0.09)) {
    return SteeringRemoteInputAnswerPhone;
  } else if (rateIsAbout(inputRateB, 0.28)) {
    return SteeringRemoteInputHangUpPhone;
  } else if (rateIsAbout(inputRateB, 0.51)) {
    return SteeringRemoteInputVoiceInput;
  } else {
    #ifdef DEBUG
    Serial.print("Unknown Steering Remote Input: ");
    Serial.print(inputRateA);
    Serial.print(" ");
    Serial.print(inputRateB);
    Serial.println();
    #endif
    return SteeringRemoteInputUnknown;
  }
}
