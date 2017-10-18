//
//  PeerTalkHelpers.m
//  PeerTalk
//
//  Created by Matthew Cheok on 4/10/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import "PeerTalkHelpers.h"
#import "PTChannel.h"

const NSInteger kPeerTalkClientPortNumber = 3456;
const NSTimeInterval kPeerTalkReconnectDelay = 1.0;

dispatch_data_t PeerTalkDispatchDataFromNSData(NSData *data) {
    return dispatch_data_create((const void*)data.bytes, data.length, nil, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
}

NSString *PeerTalkNameFromChannelUserInfo(id userInfo) {
    if ([userInfo isKindOfClass:[PTAddress class]]) {
        PTAddress *address = userInfo;
        return address.name;
    }
    else if ([userInfo isKindOfClass:[NSNumber class]]) {
        NSNumber *deviceID = userInfo;
        return [deviceID stringValue];
    }
    else {
        return nil;
    }
}