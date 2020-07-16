/*
 This file is part of BeeTee Project. It is subject to the license terms in the LICENSE file found in the top-level directory of this distribution and at https://github.com/michaeldorner/BeeTee/blob/master/LICENSE. No part of BeeTee Project, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the LICENSE file.
 */

#import "BluetoothDeviceHandler.h"

@interface BluetoothDeviceHandler ()

@property (strong, nonatomic, readwrite) BluetoothDevice* device;

@end

@implementation BluetoothDeviceHandler

- (instancetype)initWithNotification:(NSNotification*)notification {
    return [self initWithDevice:notification.object];
}

- (instancetype)initWithDevice:(BluetoothDevice*)device {
    self = [super init];

    if (self) {
        self.device = device;
    }

    return self;
}

- (void)connect {
    [self.device connect];
}

- (NSString*)name {
    return self.device.name;
}

- (NSString*)address {
    return self.device.address;
}

- (NSUInteger)majorClass {
    return self.device.majorClass;
}

- (NSUInteger)minorClass {
    return self.device.minorClass;
}

- (NSInteger)type {
    return self.device.type;
}

- (BOOL)supportsBatteryLevel {
    return self.device.supportsBatteryLevel;
}

- (BOOL)isConnected {
    return self.device.connected;
}

@end
