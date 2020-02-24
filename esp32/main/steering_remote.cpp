#include "log_config.h"
#include "steering_remote.h"
#include "Arduino.h"

static const char* TAG = "SteeringRemote";

static const int kAnalogInputMaxValue = 4095;

static const int kDebounceThresholdMillis = 50;

static bool rateIsAbout(float rate, float referenceRate) {
  // The voltage tends to be higher when the button is contacting
  return (referenceRate - 0.02) < rate && rate < (referenceRate + 0.05);
}

static void logCurrentInput(SteeringRemote* steeringRemote) {
  uint16_t inputAValue = steeringRemote->getRawInputA();
  uint16_t inputBValue = steeringRemote->getRawInputB();

  ESP_LOGV(
    TAG,
    "Current Input: %i (%f), %i (%f)",
    inputAValue,
    (float)inputAValue / kAnalogInputMaxValue,
    inputBValue,
    (float)inputBValue / kAnalogInputMaxValue
  );
}

static void observeInput(void* pvParameters) {
  SteeringRemote* steeringRemote = (SteeringRemote*)pvParameters;
  SteeringRemoteInput previousInput = SteeringRemoteInputNone;

  #if LOG_LOCAL_LEVEL >= ESP_LOG_VERBOSE
  unsigned long lastLogMillis = millis();
  #endif

  while (true) {
    SteeringRemoteInput currentInput = steeringRemote->getDebouncedCurrentInput();

    #if LOG_LOCAL_LEVEL >= ESP_LOG_VERBOSE
    unsigned long currentMillis = millis();
    if (currentMillis > lastLogMillis + 500) {
      logCurrentInput(steeringRemote);
      lastLogMillis = currentMillis;
    }
    #endif

    if (currentInput != previousInput && steeringRemote->callbacks != nullptr) {
      steeringRemote->callbacks->onInputChange(steeringRemote, currentInput);
    }

    previousInput = currentInput;
  }
}

SteeringRemote::SteeringRemote(int inputPinA, int inputPinB) {
  this->inputPinA = inputPinA;
  this->inputPinB = inputPinB;
}

void SteeringRemote::setCallbacks(SteeringRemoteCallbacks* callbacks) {
  this->callbacks = callbacks;
}

void SteeringRemote::startInputObservation() {
  xTaskCreatePinnedToCore(observeInput, "SteeringRemote::observeInput", 4096, this, 1, nullptr, CONFIG_ARDUINO_RUNNING_CORE);
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
  float inputRateA = (float)getRawInputA() / kAnalogInputMaxValue;
  float inputRateB = (float)getRawInputB() / kAnalogInputMaxValue;

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
    ESP_LOGD(TAG, "Unknown Steering Remote Input: %f %f", inputRateA, inputRateB);
    return SteeringRemoteInputUnknown;
  }
}

uint16_t SteeringRemote::getRawInputA() {
  return analogRead(inputPinA);
}

uint16_t SteeringRemote::getRawInputB() {
  return analogRead(inputPinB);
}
