//
//  OSCBroadcasterAppDelegate.h
//  OSC Broadcaster
//
//  Created by Saqoosha on 10/09/01.
//  Copyright 2010 Saqoosha. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LogView.h"


@interface OSCBroadcasterAppDelegate : NSObject <NSApplicationDelegate> {

    NSWindow *window_;
	NSToolbarItem *serverControlButton_;
	NSTextField *incomingPortField_;
	NSTextField *broadcastPortField_;
	LogView *logView_;
	
	NSImage *startServerImage_;
	NSImage *stopServerImage_;
	
	BOOL continueRunning_;
	int serverSocket_;
	int broadcastSocket_;
	u_short broadcastPort_;
}


- (IBAction)startServer:(id)sender;
- (IBAction)stopServer:(id)sender;


@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSToolbarItem *serverControlButton;
@property (assign) IBOutlet NSTextField *incomingPortField;
@property (assign) IBOutlet NSTextField *broadcastPortField;
@property (assign) IBOutlet LogView *logView;


@end
