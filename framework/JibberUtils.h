//
//  JibberUtils.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 25/1/15.
//  Copyright (c) 2015 Matthew Cheok. All rights reserved.
//

#import <objc/runtime.h>
#import <Foundation/Foundation.h>

static inline void jibber_addMethod(Class fromClass, Class toClass, SEL selector) {
    Method method = class_getInstanceMethod(fromClass, selector);
    class_addMethod(toClass, selector,  method_getImplementation(method),  method_getTypeEncoding(method));
}

static inline void jibber_swizzleSelectors(Class class, SEL originalSelector, SEL swizzledSelector) {
    // When swizzling a class method, use the following:
    // Class class = object_getClass((id)self);
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod =
    class_addMethod(class,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    }
    else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

static inline BOOL jibber_requestPathIsNotBinary(NSURLRequest *request) {
    NSString *extension = request.URL.absoluteString.pathExtension.lowercaseString;
    if (![extension isEqualToString:@"png"] &&
        ![extension isEqualToString:@"jpg"] &&
        ![extension isEqualToString:@"gif"]) {
        return true;
    }
    return false;
}