#include "ble_uart.h"
#include "Arduino.h"
#include <BLE2902.h>

static const char* TAG = "BLEUART";

// https://infocenter.nordicsemi.com/topic/com.nordic.infocenter.sdk5.v12.2.0/ble_sdk_app_nus_eval.html
static const char* kUARTServiceUUID      = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* kTXCharacteristicUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* kRXCharacteristicUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

class RXCharacteristicCallbacks: public BLECharacteristicCallbacks {
public:
  BLEUART* uart;

  RXCharacteristicCallbacks(BLEUART* uart) {
    this->uart = uart;
  }

  void onWrite(BLECharacteristic* characteristic) {
    std::string data = characteristic->getValue();

    if (uart->callbacks != nullptr) {
      uart->callbacks->onReceive(data);
    }
  }
};

BLEUART::BLEUART(BLEServer* server) {
  this->server = server;

  service = server->createService(kUARTServiceUUID);

  txCharacteristic = service->createCharacteristic(kTXCharacteristicUUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  txCharacteristic->addDescriptor(new BLE2902());

  rxCharacteristic = service->createCharacteristic(kRXCharacteristicUUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  rxCharacteristic->setCallbacks(new RXCharacteristicCallbacks(this));
}

BLEService* BLEUART::getService() {
  return this->service;
}

void BLEUART::setCallbacks(BLEUARTCallbacks* callbacks) {
  this->callbacks = callbacks;
}

void BLEUART::startService() {
  service->start();
}

void BLEUART::transmit(uint8_t* data, size_t size) {
  txCharacteristic->setValue(data, size);
  txCharacteristic->notify();
}
