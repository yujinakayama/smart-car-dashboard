#include "log_config.h"

const char* TAG = "ipad-car-integration";

void setupLogLevel() {
  esp_log_level_set("main",           LOG_LOCAL_LEVEL);
  esp_log_level_set("iPadHIDDevice",  LOG_LOCAL_LEVEL);
  esp_log_level_set("SteeringRemote", LOG_LOCAL_LEVEL);
}
