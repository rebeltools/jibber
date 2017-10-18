//
//  PeerTalkHelpers.h
//  PeerTalk
//
//  Created by Matthew Cheok on 4/10/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PeerTalkFrameType) {
    PeerTalkFrameTypeData = 1000,
//    PeerTalkFrameTypeDeviceInfo,
//    PeerTalkFrameTypePing,
//    PeerTalkFrameTypePong
};

extern const NSInteger kPeerTalkClientPortNumber;
extern const NSTimeInterval kPeerTalkReconnectDelay;

extern dispatch_data_t PeerTalkDispatchDataFromNSData(NSData *data);
extern NSString *PeerTalkNameFromChannelUserInfo(id userInfo);