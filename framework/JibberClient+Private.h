//
//  JibberClient+Private.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 25/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "JibberClient.h"

extern NSString *JibberClientTaskDescription;

@interface JibberClient (Private)

- (void)didProcessRequest:(NSURLRequest *)request;
- (void)didProcessResponse:(NSURLResponse *)response forRequest:(NSURLRequest *)request withData:(NSData *)data errorMessage:(NSString *)errorMessage;
- (void)didProcessRemoteNotificationWithUserInfo:(NSDictionary *)userInfo;

@end
