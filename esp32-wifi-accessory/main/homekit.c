#include <hap.h>
#include <iot_button.h>

/* Reset network credentials if button is pressed for more than 3 seconds and then released */
static const uint32_t kNetworkResetButtonPressDuration = 3;

/* Reset to factory if button is pressed and held for more than 10 seconds */
static const uint32_t kFactoryResetButtonPressDuration = 10;

/**
 * @brief The network reset button callback handler.
 * Useful for testing the Wi-Fi re-configuration feature of WAC2
 */
static void resetNetworkConfiguration(void* arg) {
  hap_reset_network();
}

/**
 * @brief The factory reset button callback handler.
 */
static void resetToFactory(void* arg) {
  hap_reset_to_factory();
}

/**
 * The Reset button GPIO initialisation function.
 * Same button will be used for resetting Wi-Fi network as well as for reset to factory based on
 * the time for which the button is pressed.
 */
void initializeHomeKitResetButton(gpio_num_t resetButtonPin) {
  button_handle_t button = iot_button_create(resetButtonPin, BUTTON_ACTIVE_LOW);
  iot_button_add_on_release_cb(button, kNetworkResetButtonPressDuration, resetNetworkConfiguration, NULL);
  iot_button_add_on_press_cb(button, kFactoryResetButtonPressDuration, resetToFactory, NULL);
}
