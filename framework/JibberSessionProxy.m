//
//  JibberProxy.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 30/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "JibberSessionProxy.h"
#import "JibberClient+Private.h"

@interface JibberSessionProxy ()

@property (nonatomic, strong) id <NSURLSessionDelegate> delegate;
@property (nonatomic, strong) NSMapTable *data;

@end

@implementation JibberSessionProxy

- (instancetype)initWithDelegate:(id <NSURLSessionDelegate> )delegate {
	self.delegate = delegate;
	self.data = [NSMapTable weakToStrongObjectsMapTable];
	return self;
}

- (BOOL)respondsToSelector:(SEL)selector {
	if (selector == @selector(URLSession:task:didCompleteWithError:)) {
		return YES;
	}
	else if (selector == @selector(URLSession:dataTask:didReceiveData:)) {
		return YES;
	}
	
	return [self.delegate respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	if (selector == @selector(URLSession:task:didCompleteWithError:)) {
		return nil;
	}
	else if (selector == @selector(URLSession:dataTask:didReceiveData:)) {
		return nil;
	}
	
	return [self.delegate respondsToSelector:selector] ? self.delegate : nil;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
	if ([JibberClient sharedInstance].connectionMode == JibberClientWirelessConnection) {
		NSMutableData *taskData = [self.data objectForKey:task];
		if (taskData) {
			[self.data removeObjectForKey:task];
		}
		
		NSData *data = [taskData copy];
		NSString *errorMessage = [error localizedDescription];
		[[JibberClient sharedInstance] didProcessResponse:task.response forRequest:task.originalRequest withData:data errorMessage:errorMessage];
	}
	else {
		if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
			NSMutableData *taskData = [self.data objectForKey:task];
			if (taskData) {
				[self.data removeObjectForKey:task];
			}
			
			NSData *data = [taskData copy];
			NSString *errorMessage = [error localizedDescription];
			[[JibberClient sharedInstance] didProcessResponse:task.response forRequest:task.originalRequest withData:data errorMessage:errorMessage];
		}
	}
	if ([self.delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
		[(id < NSURLSessionTaskDelegate >)self.delegate URLSession:session task:task didCompleteWithError:error];
	}
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
	if ([JibberClient sharedInstance].connectionMode == JibberClientWirelessConnection) {
		if (![dataTask.taskDescription isEqualToString:JibberClientTaskDescription]) {
			NSMutableData *taskData = [self.data objectForKey:dataTask];
			if (!taskData) {
				taskData = [NSMutableData data];
				[self.data setObject:taskData forKey:dataTask];
			}
			[taskData appendData:data];
		}
	}
	else {
		NSMutableData *taskData = [self.data objectForKey:dataTask];
		if (!taskData) {
			taskData = [NSMutableData data];
			[self.data setObject:taskData forKey:dataTask];
		}
		[taskData appendData:data];
	}
	if ([self.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
		[(id < NSURLSessionDataDelegate >)self.delegate URLSession:session dataTask:dataTask didReceiveData:data];
	}
	
}

@end
