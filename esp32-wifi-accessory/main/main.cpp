#include "log_config.h" // This needs to be the top
#include "garage_remote.h"
#include "wifi_config.h"
#include <Arduino.h>
#include <WiFi.h>

static const char* TAG = "main";

void startWiFiAccessPoint();
void registerHomeKitAccessory();

void setup() {
  setupLogLevel();
  startWiFiAccessPoint();
  registerHomeKitAccessory();
}

void startWiFiAccessPoint() {
  WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);

  delay(100);

  IPAddress ipAddress = IPAddress(192, 168, 100, 1);
  IPAddress gatewayIPAddress = IPAddress(0,0,0,0);
  IPAddress subnet = IPAddress(255, 255, 255, 0);
  WiFi.softAPConfig(ipAddress, gatewayIPAddress, subnet);

  ESP_LOGI(TAG, "IP: %s", WiFi.softAPIP().toString().c_str());
}

void registerHomeKitAccessory() {
  GarageRemote* garageRemote = new GarageRemote(18, 19);
  garageRemote->registerHomeKitAccessory();
}

void loop() {
}
