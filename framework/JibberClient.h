//
//  JibberClient.h
//  JibberFramework
//
//  Created by Matthew Cheok on 25/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, JibberClientLoggingMode) {
    JibberClientLoggingModeDefault = 0,
    JibberClientLoggingModeVerbose
};

typedef NS_ENUM(NSInteger, JibberClientConnectionMode) {
    JibberClientTetheredConnection = 0,
    JibberClientWirelessConnection
};

@interface JibberClient : NSObject

@property (nonatomic, assign) JibberClientLoggingMode loggingMode;
@property (nonatomic, assign) JibberClientConnectionMode connectionMode;

+ (instancetype)sharedInstance;

- (void)enable;
- (void)disable;

@end
