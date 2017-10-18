//
//  PeerTalkClient.m
//  PeerTalk
//
//  Created by Matthew Cheok on 3/10/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import "PeerTalkClient.h"
#import "PeerTalkHelpers.h"
#import "PTChannel.h"

@interface PeerTalkClient () <PTChannelDelegate>

@property (nonatomic, weak) PTChannel *serverChannel;
@property (nonatomic, weak) PTChannel *clientChannel;

@end

@implementation PeerTalkClient

- (instancetype)init {
    self = [super init];
    if (self) {
        PTChannel *channel = [PTChannel channelWithDelegate:self];
        [channel listenOnPort:kPeerTalkClientPortNumber IPv4Address:@"127.0.0.1" callback:^(NSError *error) {
            if (error) {
                NSLog(@"PeerTalkClient: Failed to start listening");
            }
            else {
                self.serverChannel = channel;
            }
        }];
    }
    return self;
}

- (void)dealloc {
    [self.serverChannel close];
}

- (void)sendData:(NSData *)data {
    if (self.clientChannel) {
        [self.clientChannel sendFrameOfType:PeerTalkFrameTypeData tag:0 withPayload:PeerTalkDispatchDataFromNSData(data) callback:^(NSError *error) {
            if (error) {
                NSLog(@"Error: Sending data %@", [error localizedDescription]);
            }
        }];
    }
}

- (void)ioFrameChannel:(PTChannel *)channel didAcceptConnection:(PTChannel *)otherChannel fromAddress:(PTAddress *)address {
    if (self.clientChannel) {
        [self.clientChannel cancel];
    }
    
    self.clientChannel = otherChannel;
    self.clientChannel.userInfo = address;
    
    [self.delegate peerTalkClient:self didConnectToServer:PeerTalkNameFromChannelUserInfo(channel.userInfo)];
}

- (void)ioFrameChannel:(PTChannel *)channel didEndWithError:(NSError *)error {
    if (channel == self.clientChannel) {
        [self.delegate peerTalkClient:self didDisconnectFromServer:PeerTalkNameFromChannelUserInfo(channel.userInfo)];
    }
}

- (BOOL)ioFrameChannel:(PTChannel *)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    return type == PeerTalkFrameTypeData;
}

- (void)ioFrameChannel:(PTChannel *)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData *)payload {
    NSData *data = [NSData dataWithBytes:payload.data length:payload.length];
    [self.delegate peerTalkClient:self didReceiveData:data];
}

@end
