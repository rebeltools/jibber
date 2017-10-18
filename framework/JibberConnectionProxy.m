//
//  JibberConnectionProxy.m
//  RealmJSONDemo
//
//  Created by Nikhil Sharma on 20/3/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "JibberConnectionProxy.h"
#import "JibberClient+Private.h"
#import "JibberUtils.h"

@interface JibberConnectionProxy ()

@property (nonatomic, strong) id <NSURLConnectionDataDelegate> delegate;
@property (nonatomic, strong) NSMapTable *responses;
@property (nonatomic, strong) NSMapTable *data;

@end

@implementation JibberConnectionProxy

- (instancetype)initWithDelegate:(id <NSURLConnectionDataDelegate> )delegate {
	self.delegate = delegate;
	self.responses = [NSMapTable weakToStrongObjectsMapTable];
	self.data = [NSMapTable weakToStrongObjectsMapTable];

	return self;
}

- (id)forwardingTargetForSelector:(SEL)selector {
	if (selector == @selector(connection:didFailWithError:)) {
		return nil;
	}
	else if (selector == @selector(connection:didReceiveData:)) {
		return nil;
	}
	else if (selector == @selector(connection:didReceiveResponse:)) {
		return nil;
	}
	else if (selector == @selector(connectionDidFinishLoading:)) {
		return nil;
	}
 
	return [self.delegate respondsToSelector:selector] ? self.delegate : nil;
}

- (BOOL)respondsToSelector:(SEL)selector {
	if (selector == @selector(connection:didFailWithError:)) {
		return YES;
	}
	else if (selector == @selector(connection:didReceiveData:)) {
		return YES;
	}
	else if (selector == @selector(connection:didReceiveResponse:)) {
		return YES;
	}
	else if (selector == @selector(connectionDidFinishLoading:)) {
		return YES;
	}

	return [self.delegate respondsToSelector:selector];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSURLResponse *response = [self.responses objectForKey:connection];
    if (response) {
        [self.responses removeObjectForKey:connection];
    }
    
    if (jibber_requestPathIsNotBinary(connection.originalRequest)) {
        [[JibberClient sharedInstance] didProcessResponse:response forRequest:connection.originalRequest withData:nil errorMessage:error.localizedDescription];
    }

	if ([self.delegate respondsToSelector:@selector(connection:didFailWithError:)]) {
		[(id < NSURLConnectionDelegate >) self.delegate connection:connection didFailWithError:error];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSMutableData *connectionData = [self.data objectForKey:connection];
	if (!connectionData) {
		connectionData = [NSMutableData data];
		[self.data setObject:connectionData forKey:connection];
	}
	[connectionData appendData:data];

	if ([self.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
		[(id < NSURLConnectionDataDelegate >) self.delegate connection:connection didReceiveData:data];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[self.responses setObject:response forKey:connection];

	if ([self.delegate respondsToSelector:@selector(connection:didReceiveResponse:)]) {
		[(id < NSURLConnectionDataDelegate >) self.delegate connection:connection didReceiveResponse:response];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSMutableData *connectionData = [self.data objectForKey:connection];
	if (connectionData) {
		[self.data removeObjectForKey:connection];
	}

	NSURLResponse *response = [self.responses objectForKey:connection];
	if (response) {
		[self.responses removeObjectForKey:connection];
	}

	if (jibber_requestPathIsNotBinary(connection.originalRequest)) {
		[[JibberClient sharedInstance] didProcessResponse:response forRequest:connection.originalRequest withData:[connectionData copy] errorMessage:nil];
	}

	if ([self.delegate respondsToSelector:@selector(connectionDidFinishLoading:)]) {
		[(id < NSURLConnectionDataDelegate >) self.delegate connectionDidFinishLoading:connection];
	}
}

@end
