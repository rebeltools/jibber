//
//  NSURLConnection+JibberClient.m
//  RealmJSONDemo
//
//  Created by Nikhil Sharma on 20/3/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "NSURLConnection+JibberClient.h"
#import "JibberClient+Private.h"
#import "JibberConnectionProxy.h"
#import "JibberUtils.h"

#import <objc/runtime.h>

@implementation NSURLConnection (JibberClient)

+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        [self jibber_swizzle];
	});
}

+ (void)jibber_swizzle {
    jibber_swizzleSelectors(object_getClass((id)self), @selector(sendAsynchronousRequest:queue:completionHandler:), @selector(jibber_sendAsynchronousRequest:queue:completionHandler:));
    //		SwizzleSelectorsForClass(object_getClass((id)self), @selector(sendSynchronousRequest:returningResponse:error:), @selector(jibber_sendSynchronousRequest:returningResponse:error:));
    
    jibber_swizzleSelectors(object_getClass((id)self), @selector(connectionWithRequest:delegate:), @selector(jibber_connectionWithRequest:delegate:));
    jibber_swizzleSelectors([self class], @selector(initWithRequest:delegate:startImmediately:), @selector(jibber_initWithRequest:delegate:startImmediately:));
    jibber_swizzleSelectors([self class], @selector(initWithRequest:delegate:), @selector(jibber_initWithRequest:delegate:));
    jibber_swizzleSelectors([self class], @selector(start), @selector(jibber_start));
}

+ (void)jibber_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))handler {
	if (jibber_requestPathIsNotBinary(request)) {
		[[JibberClient sharedInstance] didProcessRequest:request];
	}

	[self jibber_sendAsynchronousRequest:request queue:queue completionHandler: ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
	    if (jibber_requestPathIsNotBinary(request)) {
	        NSString *errorMessage = [connectionError localizedDescription];
	        [[JibberClient sharedInstance] didProcessResponse:response forRequest:request withData:data errorMessage:errorMessage];
		}
	    if (handler) {
	        handler(response, data, connectionError);
		}
	}];
}

+ (NSData *)jibber_sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse *__autoreleasing *)response error:(NSError *__autoreleasing *)error {
	if (jibber_requestPathIsNotBinary(request)) {
		[[JibberClient sharedInstance] didProcessRequest:request];
	}

	NSData *data = nil;
	NSError *otherError = nil;
	NSURLResponse *otherResponse = nil;

	if (error && response) {
		data = [self jibber_sendSynchronousRequest:request returningResponse:response error:error];
	}
	else if (!response) {
		data = [self jibber_sendSynchronousRequest:request returningResponse:&otherResponse error:error];
	}
	else if (!error) {
		data = [self jibber_sendSynchronousRequest:request returningResponse:response error:&otherError];
	}
	else {
		data = [self jibber_sendSynchronousRequest:request returningResponse:&otherResponse error:&otherError];
	}

	if (jibber_requestPathIsNotBinary(request)) {
		NSString *errorMessage = [otherError ? : (error ? *error : nil)localizedDescription];
		[[JibberClient sharedInstance] didProcessResponse:otherResponse ? : (response ? *response : nil) forRequest:request withData:data errorMessage:errorMessage];
	}

	return data;
}

+ (NSURLConnection *)jibber_connectionWithRequest:(NSURLRequest *)request delegate:(id <NSURLConnectionDataDelegate> )delegate {
	id <NSURLConnectionDataDelegate> proxy = [[JibberConnectionProxy alloc] initWithDelegate:delegate];

	return [self jibber_connectionWithRequest:request delegate:proxy];
}

- (instancetype)jibber_initWithRequest:(NSURLRequest *)request delegate:(id <NSURLConnectionDataDelegate> )delegate startImmediately:(BOOL)startImmediately {
	id <NSURLConnectionDataDelegate> proxy = [[JibberConnectionProxy alloc] initWithDelegate:delegate];

	return [self jibber_initWithRequest:request delegate:proxy startImmediately:startImmediately];
}

- (instancetype)jibber_initWithRequest:(NSURLRequest *)request delegate:(id <NSURLConnectionDataDelegate> )delegate {
	id <NSURLConnectionDataDelegate> proxy = [[JibberConnectionProxy alloc] initWithDelegate:delegate];

	return [self jibber_initWithRequest:request delegate:proxy];
}

- (void)jibber_start {
	if (jibber_requestPathIsNotBinary(self.originalRequest)) {
		[[JibberClient sharedInstance] didProcessRequest:self.originalRequest];
	}
	[self jibber_start];
}

@end
