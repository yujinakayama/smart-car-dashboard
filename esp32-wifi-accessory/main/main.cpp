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

#include "engine.h"
#include "garage_remote.h"
#include "homekit_bridge.h"

extern "C" {
  #include "homekit.h"
  #include "log_config.h"
  #include "wifi.h"
}

/*The main thread for handling the accessory */
static void mainTask(void *p) {
  setupLogLevel();

  /* Initialize the HAP core */
  hap_init(HAP_TRANSPORT_WIFI);

  HomeKitBridge* bridge = new HomeKitBridge();
  bridge->registerHomeKitAccessory();

  Engine* engine = new Engine(GPIO_NUM_16, GPIO_NUM_17);
  engine->registerBridgedHomeKitAccessory();

  GarageRemote* garageRemote = new GarageRemote(GPIO_NUM_18, GPIO_NUM_19);
  garageRemote->registerBridgedHomeKitAccessory();

  startWiFiAccessPoint();
  /* After all the initializations are done, start the HAP core */
  hap_start();

  bridge->printSetupQRCode();

  initializeHomeKitResetButton(GPIO_NUM_0);

  /* The task ends here. The read/write callbacks will be invoked by the HAP Framework */
  vTaskDelete(NULL);
}

extern "C" void app_main() {
  uint32_t stackDepth = 4 * 1024;
  UBaseType_t priority = 1;
  xTaskCreate(mainTask, "main", stackDepth, NULL, priority, NULL);
}
