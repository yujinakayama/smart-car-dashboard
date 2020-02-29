#ifndef IPAD_CAR_INTEGRATION_SERIAL_BLE_BRIDGE_H_
#define IPAD_CAR_INTEGRATION_SERIAL_BLE_BRIDGE_H_

#include "ble_uart.h"
#include "Arduino.h"
#include <BLEServer.h>

class SerialBLEBridge {
public:
  HardwareSerial* serial;
  BLEServer* server;
  BLEUART* uart;

  SerialBLEBridge(HardwareSerial* serial, BLEServer* server);
  bool isBLEConnected();
  void start();
};

#endif
