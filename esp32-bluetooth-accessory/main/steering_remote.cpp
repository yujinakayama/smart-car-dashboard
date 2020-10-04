#include "log_config.h"
#include "steering_remote.h"
#include "Arduino.h"

static const char* TAG = "SteeringRemote";

static const int kInputValueStep1 = 0;
static const int kInputValueStep2 = 364;
static const int kInputValueStep3 = 1130;
static const int kInputValueStep4 = 2065;
static const int kInputValueStep5 = 2734;
static const int kAnalogInputMaxValue = 4095;

static const int kDebounceThresholdMillis = 50;

static bool nearlyEqual(int actualValue, int referenceValue) {
  return (referenceValue * 0.9) <= actualValue && actualValue <= (referenceValue * 1.1);
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
  int inputValueA = getRawInputA();
  int inputValueB = getRawInputB();

  if (nearlyEqual(inputValueA, kAnalogInputMaxValue) && nearlyEqual(inputValueB, kAnalogInputMaxValue)) {
    return SteeringRemoteInputNone;
  } else if (nearlyEqual(inputValueA, kInputValueStep1)) {
    return SteeringRemoteInputNext;
  } else if (nearlyEqual(inputValueA, kInputValueStep2)) {
    return SteeringRemoteInputPrevious;
  } else if (nearlyEqual(inputValueA, kInputValueStep3)) {
    return SteeringRemoteInputPlus;
  } else if (nearlyEqual(inputValueA, kInputValueStep4)) {
    return SteeringRemoteInputMinus;
  } else if (nearlyEqual(inputValueA, kInputValueStep5)) {
    return SteeringRemoteInputMute;
  } else if (nearlyEqual(inputValueB, kInputValueStep1)) {
    return SteeringRemoteInputSource;
  } else if (nearlyEqual(inputValueB, kInputValueStep2)) {
    return SteeringRemoteInputAnswerPhone;
  } else if (nearlyEqual(inputValueB, kInputValueStep3)) {
    return SteeringRemoteInputHangUpPhone;
  } else if (nearlyEqual(inputValueB, kInputValueStep4)) {
    return SteeringRemoteInputVoiceInput;
  } else {
    ESP_LOGD(TAG, "Unknown Steering Remote Input: %d %d", inputValueA, inputValueB);
    return SteeringRemoteInputUnknown;
  }
}

uint16_t SteeringRemote::getRawInputA() {
  return analogRead(inputPinA);
}

uint16_t SteeringRemote::getRawInputB() {
  return analogRead(inputPinB);
}

// Actual input values:
//
// 0
// 0
// 0
// 0
// 351
// 362
// 368
// 369
// 370
// 371
// 371
// 371
// 373
// 373
// 373
// 373
// 374
// 375
// 375
// 375
// 378
// 378
// 379
// 379
// 384
// 385
// 386
// 410
// 1111
// 1120
// 1125
// 1126
// 1126
// 1127
// 1127
// 1127
// 1129
// 1130
// 1130
// 1131
// 1131
// 1132
// 1133
// 1133
// 1133
// 1134
// 1134
// 1135
// 1136
// 1136
// 1139
// 2021
// 2032
// 2046
// 2061
// 2063
// 2064
// 2064
// 2064
// 2064
// 2064
// 2064
// 2065
// 2065
// 2065
// 2065
// 2065
// 2065
// 2066
// 2066
// 2071
// 2071
// 2071
// 2075
// 2077
// 2108
// 2704
// 2722
// 2726
// 2727
// 2727
// 2729
// 2730
// 2730
// 2733
// 2733
// 2734
// 2734
// 2734
// 2735
// 2735
// 2736
// 2736
// 2736
// 2736
// 2736
// 2736
// 2738
// 2738
// 2742
// 2746
// 2749
// 2755
