//
//  CBServer.h
//  CBServer
//
//  Created by Matthew Cheok on 8/8/15.
//  Copyright © 2015 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CBServer : NSObject

@property (nonatomic, copy, readonly) NSString *uuid;
@property (nonatomic, assign, readonly) BOOL readyToSendData;

- (instancetype)initWithUUID:(NSString *)uuid;
- (void)enqueueDataForSending:(NSData *)data;

@end
