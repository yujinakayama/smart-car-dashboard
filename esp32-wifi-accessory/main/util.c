#include <string.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

// https://github.com/espressif/arduino-esp32/blob/5063cdd797eab3fe77ef648cbae4c93de7b9c8dc/cores/esp32/esp32-hal-misc.c#L207-L215
unsigned long millis() {
    return (unsigned long)(esp_timer_get_time() / 1000ULL);
}

void delay(uint32_t ms) {
  vTaskDelay(ms / portTICK_PERIOD_MS);
}

char* strdup(const char* string) {
   size_t length = strlen(string) + 1;
   void* buffer = malloc(length);
   if (buffer == NULL) return NULL;
   return (char*)memcpy(buffer, string, length);
}
