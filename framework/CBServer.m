//
//  CBServer.m
//  CBServer
//
//  Created by Matthew Cheok on 8/8/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import "CBServer.h"
@import CoreBluetooth;

#define CBSERVER_SERVICE_UUID @"349B8685-7684-40CE-AA80-40E2F47BD8A6"
#define CBSERVER_NOTIFY_MTU 100

@interface CBServer () <CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *manager;
@property (nonatomic, strong) CBMutableCharacteristic *characteristic;
@property (nonatomic, strong) CBService *service;
@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, assign) NSInteger index;

@property (nonatomic, copy, readwrite) NSString *uuid;

@end

@implementation CBServer

- (instancetype)initWithUUID:(NSString *)uuid {
    self = [super init];
    if (self) {
        self.uuid = uuid;
        self.queue = [NSMutableArray array];
        self.index = NSNotFound;

        [self setup];
    }
    return self;
}

- (BOOL)readyToSendData {
    return self.manager.state == CBPeripheralManagerStatePoweredOn;
}

- (void)setup {
    self.manager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)setupService {
    NSLog(@"CBServer: Initializing with UUID %@", self.uuid);
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:self.uuid] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    self.characteristic = characteristic;

    CBMutableService *service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:CBSERVER_SERVICE_UUID] primary:YES];
    service.characteristics = @[characteristic];
    self.service = service;

    [self.manager addService:service];
    [self.manager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:CBSERVER_SERVICE_UUID]] }];
    NSLog(@"CBServer: Advertising service");
}

- (void)enqueueDataForSending:(NSData *)data {
    [self.queue addObject:data];
    [self sendNextInQueue];
}

- (void)sendNextInQueue {
    // stop if we're done
    if (self.queue.count == 0) {
        return;
    }

    // get the current request
    NSData *data = [self.queue firstObject];
    BOOL didSend = YES;

    // if we're not already sending
    // send empty value first
    if (self.index == NSNotFound) {
        didSend = [self.manager updateValue:[NSData data] forCharacteristic:self.characteristic onSubscribedCentrals:nil];

        if (didSend) {
            self.index = 0;
        }
    }

    while (self.index < data.length && didSend) {
        NSInteger amount = MIN(data.length - self.index, CBSERVER_NOTIFY_MTU);
        NSData *chunk = [NSData dataWithBytes:data.bytes+self.index length:amount];
        didSend = [self.manager updateValue:chunk forCharacteristic:self.characteristic onSubscribedCentrals:nil];

        if (didSend) {
            self.index += amount;
        }
    }

    // either we dropped or we're done
    if (didSend) {
        didSend = [self.manager updateValue:[NSData data] forCharacteristic:self.characteristic onSubscribedCentrals:nil];
        if (didSend) {
            self.index = NSNotFound;
            [self.queue removeObjectAtIndex:0];
            [self sendNextInQueue];
        }
    }
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(nonnull CBPeripheralManager *)peripheral {
    if (peripheral.state == CBPeripheralManagerStateUnsupported) {
        NSLog(@"Warning: Could not initialize Core Bluetooth!");
    }

    else if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self setupService];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"CBServer: Central subscribed %@ %lu", central, central.maximumUpdateValueLength);

//    [self enqueueDataForSending:[@"Hello there this is going to be a little long so that we can see the effect completely!" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"CBServer: Central unsubscribed %@", central);
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
//    NSLog(@"CBServer: Ready to update!");
    [self sendNextInQueue];
}

@end
