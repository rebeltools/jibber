//
//  JibberConnectionProxy.h
//  RealmJSONDemo
//
//  Created by Nikhil Sharma on 20/3/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JibberConnectionProxy : NSProxy <NSURLConnectionDataDelegate>

- (instancetype)initWithDelegate:(id <NSURLConnectionDataDelegate> )delegate;

@end
