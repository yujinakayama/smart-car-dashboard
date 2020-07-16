/*
 This file is part of BeeTee Project. It is subject to the license terms in the LICENSE file found in the top-level directory of this distribution and at https://github.com/michaeldorner/BeeTee/blob/master/LICENSE. No part of BeeTee Project, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the LICENSE file.
 */

#import "BluetoothManagerHandler.h"
#import "BluetoothManager.h"

static BluetoothManager *_bluetoothManager = nil;
static BluetoothManagerHandler *_handler = nil;

@implementation BluetoothManagerHandler


+ (BluetoothManagerHandler*) sharedInstance {

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *b = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/BluetoothManager.framework"];
        if (![b load]) {
            NSLog(@"Error"); // maybe throw an exception
        } else {
            _bluetoothManager = [NSClassFromString(@"BluetoothManager") valueForKey:@"sharedInstance"];
            _handler = [[BluetoothManagerHandler alloc] init];
        }
    });
    return _handler;
}


- (bool) available {
    return [_bluetoothManager available];
}

- (bool) connectable {
    return [_bluetoothManager connectable];
}

- (bool) powered {
    return [_bluetoothManager powered];
}

- (bool)enabled {
    return [_bluetoothManager enabled];
}

- (void)disable {
    [_bluetoothManager setEnabled:false];
}

- (void)enable {
    [_bluetoothManager setEnabled:true];
}

- (NSArray<BluetoothDeviceHandler*>*)pairedDevices {
    NSArray<BluetoothDevice*>* devices = [_bluetoothManager pairedDevices];
    NSMutableArray<BluetoothDeviceHandler*>* handlers = [[NSMutableArray alloc] initWithCapacity:devices.count];

    for (BluetoothDevice* device in devices) {
        BluetoothDeviceHandler* handler = [[BluetoothDeviceHandler alloc] initWithDevice:device];
        [handlers addObject:handler];
    }

    return handlers;
}

@end
