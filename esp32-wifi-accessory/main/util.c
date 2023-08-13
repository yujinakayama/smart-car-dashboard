#include <string.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

void delay(uint32_t ms) {
  vTaskDelay(ms / portTICK_PERIOD_MS);
}

char* strdup(const char* string) {
   size_t length = strlen(string) + 1;
   void* buffer = malloc(length);
   if (buffer == NULL) return NULL;
   return (char*)memcpy(buffer, string, length);
}
