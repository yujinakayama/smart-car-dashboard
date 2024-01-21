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
/** HAP Apple Services
 *
 * This offers helper APIs for all the standard HomeKit Services defined by Apple
 */
#ifndef _HAP_CUSTOM_SERVS_H_
#define _HAP_CUSTOM_SERVS_H_

#include <stdint.h>
#include <stdbool.h>

#include <hap.h>

#ifdef __cplusplus
extern "C" {
#endif

// https://github.com/apple/HomeKitADK/blob/fb201f98f5fdc7fef6a455054f08b59cca5d1ec8/HAP/HAPUUID.h#L27-L28
#define HAP_SERV_UUID_AIR_PRESSURE_SENSOR "00010000-3420-4EDC-90D1-E326457409CF"

/** Air Pressure Sensor Service
 *
 * This API will create the Air Pressure Sensor Service with the mandatory
 * characteristics.
 *
 * @param[in]  curr_temp  Initial value of Current Air Pressure characteristic
 *
 * @return Pointer to the service object on success
 * @return NULL on failure
 */
hap_serv_t *hap_serv_air_pressure_sensor_create(float curr_pressure);

#ifdef __cplusplus
}
#endif

#endif /* _HAP_CUSTOM_SERVS_H_ */
