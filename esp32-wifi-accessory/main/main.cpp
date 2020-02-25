#include "log_config.h" // This needs to be the top
#include "wifi.h"
#include "garage_remote.h"
#include "Arduino.h"

static const char* TAG = "main";

void wifiDidConnect();

void setup() {
  setupLogLevel();
  connectToWiFiAccessPoint(&wifiDidConnect);
}

void loop() {
}

void wifiDidConnect() {
  ESP_LOGI(TAG, "onWiFiConnected");
  GarageRemote* garageRemote = new GarageRemote(18, 19);
  garageRemote->registerHomeKitAccessory();
}
