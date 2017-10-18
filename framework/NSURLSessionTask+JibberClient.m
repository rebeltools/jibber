//
//  NSURLSessionTask+JibberClient.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 30/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "NSURLSessionTask+JibberClient.h"
#import "JibberClient+Private.h"
#import "JibberUtils.h"

#import <UIKit/UIKit.h>

@implementation NSURLSessionTask (JibberClient)

+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[self jibber_swizzle];
	});
}

+ (void)jibber_swizzle {
	if ([NSURLSessionDataTask class]) {
		NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL new]];
		Class taskClass = [dataTask superclass];
		
		jibber_addMethod([self class], taskClass, @selector(jibber_resume));
		jibber_swizzleSelectors(taskClass, @selector(resume), @selector(jibber_resume));
	}
}

- (void)jibber_resume {
	if ([JibberClient sharedInstance].connectionMode == JibberClientWirelessConnection) {
		if ([self isKindOfClass:[NSURLSessionDataTask class]] && ![self.taskDescription isEqualToString:JibberClientTaskDescription]) {
			[[JibberClient sharedInstance] didProcessRequest:self.originalRequest];
		}
	}
	else {
		if ([self isKindOfClass:[NSURLSessionDataTask class]]) {
			[[JibberClient sharedInstance] didProcessRequest:self.originalRequest];
		}
	}
	
	[self jibber_resume];
}

@end
