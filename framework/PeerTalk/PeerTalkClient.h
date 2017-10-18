//
//  PeerTalkClient.h
//  PeerTalk
//
//  Created by Matthew Cheok on 3/10/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PeerTalkClient;
@protocol PeerTalkClientDelegate <NSObject>

@optional
- (void)peerTalkClient:(PeerTalkClient * _Nonnull )peerTalkClient didConnectToServer:(NSString * _Nullable)server;
- (void)peerTalkClient:(PeerTalkClient * _Nonnull )peerTalkClient didDisconnectFromServer:(NSString * _Nullable)server;
- (void)peerTalkClient:(PeerTalkClient * _Nonnull)peerTalkClient didReceiveData:(NSData * _Nonnull)data;

@end

@interface PeerTalkClient : NSObject

@property (nonatomic, weak) id<PeerTalkClientDelegate> delegate;

- (void)sendData:(NSData * _Nonnull)data;

@end
