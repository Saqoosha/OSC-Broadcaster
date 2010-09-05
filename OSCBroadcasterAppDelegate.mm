//
//  OSCBroadcasterAppDelegate.m
//  OSC Broadcaster
//
//  Created by Saqoosha on 10/09/01.
//  Copyright 2010 Saqoosha. All rights reserved.
//

#include <sys/types.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/bpf.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <errno.h>

#include "pcap.h"
#include "WOscMessage.h"

#import "OSCBroadcasterAppDelegate.h"



#pragma mark ---



int createBroadcastRawSocket() {
	int sock;
	if ((sock = socket(AF_INET, SOCK_RAW, IPPROTO_RAW)) < 0){
		NSLog(@"socket create error");
		return -1;
	}
	
	int yes = 1;
	if (setsockopt(sock, IPPROTO_IP, IP_HDRINCL, &yes, sizeof(int)) < 0) {
		NSLog(@"setsockopt error");
		return -2;
	}
	
	if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &yes, sizeof(int)) < 0) {
		NSLog(@"setsockopt error");
		return -3;
	}
	
	NSLog(@"socket create succeeded");
	
	return sock;
}



#pragma mark ---



@implementation OSCBroadcasterAppDelegate



@synthesize window = window_, serverControlButton = serverControlButton_, incomingPortField = incomingPortField_, broadcastPortField = broadcastPortField_, logView = logView_;




+ (void)initialize {
    NSString *userDefaultsValuesPath;
    NSDictionary *userDefaultsValuesDict;
    
    userDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"UserDefaults" 
                                                             ofType:@"plist"];
    userDefaultsValuesDict = [NSDictionary dictionaryWithContentsOfFile:userDefaultsValuesPath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsValuesDict];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:userDefaultsValuesDict];
}



- (void)_broadcast:(unsigned char *)data length:(unsigned int)dataLength from:(struct in_addr)address port:(u_short)port {
	unsigned char buffer[2048];
	memset(buffer, 0, 2048);
	
	struct ip *ip_header = (struct ip *)buffer;
	ip_header->ip_v = 4;
	ip_header->ip_hl = 5;
	ip_header->ip_tos = 0;
	ip_header->ip_len = sizeof(struct ip) + sizeof(struct udphdr) + dataLength;
	ip_header->ip_id = 0;
	ip_header->ip_off = 0;
	ip_header->ip_ttl = 16;
	ip_header->ip_p = IPPROTO_UDP;
	ip_header->ip_sum = 0;
	ip_header->ip_src = address;
	//ip_header->ip_src.s_addr = inet_addr("192.168.1.222");
	ip_header->ip_dst.s_addr = inet_addr("255.255.255.255");
	
	struct udphdr *udp_header = (struct udphdr *)(buffer + sizeof(struct ip));
	udp_header->uh_sport = htons(4000);
	udp_header->uh_dport = htons(port);//htons(port);
	udp_header->uh_ulen = htons(sizeof(struct udphdr) + dataLength);
	udp_header->uh_sum = 0;
	
	memcpy(buffer + sizeof(struct ip) + sizeof(struct udphdr), data, dataLength);
	
	struct sockaddr_in serv;
	memset(&serv, 0, sizeof(struct sockaddr_in));
	serv.sin_family = AF_INET;
	
	int len = sizeof(struct ip) + sizeof(struct udphdr) + dataLength;
	len = sendto(broadcastSocket_, &buffer, len, 0, (struct sockaddr *)&serv, sizeof(struct sockaddr));
//	[logView_ log:@"%d bytes broadcasted.", len];
//	if (len < 0) [logView_ log:@"Error on sendto: %d", errno];
}



- (void)_startServerSucceeded:(NSString *)message {
	[logView_ log:message];
	[serverControlButton_ setImage:stopServerImage_];
	[serverControlButton_ setLabel:@"Stop Server"];
	[serverControlButton_ setAction:@selector(stopServer:)];
	[serverControlButton_ setEnabled:YES];
}



- (void)_startServerError:(NSString *)reason {
	[logView_ log:reason];
	[serverControlButton_ setEnabled:YES];
	[incomingPortField_ setEnabled:YES];
	[broadcastPortField_ setEnabled:YES];
}



- (void)_stopServerSucceeded {
	[logView_ log:@"Server stopped."];
	[serverControlButton_ setImage:startServerImage_];
	[serverControlButton_ setLabel:@"Start Server"];
	[serverControlButton_ setAction:@selector(startServer:)];
	[serverControlButton_ setEnabled:YES];
	[incomingPortField_ setEnabled:YES];
	[broadcastPortField_ setEnabled:YES];
}



- (void)_startServer {
	if ((serverSocket_ = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
		[self performSelectorOnMainThread:@selector(_startServerError:) withObject:@"Failed to create server socket." waitUntilDone:NO];
		return;
	}
	
	int result;
	int yes = 1;
	result = setsockopt(serverSocket_, IPPROTO_IP, IP_RECVDSTADDR, &yes, sizeof(yes));
	if (result < 0) {
		[self performSelectorOnMainThread:@selector(_startServerError:) withObject:@"Error on setsockopt(IPPROTO_IP)" waitUntilDone:NO];
		return;
	}
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	short incomingPort = [[[NSUserDefaults standardUserDefaults] objectForKey:@"incomingPort"] shortValue];
	broadcastPort_ = [[[NSUserDefaults standardUserDefaults] objectForKey:@"broadcastPort"] shortValue];
	
	struct sockaddr_in serverAddress;
	memset(&serverAddress, 0, sizeof(serverAddress));
	serverAddress.sin_family = AF_INET;
	serverAddress.sin_addr.s_addr = INADDR_ANY;
	serverAddress.sin_port = htons(incomingPort);
	
	result = bind(serverSocket_, (struct sockaddr *)&serverAddress, sizeof(serverAddress));
	if (result == -1) {
		[self performSelectorOnMainThread:@selector(_startServerError:) withObject:@"Error on bind server socket. (alread used incoming port by another application?)" waitUntilDone:NO];
		return;
	}
	
	[self performSelectorOnMainThread:@selector(_startServerSucceeded:)
						   withObject:[NSString stringWithFormat:@"Broadcast server started at port %d.", incomingPort]
						waitUntilDone:NO];
	
	[pool release];

	struct sockaddr_in clientAddress;
	struct msghdr msg;
	struct iovec iov[1];
	char receiveBuffer[2048];
	struct cmsghdr *cmsg;
	char cbuf[512];
	struct in_addr *destinationAddress;

	continueRunning_ = YES;
	while (continueRunning_) {
		
		iov[0].iov_base = receiveBuffer;
		iov[0].iov_len = 2048;
		
		memset(&msg, 0, sizeof(msg));
		msg.msg_name = &clientAddress;
		msg.msg_namelen = sizeof(clientAddress);
		msg.msg_iov = iov;
		msg.msg_iovlen = 1;
		msg.msg_control = cbuf;
		msg.msg_controllen = 512;
		
		result = recvmsg(serverSocket_, &msg, 0);
		if (result < 0){
//			[logView_ log:@"Error on recvmsg: %d", errno];
			continue;
		}
		
		for (cmsg = CMSG_FIRSTHDR(&msg); cmsg != NULL; cmsg = CMSG_NXTHDR(&msg, cmsg)) {
			if (cmsg->cmsg_level == IPPROTO_IP && cmsg->cmsg_type == IP_RECVDSTADDR){
				destinationAddress = (struct in_addr *)CMSG_DATA(cmsg);
			}
		}
		
//		[logView_ log:@"Source address:port: %s:%d", inet_ntoa(clientAddress.sin_addr), ntohs(clientAddress.sin_port)];
//		[logView_ log:@"Destination address: %s", inet_ntoa(*destinationAddress)];
		
		if (destinationAddress->s_addr != 0xffffffff) {
			[self _broadcast:(unsigned char *)receiveBuffer length:result from:*destinationAddress port:broadcastPort_];
		}
	}
	
	[self performSelectorOnMainThread:@selector(_stopServerSucceeded) withObject:nil waitUntilDone:NO];
}



#pragma mark ---



- (IBAction)startServer:(id)sender {
	[serverControlButton_ setEnabled:NO];
	[incomingPortField_ setEnabled:NO];
	[broadcastPortField_ setEnabled:NO];
	[NSThread detachNewThreadSelector:@selector(_startServer) toTarget:self withObject:nil];
}



- (IBAction)stopServer:(id)sender {
	continueRunning_ = NO;
	close(serverSocket_);
}



- (void)userDefaultsDidChange:(NSNotification *)notification {
	NSLog(@"%@", notification);
	broadcastPort_ = [[[NSUserDefaults standardUserDefaults] objectForKey:@"broadcastPort"] shortValue];
	NSLog(@"broadcast port: %d", broadcastPort_);
}



#pragma mark ---



- (void)initApp {
	continueRunning_ = YES;
	startServerImage_ = [[NSImage imageNamed:@"Play Green Button.png"] retain];
	stopServerImage_ = [[NSImage imageNamed:@"Stop Red Button.png"] retain];
	broadcastSocket_ = createBroadcastRawSocket();
	
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];

	[window_ makeKeyAndOrderFront:self];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}



- (void)readToEndOfFileCompletion:(NSNotification *)notification {
	NSLog(@"readToEndOfFileCompletion: %@", notification);
	NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	NSLog(@"%@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
	[[NSApplication sharedApplication] terminate:self];
}



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	NSLog(@"arguments: %@", arguments);
	
	if ([arguments count] == 2 && [[arguments objectAtIndex:1] isEqualToString:@"--authorized"]) {
		// running with admin privillege
		[self initApp];
		
	} else {
		// relaunth self with admin privillege
		OSStatus status;
		AuthorizationRef authRef;
		AuthorizationItem authItem;
		AuthorizationRights authRights;
		BOOL waitForExit = NO;
		
		status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef);
		if (status != errAuthorizationSuccess) {
			NSLog(@"AuthorizationCreate Error.");
			exit(1);
		}
		
		authItem.name = kAuthorizationRightExecute;
		authItem.valueLength = 0;
		authItem.value = NULL;
		authItem.flags = 0;
		
		authRights.count = 1;
		authRights.items = &authItem;
		
		status = AuthorizationCopyRights(authRef,
										 &authRights,
										 kAuthorizationEmptyEnvironment,
										 kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights,
										 NULL);
		if (status == errAuthorizationSuccess) {
			NSLog(@"Authorization succeeded.");
			
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			char *args[] = { (char *)"--authorized", NULL };
			FILE *pipe;
			status = AuthorizationExecuteWithPrivileges(authRef,
														[[arguments objectAtIndex:0] UTF8String],
														kAuthorizationFlagDefaults,
														args,
														&pipe);
#ifdef DEBUG
			if (status == errAuthorizationSuccess) {
				NSFileHandle *file = [[NSFileHandle alloc] initWithFileDescriptor:fileno(pipe) closeOnDealloc:YES];
				[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(readToEndOfFileCompletion:)
															 name:NSFileHandleReadToEndOfFileCompletionNotification
														   object:nil];
				[file readToEndOfFileInBackgroundAndNotify];
				waitForExit = YES;
			}
#endif
			
			[pool release];
			
		} else {
			NSLog(@"AuthorizationCopyRights Error.");
		}
		
		NSLog(@"Parent process finished.");
		
		AuthorizationFree(authRef, kAuthorizationFlagDefaults);

		if (!waitForExit) [[NSApplication sharedApplication] terminate:self];
	}
}



- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}



@end

