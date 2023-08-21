#include "log_config.h"
#include "homekit_bridge.h"

extern "C" {
  #include <app_hap_setup_payload.h>
}

static const char* TAG = "HomeKitBridge";

static const char* kSetupID = "BRDG"; // This must be unique
static const hap_cid_t kCategoryID = HAP_CID_BRIDGE;

/* Mandatory identify routine for the accessory.
 * In a real accessory, something like LED blink should be implemented
 * got visual identification
 */
static int identifyAccessory(hap_acc_t* ha) {
  ESP_LOGI(TAG, "Accessory identified");
  return HAP_SUCCESS;
}

HomeKitBridge::HomeKitBridge() {
}

void HomeKitBridge::registerHomeKitAccessory() {
  ESP_LOGI(TAG, "registerHomeKitAccessory");

  this->createAccessory();
  hap_add_accessory(this->accessory);
  this->configureHomeKitSetupCode();
}

void HomeKitBridge::createAccessory() {
  /* Initialise the mandatory parameters for Accessory which will be added as
   * the mandatory services internally
   */
  hap_acc_cfg_t config = {
    .name = (char*)"Bridge",
    .model = (char*)"Model",
    .manufacturer = (char*)"Yuji Nakayama",
    .serial_num = (char*)"Serial Number",
    .fw_rev = (char*)"Firmware Version",
    .hw_rev = NULL,
    .pv = (char*)"1.0.0",
    .cid = kCategoryID,
    .identify_routine = identifyAccessory,
  };

  /* Create accessory object */
  this->accessory = hap_acc_create(&config);

  /* Add a dummy Product Data */
  uint8_t product_data[] = {'E','S','P','3','2','H','A','P'};
  hap_acc_add_product_data(accessory, product_data, sizeof(product_data));
}

void HomeKitBridge::configureHomeKitSetupCode() {
  /* Unique Setup code of the format xxx-xx-xxx. Default: 111-22-333 */
  hap_set_setup_code(CONFIG_EXAMPLE_SETUP_CODE);
  /* Unique four character Setup Id. Default: ES32 */
  hap_set_setup_id(kSetupID);
}

void HomeKitBridge::printSetupQRCode() {
  app_hap_setup_payload((char*)CONFIG_EXAMPLE_SETUP_CODE, (char*)kSetupID, false, kCategoryID);
}
