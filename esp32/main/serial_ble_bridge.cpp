#include "log_config.h"
#include "serial_ble_bridge.h"

static const char* TAG = "SerialBLEBridge";
static const size_t serialReadBufferSize = 256;

static void transmitDataFromSerialToBLE(void* pvParameters) {
  SerialBLEBridge* bridge = (SerialBLEBridge*)pvParameters;

  uint8_t serialReadBuffer[serialReadBufferSize];
  size_t readableByteSize;
  size_t actualReadByteSize;

  while (true) {
    if (!bridge->isBLEConnected()) {
      continue;
    }

    readableByteSize = bridge->serial->available();

    if (readableByteSize == 0) {
      continue;
    }

    actualReadByteSize = bridge->serial->readBytes(serialReadBuffer, min(readableByteSize, serialReadBufferSize));

    ESP_LOGD(TAG, "Receiving data from serial:");
    ESP_LOG_BUFFER_HEX_LEVEL(TAG, serialReadBuffer, actualReadByteSize, ESP_LOG_DEBUG);

    bridge->uart->transmit(serialReadBuffer, actualReadByteSize);
    delay(3);
  }
}

class MyBLEUARTCallbacks: public BLEUARTCallbacks {
public:
  SerialBLEBridge* bridge;

  MyBLEUARTCallbacks(SerialBLEBridge* bridge) {
    this->bridge = bridge;
  }

  void onReceive(std::string data) {
    if (data.length() == 0) {
      return;
    }

    ESP_LOGD(TAG, "Receiving data from BLE:");
    ESP_LOG_BUFFER_HEX_LEVEL(TAG, data.data(), data.length(), ESP_LOG_DEBUG);

    bridge->serial->write((uint8_t*)data.data(), data.length());
  }
};

SerialBLEBridge::SerialBLEBridge(HardwareSerial* serial, BLEServer* server) {
  this->serial = serial;
  this->server = server;

  uart = new BLEUART(server);
  uart->setCallbacks(new MyBLEUARTCallbacks(this));
}

bool SerialBLEBridge::isBLEConnected() {
  return server->getConnectedCount() > 0;
}

void SerialBLEBridge::start() {
  uart->startService();
  xTaskCreatePinnedToCore(transmitDataFromSerialToBLE, "SerialBLEBridge::transmitDataFromSerialToBLE", 4096, this, 1, nullptr, CONFIG_ARDUINO_RUNNING_CORE);
}
