#include "log_config.h"
#include "http_server.h"

#include <esp_http_server.h>

static const char* TAG = "HTTPServer";

static const char* kDoorsLockPath = "/doors/lock";

static esp_err_t doorsLockHandler(httpd_req_t* request) {
  ESP_LOGI(TAG, "POST %s", kDoorsLockPath);

  CarSmartKey* smartKey = (CarSmartKey*)request->user_ctx;
  smartKey->lockDoors();

  const char response[] = "OK";
  httpd_resp_send(request, response, HTTPD_RESP_USE_STRLEN);
  return ESP_OK;
}

void startHTTPServer(uint16_t port, CarSmartKey* smartKey) {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = port;

    httpd_handle_t server = NULL;

    if (httpd_start(&server, &config) == ESP_OK) {
        httpd_uri_t doorsLockEndpoint = {};
        doorsLockEndpoint.method   = HTTP_POST;
        doorsLockEndpoint.uri      = "/doors/lock";
        doorsLockEndpoint.handler  = doorsLockHandler;
        doorsLockEndpoint.user_ctx = smartKey;
        httpd_register_uri_handler(server, &doorsLockEndpoint);

        ESP_LOGI(TAG, "HTTP server running on port %d", port);
    }
}
