#pragma once

#ifdef __cplusplus
extern "C" {
#endif

unsigned long millis();

void delay(uint32_t ms);

char* strdup(const char* string);

#ifdef __cplusplus
}
#endif
