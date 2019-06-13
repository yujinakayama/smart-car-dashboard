#include "log_config.h"
#include <BLEDevice.h>

static const char* TAG = "BLE";

// https://github.com/espressif/esp-idf/blob/v3.2/components/bt/bluedroid/api/include/api/esp_gatts_api.h#L26-L54
static const char* kGATTServerEventNames[] = {
  "REG",
  "READ",
  "WRITE",
  "EXEC_WRITE",
  "MTU",
  "CONF",
  "UNREG",
  "CREATE",
  "ADD_INCL_SRVC",
  "ADD_CHAR",
  "ADD_CHAR_DESCR",
  "DELETE",
  "START",
  "STOP",
  "CONNECT",
  "DISCONNECT",
  "OPEN",
  "CANCEL_OPEN",
  "CLOSE",
  "LISTEN",
  "CONGEST",
  "RESPONSE",
  "CREAT_ATTR_TAB",
  "SET_ATTR_VAL",
  "SEND_SERVICE_CHANGE",
};

void handleBLEServerEvent(esp_gatts_cb_event_t event, esp_gatt_if_t gattc_if, esp_ble_gatts_cb_param_t* param) {
  ESP_LOGD(TAG, "%s", kGATTServerEventNames[event]);
}

void enableBLEServerEventLogging() {
  BLEDevice::setCustomGattsHandler(handleBLEServerEvent);
}
