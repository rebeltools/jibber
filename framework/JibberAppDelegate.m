//
//  JibberAppDelegate.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 18/3/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "JibberAppDelegate.h"
#import "JibberUtils.h"
#import "JibberClient+Private.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface JibberAppDelegate () <UIApplicationDelegate>
@end

@implementation JibberAppDelegate

+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(swizzleAppDelegate) name:UIApplicationDidFinishLaunchingNotification object:nil];
	});
}

+ (void)swizzleAppDelegate {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Class appDelegateClass = [[UIApplication sharedApplication].delegate class];
		jibber_addMethod(self, appDelegateClass, @selector(jibber_application:didReceiveRemoteNotification:));
		jibber_swizzleSelectors(appDelegateClass, @selector(application:didReceiveRemoteNotification:), @selector(jibber_application:didReceiveRemoteNotification:));

		if (class_getInstanceMethod(appDelegateClass, @selector(jibber_application:didReceiveRemoteNotification:fetchCompletionHandler:)) != NULL) {
		    jibber_addMethod(self, appDelegateClass, @selector(jibber_application:didReceiveRemoteNotification:fetchCompletionHandler:));
		    jibber_swizzleSelectors(appDelegateClass, @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:), @selector(jibber_application:didReceiveRemoteNotification:fetchCompletionHandler:));
		}
	});
}

- (void)jibber_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
	[[JibberClient sharedInstance] didProcessRemoteNotificationWithUserInfo:userInfo];
	[self jibber_application:application didReceiveRemoteNotification:userInfo];
}

- (void)jibber_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	[[JibberClient sharedInstance] didProcessRemoteNotificationWithUserInfo:userInfo];
	[self jibber_application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}

@end
