//
//  MCWebViewController.m
//  JibberDemo
//
//  Created by Matthew Cheok on 21/3/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import "MCWebViewController.h"

@interface MCWebViewController ()

@property (strong, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation MCWebViewController

- (void)viewDidLoad {
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]]];
}

@end
