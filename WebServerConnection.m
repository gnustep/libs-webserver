/** 
   Copyright (C) 2010 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	June 2010
   
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

#import "WebServer.h"
#import "Internal.h"
#import <Foundation/NSHost.h>

static Class NSDateClass = Nil;
static Class NSMutableDataClass = Nil;
static Class NSStringClass = Nil;
static Class WebServerResponseClass = Nil;

@implementation	WebServerResponse

- (id) copy
{
  return [self copyWithZone: NSDefaultMallocZone()];
}

- (id) copyWithZone: (NSZone*)z
{
  return [self retain];
}

- (NSUInteger) hash
{
  return ((NSUInteger)self)>>2;
}

- (BOOL) isEqual: (id)other
{
  return (other == self) ? YES : NO;
}

- (void) setWebServerConnection: (WebServerConnection*)c
{
  webServerConnection = c;
}

- (WebServerConnection*) webServerConnection
{
  return webServerConnection;
}
@end



@implementation	WebServerConnection

+ (void) initialize
{
  if ([WebServerConnection class] == self)
    {
      NSDateClass = [NSDate class];
      NSMutableDataClass = [NSMutableData class];
      NSStringClass = [NSString class];
      WebServerResponseClass = self;
    }
}

- (NSString*) address
{
  return address;
}

- (NSString*) audit
{
  NSString	*h;
  NSString	*c;
  NSString	*a;
  NSString	*r;
  NSString	*u;
  NSDate	*d;

  if (address == nil)
    {
      h = @"-";
    }
  else
    {
      h = address;	
    }

  if (command == nil)
    {
      c = @"-";
    }
  else
    {
      c = [command description];	
      if ([c rangeOfString: @"\\"].length > 0)
        {
	  c = [c stringByReplacingString: @"\\" withString: @"\\\\"];
	}
      if ([c rangeOfString: @"\""].length > 0)
        {
	  c = [c stringByReplacingString: @"\"" withString: @"\\\""];
	}
      c = [NSStringClass stringWithFormat: @"\"%@\"", c];
    }

  if (agent == nil)
    {
      a = @"-";
    }
  else
    {
      a = agent;	
      if ([a rangeOfString: @"\\"].length > 0)
        {
	  a = [a stringByReplacingString: @"\\" withString: @"\\\\"];
	}
      if ([a rangeOfString: @"\""].length > 0)
        {
	  a = [a stringByReplacingString: @"\"" withString: @"\\\""];
	}
      a = [NSStringClass stringWithFormat: @"\"%@\"", a];
    }

  if (result == nil)
    {
      r = @"-";
    }
  else
    {
      r = result;	
      if ([r rangeOfString: @"\\"].length > 0)
        {
	  r = [r stringByReplacingString: @"\\" withString: @"\\\\"];
	}
      if ([r rangeOfString: @"\""].length > 0)
        {
	  r = [r stringByReplacingString: @"\"" withString: @"\\\""];
	}
      r = [NSStringClass stringWithFormat: @"\"%@\"", r];
    }

  if (user == nil)
    {
      u = @"-";
    }
  else
    {
      u = user;	
    }

  if (requestStart == 0.0)
    {
      d = [NSDateClass date];
    }
  else
    {
      d = [NSDateClass dateWithTimeIntervalSinceReferenceDate: requestStart];
    }
  return [NSStringClass stringWithFormat: @"%@ - %@ [%@] %@ %@ %@",
    h, u, d, c, a, r];
}

- (void) dealloc
{
  [ticker invalidate];
  ticker = nil;
  [handle closeFile];
  DESTROY(handle);
  DESTROY(excess);
  DESTROY(address);
  DESTROY(buffer);
  DESTROY(parser);
  DESTROY(command);
  DESTROY(agent);
  DESTROY(result);
  DESTROY(response);
  DESTROY(conf);
  DESTROY(nc);
  [super dealloc];
}

- (NSString*) description
{
  return [NSStringClass stringWithFormat: @"WebServerConnection: %08x [%@] ",
    [self identity], [self address]];
}

- (void) end
{
  NSFileHandle	*h;

  [ticker invalidate];
  ticker = nil;

  [nc removeObserver: self
		name: NSFileHandleReadCompletionNotification
	      object: handle];
  [nc removeObserver: self
		name: GSFileHandleWriteCompletionNotification
	      object: handle];
  h = handle;
  handle = nil;
  [h closeFile];
  [h release];

  ticked = [NSDateClass timeIntervalSinceReferenceDate];
  if (NO == quiet)
    {
      NSTimeInterval	r = [self requestDuration: ticked];

      if (r > 0.0)
	{
	  [self setRequestEnd: ticked];
	  if (YES == conf->durations)
	    {
	      [server _log: @"%@ end of request (duration %g)", self, r];
	    }
	}
      if (YES == conf->verbose)
	{
	  NSTimeInterval	s = [self connectionDuration: ticked];

	  [server _log: @"%@ disconnect (duration %g)", self, s];
	}
      [server _audit: self];
    }
}

- (BOOL) ended
{
  if (nil == handle)
    {
      return YES;
    }
  return NO;
}

- (NSData*) excess
{
  return excess;
}

- (void) extend: (NSTimeInterval)i
{
  if (i > 0.0)
    {
      if (extended == 0.0)
	{
	  extended = ticked;
	}
      extended += i;
    }
}

- (NSFileHandle*) handle
{
  return handle;
}

- (BOOL) hasReset
{
  return hasReset;
}

- (NSUInteger) identity
{
  return identity;
}

- (id) initWithHandle: (NSFileHandle*)hdl
		  for: (WebServer*)svr
	      address: (NSString*)adr
	       config: (WebServerConfig*)c
		quiet: (BOOL)q
		  ssl: (BOOL)s
	      refusal: (NSString*)r
{
  static NSUInteger	connectionIdentity = 0;

  nc = [[NSNotificationCenter defaultCenter] retain];
  server = svr;
  identity = ++connectionIdentity;
  requestStart = 0.0;
  duration = 0.0;
  requests = 0;
  ASSIGN(handle, hdl);
  address = [adr copy];
  conf = [c retain];
  quiet = q;
  ssl = s;
  result = [r copy];
  if (ticker == nil)
    {
      ticker = [NSTimer scheduledTimerWithTimeInterval: 0.8
        target: self
        selector: @selector(timeout:)
        userInfo: 0
        repeats: YES];
    }

  return self;
}

- (NSUInteger) moreBytes: (NSUInteger)count
{
  byteCount += count;
  return byteCount;
}

- (GSMimeParser*) parser
{
  return parser;
}

- (BOOL) processing
{
  return processing;
}

- (BOOL) quiet
{
  return quiet;
}

- (GSMimeDocument*) request
{
  return [parser mimeDocument];
}

- (NSTimeInterval) requestDuration: (NSTimeInterval)now
{
  if (requestStart > 0.0)
    {
      return now - requestStart;
    }
  return 0.0;
}

- (NSUInteger) requests
{
  return requests;
}

- (void) reset
{
  hasReset = YES;
  simple = NO;
  DESTROY(command);
  [response setWebServerConnection: nil];
  DESTROY(response);
  DESTROY(agent);
  DESTROY(result);
  byteCount = 0;
  DESTROY(buffer);
  buffer = [[NSMutableDataClass alloc] initWithCapacity: 1024];
  [self setRequestStart: 0.0];
  [self setParser: nil];
  [self setProcessing: NO];
}

- (void) respond
{
  NSData	*data;

  ticked = [NSDateClass timeIntervalSinceReferenceDate];
  [self setProcessing: NO];

  [response setHeader: @"content-transfer-encoding"
		value: @"binary"
	   parameters: nil];

  if (YES == simple)
    {
      /*
       * If we had a 'simple' request with no HTTP version, we must respond
       * with a 'simple' response ... just the raw data with no headers.
       */
      data = [response convertToData];
      [self setResult: @""];
    } 
  else
    {
      NSMutableData	*out;
      NSMutableData	*raw;
      uint8_t		*buf;
      NSUInteger	len;
      NSUInteger	pos;
      NSUInteger	contentLength;
      NSEnumerator	*enumerator;
      GSMimeHeader	*hdr;
      NSString		*str;

      raw = [response rawMimeData];
      buf = [raw mutableBytes];
      len = [raw length];

      for (pos = 4; pos < len; pos++)
	{
	  if (strncmp((char*)&buf[pos-4], "\r\n\r\n", 4) == 0)
	    {
	      break;
	    }
	}
      contentLength = len - pos;
      pos -= 2;
      [raw replaceBytesInRange: NSMakeRange(0, pos) withBytes: 0 length: 0];

      out = [NSMutableDataClass dataWithCapacity: len + 1024];
      [response deleteHeaderNamed: @"mime-version"];
      [response deleteHeaderNamed: @"content-length"];
      [response deleteHeaderNamed: @"content-encoding"];
      [response deleteHeaderNamed: @"content-transfer-encoding"];
      if (contentLength == 0)
	{
	  [response deleteHeaderNamed: @"content-type"];
	}
      str = [NSStringClass stringWithFormat: @"%u", contentLength];
      [response setHeader: @"content-length" value: str parameters: nil];

      hdr = [response headerNamed: @"http"];
      if (hdr == nil)
	{
	  const char	*s;

	  if (contentLength == 0)
	    {
	      s = "HTTP/1.1 204 No Content\r\n";
	      [self setResult: @"HTTP/1.1 204 No Content"];
	    }
	  else
	    {
	      s = "HTTP/1.1 200 Success\r\n";
	      [self setResult: @"HTTP/1.1 200 Success"];
	    }
	  [out appendBytes: s length: strlen(s)];
	}
      else
	{
	  NSString	*s = [[hdr value] stringByTrimmingSpaces];

	  [self setResult: s];
	  s = [s stringByAppendingString: @"\r\n"];
	  [out appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
	  [response deleteHeader: hdr];
	  /*
	   * If the http version has been set to be an old one,
	   * we must be prepared to close the connection at once
	   * unless connection keep-alive has been set.
	   */
	  if ([s hasPrefix: @"HTTP/"] == NO)
	    {
	      [self setShouldClose: YES];
	    }
	  else if ([[s substringFromIndex: 5] floatValue] < 1.1) 
	    {
	      s = [[response headerNamed: @"connection"] value]; 
	      if (s == nil
	        || ([s caseInsensitiveCompare: @"keep-alive"] != NSOrderedSame))
		{
		  [self setShouldClose: YES];
		}
	    }
	}

      /* We will close this connection if the maximum number of requests
       * or maximum request duration has been exceeded.
       */
      if (requests >= conf->maxConnectionRequests)
	{
	  [self setShouldClose: YES];
	}
      else if (duration >= conf->maxConnectionDuration)
	{
	  [self setShouldClose: YES];
	}

      /* Ensure that we send a connection close if we are about to drop
       * the connection.
       */
      if ([self shouldClose] == YES)
        {
	  [response setHeader: @"Connection"
			value: @"close"
		   parameters: nil];
	}

      enumerator = [[response allHeaders] objectEnumerator];
      while ((hdr = [enumerator nextObject]) != nil)
	{
	  [out appendData: [hdr rawMimeData]];
	}
      if ([raw length] > 0)
	{
	  [out appendData: raw];
	}
      else
	{
	  [out appendBytes: "\r\n" length: 2];	// Terminate headers
	}
      data = out;
    }

  if (YES == conf->verbose && NO == quiet)
    {
      [server _log: @"Response %@ - %@", self, data];
    }
  [nc removeObserver: self
		name: NSFileHandleReadCompletionNotification
	      object: handle];
  [server _threadWrite: data to: handle];

  /* If this connection is not closing and excess data has been read,
   * we may continue dealing with incoming data before the write
   * has completed.
   */
  if ([self shouldClose] == YES)
    {
      [self setExcess: nil];
    }
  else
    {
      NSData	*more = [self excess];

      if (more != nil)
	{
	  [more retain];
	  [self setExcess: nil];
	  [self reset];
          [self _didData: more];
	  [more release];
	}
    }
}

- (WebServerResponse*) response
{
  if (nil == response)
    {
      response = [WebServerResponse new];
      [response setWebServerConnection: self];
    }
  return response;
}

- (NSTimeInterval) connectionDuration: (NSTimeInterval)now
{
  if (connectionStart > 0.0)
    {
      return now - connectionStart;
    }
  return 0.0;
}

- (void) setAddress: (NSString*)aString
{
  ASSIGN(address, aString);
}

- (void) setAgent: (NSString*)aString
{
  ASSIGN(agent, aString);
}

- (void) setConnectionStart: (NSTimeInterval)when
{
  connectionStart = when;
}

- (void) setExcess: (NSData*)d
{
  ASSIGNCOPY(excess, d);
}

- (void) setParser: (GSMimeParser*)aParser
{
  ASSIGN(parser, aParser);
}

- (void) setProcessing: (BOOL)aFlag
{
  processing = aFlag;
}

- (void) setRequestEnd: (NSTimeInterval)when
{
  NSTimeInterval	ti = when - requestStart;

  if (ti > 0.0)
    {
      requestStart = 0.0;
      duration += ti;
      requests++;
    }
}

- (void) setRequestStart: (NSTimeInterval)when
{
  requestStart = when;
}

- (void) setResult: (NSString*)aString
{
  ASSIGN(result, aString);
}

- (void) setShouldClose: (BOOL)aFlag
{
  shouldClose = aFlag;
}

- (void) setSimple: (BOOL)aFlag
{
  simple = aFlag;
}

- (void) setTicked: (NSTimeInterval)when
{
  ticked = when;
}

- (void) setUser: (NSString*)aString
{
  ASSIGN(user, aString);
}

- (BOOL) shouldClose
{
  return shouldClose;
}

- (BOOL) simple
{
  return simple;
}

- (BOOL) ssl
{
  BOOL	r;

  handshake = YES;			// Avoid timeouts during handshake
  r = [handle sslAccept];
  handshake = NO;
  if (r == YES)			// Reset timer of last I/O
    {
      [self setTicked: [NSDateClass timeIntervalSinceReferenceDate]];
    }
  return r;
}

- (void) start
{
  NSHost	*host;

  host = nil;
  if (YES == conf->reverse && nil == result)
    {
      host = [NSHost hostWithAddress: address];
      if (nil == host)
	{
	  result = @"HTTP/1.0 403 Bad client host";
	}
    }
  else
    {
      host = nil;
    }

  if (YES == conf->verbose && NO == quiet)
    {
      if (host == nil)
	{
	  [server _log: @"%@ connect", self];
	}
      else
	{
	  [server _log: @"%@ connect from %@", self, [host name]];
	}
    }

  if (YES == ssl)
    {
      BOOL	ok;

      handshake = YES;			// Avoid timeouts during handshake
      ok = [handle sslAccept];
      handshake = NO;
      if (YES == ok)			// Reset timer of last I/O
	{
	  ticked = [NSDateClass timeIntervalSinceReferenceDate];
	}
      else
	{
	  if (NO == quiet)
	    {
	      [server _log: @"SSL accept fail on (%@).", address];
	    }
	  [server _endConnect: self];
	}
    }

  [nc addObserver: self
	 selector: @selector(_didWrite:)
	     name: GSFileHandleWriteCompletionNotification
	   object: handle];

  if (nil == result)
    {
      buffer = [[NSMutableDataClass alloc] initWithCapacity: 1024];
      [nc addObserver: self
	     selector: @selector(_didRead:)
		 name: NSFileHandleReadCompletionNotification
	       object: handle];
      [server _threadReadFrom: handle];
    }
  else
    {
      NSString	*body;

      [self setShouldClose: YES];

      if ([result rangeOfString: @" 503 "].location != NSNotFound)
	{
	  [server _alert: result];
	  body = [result stringByAppendingString:
	    @"\r\nRetry-After: 120\r\n\r\n"];
	}
      else
	{
	  if (YES == quiet)
	    {
	      [server _log: result];
	    }
	  body = [result stringByAppendingString: @"\r\n\r\n"];
        }
      [server _threadWrite: [body dataUsingEncoding: NSASCIIStringEncoding]
			to: handle];
    }
}

- (NSTimeInterval) ticked
{
  /* If we are doing an SSL handshake, we add 30 seconds to the timestamp
   * to allow for the fact that the handshake may take up to 30 seconds
   * itsself.  This prevents the connection from being removed during
   * a slow handshake.
   */
  return ticked + (YES == handshake ? 30.0 : 0.0);
}

- (void) timeout: (NSTimer*)timer
{
  NSTimeInterval	now = [NSDateClass timeIntervalSinceReferenceDate];
  NSTimeInterval	age = now - ticked;
  BOOL			shouldEnd = NO;

  if (age > conf->connectionTimeout)
    {
      if ([self processing] == NO)
	{
	  shouldEnd = YES;
	}
      else
	{
	  NSTimeInterval	e = (extended == 0.0) ? ticked : extended;

	  if (now - e > conf->connectionTimeout)
	    {
	      if (e == ticked)
		{
		  [self extend: 300.0];
		}
	      else
		{
		  [server _alert: @"%@ abort after %g seconds to process %@",
		    self, age, [self request]];
		  shouldEnd = YES;
		}
	    }
	}
    }

  if (YES == shouldEnd)
    {
      if (YES == conf->verbose)
	{
	  [server _log: @"Connection timed out - %@", self];
	}
      [server _endConnect: self];
    }
}

- (void) _didData: (NSData*)d
{
  NSString		*method = @"";
  NSString		*query = @"";
  NSString		*path = @"";
  NSString		*version = @"";
  GSMimeDocument	*doc;

  // Mark as having had I/O ... not idle.
  ticked = [NSDateClass timeIntervalSinceReferenceDate];

  if (parser == nil)
    {
      uint8_t		*bytes;
      NSUInteger	length;
      NSUInteger	pos;

      /*
       * If we are starting to read a new request, record the request
       * startup time.
       */
      if ([self requestDuration: ticked] == 0.0)
	{
	  [self setRequestStart: ticked];
	}

      /*
       * Add new data to any we already have and search for the end
       * of the initial request line.
       */
      [buffer appendData: d];
      bytes = [buffer mutableBytes];
      length = [buffer length];

      /*
       * Some buggy browsers/libraries add a CR-LF after POSTing data,
       * so if we are using a connection which has been kept alive,
       * we must eat up that initial white space.
       */
      while (length > 0 && isspace(bytes[0]))
        {
	  bytes++;
	  length--;
	}

      /* Try to find end of first line (the request line).
       */
      for (pos = 0; pos < length; pos++)
	{
	  if (bytes[pos] == '\n')
	    {
	      break;
	    }
	}

      /*
       * Attackers may try to send too much data in the hope of causing
       * a buffer overflow ... so we try to detect it here.
       */
      if (pos >= conf->maxRequestSize)
	{
	  [server _log: @"Request too long ... rejected"];
	  [self setShouldClose: YES];
	  [self setResult: @"HTTP/1.0 413 Request data too long"];
	  [nc removeObserver: self
			name: NSFileHandleReadCompletionNotification
		      object: handle];
	  [server _threadWrite: 
	    [@"HTTP/1.0 413 Request data too long\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]
	    to: handle];
	  return;
	}

      if (pos == length)
	{
	  /* Needs more data.
	   */
	  [server _threadReadFrom: handle];
	  return;
	}
      else
	{
	  NSUInteger	back = pos;
	  NSUInteger	start = 0;
	  NSUInteger	end;

	  /*
	   * Trim trailing whitespace from request line.
	   */
	  bytes[pos++] = '\0';
	  while (back > 0 && isspace(bytes[--back]))
	    {
	      bytes[back] = '\0';
	    }

	  /*
	   * Store the actual command string used.
	   */
	  [command release];
	  command = [NSStringClass alloc];
	  command = [command initWithUTF8String: (const char*)bytes];

	  /*
	   * Remove and store trailing HTTP version extension
	   */
	  while (back > 0 && !isspace(bytes[back]))
	    {
	      back--;
	    }
	  if (isspace(bytes[back])
	    && strncmp((char*)bytes + back + 1, "HTTP/", 5) == 0)
	    {
	      bytes[back] = '\0';
	      end = back + 6;
	      version
		= [NSStringClass stringWithUTF8String: (char*)bytes + end];
	      if ([version floatValue] < 1.1)
		{
		  [self setShouldClose: YES];	// Not persistent.
		}
	    }
	  else
	    {
	      back = strlen((const char*)bytes);
	      [self setSimple: YES];	// Old style simple request.
	      [self setShouldClose: YES];	// Not persistent.
	    }

	  /*
	   * Remove leading white space.
	   */
	  start = 0;
	  while (start < back && isspace(bytes[start]))
	    {
	      start++;
	    }

	  /*
	   * Extract method string as uppercase value.
	   */
	  end = start;
	  while (end < back && !isspace(bytes[end]))
	    {
	      if (islower(bytes[end]))
		{
		  bytes[end] = toupper(bytes[end]);
		}
	      end++;
	    }
	  bytes[end++] = '\0';
	  method = [NSStringClass stringWithUTF8String: (char*)bytes + start];

	  /*
	   * Extract path string.
	   */
	  start = end;
	  while (start < back && isspace(bytes[start]))
	    {
	      start++;
	    }
	  end = start;
	  while (end < back && bytes[end] != '?')
	    {
	      end++;
	    }
	  if (bytes[end] == '?')
	    {
	      /*
	       * Extract query string.
	       */
	      bytes[end++] = '\0';
	      query = [NSStringClass stringWithUTF8String: (char*)bytes + end];
	      if (query == nil)
		{
		  [server _log: @"Request query string not valid UTF8"];
		  [self setShouldClose: YES];	// Not persistent.
		  [self setResult: @"HTTP/1.0 413 Query string not UTF8"];
		  [server _threadWrite: 
		    [@"HTTP/1.0 413 Query string not UTF8\r\n\r\n"
		    dataUsingEncoding: NSASCIIStringEncoding]
		    to: handle];
		  return;
		}
	    }
	  else
	    {
	      bytes[end] = '\0';
	    }
	  path = [NSStringClass stringWithUTF8String: (char*)bytes + start];

	  if ([method isEqualToString: @"GET"] == NO
	    && [method isEqualToString: @"POST"] == NO)
	    {
	      [self setShouldClose: YES];	// Not persistent.
	      [self setResult: @"HTTP/1.0 501 Not Implemented"];
	      [server _threadWrite: 
		[@"HTTP/1.0 501 Not Implemented\r\n\r\n"
		dataUsingEncoding: NSASCIIStringEncoding]
		to: handle];
	      return;
	    }

	  /*
	   * Any left over data is passed to the mime parser.
	   */
	  if (pos < length)
	    {
	      memmove(bytes, &bytes[pos], length - pos);
	      [buffer setLength: length - pos];
	      d = AUTORELEASE(RETAIN(buffer));
	    }

	  parser = [GSMimeParser new];
	  [parser setIsHttp];
	  if ([method isEqualToString: @"POST"] == NO)
	    {
	      /* If it's not a POST, we don't need a body.
	       */
	      [parser setHeadersOnly];
	    }
	  [parser setDefaultCharset: @"utf-8"];

	  doc = [parser mimeDocument];

	  [doc setHeader: @"x-http-method"
		   value: method
	      parameters: nil];
	  [doc setHeader: @"x-http-path"
		   value: path
	      parameters: nil];
	  [doc setHeader: @"x-http-query"
		   value: query
	      parameters: nil];
	  [doc setHeader: @"x-http-scheme"
		   value: ((conf->secureProxy || ssl) ? @"https" : @"http")
	      parameters: nil];
	  [doc setHeader: @"x-http-version"
		   value: version
	      parameters: nil];

	  if (pos >= length)
	    {
	      // Needs more data.
	      [server _threadReadFrom: handle];
	      return;
	    }
	  // Fall through to parse remaining data with mime parser
	}
    }

  doc = [parser mimeDocument];
  method = [[doc headerNamed: @"x-http-method"] value];

  if ([self moreBytes: [d length]] > conf->maxBodySize)
    {
      [server _log: @"Request body too long ... rejected"];
      [self setShouldClose: YES];	// Not persistent.
      [self setResult: @"HTTP/1.0 413 Request body too long"];
      [server _threadWrite: 
	[@"HTTP/1.0 413 Request body too long\r\n\r\n"
	dataUsingEncoding: NSASCIIStringEncoding]
	to: handle];
      return;
    }
  else if ([parser parse: d] == NO)
    {
      if ([parser isComplete] == YES)
	{
	  [server _process1: self];
	}
      else
	{
	  [server _log: @"HTTP parse failure - %@", parser];
          [self setShouldClose: YES];	// Not persistent.
          [self setResult: @"HTTP/1.0 400 Bad Request"];
	  [server _threadWrite: 
            [@"HTTP/1.0 400 Bad Request\r\n\r\n"
            dataUsingEncoding: NSASCIIStringEncoding]
	    to: handle];
	  return;
	}
    }
  else if (([parser isComplete] == YES)
    || ([parser isInHeaders] == NO && ([method isEqualToString: @"GET"])))
    {
      [server _process1: self];
    }
  else
    {
      [server _threadReadFrom: handle];
    }
}

- (void) _didRead: (NSNotification*)notification
{
  NSDictionary		*dict;
  NSData		*d;

  NSAssert([notification object] == handle, NSInternalInconsistencyException);

  dict = [notification userInfo];
  d = [dict objectForKey: NSFileHandleNotificationDataItem];

  if ([d length] == 0)
    {
      if (parser == nil)
	{
	  if ([buffer length] == 0)
	    {
	      /*
	       * Don't log if we have already reset after handling
	       * a request.
	       * Don't log this in quiet mode as it could just be a
	       * test connection that we are ignoring.
	       */
	      if (NO == quiet && [self hasReset] == NO)
		{
		  [server _log: @"%@ read end-of-file in empty request", self];
		}
	    }
	  else
	    {
	      [server _log: @"%@ read end-of-file in partial request - %@",
		self, buffer];
	    }
	}
      else
	{
	  [server _log: @"%@ read end-of-file in incomplete request - %@",
	    self, [parser mimeDocument]];
	}
      [server _endConnect: self];
      return;
    }

  if (YES == conf->verbose && NO == quiet)
    {
      [server _log: @"Data read on %@ ... %@", self, d];
    }

  [self _didData: d];
}

- (void) _didWrite: (NSNotification*)notification
{
  NSAssert([notification object] == handle, NSInternalInconsistencyException);
  if ([self shouldClose] == YES)
    {
      [server _endConnect: self];
    }
  else
    {
      NSTimeInterval	now = [NSDateClass timeIntervalSinceReferenceDate];
      NSTimeInterval	t = [self requestDuration: now];

      if (t > 0.0)
	{
	  [self setRequestEnd: now];
	  if (NO == quiet && YES == conf->durations)
	    {
	      [server _log: @"%@ end of request (duration %g)", self, t];
	    }
	}
      else
	{
	  if (NO == quiet && YES == conf->durations)
	    {
	      [server _log: @"%@ reset", self];
	    }
	}
      if (NO == quiet)
	{
          [server _audit: self];
	}
      [self reset];
      [nc addObserver: self
	     selector: @selector(_didRead:)
		 name: NSFileHandleReadCompletionNotification
	       object: handle];
      [server _threadReadFrom: handle];	// Want another request.
    }
}

@end
