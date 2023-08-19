#pragma once

// https://docs.espressif.com/projects/esp-idf/en/latest/api-reference/system/log.html

#define LOG_LOCAL_LEVEL ESP_LOG_DEBUG

#include <esp_log.h>

void setupLogLevel();
