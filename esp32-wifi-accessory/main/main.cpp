/*
 * ESPRESSIF MIT License
 *
 * Copyright (c) 2018 <ESPRESSIF SYSTEMS (SHANGHAI) PTE LTD>
 *
 * Permission is hereby granted for use on ESPRESSIF SYSTEMS products only, in which case,
 * it is free of charge, to any person obtaining a copy of this software and associated
 * documentation files (the "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished
 * to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <driver/gpio.h>

#include "car_smart_key.h"
#include "garage_remote.h"
#include "homekit_bridge.h"
#include "homekit.h"
#include "log_config.h"
#include "util.h"
#include "wifi.h"

static void configureGPIOPins() {
  // Configure 12-15 GPIO pins since they cannot be used as output pins by default.
  // https://esp32.com/viewtopic.php?f=14&t=2687
  gpio_config_t config;
  config.pin_bit_mask = (1 << GPIO_NUM_12) | (1 << GPIO_NUM_13) | (1 << GPIO_NUM_14) | (1 << GPIO_NUM_15);
  config.mode = GPIO_MODE_INPUT_OUTPUT;
  ESP_ERROR_CHECK(gpio_config(&config));
}

/*The main thread for handling the accessory */
static void mainTask(void *p) {
  // Wait a bit to make inrush current lower at the boot time
  // https://dreamerdream.hateblo.jp/entry/2019/12/04/120000
  delay(50);

  setupLogLevel();

  configureGPIOPins();

  // This needs to be prior to CarSmartKey initialization
  // because this internally calls gpio_install_isr_service(),
  // which is also required in CarSmartKey.
  initializeHomeKitResetButton(GPIO_NUM_0);

  /* Initialize the HAP core */
  hap_init(HAP_TRANSPORT_WIFI);

  HomeKitBridge* bridge = new HomeKitBridge();
  bridge->registerHomeKitAccessory();

  CarSmartKey* smartKey = new CarSmartKey(GPIO_NUM_27, GPIO_NUM_14, GPIO_NUM_25, GPIO_NUM_26);
  smartKey->registerBridgedHomeKitAccessory();

  GarageRemote* garageRemote = new GarageRemote(GPIO_NUM_12, GPIO_NUM_13);
  garageRemote->registerBridgedHomeKitAccessory();

  startWiFiAccessPoint();
  /* After all the initializations are done, start the HAP core */
  hap_start();

  bridge->printSetupQRCode();

  /* The task ends here. The read/write callbacks will be invoked by the HAP Framework */
  vTaskDelete(NULL);
}

extern "C" void app_main() {
  uint32_t stackDepth = 4 * 1024;
  UBaseType_t priority = 1;
  xTaskCreate(mainTask, "main", stackDepth, NULL, priority, NULL);
}
