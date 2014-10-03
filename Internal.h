/** 
   Copyright (C) 2010 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	September 2010
   
   This file is part of the WebServer Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Date: 2010-09-17 16:47:13 +0100 (Fri, 17 Sep 2010) $ $Revision: 31364 $
   */ 

#import	<Foundation/NSAutoreleasePool.h>
#import	<Foundation/NSData.h>
#import	<Foundation/NSDebug.h>
#import	<Foundation/NSException.h>
#import	<Foundation/NSFileHandle.h>
#import	<Foundation/NSObject.h>
#import	<Foundation/NSNotification.h>
#import	<Foundation/NSRunLoop.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSThread.h>
#import	<Foundation/NSTimer.h>
#import	<GNUstepBase/GSMime.h>
#import	<Performance/GSLinkedList.h>

@class	WebServer;
@class	WebServerConfig;
@class	WebServerConnection;
@class	WebServerRequest;
@class	WebServerResponse;

/* Class to manage an I/O thread and the connections running on it.
 *
 * The -run method of this class is called in the thread used by each
 * instance, and this method runs a runloop to handle I/O and timeouts.
 *
 * Each instance runs a repeating timer which checks the connections
 * to see if any have timed out (and also keeps the runloop alive when
 * there are currently no connections performing I/O).
 *
 * The connections are held in three linked lists according to their state
 * (which determines how long the connection can be idle before timing out).
 *
 * Whenever an event occurs on a connection, the 'ticker' timestamp for the
 * connection is updated and the connection is moved to the end of its list,
 * so the timeout process knows the connections in the list are ordered,
 * and it doesn't need to check further than the first connection which
 * has not timed out.
 */
@interface	IOThread : NSObject
{
@public
  WebServer	*server;	// The owner of this thread (not retained).
  NSThread	*thread;	// The actual thread being used.
  NSLock	*threadLock;	// Protect ivars from changes.
  NSTimer	*timer;		// Repeated regular timer (not retained).
  NSTimeInterval cTimeout;	// Timeout period for connections.
  GSLinkedList	*processing;	// Connections processing a request.
  GSLinkedList	*handshakes;	// Connections performing SSL handshake
  GSLinkedList	*readwrites;	// Connections performing read or write.
  GSLinkedList	*keepalives;	// Connections waiting for a new request.
  uint16_t	keepaliveCount;	// Number of connections in keepalive.
  uint16_t	keepaliveMax;	// Maximum connections kept alive.
}
- (void) run;
- (void) timeout: (NSTimer*)t;
@end


/* This class is used to hold configuration information needed by a single
 * connection ... once set up an instance is never modified so it can be
 * shared between threads.  When configuration is modified, it is replaced
 * by a new instance.
 */
@interface	WebServerConfig: NSObject
{
@public
  BOOL			verbose;	// logging type is detailed/verbose
  BOOL			durations;	// log request and connection times
  BOOL                  reverse;	// should do reverse DNS lookup
  BOOL			secureProxy;	// using a secure proxy
  BOOL			logRawIO;	// log raw I/O on connection
  BOOL                  foldHeaders;    // Whether long headers are folded
  NSUInteger		maxBodySize;
  NSUInteger		maxRequestSize;
  NSUInteger		maxConnectionRequests;
  NSTimeInterval	maxConnectionDuration;
  NSSet			*permittedMethods;
}
@end

@interface	WebServerRequest : GSMimeDocument
@end

/* We need to ensure that our map table holds response information safely
 * and efficiently ... so we use a subclass where we control -hash and
 * -isEqual: to ensure that each object is unique and quick.
 * We also store a pointer to the owning connection so that we can find
 * the connections from the response really quickly.
 */
@interface	WebServerResponse : GSMimeDocument
{
  WebServerConnection	*webServerConnection;
  BOOL                  prepared;
  BOOL                  foldHeaders;
}
- (BOOL) foldHeaders;
- (BOOL) prepared;
- (void) setFoldHeaders: (BOOL)aFlag;
- (void) setPrepared;
- (void) setWebServerConnection: (WebServerConnection*)c;
- (WebServerConnection*) webServerConnection;
@end

typedef	enum {
  WSHCountRequests,
  WSHCountConnections,
  WSHCountConnectedHosts
} WSHType;

/* Special header used to store information in a request.
 */
@interface	WebServerHeader : GSMimeHeader
{
  WSHType	wshType;
  NSObject	*wshObject;
}
- (id) initWithType: (WSHType)t andObject: (NSObject*)o;
@end


@interface	WebServerConnection : GSListLink
{
  NSNotificationCenter	*nc;
  IOThread		*ioThread;
  WebServer		*server;
  WebServerResponse	*response;
  WebServerConfig	*conf;
  NSString		*address;	// Client address
  NSString		*command;	// Command sent by client
  NSString		*agent;		// User-Agent header
  NSString		*result;	// Result sent back
  NSString		*user;		// The remote user
  NSFileHandle		*handle;
  GSMimeParser		*parser;
  NSMutableData		*buffer;
  NSData		*excess;
  NSUInteger		byteCount;
  NSUInteger		identity;
  NSUInteger		requestCount;
  NSTimeInterval	requestStart;
  NSTimeInterval	connectionStart;
  NSTimeInterval	duration;
  NSTimeInterval	handshakeRetry;
  NSTimer		*handshakeTimer;
  NSUInteger		requests;
  NSUInteger		bodyLength;
  BOOL			shouldClose;
  BOOL			hasReset;
  BOOL			simple;
  BOOL                  hadHeader;      // Header has been completely read?
  BOOL                  hadRequest;     // Request has been completely read?
  BOOL			quiet;		// Suppress log of warning/debug info?
  BOOL			ssl;		// Should perform SSL negotiation?
  BOOL			responding;	// Writing to remote system
  BOOL			streaming;	// Need to write more data?
  BOOL                  chunked;        // Stream in chunks?
  uint32_t              incremental;    // Incremental parsing of request?
  NSMutableData         *outBuffer;
@public
  NSTimeInterval	ticked;
  NSTimeInterval	extended;
}
- (NSString*) address;
- (NSString*) audit;
- (NSTimeInterval) connectionDuration: (NSTimeInterval)now;
- (void) end;
- (BOOL) ended;
- (NSData*) excess;
- (BOOL) foldHeaders;
- (NSFileHandle*) handle;
- (void) handshake;
- (BOOL) hasReset;
- (NSUInteger) identity;
- (id) initWithHandle: (NSFileHandle*)hdl
	     onThread: (IOThread*)t
		  for: (WebServer*)svr
	      address: (NSString*)adr
	       config: (WebServerConfig*)c
		quiet: (BOOL)q
		  ssl: (BOOL)s
	      refusal: (NSString*)r;
- (IOThread*) ioThread;
- (NSUInteger) moreBytes: (NSUInteger)count;
- (GSMimeParser*) parser;
- (BOOL) processing;
- (BOOL) quiet;
- (WebServerRequest*) request;
- (NSTimeInterval) requestDuration: (NSTimeInterval)now;
- (void) reset;
- (void) respond: (NSData*)stream;
- (WebServerResponse*) response;
- (void) run;
- (void) setAddress: (NSString*)aString;
- (void) setAgent: (NSString*)aString;
- (void) setConnectionStart: (NSTimeInterval)when;
- (void) setExcess: (NSData*)d;
- (void) setParser: (GSMimeParser*)aParser;
- (void) setProcessing: (BOOL)aFlag;
- (void) setRequestEnd: (NSTimeInterval)when;
- (void) setRequestStart: (NSTimeInterval)when;
- (void) setResult: (NSString*)aString;
- (void) setShouldClose: (BOOL)aFlag;
- (void) setSimple: (BOOL)aFlag;
- (void) setTicked: (NSTimeInterval)t;
- (void) setUser: (NSString*)aString;
- (BOOL) shouldClose;
- (void) shutdown;
- (void) start;
- (BOOL) verbose;

- (void) _didData: (NSData*)d;
- (void) _didRead: (NSNotification*)notification;
- (void) _didWrite: (NSNotification*)notification;
- (void) _keepalive;
- (void) _timeout: (NSTimer*)t;
@end

@interface	WebServer (Internal)
- (void) _alert: (NSString*)fmt, ...;
- (void) _audit: (WebServerConnection*)connection;
- (void) _didConnect: (NSNotification*)notification;
- (void) _endConnect: (WebServerConnection*)connection;
- (NSString*) _ioThreadDescription;
- (uint32_t) _incremental: (WebServerConnection*)connection;
- (void) _listen;
- (void) _log: (NSString*)fmt, ...;
- (NSString*) _poolDescription;
- (void) _process1: (WebServerConnection*)connection;
- (void) _process2: (WebServerConnection*)connection;
- (void) _removeConnection: (WebServerConnection*)connection;
- (void) _setup;
- (NSUInteger) _setIncrementalBytes: (const void*)bytes
                             length: (NSUInteger)length
                         forRequest: (WebServerRequest*)request;
- (NSString*) _xCountRequests;
- (NSString*) _xCountConnections;
- (NSString*) _xCountConnectedHosts;
@end

