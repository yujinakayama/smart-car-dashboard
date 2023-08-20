#pragma once

#include <hap.h>

class HomeKitBridge {
public:
  hap_acc_t* accessory;

  HomeKitBridge();
  void registerHomeKitAccessory();
  void printSetupQRCode();

private:
  void createAccessory();
  void configureHomeKitSetupCode();
};
