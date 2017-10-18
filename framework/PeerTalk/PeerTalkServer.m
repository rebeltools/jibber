//
//  PeerTalkServer.m
//  PeerTalk
//
//  Created by Matthew Cheok on 4/10/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import "PeerTalkServer.h"
#import "PeerTalkHelpers.h"
#import "PTChannel.h"

@interface PeerTalkServer () <PTChannelDelegate>

@property (nonatomic, weak) PTChannel *channel;

@end

@implementation PeerTalkServer {
    dispatch_queue_t _queue;
    id _deviceAttachedToken;
    id _deviceDetachedToken;
    NSNumber *_deviceID;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("PeerTalk.Server", DISPATCH_QUEUE_SERIAL);
        
        _deviceAttachedToken = [[NSNotificationCenter defaultCenter] addObserverForName:PTUSBDeviceDidAttachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            
            [self disconnectFromCurrentChannel];
            
            NSNumber *deviceID = [note.userInfo objectForKey:@"DeviceID"];
            NSLog(@"deviceID %@ attached", deviceID);
            _deviceID = deviceID;

            NSDictionary *properties = [note.userInfo objectForKey:@"Properties"];
            NSLog(@"properties %@", properties);
            
            __weak typeof(self) weakSelf = self;
            [self enqueueBlock:^{
                typeof(self) strongSelf = weakSelf;
                [strongSelf connectToUSBDevice];
            } afterInterval:kPeerTalkReconnectDelay];

        }];
        
        _deviceDetachedToken = [[NSNotificationCenter defaultCenter] addObserverForName:PTUSBDeviceDidDetachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            NSNumber *deviceID = [note.userInfo objectForKey:@"DeviceID"];
            NSLog(@"deviceID %@ detached", deviceID);
            
            if ([deviceID isEqualToNumber:_deviceID]) {
                if (self.channel) {
                    [self.channel close];
                }
            }
        }];
        
        [self connectToLocalIPv4Port];
        [self connectToUSBDevice];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:_deviceAttachedToken];
    [[NSNotificationCenter defaultCenter] removeObserver:_deviceDetachedToken];
}

- (void)sendData:(NSData *)data {
    if (self.channel) {
        [self.channel sendFrameOfType:PeerTalkFrameTypeData tag:0 withPayload:PeerTalkDispatchDataFromNSData(data) callback:^(NSError *error) {
            if (error) {
                NSLog(@"Error: Sending data %@", [error localizedDescription]);
            }
        }];
    }
}

#pragma mark - Private

- (void)setChannel:(PTChannel *)channel {
    _channel = channel;
    if (channel) {
        dispatch_suspend(_queue);
    }
    else {
        dispatch_resume(_queue);
    }
}

- (void)enqueueBlock:(dispatch_block_t)block afterInterval:(NSTimeInterval)interval {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), _queue, ^{
        dispatch_async(dispatch_get_main_queue(), block);
    });
}

- (void)connectToLocalIPv4Port {
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    [channel connectToPort:kPeerTalkClientPortNumber IPv4Address:@"127.0.0.1" callback:^(NSError *error, PTAddress *address) {
        if (error) {
            if (error.domain == NSPOSIXErrorDomain && (error.code == ECONNREFUSED || error.code == ETIMEDOUT)) {
                // this is an expected state
            } else {
                NSLog(@"Failed to connect to 127.0.0.1:%lu: %@", kPeerTalkClientPortNumber, error);
            }
        } else {
            [self disconnectFromCurrentChannel];
            
            channel.userInfo = address;
            self.channel = channel;
            
            if ([self.delegate respondsToSelector:@selector(peerTalkServer:didConnectToClient:)]) {
                [self.delegate peerTalkServer:self didConnectToClient:PeerTalkNameFromChannelUserInfo(channel.userInfo)];
            }
        }
        
        __weak typeof(self) weakSelf = self;
        [self enqueueBlock:^{
            typeof(self) strongSelf = weakSelf;
            [strongSelf connectToLocalIPv4Port];
        } afterInterval:kPeerTalkReconnectDelay];
    }];
}

- (void)connectToUSBDevice {
    if (_deviceID) {
        PTChannel *channel = [PTChannel channelWithDelegate:self];
        channel.userInfo = _deviceID;
        channel.delegate = self;
        
        [channel connectToPort:kPeerTalkClientPortNumber overUSBHub:PTUSBHub.sharedHub deviceID:_deviceID callback:^(NSError *error) {
            if (error) {
                if (error.domain == PTUSBHubErrorDomain && error.code == PTUSBHubErrorConnectionRefused) {
                    NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
                } else {
                    NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
                }
            } else {
                self.channel = channel;
                
                if ([self.delegate respondsToSelector:@selector(peerTalkServer:didConnectToClient:)]) {
                    [self.delegate peerTalkServer:self didConnectToClient:PeerTalkNameFromChannelUserInfo(channel.userInfo)];
                }
            }
            
            __weak typeof(self) weakSelf = self;
            [self enqueueBlock:^{
                typeof(self) strongSelf = weakSelf;
                [strongSelf connectToUSBDevice];
            } afterInterval:kPeerTalkReconnectDelay];
        }];
    }
}

- (void)disconnectFromCurrentChannel {
    if (self.channel) {
        [self.channel close];
        self.channel = nil;
        _deviceID = nil;
    }
}

#pragma mark - PTChannelDelegate

- (BOOL)ioFrameChannel:(PTChannel *)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    return type == PeerTalkFrameTypeData;
}

- (void)ioFrameChannel:(PTChannel *)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData *)payload {
    NSData *data = [NSData dataWithBytes:payload.data
                                  length:payload.length];
    
    if ([self.delegate respondsToSelector:@selector(peerTalkServer:didReceiveData:)]) {
        [self.delegate peerTalkServer:self didReceiveData:data];
    }
}

- (void)ioFrameChannel:(PTChannel *)channel didEndWithError:(NSError *)error {
    if (self.channel == channel) {
        self.channel = nil;
        if ([self.delegate respondsToSelector:@selector(peerTalkServer:didDisconnectFromClient:)]) {
            [self.delegate peerTalkServer:self didDisconnectFromClient:PeerTalkNameFromChannelUserInfo(channel.userInfo)];
        }
    }
}

@end

