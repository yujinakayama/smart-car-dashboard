#ifndef IPAD_CAR_INTEGRATION_BLE_UART_H_
#define IPAD_CAR_INTEGRATION_BLE_UART_H_

#include <BLEServer.h>
#include <BLEService.h>

class BLEUARTCallbacks;

class BLEUART {
public:
  BLEUARTCallbacks* callbacks;

  BLEUART(BLEServer* server);
  BLEService* getService();
  void setCallbacks(BLEUARTCallbacks* callbacks);
  void startService();
  void transmit(uint8_t* data, size_t size);

private:
  BLEServer* server;
  BLEService* service;
  BLECharacteristic* txCharacteristic;
  BLECharacteristic* rxCharacteristic;
};

class BLEUARTCallbacks {
public:
  virtual void onReceive(std::string data);
};

#endif
