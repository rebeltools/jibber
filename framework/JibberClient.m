//
//  JibberClient.m
//  JibberFramework
//
//  Created by Matthew Cheok on 25/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "JibberClient.h"
#import "JibberAppDelegate.h"

#import "NSData+Brotli.h"
#import "NSData+JibberZip.h"
#import "NSURLSession+JibberClient.h"
#import "NSURLSessionTask+JibberClient.h"
#import "NSURLConnection+JibberClient.h"
#import "PeerTalkClient.h"

#import <UIKit/UIKit.h>
#import <arpa/inet.h>
#import <sys/utsname.h>

NSString *JibberClientTaskDescription = @"[JibberClientTaskDescription]";


static NSString const *kJibberFrameworkVersion = @"2.0.1";
static NSInteger const kJibberRequestFailureStatusCode = 0;
static NSInteger const kJibberRemoteNotificationStatusCode = -100;
static NSInteger const kJibberCompressionQuality = 7;

static NSString *GetMachineName() {
	struct utsname systemInfo;
	uname(&systemInfo);
	
	return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

static NSString *GetIPAddressFromData(NSData *data) {
	struct sockaddr_in *socketAddress = nil;
	NSString *ipString = nil;
	
	socketAddress = (struct sockaddr_in *)[data bytes];
	ipString = [NSString stringWithFormat:@"%s",
	            inet_ntoa(socketAddress->sin_addr)]; ///problem here
	return ipString;
}

@interface JibberClient () <PeerTalkClientDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (nonatomic, strong) NSNetServiceBrowser *browser;
@property (nonatomic, strong) NSMutableArray *services;
@property (nonatomic, strong) NSMapTable *servers;
@property (nonatomic, strong) NSMapTable *requests;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, strong) NSMutableArray *savedRequests;
@property (nonatomic, strong) NSMutableArray *savedResponses;
@property (nonatomic, strong) NSDictionary *deviceParameters;
@property (nonatomic, strong) dispatch_queue_t jibberQueue;
@property (nonatomic, strong) PeerTalkClient *client;
@property (nonatomic, assign) BOOL connectedToClient;

@property (nonatomic, strong) id resignApplicationObserver;
@property (nonatomic, strong) id activeApplicationObserver;

@end

@implementation JibberClient

+ (void)load {
	id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock: ^(NSNotification *note) {
	                       [self sharedInstance];
	                       [[NSNotificationCenter defaultCenter] removeObserver:observer];
		       }];
}

+ (instancetype)sharedInstance {
	static dispatch_once_t pred = 0;
	__strong static id _sharedObject = nil;
	dispatch_once(&pred, ^{
		_sharedObject = [[self alloc] init];
	});
	return _sharedObject;
}

- (void)log:(NSString *)format, ...{
	if (self.loggingMode == JibberClientLoggingModeVerbose) {
		va_list argumentList;
		va_start(argumentList, format);
		NSMutableString *message = [[NSMutableString alloc] initWithFormat:format
		                            arguments:argumentList];
		                            
		NSLog(@"%@", message); // Originally NSLog is a wrapper around NSLogv.
		va_end(argumentList);
	}
}

- (instancetype)init {
	self = [super init];
	if (self) {
		NSLog(@"[JibberClient] Initialized.");
		
		UIDevice *device = [UIDevice currentDevice];
		NSBundle *bundle = [NSBundle mainBundle];
		NSString *displayName = bundle.infoDictionary[@"CFBundleDisplayName"] ? : bundle.infoDictionary[@"CFBundleName"];
		
		self.jibberQueue = dispatch_queue_create("tools.rebel.jibber.queue", NULL);
		self.deviceParameters = @{
			@"uuid": device.identifierForVendor.UUIDString ? : @"",
			@"name": device.name ? : @"",
			@"model": device.model ? : @"",
			@"hardware": GetMachineName() ? : @"",
			@"system_name": device.systemName ? : @"",
			@"system_version": device.systemVersion ? : @"",
			@"bundle_name": displayName ? : @"",
			@"bundle_identifier": bundle.bundleIdentifier ? : @"",
			@"framework_version": kJibberFrameworkVersion ? : @""
		};
		[self log:@"[JibberClient] Retrieved device info: %@", self.deviceParameters];
		
		self.requests = [NSMapTable strongToStrongObjectsMapTable];
		self.savedRequests = [NSMutableArray array];
		self.savedResponses = [NSMutableArray array];
		
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf enable];
		});
	}
	
	return self;
}

- (void)start {
	self.client = [[PeerTalkClient alloc] init];
	self.client.delegate = self;
	self.connectedToClient = false;
	self.timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(sendHeartBeatData) userInfo:nil repeats:YES];
}

- (void)stop {
	[self.timer invalidate];
    self.connectedToClient = false;
	self.timer = nil;
	self.client = nil;
}

- (void)startScanning {
	NSLog(@"[JibberClient] Scanning for servers %@", self.browser);
	[self.browser searchForServicesOfType:@"_jibber._tcp" inDomain:@""];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(sendHeartBeatData) userInfo:nil repeats:YES];
}

- (void)stopScanning {
	NSLog(@"[JibberClient] Stop scanning for servers");
	[self.browser stop];
	[self.servers removeAllObjects];
	[self.timer invalidate];
	self.timer = nil;
}

- (void)enable {
	[self log:@"[JibberClient] enabled"];
	__weak typeof(self) weakSelf = self;
	
	self.resignApplicationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock: ^(NSNotification *note) {
	                                          [weakSelf log:@"[JibberClient] Application will resign active"];
	                                          if (self.connectionMode == JibberClientWirelessConnection) {
	                                                  [weakSelf stopScanning];
						  }
	                                          else {
	                                                  [weakSelf stop];
						  }
					  }];
	self.activeApplicationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock: ^(NSNotification *note) {
	                                          [weakSelf log:@"[JibberClient] Application did become active"];
	                                          if (self.connectionMode == JibberClientWirelessConnection) {
	                                                  [weakSelf startScanning];
						  }
	                                          else {
	                                                  [weakSelf start];
						  }
					  }];
	if (self.connectionMode == JibberClientWirelessConnection) {
		self.servers = [NSMapTable weakToStrongObjectsMapTable];
		self.services = [NSMutableArray array];
		self.browser = [[NSNetServiceBrowser alloc] init];
		self.browser.delegate = self;
		[self startScanning];
	}
	else {
		[self start];
	}
}

- (void)disable {
	[self log:@"[JibberClient] disabled"];
	[self stop];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self.resignApplicationObserver];
	[[NSNotificationCenter defaultCenter] removeObserver:self.activeApplicationObserver];
	
	self.resignApplicationObserver = nil;
	self.activeApplicationObserver = nil;
}

- (void)didProcessRequest:(NSURLRequest *)request {
	dispatch_async(self.jibberQueue, ^{
		if ([[[self.requests keyEnumerator] allObjects] containsObject:request]) {
		        return;
		}
		
		NSDictionary *params = @{
		        @"uuid": [NSUUID UUID].UUIDString,
		        @"method": request.HTTPMethod ? : @"",
		        @"path": request.URL.absoluteString ? : @"",
		        @"body": [request.HTTPBody base64EncodedStringWithOptions:0] ? : @"",
		        @"headers": request.allHTTPHeaderFields ? : @{},
		        @"date": @([NSDate date].timeIntervalSince1970)
		};
		[self.requests setObject:params forKey:request];
		[self logRequestWithParameters:params];
	});
}

- (void)didProcessResponse:(NSURLResponse *)response forRequest:(NSURLRequest *)request withData:(NSData *)data errorMessage:(NSString *)errorMessage {
	dispatch_async(self.jibberQueue, ^{
		NSDictionary *headers = @{};
		NSInteger statusCode = kJibberRequestFailureStatusCode;
		
		if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
		        headers = httpResponse.allHeaderFields;
		        statusCode = httpResponse.statusCode;
		}
		
		NSDictionary *requestParams = [self.requests objectForKey:request];
		
		if (!requestParams) {
		        [self log:@"[JibberClient] Could not find previous request: %@", request];
		        return;
		}
		
		[self.requests removeObjectForKey:request];
		
		NSTimeInterval timeOfRequest = [requestParams[@"date"] doubleValue];
		NSTimeInterval timeOfNow = [NSDate date].timeIntervalSince1970;
		
		NSDictionary *params = @{
		        @"uuid": requestParams[@"uuid"],
		        @"status_code": @(statusCode),
		        @"error_message": errorMessage ? : @"",
		        @"body": [data base64EncodedStringWithOptions:0] ? : @"",
		        @"headers": headers ? : @{},
		        @"duration": @(timeOfNow - timeOfRequest),
		        @"date": @(timeOfNow)
		};
		
		[self logResponseWithParameters:params];
	});
}

- (void)didProcessRemoteNotificationWithUserInfo:(NSDictionary *)userInfo {
	dispatch_async(self.jibberQueue, ^{
		[self log:@"[JibberClient] Remote notification received with userInfo: %@", userInfo];
		
		NSData *data = [NSJSONSerialization dataWithJSONObject:userInfo options:0 error:nil];
		NSTimeInterval timeOfNow = [NSDate date].timeIntervalSince1970;
		NSDictionary *params = @{
		        @"uuid": [NSUUID UUID].UUIDString,
		        @"status_code": @(kJibberRemoteNotificationStatusCode),
		        @"error_message": @"",
		        @"body": [data base64EncodedStringWithOptions:0] ? : @"",
		        @"headers": @{ @"Content-Type": @"application/json" },
		        @"duration": @(0),
		        @"date": @(timeOfNow)
		};
		
		[self logResponseWithParameters:params];
	});
}

#pragma mark - Private

- (void)forEachConnectedServerPerformBlock:(void (^)(NSString *server))block {
	NSMapTable *copyOfServers = [self.servers copy];
	for (NSArray *servers in[copyOfServers objectEnumerator]) {
		for (NSString *server in servers) {
			block(server);
		}
	}
}

- (UIImage *)appIconImage {
	UIImage *image = nil;
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	
	// try image asset catalog
	image = [UIImage imageNamed:[[infoDictionary valueForKeyPath:@"CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles"] lastObject]];
	
	// try traditional icon from Info.plist
	if (!image) {
		image = [UIImage imageNamed:[infoDictionary[@"CFBundleIconFiles"] firstObject]];
	}
	
	return image;
}

- (void)logRequestWithParameters:(NSDictionary *)parameters {
	if (!parameters) {
		NSLog(@"parameters");
		return;
	}
	if (self.connectionMode == JibberClientWirelessConnection) {
		if (self.servers.count > 0) {
			[self log:@"[JibberClient] Sending request parameters: %@", parameters];
			[self sendToServerWithEndpoint:@"requests" parameters:@{
			         @"device": self.deviceParameters,
			         @"request": parameters
			 }];
		}
		else {
			[self addObject:parameters toArray:self.savedRequests];
			[self log:@"[JibberClient] Sending request but no servers"];
		}
	}
	else {
		if (self.connectedToClient) {
			NSDictionary *dataDict = @{
				@"request" : @{
					@"device": self.deviceParameters,
					@"request": parameters
				}
			};
			NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
			[self.client sendData:[data compressedDataWithQuality:kJibberCompressionQuality]];
		}
		else {
			[self addObject:parameters toArray:self.savedRequests];
		}
	}
	
//	if (self.server.readyToSendData) {
//		[self.server enqueueDataForSending:[data compressedDataWithQuality:5]];
//	}
}

- (void)logResponseWithParameters:(NSDictionary *)parameters {
	if (!parameters) {
		NSLog(@"parameters");
		return;
	}
	if (self.connectionMode == JibberClientWirelessConnection) {
		if (self.servers.count > 0) {
			[self log:@"[JibberClient] Sending response parameters: %@", parameters];
			[self sendToServerWithEndpoint:@"responses" parameters:@{
			         @"device": self.deviceParameters,
			         @"response": parameters
			 }];
		}
		else {
			[self addObject:parameters toArray:self.savedResponses];
			[self log:@"[JibberClient] Sending response but no servers"];
		}
	}
	else {
		if (self.connectedToClient) {
			NSDictionary *dataDict = @{
				@"response" : @{
					@"device": self.deviceParameters,
					@"response": parameters
				}
			};
			NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
			[self.client sendData:[data compressedDataWithQuality:kJibberCompressionQuality]];
		}
		else {
			[self addObject:parameters toArray:self.savedResponses];
		}
		
	}
//	if (self.server.readyToSendData) {
//		[self.server enqueueDataForSending:[data compressedDataWithQuality:5]];
//	}
}

- (void)sendHeartBeatData {
	if (self.connectionMode == JibberClientWirelessConnection) {
		[self sendToServerWithEndpoint:@"heartbeat" parameters:@{
		         @"device": self.deviceParameters,
		 }];
	}
	else {
		NSDictionary *dataDict = @{
			@"heartbeat" : @{
				@"device": self.deviceParameters,
			}
		};
		NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
		[self.client sendData:[data compressedDataWithQuality:kJibberCompressionQuality]];
	}
//	if (self.server.readyToSendData) {
//		[self.server enqueueDataForSending:[data compressedDataWithQuality:5]];
//	}
}

- (void)sendToServerWithEndpoint:(NSString *)endpoint parameters:(NSDictionary *)parameters {
	dispatch_async(self.jibberQueue, ^{
		NSData *data = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
		NSData *gzippedData = [data gzippedData];
		NSString *dataLengthString = [[NSString alloc] initWithFormat:@"%lu", (unsigned long)[gzippedData length]];
		
		[self forEachConnectedServerPerformBlock: ^(NSString *server) {
		         NSString *urlString = [NSString stringWithFormat:@"http://%@/%@", server, endpoint];
		         NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
		         [request setHTTPMethod:@"POST"];
		         [request setHTTPBody:gzippedData];
		         
		         [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
		         [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		         [request setValue:dataLengthString forHTTPHeaderField:@"Content-Length"];
		         
		         NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
		                                           if (error) {
		                                                   return;
							   }
		                                           NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		                                           if ([[jsonDictionary objectForKey:@"requires-icon-upload"] boolValue]) {
		                                                   [self uploadIconToServer:server];
							   }
						   }];
						   
		         task.taskDescription = JibberClientTaskDescription;
		         [task resume];
		 }];
	});
}

- (void)uploadIconToServer:(NSString *)server {
	NSString *iconURLString = [NSString stringWithFormat:@"http://%@/icons/%@", server, [self.deviceParameters objectForKey:@"bundle_identifier"]];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:iconURLString]];
	[request setHTTPMethod:@"POST"];
	
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	UIImage *iconImage = [self appIconImage];
	
	// try image asset catalog
	if (iconImage) {
		NSData *imageData = UIImagePNGRepresentation(iconImage);
		NSURLSessionUploadTask *uploadTask = [[NSURLSession sharedSession] uploadTaskWithRequest:request fromData:imageData];
		uploadTask.taskDescription = JibberClientTaskDescription;
		[uploadTask resume];
	}
}

- (void)clearRequestsBacklog {
	NSArray *arrayToEnumerate = [self.savedRequests copy];
	if (self.connectionMode == JibberClientWirelessConnection) {
		for (NSDictionary *params in arrayToEnumerate) {
			[self sendToServerWithEndpoint:@"requests" parameters:@{
			         @"device": self.deviceParameters,
			         @"request": params
			 }];
		}
	}
	else {
		for (NSDictionary *params in arrayToEnumerate) {
			NSDictionary *dataDict = @{
				@"request" : @{
					@"device": self.deviceParameters,
					@"request": params
				}
			};
			NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
			[self.client sendData:[data compressedDataWithQuality:kJibberCompressionQuality]];
		}
	}
	
	[self.savedRequests removeObjectsInArray:arrayToEnumerate];
}

- (void)clearResponsesBacklog {
	NSArray *arrayToEnumerate = [self.savedResponses copy];
	if (self.connectionMode == JibberClientWirelessConnection) {
		for (NSDictionary *params in arrayToEnumerate) {
			[self sendToServerWithEndpoint:@"responses" parameters:@{
			         @"device": self.deviceParameters,
			         @"response": params
			 }];
		}
	}
	else {
		for (NSDictionary *params in arrayToEnumerate) {
			NSDictionary *dataDict = @{
				@"response" : @{
					@"device": self.deviceParameters,
					@"response": params
				}
			};
			NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
			[self.client sendData:[data compressedDataWithQuality:kJibberCompressionQuality]];
		}
	}
	
	[self.savedResponses removeObjectsInArray:arrayToEnumerate];
}

- (void)addObject:(NSDictionary *)dictionary toArray:(NSMutableArray *)array {
	while (array.count > 10) {
		[array removeObjectAtIndex:0];
	}
	[array addObject:dictionary];
}

- (void)sendAppIconImage {
	UIImage *image = [self appIconImage];
	if (!image) {
		return;
	}
	
	NSData *imageData = UIImagePNGRepresentation(image);
	NSString *stringData = [imageData base64EncodedStringWithOptions:0];
	
	NSDictionary *dataDict = @{
		@"image" : @{
			@"device": self.deviceParameters,
			@"data": stringData
		}
	};
	NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
	[self.client sendData:[data compressedDataWithQuality:kJibberCompressionQuality]];
}

#pragma mark - PeerTalkClientDelegate

- (void)peerTalkClient:(PeerTalkClient *)peerTalkClient didConnectToServer:(NSString *)server {
	self.connectedToClient = true;
	dispatch_async(self.jibberQueue, ^{
		[self sendHeartBeatData];
		[self clearRequestsBacklog];
		[self clearResponsesBacklog];
	});
}

- (void)peerTalkClient:(PeerTalkClient *)peerTalkClient didDisconnectFromServer:(NSString *)server {
    self.connectedToClient = false;
}

- (void)peerTalkClient:(PeerTalkClient *)peerTalkClient didReceiveData:(NSData *)data {
	[self sendAppIconImage];
}
#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser {
	[self log:@"[JibberClient] Begin searching for server"];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict {
	[self log:@"[JibberClient] Search failed with error: %@", errorDict];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
	[self.services addObject:service];
	
	[service setDelegate:self];
	[service resolveWithTimeout:10];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
	NSArray *servers = [self.servers objectForKey:service];
	if (servers) {
		[self log:@"[JibberClient] Removed servers: %@", servers];
		[self.servers removeObjectForKey:service];
	}
	[self.services removeObject:service];
}

#pragma mark - NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)service {
	NSMutableArray *servers = [NSMutableArray array];
	
	for (NSData *data in service.addresses) {
		NSString *address = GetIPAddressFromData(data);
		if (![address isEqualToString:@"0.0.0.0"]) {
			NSString *server = [NSString stringWithFormat:@"%@:%lu", address, (unsigned long)service.port];
			[servers addObject:server];
		}
	}
	
	[self log:@"[JibberClient] Resolved servers: %@", servers];
	[self.servers setObject:servers forKey:service];
	
	dispatch_async(self.jibberQueue, ^{
		[self sendHeartBeatData];
		[self clearRequestsBacklog];
		[self clearResponsesBacklog];
	});
}

@end
