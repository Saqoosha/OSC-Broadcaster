//
//  LogView.m
//  OSC Broadcaster
//
//  Created by Saqoosha on 10/09/05.
//  Copyright 2010 Saqoosha. All rights reserved.
//

#import "LogView.h"



@implementation LogView



- (void)awakeFromNib {
	NSFont *font = [NSFont fontWithName:@"Courier" size:12.0f];
	if (font) [self setFont:font];
}



- (void)_log:(NSString *)text {
	NSRange	wholeRange;
	NSRange	endRange;
	
	[self selectAll:nil];
	wholeRange = [self selectedRange];
	endRange = NSMakeRange(wholeRange.length, 0);
	[self setSelectedRange:endRange];
	[self insertText:text];	
	endRange.length = [text length];
	[self scrollRangeToVisible:endRange];
}



- (void)log:(NSString *)format arguments:(va_list)argList {
	NSString *logText = [[NSString alloc] initWithFormat:[format stringByAppendingString:@"\n"] arguments:argList];
	[self performSelectorOnMainThread:@selector(_log:) withObject:logText waitUntilDone:YES];
	[logText release];
}



- (void)log:(NSString *)format, ... {
    va_list argList;
    va_start(argList, format);
	[self log:format arguments:argList];
    va_end(argList);
}



@end
