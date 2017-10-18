//
//  PeerTalkServer.h
//  PeerTalk
//
//  Created by Matthew Cheok on 4/10/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PeerTalkServer;
@protocol PeerTalkServerDelegate <NSObject>

@optional
- (void)peerTalkServer:(PeerTalkServer * _Nonnull )peerTalkServer didConnectToClient:(NSString * _Nullable)client;
- (void)peerTalkServer:(PeerTalkServer * _Nonnull )peerTalkServer didDisconnectFromClient:(NSString * _Nullable)client;
- (void)peerTalkServer:(PeerTalkServer * _Nonnull)peerTalkServer didReceiveData:(NSData * _Nonnull)data;

@end

@interface PeerTalkServer : NSObject

@property (nonatomic, weak) id<PeerTalkServerDelegate> delegate;

- (void)sendData:(NSData * _Nonnull)data;

@end
