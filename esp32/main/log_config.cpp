#include "log_config.h"

const char* TAG = "ipad-car-integration";

void setupLogLevel() {
  esp_log_level_set(TAG, LOG_LOCAL_LEVEL);
}
