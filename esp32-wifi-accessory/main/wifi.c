#include "wifi.h"
#include "wifi_config.h"

#include <esp_netif.h>
#include <esp_wifi.h>
#include <string.h>

static void configureDHCPServer() {
  esp_netif_t* netif = esp_netif_create_default_wifi_ap();

  ESP_ERROR_CHECK(esp_netif_dhcps_stop(netif)); // Need to stop DHCP server to update IP info

  // https://github.com/espressif/esp-idf/blob/8bc19ba893e5544d571a753d82b44a84799b94b1/components/esp_netif/esp_netif_defaults.c#L42-L45
  esp_netif_ip_info_t ipInfo;
  ESP_ERROR_CHECK(esp_netif_get_ip_info(netif, &ipInfo));
  esp_ip4_addr_t gatewayAddress;
  gatewayAddress.addr = 0; // 0.0.0.0
  ipInfo.gw = gatewayAddress;
  ESP_ERROR_CHECK(esp_netif_set_ip_info(netif, &ipInfo));

  ESP_ERROR_CHECK(esp_netif_dhcps_start(netif));
}

void configureWiFi() {
  wifi_init_config_t initializationConfig = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&initializationConfig));

  wifi_config_t config = {
    .ap = {
      .ssid = WIFI_SSID,
      .ssid_len = strlen(WIFI_SSID),
      .password = WIFI_PASSWORD,
      .max_connection = 10,
      .authmode = WIFI_AUTH_WPA_WPA2_PSK
    },
  };

  if (strlen(WIFI_SSID) == 0) {
    config.ap.authmode = WIFI_AUTH_OPEN;
  }

  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
  ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_AP, &config));
}

void startWiFiAccessPoint() {
  /* Initialize TCP/IP */
  ESP_ERROR_CHECK(esp_netif_init());

  /* Initialize the event loop */
  ESP_ERROR_CHECK(esp_event_loop_create_default());

  configureDHCPServer();

  configureWiFi();

  ESP_ERROR_CHECK(esp_wifi_start());
}
