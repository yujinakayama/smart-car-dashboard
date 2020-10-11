#include "wifi.h"
#include "wifi_config.h"

#include <esp_netif.h>
#include <esp_wifi.h>
#include <string.h>

void startWiFiAccessPoint() {
  /* Initialize TCP/IP */
  ESP_ERROR_CHECK(esp_netif_init());

  /* Initialize the event loop */
  ESP_ERROR_CHECK(esp_event_loop_create_default());

  esp_netif_create_default_wifi_ap();

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));

  wifi_config_t wifi_config = {
    .ap = {
      .ssid = WIFI_SSID,
      .ssid_len = strlen(WIFI_SSID),
      .password = WIFI_PASSWORD,
      .max_connection = 10,
      .authmode = WIFI_AUTH_WPA_WPA2_PSK
    },
  };

  if (strlen(WIFI_SSID) == 0) {
    wifi_config.ap.authmode = WIFI_AUTH_OPEN;
  }

  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
  ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_AP, &wifi_config));
  ESP_ERROR_CHECK(esp_wifi_start());
}
