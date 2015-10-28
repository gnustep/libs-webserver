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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSHost.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSThread.h>

#define WEBSERVERINTERNAL       1

#import "WebServer.h"
#import "Internal.h"

@interface NSFileHandle (new)
- (BOOL) sslHandshakeEstablished: (BOOL*)result outgoing: (BOOL)direction;
@end

static Class NSDateClass = Nil;
static Class NSMutableDataClass = Nil;
static Class NSStringClass = Nil;
static Class GSMimeDocumentClass = Nil;
static Class WebServerRequestClass = Nil;
static Class WebServerResponseClass = Nil;

static char *
base64Escape(const uint8_t *src, NSUInteger len)
{
  uint8_t       *dst;
  NSUInteger	dIndex = 0;
  NSUInteger	sIndex;

  dst = (uint8_t*)malloc(((len + 2) / 3) * 4 + 5);
  dst[dIndex++] = '<';
  dst[dIndex++] = '[';
  for (sIndex = 0; sIndex < len; sIndex += 3)
    {
      static char b64[]
        = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      int	c0 = src[sIndex];
      int	c1 = (sIndex+1 < len) ? src[sIndex+1] : 0;
      int	c2 = (sIndex+2 < len) ? src[sIndex+2] : 0;

      dst[dIndex++] = b64[(c0 >> 2) & 077];
      dst[dIndex++] = b64[((c0 << 4) & 060) | ((c1 >> 4) & 017)];
      dst[dIndex++] = b64[((c1 << 2) & 074) | ((c2 >> 6) & 03)];
      dst[dIndex++] = b64[c2 & 077];
    }

   /* If len was not a multiple of 3, then we have encoded too
    * many characters.  Adjust appropriately.
    */
   if (sIndex == len + 1)
     {
       /* There were only 2 bytes in that last group */
       dst[dIndex - 1] = '=';
     }
   else if (sIndex == len + 2)
     {
       /* There was only 1 byte in that last group */
       dst[dIndex - 1] = '=';
       dst[dIndex - 2] = '=';
     }
  dst[dIndex++] = ']';
  dst[dIndex++] = '>';
  dst[dIndex] = '\0';
  return (char*)dst;
}

static char *
rawEscape(const uint8_t *src, NSUInteger len)
{
  uint8_t       *dst;
  NSUInteger    size = len + 1;
  NSUInteger    index;
  NSUInteger    pos;

  for (index = 0; index < len; index++)
    {
      uint8_t   b = src[index];

      if ('\n' == b) size++;
      else if ('\r' == b) size++;
      else if ('\t' == b) size++;
      else if ('\\' == b) size++;
      else if (b < 32 || b > 126) size += 3;
    }
  dst = (uint8_t*)malloc(size);
  for (pos = index = 0; index < len; index++)
    {
      uint8_t   b = src[index];

      if ('\n' == b)
        {
          dst[pos++] = '\\';
          dst[pos++] = 'n';
        }
      else if ('\r' == b)
        {
          dst[pos++] = '\\';
          dst[pos++] = 'r';
        }
      else if ('\t' == b)
        {
          dst[pos++] = '\\';
          dst[pos++] = 't';
        }
      else if ('\\' == b)
        {
          dst[pos++] = '\\';
          dst[pos++] = '\\';
        }
      else if (b < 32 || b > 126)
        {
          sprintf((char*)&dst[pos], "\\x%02x", b);
          pos += 4;
        }
      else
        {
          dst[pos++] = b;
        }
    }
  dst[pos] = '\0';
  return (char*)dst;
}

static void
debugRead(WebServer *server, WebServerConnection *c, NSData *data)
{
  int   	len = (int)[data length];
  const uint8_t	*ptr = (const uint8_t*)[data bytes];
  char	        *b64 = base64Escape(ptr, len);
  int           pos;

  for (pos = 0; pos < len; pos++)
    {
      if (0 == ptr[pos])
        {
          char  *esc = rawEscape(ptr, len);

          [server _log: @"Read for %@ of %d bytes (escaped) - '%s'\n%s",
            c, len, esc, b64]; 
          free(esc);
          free(b64);
          return;
        }
    }
  [server _log: @"Read for %@ of %d bytes - '%*.*s'\n%s",
    c, len, len, len, (const char*)ptr, b64]; 
  free(b64);
}

static void
debugWrite(WebServer *server, WebServerConnection *c, NSData *data)
{
  int   	len = (int)[data length];
  const uint8_t	*ptr = (const uint8_t*)[data bytes];
  char	        *b64 = base64Escape(ptr, len);
  int           pos;

  for (pos = 0; pos < len; pos++)
    {
      if (0 == ptr[pos])
        {
          char  *esc = rawEscape(ptr, len);

          [server _log: @"Write for %@ of %d bytes (escaped) - '%s'\n%s",
            c, len, esc, b64]; 
          free(esc);
          free(b64);
          return;
        }
    }
  [server _log: @"Write for %@ of %d bytes - '%*.*s'\n%s",
    c, len, len, len, (const char*)ptr, b64]; 
  free(b64);
}

@implementation	WebServerRequest

+ (void) initialize
{
  if (Nil == WebServerRequestClass)
    {
      WebServerRequestClass = [WebServerRequest class];
    }
}

- (id) copy
{
  return [self retain];
}

- (id) copyWithZone: (NSZone*)z
{
  return [self retain];
}

- (NSUInteger) hash
{
  return ((NSUInteger)self)>>2;
}

- (id) init
{
  Class c = [self class];

  [self release];
  [NSException raise: NSGenericException
              format: @"[%@-%@] illegal initialisation",
    NSStringFromClass(c), NSStringFromSelector(_cmd)];
  return nil;
}

- (BOOL) isEqual: (id)other
{
  return (other == self) ? YES : NO;
}

@end

@implementation	WebServerResponse

+ (void) initialize
{
  if (Nil == WebServerResponseClass)
    {
      WebServerResponseClass = [WebServerResponse class];
    }
}

- (id) copy
{
  return [self retain];
}

- (id) copyWithZone: (NSZone*)z
{
  return [self retain];
}

- (BOOL) foldHeaders
{
  return foldHeaders;
}

- (NSUInteger) hash
{
  return ((NSUInteger)self)>>2;
}

- (id) init
{
  Class c = [self class];

  [self release];
  [NSException raise: NSGenericException
              format: @"[%@-%@] illegal initialisation",
    NSStringFromClass(c), NSStringFromSelector(_cmd)];
  return nil;
}

- (id) initWithConnection: (WebServerConnection*)c
{
  NSAssert([c isKindOfClass: [WebServerConnection class]],
    NSInvalidArgumentException);
  if (nil != (self = [super init]))
    {
      webServerConnection = c;
      foldHeaders = [webServerConnection foldHeaders];
    }
  return self;
}

- (BOOL) isEqual: (id)other
{
  return (other == self) ? YES : NO;
}

- (BOOL) prepared
{
  return prepared;
}

- (void) setFoldHeaders: (BOOL)aFlag
{
  foldHeaders = (NO == aFlag) ? NO : YES;
}

- (void) setPrepared
{
  prepared = YES;
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
      GSMimeDocumentClass = [GSMimeDocument class];
      [WebServerRequest class];
      [WebServerResponse class];
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

  if (nil == command)
    {
      /* If we haven't read in a command, we don't actually have a request
       * to log (eg the connection is closing after a response or when the
       * remote end didn't send us a request).
       * We only generate an empty log to record the end of the connection
       * if in verbose mode or if there have been no requests.
       */
      if (NO == conf->verbose && requestCount > 0)
	{
	  return nil;
	}
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

  if (nil == address)
    {
      h = @"-";
    }
  else
    {
      h = address;	
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

  u = user;
  if (nil == u)
    {
      u = @"-";
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
  [handle closeFile];
  DESTROY(ioThread);
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
  DESTROY(user);
  DESTROY(nc);
  [super dealloc];
}

- (NSString*) description
{
  return [NSStringClass stringWithFormat:
    @"WebServerConnection: %"PRIxPTR" [%@]",
    [self identity], [self address]];
}

/* Must be called on the IO thread.
 */
- (void) end
{
  if ([NSThread currentThread] != ioThread->thread)
    {
      NSLog(@"Argh ... -end called on wrong thread");
      [self performSelector: @selector(end)
		   onThread: ioThread->thread
		 withObject: nil
	      waitUntilDone: YES];
    }
  else
    {
      NSFileHandle	*h;

      [handshakeTimer invalidate];
      handshakeTimer = nil;
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

      [self setExcess: nil];
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
	}
      /* Remove from the linked list we are in (if any).
       */
      [ioThread->threadLock lock];
      if (nil != owner)
	{
	  if (owner == ioThread->keepalives)
	    {
	      ioThread->keepaliveCount--;
	    }
	  GSLinkedListRemove(self, owner);
	}
      [ioThread->threadLock unlock];
      [server _endConnect: self];
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

- (BOOL) foldHeaders
{
  return conf->foldHeaders;
}

- (NSFileHandle*) handle
{
  return handle;
}

/* This must only be run from the I/O thread.
 */
- (void) handshake
{
  BOOL	ok;

  ok = [handle sslAccept];
  if (nil == owner)
    {
      return;	// Already ended
    }

  if (NO == ok)			// Reset time of last I/O
    {
      if (NO == quiet)
	{
	  [server _log: @"%@ SSL accept fail on (%@).", self, address];
	}
      [self end];
      return;
    }

  /* SSL handshake OK ... move to readwrite thread and record start time.
   */
  [ioThread->threadLock lock];
  ticked = [NSDateClass timeIntervalSinceReferenceDate];
  GSLinkedListRemove(self, owner);
  GSLinkedListInsertAfter(self, ioThread->readwrites,
    ioThread->readwrites->tail);
  [ioThread->threadLock unlock];

  [self run];
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
	     onThread: (IOThread*)t
		  for: (WebServer*)svr
	      address: (NSString*)adr
	       config: (WebServerConfig*)c
		quiet: (BOOL)q
		  ssl: (BOOL)s
	      refusal: (NSString*)r
{
  static NSUInteger	connectionIdentity = 0;

  if ((self = [super init]) != nil)
    {
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
      ioThread = [t retain];
      [ioThread->threadLock lock];
      if (YES == ssl)
	{
	  GSLinkedListInsertAfter(self, t->handshakes, t->handshakes->tail);
	}
      else
	{
	  GSLinkedListInsertAfter(self, t->readwrites, t->readwrites->tail);
	}
      [ioThread->threadLock unlock];
    }
  return self;
}

- (IOThread*) ioThread
{
  return ioThread;
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
  return  owner == ioThread->processing ? YES : NO;
}

- (BOOL) quiet
{
  return quiet;
}

- (WebServerRequest*) request
{
  return (WebServerRequest*)[parser mimeDocument];
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
  WebServerRequest      *r;

  hasReset = YES;
  responding = NO;
  simple = NO;
  hadHeader = NO;
  hadRequest = NO;
  incremental = NO;
  streaming = NO;
  chunked = NO;
  DESTROY(outBuffer);
  DESTROY(command);
  r = [self request];
  [server _setIncrementalBytes: 0 length: 0 forRequest: r];
  [server setUserInfo: nil forRequest: r];
  [response setWebServerConnection: nil];
  DESTROY(response);
  DESTROY(agent);
  DESTROY(result);
  DESTROY(user);
  byteCount = 0;
  bodyLength = 0;
  DESTROY(buffer);
  [self setRequestStart: 0.0];
  [self setParser: nil];
  [self setProcessing: NO];
}

- (void) respond: (NSData*)stream
{
  NSData	*data;

  ticked = [NSDateClass timeIntervalSinceReferenceDate];

  if (YES == streaming)
    {
      /* We are already streaming, so we just need to stream the new data
       * or to end streaming if there is no new data.
       */
      if (nil == stream)
        {
          /* We are stopping streaming.
           */
          streaming = NO;
          if (YES == chunked)
            {
              /* Terminate the chunked transfer encoding.
               */
              [outBuffer appendBytes: "0\r\n\r\n" length: 5];
            }
          chunked = NO;
          if (NO == responding)
            {
              if ([outBuffer length] > 0)
                {
                  /* There's still data to be written ... try to do it.
                   */
                  responding = YES;
                  [self performSelector: @selector(_doWrite:)
                               onThread: ioThread->thread
                             withObject: outBuffer
                          waitUntilDone: NO];
                }
              else
                {
                  /* We have finished streaming data, and the last write
                   * has already completed, so we fake another write
                   * completion notification to get the end of streaming
                   * cleanup done.
                   */
                  DESTROY(outBuffer);
                  [self _didWrite:
                    [NSNotification notificationWithName:
                      GSFileHandleWriteCompletionNotification
                      object: handle userInfo: nil]];
                }
            }
        }
      else
        {
          /* Continue streaming.
           */
          if (YES == conf->verbose && NO == quiet)
            {
              [server _log: @"Response continued %@ - %@", self, stream];
            }
          if (YES == chunked)
            {
              char      buf[16];

              sprintf(buf, "%"PRIXPTR"\r\n", [stream length]);
              [outBuffer appendBytes: buf length: strlen(buf)];
            }
          [outBuffer appendData: stream];
          if (NO == responding)
            {
              NSData    *data;

              responding = YES;
              data = [outBuffer copy];
              [outBuffer setLength: 0];
              [self performSelector: @selector(_doWrite:)
                           onThread: ioThread->thread
                         withObject: data
                      waitUntilDone: NO];
              [data release];
            }
        }
    }
  else
    {
      responding = YES;
      [self setProcessing: NO];
      if (NO == hadRequest)
        {
          /* We haven't actually read an entire request ... so we need to
           * drop the network connection or we would be out of sync trying
           * to read the next request.
           */
          [self setShouldClose: YES];
        }
      [response setHeader: @"content-transfer-encoding"
                    value: @"binary"
               parameters: nil];

      if (YES == simple)
        {
          /*
           * If we had a 'simple' request with no HTTP version, we must respond
           * with a 'simple' response ... just the raw data with no headers.
           */
          if (nil == stream)
            {
              data = [response convertToData];
            }
          else
            {
              streaming = YES;
              data = stream;
            }
          [self setResult: @""];
        } 
      else
        {
          NSMutableData	*out;
          NSMutableData	*raw;
          uint8_t	*buf;
          NSUInteger	len;
          NSUInteger	pos;
          NSUInteger	contentLength;
          NSEnumerator	*enumerator;
          GSMimeHeader	*hdr;
          NSString	*str;

          if (nil == stream)
            {
              if (YES == [response foldHeaders])
                {
                  raw = [response rawMimeData];
                }
              else
                {
                  raw = [response rawMimeData: YES foldedAt: 0];
                }
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
              [raw replaceBytesInRange: NSMakeRange(0, pos)
                             withBytes: 0
                                length: 0];
              data = raw;
            }
          else
            {
              data = stream;
              len = [data length] + 1024;
            }
          out = [NSMutableDataClass dataWithCapacity: len + 1024];
          [response deleteHeaderNamed: @"mime-version"];
          [response deleteHeaderNamed: @"content-length"];
          [response deleteHeaderNamed: @"content-transfer-encoding"];
          if (nil != stream)
            {
              [response setHeader: @"transfer-encoding"
                            value: @"chunked"
                       parameters: nil];
              streaming = YES;
              chunked = YES;
            }
          else
            {
              [response deleteHeaderNamed: @"transfer-encoding"];
            }

          if (NO == streaming)
            {
              if (0 == contentLength)
                {
                  [response deleteHeaderNamed: @"content-type"];
                }
              str = [NSStringClass stringWithFormat: @"%"PRIuPTR,
                contentLength];
              [response setHeader: @"content-length"
                            value: str
                       parameters: nil];
            }

          hdr = [response headerNamed: @"http"];
          if (hdr == nil)
            {
              const char	*s;

              if (0 == contentLength && NO == streaming)
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
              if ([s hasPrefix: @"HTTP/"] == NO)
                {
                  /* Old browser ... pre HTTP 1.0 ... always close.
                   */
                  [self setShouldClose: YES];
                  if (YES == chunked)
                    {
                      [response deleteHeaderNamed: @"transfer-encoding"];
                      chunked = NO;
                    }
                }
              else if ([[s substringFromIndex: 5] floatValue] < 1.1) 
                {
                  /* This is HTTP 1.0 ...
                   * we must be prepared to close the connection at once
                   * unless connection keep-alive has been set.
                   */
                  s = [[response headerNamed: @"connection"] value]; 
                  if (s == nil
                    || ([s caseInsensitiveCompare: @"keep-alive"]
                      != NSOrderedSame))
                    {
                      [self setShouldClose: YES];
                    }
                  if (YES == chunked)
                    {
                      [response deleteHeaderNamed: @"transfer-encoding"];
                      chunked = NO;
                    }
                }
              else if (NO == [self shouldClose])
                {
                  /* Modern browser ... we assume the connection will be
                   * kept open unless a 'close' has been set.
                   */
                  s = [[response headerNamed: @"connection"] value]; 
                  if (nil != s)
                    {
                      s = [s lowercaseString];
                      if ([s compare: @"close"] == NSOrderedSame)
                        {
                          [self setShouldClose: YES];
                        } 
                      else if ([s length] > 5)
                        {
                          NSEnumerator	*e;

                          e = [[s componentsSeparatedByString: @","]
                            objectEnumerator];
                          while (nil != (s = [e nextObject]))
                            {
                              s = [s stringByTrimmingSpaces];
                              if ([s compare: @"close"] == NSOrderedSame)
                                {
                                  [self setShouldClose: YES];
                                }
                            }
                        }
                    }
                }
            }

          /* We will close this connection if the maximum number of requests
           * or maximum request duration has been exceeded or if the keepalive
           * limit for the thread has been reached.
           */
          if (requests >= conf->maxConnectionRequests)
            {
              [self setShouldClose: YES];
            }
          else if (duration >= conf->maxConnectionDuration)
            {
              [self setShouldClose: YES];
            }
          else if (ioThread->keepaliveCount >= ioThread->keepaliveMax)
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
          if (YES == [response foldHeaders])
            {
              while ((hdr = [enumerator nextObject]) != nil)
                {
                  [out appendData: [hdr rawMimeData]];
                }
            }
          else
            {
              while ((hdr = [enumerator nextObject]) != nil)
                {
                  [out appendData:
                    [hdr rawMimeDataPreservingCase: NO foldedAt: 0]];
                }
            }
          [out appendBytes: "\r\n" length: 2];	// Terminate headers
          if ([data length] > 0)
            {
              if (YES == chunked)
                {
                  char      buf[16];

                  sprintf(buf, "%"PRIXPTR"\r\n", [raw length]);
                  [out appendBytes: buf length: strlen(buf)];
                }
              [out appendData: raw];
            }
          data = out;
        }

      [nc removeObserver: self
                    name: NSFileHandleReadCompletionNotification
                  object: handle];
      if (YES == conf->verbose && NO == quiet && NO == conf->logRawIO)
        {
          [server _log: @"Response %@ - %@", self, data];
        }
      [self performSelector: @selector(_doWrite:)
                   onThread: ioThread->thread
                 withObject: data
              waitUntilDone: NO];
    }
}

- (WebServerResponse*) response
{
  if (nil == response)
    {
      response = [WebServerResponse allocWithZone: NSDefaultMallocZone()];
      response = [response initWithConnection: self];
    }
  return response;
}

/* NB. This must be called from within the I/O thread.
 */
- (void) run
{
  if (nil == owner)
    {
      return;	// Already finished.
    }
  [nc addObserver: self
	 selector: @selector(_didWrite:)
	     name: GSFileHandleWriteCompletionNotification
	   object: handle];

  if (nil == result)
    {
      [nc addObserver: self
	     selector: @selector(_didRead:)
		 name: NSFileHandleReadCompletionNotification
	       object: handle];
      [self performSelector: @selector(_doRead)
		   onThread: ioThread->thread
		 withObject: nil
	      waitUntilDone: NO];
    }
  else
    {
      NSString	*body;

      [self setShouldClose: YES];

      if ([result rangeOfString: @" 503 "].location != NSNotFound)
	{
          /* We use 503 for a throughput/connection limit issue.
           * Tell the remote end to back-off and log an alert.
           */
	  [server _alert: result];
	  body = [result stringByAppendingString:
	    @"\r\nRetry-After: 120\r\n\r\n"];
	}
      else
	{
	  if (NO == quiet)
	    {
	      [server _log: result];
	    }
	  body = [result stringByAppendingString: @"\r\n\r\n"];
        }
      [self performSelector: @selector(_doWrite:)
		   onThread: ioThread->thread
		 withObject: [body dataUsingEncoding: NSASCIIStringEncoding]
	      waitUntilDone: NO];
    }
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
  [ioThread->threadLock lock];
  if (YES == aFlag)
    {
      if (owner != ioThread->processing)
	{
	  if (nil != owner)
	    {
	      GSLinkedListRemove(self, owner);
	    }
	  GSLinkedListInsertAfter(self, ioThread->processing,
	    ioThread->processing->tail);
	}
    }
  else
    {
      if (owner != ioThread->readwrites)
	{
	  if (nil != owner)
	    {
	      GSLinkedListRemove(self, owner);
	    }
	  GSLinkedListInsertAfter(self, ioThread->readwrites,
	    ioThread->readwrites->tail);
	}
    }
  [ioThread->threadLock unlock];
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

- (void) setTicked: (NSTimeInterval)t
{
  [ioThread->threadLock lock];
  ticked = t;
  if (nil != owner)
    {
      GSLinkedListMoveToTail(self, owner);
    }
  [ioThread->threadLock unlock];
}

- (void) setUser: (NSString*)aString
{
  ASSIGN(user, aString);
}

- (BOOL) shouldClose
{
  return shouldClose;
}

- (void) shutdown
{
  [ioThread->threadLock lock];
  [self setShouldClose: YES];
  if (owner == ioThread->keepalives
    || (NO == responding && owner == ioThread->readwrites))
    {
      /* We are waiting for an incoming request ... set zero timeout.
       */
      ticked = 0.0;
    }
  [ioThread->threadLock unlock];
}

- (BOOL) simple
{
  return simple;
}

/* NB. This must be called from the I/O thread.
 */
- (void) start
{
  NSHost	*host;

  if (YES == conf->reverse && nil == result)
    {
      host = [NSHost hostWithAddress: address];
      if (nil == host)
	{
	  result = @"HTTP/1.0 403 Bad client host";
	  [self setShouldClose: YES];
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
      if ([handle respondsToSelector:
	@selector(sslHandshakeEstablished:outgoing:)])
	{
	  handshakeRetry = 0.01;
	  handshakeTimer
	    = [NSTimer scheduledTimerWithTimeInterval: handshakeRetry
					       target: self
					     selector: @selector(_timeout:)
					     userInfo: nil
					      repeats: NO];
	}
      else
	{
	  [self handshake];
	}
    }
  else
    {
      [self run];
    }
}

- (NSString*) user
{
  NSString      *tmp;

  [ioThread->threadLock lock];
  tmp = RETAIN(user);
  [ioThread->threadLock unlock];
  return AUTORELEASE(tmp);
}

- (BOOL) verbose
{
  return conf->verbose;
}

#define PROCESS \
if (incremental > 0) \
  { \
    NSData        *d = [parser data]; \
    const void    *b = [d bytes]; \
    NSUInteger    l = [d length]; \
 \
    if (l > bodyLength) \
      { \
        NSUInteger buffered = [server _setIncrementalBytes: b + bodyLength \
                                                    length: l - bodyLength \
                                                forRequest: doc]; \
        bodyLength = l; \
        if (YES == hadRequest || buffered >= incremental) \
          { \
            [server _process1: self]; \
          } \
      } \
  } \
else if (YES == hadRequest) \
  { \
    [server _process1: self]; \
  }

- (void) _didData: (NSData*)d
{
  NSString		*method = @"";
  NSString		*query = @"";
  NSString		*path = @"";
  NSString		*version = @"";
  WebServerRequest	*doc = nil;

  // Mark as having had I/O ... not idle.
  ticked = [NSDateClass timeIntervalSinceReferenceDate];

  if (nil == parser)
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
      if (nil == buffer)
	{
	  buffer = [[NSMutableDataClass alloc] initWithCapacity: 1024];
	}
      [buffer appendData: d];
      bytes = [buffer mutableBytes];
      length = [buffer length];

      /* Some browsers/libraries add a CR-LF after POSTing data,
       * while others do not.
       * If we are using a connection which has been kept alive,
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
	  NSData	*data;

	  [server _log: @"%@ Request too long ... rejected", self];
	  [self setShouldClose: YES];
	  [self setResult: @"HTTP/1.0 413 Request data too long"];
	  [nc removeObserver: self
			name: NSFileHandleReadCompletionNotification
		      object: handle];
	  data = [@"HTTP/1.0 413 Request data too long\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding];
	  [self performSelector: @selector(_doWrite:)
		       onThread: ioThread->thread
		     withObject: data
		  waitUntilDone: NO];
	  return;
	}

      if (pos == length)
	{
	  /* Needs more data.
	   */
	  [self performSelector: @selector(_doRead)
		       onThread: ioThread->thread
		     withObject: nil
		  waitUntilDone: NO];
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
		  NSData	*data;

		  [server _log: @"%@ Request query string not valid UTF8",
		    self];
		  [self setShouldClose: YES];	// Not persistent.
		  [self setResult: @"HTTP/1.0 413 Query string not UTF8"];
		  data = [@"HTTP/1.0 413 Query string not UTF8\r\n\r\n"
		    dataUsingEncoding: NSASCIIStringEncoding];
		  [self performSelector: @selector(_doWrite:)
			       onThread: ioThread->thread
			     withObject: data
			  waitUntilDone: NO];
		  return;
		}
	    }
	  else
	    {
	      bytes[end] = '\0';
	    }
	  path = [NSStringClass stringWithUTF8String: (char*)bytes + start];

	  if (nil == [conf->permittedMethods member: method])
	    {
	      NSData	*data;

	      [self setShouldClose: YES];	// Not persistent.
	      [self setResult: @"HTTP/1.0 501 Method not implemented"];
	      data = [@"HTTP/1.0 501 method not implemented\r\n\r\n"
		dataUsingEncoding: NSASCIIStringEncoding];
	      [self performSelector: @selector(_doWrite:)
			   onThread: ioThread->thread
			 withObject: data
		      waitUntilDone: NO];
	      return;
	    }

	  /* Step past any trailing space in the request line.
            */
	  while (pos < length && isspace(bytes[pos]))
	    {
	      pos++;
	    }

	  /*
	   * Any left over data is passed to the mime parser.
	   */
	  if (pos < length)
	    {
	      memmove([buffer mutableBytes], bytes + pos, length - pos);
	      [buffer setLength: length - pos];
	      d = buffer;
	    }
	  else
	    {
	      d = nil;	// Need request body to parse
	    }

	  parser = [GSMimeParser new];
	  [parser setIsHttp];
	  if (NO == [method isEqualToString: @"POST"]
	    && NO == [method isEqualToString: @"PUT"])
	    {
	      /* If it's not a POST or PUT, we don't need a body.
	       */
	      [parser setHeadersOnly];
	    }
	  [parser setDefaultCharset: @"utf-8"];

	  doc = (WebServerRequest*)[parser mimeDocument];
          GSClassSwizzle(doc, WebServerRequestClass);

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
	      [self performSelector: @selector(_doRead)
			   onThread: ioThread->thread
			 withObject: nil
		      waitUntilDone: NO];
	      return;
	    }
	  // Fall through to parse remaining data with mime parser
	}
    }

  if (nil == doc)
    {
      doc = [self request];
    }
  method = [[doc headerNamed: @"x-http-method"] value];

  /* Abandon request if the total data read is too long.
   * NB.  If we are doing incremental parsing then no length is too great
   * and it's the responsibility of the higher level application to end
   * the request if too much has been read.
   */
  if ([self moreBytes: [d length]] > conf->maxBodySize && NO == incremental)
    {
      NSData	*data;

      [server _log: @"%@ Request body too long ... rejected", self];
      [self setShouldClose: YES];	// Not persistent.
      [self setResult: @"HTTP/1.0 413 Request body too long"];
      data = [@"HTTP/1.0 413 Request body too long\r\n\r\n"
	dataUsingEncoding: NSASCIIStringEncoding];
      [self performSelector: @selector(_doWrite:)
		   onThread: ioThread->thread
		 withObject: data
	      waitUntilDone: NO];
      return;
    }

  if (nil != d && [parser parse: d] == NO)
    {
      if (YES == (hadRequest = [parser isComplete]))
	{
          if (NO == hadHeader)
            {
              hadHeader = YES;
              incremental = [server _incremental: self];
            }
	  requestCount++;
	  [doc setHeader: @"x-webserver-completed"
                   value: @"YES"
              parameters: nil];
	  PROCESS
	}
      else
	{
	  NSData	*data;

	  [server _log: @"%@ HTTP parse failure - %@", self, parser];
          [self setShouldClose: YES];	// Not persistent.
          [self setResult: @"HTTP/1.0 400 Bad Request"];
          data = [@"HTTP/1.0 400 Bad Request\r\n\r\n"
            dataUsingEncoding: NSASCIIStringEncoding];
	  [self performSelector: @selector(_doWrite:)
		       onThread: ioThread->thread
		     withObject: data
		  waitUntilDone: NO];
	}
      return;
    }

  if (YES == (hadRequest = [parser isComplete]))
    {
      /* Parsing complete ... pass request on.
       */
      if (NO == hadHeader)
        {
          hadHeader = YES;
          incremental = [server _incremental: self];
        }
      requestCount++;
      [doc setHeader: @"x-webserver-completed"
               value: @"YES"
          parameters: nil];
      PROCESS
      return;
    }

  if (NO == [parser isInHeaders])
    {
      if (NO == hadHeader)
        {
          hadHeader = YES;
          incremental = [server _incremental: self];
          if (YES == [method isEqualToString: @"GET"])
            {
              /* A GET request has no body ... pass it on now.
               */
              hadRequest = YES;
              requestCount++;
              [doc setHeader: @"x-webserver-completed"
                       value: @"YES"
                  parameters: nil];
              PROCESS
              return;
            }
        }
      PROCESS
    }

  [self performSelector: @selector(_doRead)
               onThread: ioThread->thread
             withObject: nil
          waitUntilDone: NO];
}

- (void) _didRead: (NSNotification*)notification
{
  NSDictionary		*dict;
  NSData		*d;
  NSTimeInterval	now;

  if ([notification object] != handle)
    {
      return;	// Must be an old notification
    }

  if (owner == ioThread->keepalives)
    {
      [ioThread->threadLock lock];
      if (owner == ioThread->keepalives)
	{
	  ioThread->keepaliveCount--;
	  GSLinkedListRemove(self, owner);
	  GSLinkedListInsertAfter(self, ioThread->readwrites,
	    ioThread->readwrites->tail);
	}
      [ioThread->threadLock unlock];
    }

  now = [NSDateClass timeIntervalSinceReferenceDate];
  [self setTicked: now];

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
      [self end];
      return;
    }

  if (YES == conf->logRawIO && NO == quiet)
    {
      debugRead(server, self, d);
    }
  [self _didData: d];
}

- (void) _didWrite: (NSNotification*)notification
{
  NSTimeInterval	now;
  NSString		*err;

  if ([notification object] != handle)
    {
      return;	// Must be an old notification
    }
  now = [NSDateClass timeIntervalSinceReferenceDate];
  [self setTicked: now];

  responding = NO;
  err = [[notification userInfo] objectForKey: GSFileHandleNotificationError];
  if ([self shouldClose] == YES && nil == outBuffer)
    {
      [self end];
      return;
    }
  else if (nil == err)
    {
      if (nil == outBuffer)
        {
          NSTimeInterval	t = [self requestDuration: now];
          NSData		*more;

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

          [self _keepalive];

          more = [self excess];
          [nc addObserver: self
                 selector: @selector(_didRead:)
                     name: NSFileHandleReadCompletionNotification
                   object: handle];
          if (nil != more)
            {
              /* Use pipelined data to start new request.
               */
              [more retain];
              [self setExcess: nil];
              [self _didData: more];
              [more release];
            }
          else
            {
              /* Start reading a new request.
               */
              [self performSelector: @selector(_doRead)
                           onThread: ioThread->thread
                         withObject: nil
                      waitUntilDone: NO];
            }
        }
      else
        {
          /* We are streaming data ... if there is any ready we write it now,
           * otherwise the connection becomes idle until more data is added.
           */
          if ([outBuffer length] > 0)
            {
              NSData    *data;

              if (YES == streaming)
                {
                  data = [outBuffer copy];
                  [outBuffer setLength: 0];
                }
              else
                {
                  /* Streaming is ended ... write the last data and then we
                   * will be done.
                   */
                  data = outBuffer;
                  outBuffer = nil;
                }
              responding = YES;
              [self performSelector: @selector(_doWrite:)
                           onThread: ioThread->thread
                         withObject: data
                      waitUntilDone: NO];
              [data release];
            }
        }
    }
  else
    {
      if (NO == quiet)
	{
	  [server _log: @"%@ %@", self, err];
	}
      [self end];
      return;
    }
}

/* This method must only ever be called from the I/O thread.
 * It starts an asynchronous read in that thread, but only if the handle
 * still exists (is not nil).
 */
- (void) _doRead
{
  [handle readInBackgroundAndNotify];
}

/* This method must only ever be called from the I/O thread.
 * It starts an asynchronous write in that thread, but only if the handle
 * still exists (is not nil).
 */
- (void) _doWrite: (NSData*)d
{
  if (YES == conf->logRawIO && NO == quiet)
    {
      debugWrite(server, self, d);
   }
  [handle writeInBackgroundAndNotify: d];
}

- (void) _keepalive
{
  [ioThread->threadLock lock];
  if (owner != ioThread->keepalives)
    {
      GSLinkedListRemove(self, owner);
      GSLinkedListInsertAfter(self, ioThread->keepalives,
	ioThread->keepalives->tail);
      ioThread->keepaliveCount++;
    }
  [ioThread->threadLock unlock];
}

/* Called to try an ssl handshake.
 */
- (void) _timeout: (NSTimer*)t
{
  BOOL	established;

  handshakeTimer = nil;
  if (YES == [handle sslHandshakeEstablished: &established outgoing: NO])
    {
      if (YES == established)
	{
	  [self run];
	}
      else
	{
	  [self end];
	}
    }
  else if (ioThread->handshakes == owner)
    {
      handshakeRetry *= 2.0;
      if (handshakeRetry > 0.5)
	{
	  handshakeRetry = 0.01;
	}
      handshakeTimer
	= [NSTimer scheduledTimerWithTimeInterval: handshakeRetry
					   target: self
					 selector: @selector(_timeout:)
					 userInfo: nil
					  repeats: NO];
    }
}

@end
