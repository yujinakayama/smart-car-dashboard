#pragma once

#include <hap.h>

class HomeKitBridge {
public:
  hap_acc_t* accessory;
  hap_acc_cfg_t accessoryConfig;

  HomeKitBridge();
  void registerHomeKitAccessory();
  void printSetupQRCode();

private:
  void createAccessory();
  void configureHomeKitSetupCode();
};
