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
#include "hap_custom_chars.h"

/* Char: Current Air Pressure */
hap_char_t *hap_char_current_air_pressure_create(float curr_pressure)
{
    hap_char_t *hc = hap_char_float_create(HAP_CHAR_UUID_CURRENT_AIR_PRESSURE,
                                           HAP_CHAR_PERM_PR | HAP_CHAR_PERM_EV, curr_pressure);
    if (!hc) {
        return NULL;
    }

    // 0 - 2000 hPa
    hap_char_float_set_constraints(hc, 0, 200000, 1);
    hap_char_add_unit(hc, HAP_CHAR_UNIT_PASCALS);

    return hc;
}
