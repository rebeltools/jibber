//
//  NSURLSession+JibberClient.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 30/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "NSURLSession+JibberClient.h"
#import "JibberClient+Private.h"
#import "JibberSessionProxy.h"
#import "JibberUtils.h"

#import <objc/runtime.h>

@implementation NSURLSession (JibberClient)

+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[self jibber_swizzle];
	});
}

+ (void)jibber_swizzle {
	jibber_swizzleSelectors(object_getClass((id)self), @selector(sessionWithConfiguration:delegate:delegateQueue:), @selector(jibber_sessionWithConfiguration:delegate:delegateQueue:));
	jibber_swizzleSelectors([self class], @selector(dataTaskWithRequest:completionHandler:), @selector(jibber_dataTaskWithRequest:completionHandler:));
}

+ (NSURLSession *)jibber_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id <NSURLSessionDelegate> )delegate delegateQueue:(NSOperationQueue *)queue {
	id <NSURLSessionDelegate> proxy = [[JibberSessionProxy alloc] initWithDelegate:delegate];
	return [self jibber_sessionWithConfiguration:configuration delegate:proxy delegateQueue:queue];
}

- (NSURLSessionDataTask *)jibber_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
	// if no completion handler provided - will default to delegate
	if (completionHandler) {
		__block NSURLSessionDataTask *task = [self jibber_dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
		                                              if ([JibberClient sharedInstance].connectionMode == JibberClientWirelessConnection) {
		                                                      if (![task.taskDescription isEqualToString:JibberClientTaskDescription]) {
		                                                              NSString *errorMessage = [error localizedDescription];
		                                                              [[JibberClient sharedInstance] didProcessResponse:response forRequest:request withData:data errorMessage:errorMessage];
								      }
							      }
		                                              else {
		                                                      NSString *errorMessage = [error localizedDescription];
		                                                      [[JibberClient sharedInstance] didProcessResponse:response forRequest:request withData:data errorMessage:errorMessage];
							      }
		                                              completionHandler(data, response, error);
						      }];
		return task;
	}
	else {
		return [self jibber_dataTaskWithRequest:request completionHandler:nil];
	}
}

@end
