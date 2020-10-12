#include "log_config.h"

void setupLogLevel() {
  esp_log_level_set("main", LOG_LOCAL_LEVEL);
  esp_log_level_set("GarageRemote", LOG_LOCAL_LEVEL);
}
