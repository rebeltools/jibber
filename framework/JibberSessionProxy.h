//
//  JibberProxy.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 30/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JibberSessionProxy : NSProxy <NSURLSessionDelegate>

- (instancetype)initWithDelegate:(id <NSURLSessionDelegate> )delegate;

@end
