//
//  MCConnectionController.m
//  JibberDemo
//
//  Created by Matthew Cheok on 21/3/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "MCConnectionController.h"
#import <AFNetworking.h>

@implementation MCConnectionController

- (IBAction)handleButton:(UIButton *)sender {
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com?q=nexus%205x"]];

	switch (sender.tag) {
		case 0: {
			NSLog(@"send async");
			[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler: ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
			}];
			break;
		}

		case 1: {
			NSLog(@"send sync");
			NSURLResponse *response;
			NSError *error;
			[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
			break;
		}

		case 2: {
			NSLog(@"+connectionWithRequest:delegate:");
			[NSURLConnection connectionWithRequest:request delegate:nil];

			break;
		}

		case 3: {
			NSLog(@"-initWithRequest:delegate:");
			NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:nil];
			break;
		}

		case 4: {
			NSLog(@"-initWithRequest:delegate:startImmediately:");
			NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:nil startImmediately:NO];
			[connection start];
			break;
		}

		case 5: {
			NSLog(@"AFHTTPSessionManager");
            AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
            [manager GET:@"https://www.nsscreencast.com/api/episodes.json" parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                //
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                NSLog(@"Error: %@", error);
            }];
			break;
		}

		default:
			break;
	}
}

@end
