//
//  LogView.h
//  OSC Broadcaster
//
//  Created by Saqoosha on 10/09/05.
//  Copyright 2010 Saqoosha. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LogView : NSTextView {

}


- (void)log:(NSString *)format, ...;


@end
