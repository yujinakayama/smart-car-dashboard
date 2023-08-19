#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <driver/gpio.h>

void initializeHomeKitResetButton(gpio_num_t resetButtonPin);

#ifdef __cplusplus
}
#endif
