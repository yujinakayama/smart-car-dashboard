#ifndef _HAP_CUSTOM_CHARS_H_
#define _HAP_CUSTOM_CHARS_H_

#include <stdint.h>
#include <stdbool.h>

#include <hap.h>

#ifdef __cplusplus
extern "C" {
#endif

#define HAP_CHAR_UNIT_PASCALS "pascals"

// https://github.com/apple/HomeKitADK/blob/fb201f98f5fdc7fef6a455054f08b59cca5d1ec8/HAP/HAPUUID.h#L27-L28
#define HAP_CHAR_UUID_CURRENT_AIR_PRESSURE "00000001-3420-4EDC-90D1-E326457409CF"

/** Current Air Pressure Characteristic
 *
 * This API creates the Air Pressure characteristic object with other metadata
 * (format, constraints, permissions, etc.) set
 *
 * @param[in] curr_pressure Initial value of current air pressure characteristic
 *
 * @return Pointer to the characteristic object on success
 * @return NULL on failure
 */
hap_char_t *hap_char_current_air_pressure_create(float curr_pressure);

#ifdef __cplusplus
}
#endif

#endif /* _HAP_CUSTOM_CHARS_H_ */
