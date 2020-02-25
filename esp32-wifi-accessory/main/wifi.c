#include "log_config.h"
#include "wifi.h"
#include "wifi_config.h"
#include <esp_wifi.h>
#include <esp_event_loop.h>

static const char* TAG = "Wi-Fi";

void (*connectionCallback)();

static esp_err_t handleWiFiEvent(void* context, system_event_t* event);

void connectToWiFiAccessPoint(void (*callback)()) {
    connectionCallback = callback;

    tcpip_adapter_init();

    ESP_ERROR_CHECK(esp_event_loop_init(handleWiFiEvent, NULL) );

    wifi_init_config_t defaultConfig = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&defaultConfig));

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA) );

    wifi_config_t wifiConfig = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASSWORD
        }
    };
    ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifiConfig) );

    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "Connecting to SSID: %s", WIFI_SSID);
}

static esp_err_t handleWiFiEvent(void* context, system_event_t* event) {
    switch(event->event_id) {
    case SYSTEM_EVENT_STA_START:
        esp_wifi_connect();
        break;
    case SYSTEM_EVENT_STA_GOT_IP:
        ESP_LOGI(TAG, "Got IP Address: %s", ip4addr_ntoa(&event->event_info.got_ip.ip_info.ip));
        connectionCallback();
        break;
    case SYSTEM_EVENT_STA_DISCONNECTED:
        esp_wifi_connect();
        break;
    default:
        break;
    }

    return ESP_OK;
}
