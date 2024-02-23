/*
 * ESPRESSIF MIT License
 *
 * Copyright (c) 2020 <ESPRESSIF SYSTEMS (SHANGHAI) PTE LTD>
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
#include <hap.h>
#include "hap_custom_servs.h"
#include "hap_custom_chars.h"
#include "hap_apple_servs.h"

hap_serv_t *hap_serv_air_pressure_sensor_create(float curr_pressure)
{
    hap_serv_t *hs = hap_serv_create(HAP_SERV_UUID_AIR_PRESSURE_SENSOR);
    if (!hs) {
        return NULL;
    }
    if (hap_serv_add_char(hs, hap_char_current_air_pressure_create(curr_pressure)) != HAP_SUCCESS) {
        goto err;
    }
    return hs;
err:
    hap_serv_delete(hs);
    return NULL;
}

hap_serv_t *hap_serv_temperature_sensor_with_negative_value_create(float curr_temp)
{
    hap_serv_t *hs = hap_serv_create(HAP_SERV_UUID_TEMPERATURE_SENSOR);
    if (!hs) {
        return NULL;
    }
    if (hap_serv_add_char(hs, hap_char_current_temperature_with_negative_value_create(curr_temp)) != HAP_SUCCESS) {
        goto err;
    }
    return hs;
err:
    hap_serv_delete(hs);
    return NULL;
}

