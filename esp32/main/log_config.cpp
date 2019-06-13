#include "log_config.h"

void setupLogLevel() {
  esp_log_level_set("main",           LOG_LOCAL_LEVEL);
  esp_log_level_set("BLE",            LOG_LOCAL_LEVEL);
  esp_log_level_set("HID",            LOG_LOCAL_LEVEL);
  esp_log_level_set("SteeringRemote", LOG_LOCAL_LEVEL);
}
