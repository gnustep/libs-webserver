/** 
   Copyright (C) 2004 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	June 2004
   
   This file is part of the WebServer Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Date$ $Revision$
   */ 

#include <Foundation/Foundation.h>
#include "WebServer.h"

@interface	WebServerConnection : NSObject
{
  NSString		*address;	// Client address
  NSString		*command;	// Command sent by client
  NSString		*agent;		// User-Agent header
  NSString		*result;	// Result sent back
  NSFileHandle		*handle;
  GSMimeParser		*parser;
  NSMutableData		*buffer;
  unsigned		byteCount;
  unsigned		identity;
  NSTimeInterval	ticked;
  NSTimeInterval	requestStart;
  NSTimeInterval	connectionStart;
  BOOL			processing;
  BOOL			shouldEnd;
  BOOL			hasReset;
  BOOL			simple;
}
- (NSString*) address;
- (NSString*) audit;
- (NSMutableData*) buffer;
- (NSTimeInterval) connectionDuration: (NSTimeInterval)now;
- (NSFileHandle*) handle;
- (BOOL) hasReset;
- (unsigned) identity;
- (unsigned) moreBytes: (unsigned)count;
- (GSMimeParser*) parser;
- (BOOL) processing;
- (GSMimeDocument*) request;
- (NSTimeInterval) requestDuration: (NSTimeInterval)now;
- (void) reset;
- (void) setAddress: (NSString*)aString;
- (void) setAgent: (NSString*)aString;
- (void) setBuffer: (NSMutableData*)aBuffer;
- (void) setCommand: (NSString*)aString;
- (void) setConnectionStart: (NSTimeInterval)when;
- (void) setHandle: (NSFileHandle*)aHandle;
- (void) setParser: (GSMimeParser*)aParser;
- (void) setProcessing: (BOOL)aFlag;
- (void) setRequestStart: (NSTimeInterval)when;
- (void) setResult: (NSString*)aString;
- (void) setShouldEnd: (BOOL)aFlag;
- (void) setSimple: (BOOL)aFlag;
- (void) setTicked: (NSTimeInterval)when;
- (BOOL) shouldEnd;
- (BOOL) simple;
- (NSTimeInterval) ticked;
@end

@implementation	WebServerConnection
- (NSString*) address
{
  return address;
}

- (NSString*) audit
{
  NSString	*h = (address == nil) ? (id)@"-" : (id)address;	
  NSString	*c = (command == nil) ? (id)@"-" : (id)command;	
  NSString	*a = (agent == nil) ? (id)@"-" : (id)agent;	
  NSString	*r = (result == nil) ? (id)@"-" : (id)result;	
  NSDate	*d;

  if (requestStart == 0.0)
    {
      d = [NSDate date];
    }
  else
    {
      d = [NSDate dateWithTimeIntervalSinceReferenceDate: requestStart];
    }
  return [NSString stringWithFormat: @"%@ [%@] \"%@\"; \"%@\"; \"%@\"",
    h, d, c, a, r];
}

- (NSMutableData*) buffer
{
  return buffer;
}

- (void) dealloc
{
  [handle closeFile];
  DESTROY(address);
  DESTROY(buffer);
  DESTROY(handle);
  DESTROY(parser);
  DESTROY(command);
  DESTROY(agent);
  DESTROY(result);
  [super dealloc];
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"WebServerConnection: %08x [%@] ",
    [self identity], [self address]];
}

- (NSFileHandle*) handle
{
  return handle;
}

- (BOOL) hasReset
{
  return hasReset;
}

- (unsigned) identity
{
  return identity;
}

- (id) init
{
  static unsigned	connectionIdentity = 0;

  identity = ++connectionIdentity;
  requestStart = 0.0;
  return self;
}

- (unsigned) moreBytes: (unsigned)count
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

- (void) reset
{
  hasReset = YES;
  simple = NO;
  DESTROY(command);
  DESTROY(agent);
  DESTROY(result);
  [self setRequestStart: 0.0];
  [self setBuffer: [NSMutableData dataWithCapacity: 1024]];
  [self setParser: nil];
  [self setProcessing: NO];
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

- (void) setBuffer: (NSMutableData*)aBuffer
{
  ASSIGN(buffer, aBuffer);
}

- (void) setCommand: (NSString*)aString
{
  ASSIGN(command, aString);
}

- (void) setConnectionStart: (NSTimeInterval)when
{
  connectionStart = when;
}

- (void) setHandle: (NSFileHandle*)aHandle
{
  ASSIGN(handle, aHandle);
}

- (void) setParser: (GSMimeParser*)aParser
{
  ASSIGN(parser, aParser);
}

- (void) setProcessing: (BOOL)aFlag
{
  processing = aFlag;
}

- (void) setRequestStart: (NSTimeInterval)when
{
  requestStart = when;
}

- (void) setResult: (NSString*)aString
{
  ASSIGN(result, aString);
}

- (void) setShouldEnd: (BOOL)aFlag
{
  shouldEnd = aFlag;
}

- (void) setSimple: (BOOL)aFlag
{
  simple = aFlag;
}

- (void) setTicked: (NSTimeInterval)when
{
  ticked = when;
}

- (BOOL) shouldEnd
{
  return shouldEnd;
}

- (BOOL) simple
{
  return simple;
}

- (NSTimeInterval) ticked
{
  return ticked;
}
@end

@interface	WebServer (Private)
- (void) _alert: (NSString*)fmt, ...;
- (void) _audit: (WebServerConnection*)connection;
- (void) _completedWithResponse: (GSMimeDocument*)response;
- (void) _didConnect: (NSNotification*)notification;
- (void) _didRead: (NSNotification*)notification;
- (void) _didWrite: (NSNotification*)notification;
- (void) _endConnection: (WebServerConnection*)connection;
- (void) _log: (NSString*)fmt, ...;
- (void) _process: (WebServerConnection*)connection;
- (void) _timeout: (NSTimer*)timer;
@end

@implementation	WebServer

- (BOOL) accessRequest: (GSMimeDocument*)request
	      response: (GSMimeDocument*)response
{
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  NSDictionary		*conf = [defs dictionaryForKey: @"WebServerAccess"];
  NSString		*path = [[request headerNamed: @"x-http-path"] value];
  NSDictionary		*access = nil;
  NSString		*stored;
  NSString		*username;
  NSString		*password;

  while (access == nil)
    {
      access = [conf objectForKey: path];
      if ([access isKindOfClass: [NSDictionary class]] == NO)
	{
	  NSRange	r;

	  r = [path rangeOfString: @"/" options: NSBackwardsSearch];
	  if (r.length > 0)
	    {
	      path = [path substringToIndex: r.location];
	    }
	  else
	    {
	      return YES;	// No access dictionary - permit access
	    }
	}
    }

  username = [[request headerNamed: @"x-http-username"] value];
  password = [[request headerNamed: @"x-http-password"] value];
  if ([access objectForKey: @"Users"] != nil)
    {
      NSDictionary	*users = [access objectForKey: @"Users"];

      stored = [users objectForKey: username];
    }

  if (username == nil || password == nil || [password isEqual: stored] == NO)
    {
      NSString	*realm = [access objectForKey: @"Realm"];
      NSString	*auth;

      auth = [NSString stringWithFormat: @"Basic realm=\"%@\"", realm];

      /*
       * Return status code 401 (Aunauthorised)
       */
      [response setHeader: @"http"
		    value: @"HTTP/1.1 401 Unauthorised"
	       parameters: nil];
      [response setHeader: @"WWW-authenticate"
		    value: auth
	       parameters: nil];

      [response setContent:
@"<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
@"<html><head><title>401 Authorization Required</title></head><body>\n"
@"<h1>Authorization Required</h1>\n"
@"<p>This server could not verify that you "
@"are authorized to access the resource "
@"requested.  Either you supplied the wrong "
@"credentials (e.g., bad password), or your "
@"browser doesn't understand how to supply "
@"the credentials required.</p>\n"
@"</body></html>\n"
	type: @"text/html"];

      return NO;
    }
  else
    {
      return YES;	// OK to access
    }
}

- (void) completedWithResponse: (GSMimeDocument*)response
{
  static NSArray	*modes = nil;

  if (modes == nil)
    {
      id	objs[1];

      objs[0] = NSDefaultRunLoopMode;
      modes = [[NSArray alloc] initWithObjects: objs count: 1];
    }
  [self performSelectorOnMainThread: @selector(_completedWithResponse:)
			 withObject: response
		      waitUntilDone: NO
			      modes: modes];
}

- (void) dealloc
{
  if (_ticker != nil)
    {
      [_ticker invalidate];
      _ticker = nil;
    }
  [self setPort: nil secure: nil];
  DESTROY(_nc);
  DESTROY(_root);
  DESTROY(_quiet);
  DESTROY(_hosts);
  DESTROY(_perHost);
  if (_connections != 0)
    {
      NSFreeMapTable(_connections);
      _connections = 0;
    }
  if (_processing != 0)
    {
      NSFreeMapTable(_processing);
      _processing = 0;
    }
  [super dealloc];
}

static unsigned
unescapeData(const unsigned char* bytes, unsigned length, unsigned char *buf)
{
  unsigned int	to = 0;
  unsigned int	from = 0;

  while (from < length)
    {
      unsigned char	c = bytes[from++];

      if (c == '+')
	{
	  c = ' ';
	}
      else if (c == '%' && from < length - 1)
	{
	  unsigned char	tmp;

	  c = 0;
	  tmp = bytes[from++];
	  if (tmp <= '9' && tmp >= '0')
	    {
	      c = tmp - '0';
	    }
	  else if (tmp <= 'F' && tmp >= 'A')
	    {
	      c = tmp + 10 - 'A';
	    }
	  else if (tmp <= 'f' && tmp >= 'a')
	    {
	      c = tmp + 10 - 'a';
	    }
	  else
	    {
	      c = 0;
	    }
	  c <<= 4;
	  tmp = bytes[from++];
	  if (tmp <= '9' && tmp >= '0')
	    {
	      c += tmp - '0';
	    }
	  else if (tmp <= 'F' && tmp >= 'A')
	    {
	      c += tmp + 10 - 'A';
	    }
	  else if (tmp <= 'f' && tmp >= 'a')
	    {
	      c += tmp + 10 - 'a';
	    }
	  else
	    {
	      c = 0;
	    }
	}
      buf[to++] = c;
    }
  return to;
}

- (unsigned) decodeURLEncodedForm: (NSData*)data
			     into: (NSMutableDictionary*)dict
{
  const unsigned char	*bytes = (const unsigned char*)[data bytes];
  unsigned		length = [data length];
  unsigned		pos = 0;
  unsigned		fields = 0;

  while (pos < length)
    {
      unsigned int	keyStart = pos;
      unsigned int	keyEnd;
      unsigned int	valStart;
      unsigned int	valEnd;
      unsigned char	*buf;
      unsigned int	buflen;
      BOOL		escape = NO;
      NSData		*d;
      NSString		*k;
      NSMutableArray	*a;

      while (pos < length && bytes[pos] != '&')
	{
	  pos++;
	}
      valEnd = pos;
      if (pos < length)
	{
	  pos++;	// Step past '&'
	}

      keyEnd = keyStart;
      while (keyEnd < pos && bytes[keyEnd] != '=')
	{
	  if (bytes[keyEnd] == '%' || bytes[keyEnd] == '+')
	    {
	      escape = YES;
	    }
	  keyEnd++;
	}

      if (escape == YES)
	{
	  buf = NSZoneMalloc(NSDefaultMallocZone(), keyEnd - keyStart);
	  buflen = unescapeData(&bytes[keyStart], keyEnd - keyStart, buf);
	  d = [[NSData alloc] initWithBytesNoCopy: buf
					   length: buflen
				     freeWhenDone: YES];
	}
      else
	{
	  d = [[NSData alloc] initWithBytesNoCopy: (void*)&bytes[keyStart]
					   length: keyEnd - keyStart
				     freeWhenDone: NO];
	}
      k = [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding];
      if (k == nil)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"Bad UTF-8 form data (key of field %d)", fields];
	}
      RELEASE(d);

      valStart = keyEnd;
      if (valStart < pos)
	{
	  valStart++;	// Step past '='
	}
      if (valStart < valEnd)
	{
	  buf = NSZoneMalloc(NSDefaultMallocZone(), valEnd - valStart);
	  buflen = unescapeData(&bytes[valStart], valEnd - valStart, buf);
	  d = [[NSData alloc] initWithBytesNoCopy: buf
					   length: buflen
				     freeWhenDone: YES];
	}
      else
	{
	  d = [NSData new];
	}
      a = [dict objectForKey: k];
      if (a == nil)
	{
	  a = [[NSMutableArray alloc] initWithCapacity: 1];
	  [dict setObject: a forKey: k];
	  RELEASE(a);
	}
      [a addObject: d];
      RELEASE(d);
      RELEASE(k);
      fields++;
    }
  return fields;
}

static NSMutableData*
escapeData(const unsigned char* bytes, unsigned length, NSMutableData *d)
{
  unsigned char	*dst;
  unsigned int	spos = 0;
  unsigned int	dpos = [d length];

  [d setLength: dpos + 3 * length];
  dst = (unsigned char*)[d mutableBytes];
  while (spos < length)
    {
      unsigned char	c = bytes[spos++];
      unsigned int	hi;
      unsigned int	lo;

      switch (c)
	{
	  case ',':
	  case ';':
	  case '"':
	  case '\'':
	  case '&':
	  case '=':
	  case '(':
	  case ')':
	  case '<':
	  case '>':
	  case '?':
	  case '#':
	  case '{':
	  case '}':
	  case '%':
	  case ' ':
	  case '+':
	    dst[dpos++] = '%';
	    hi = (c & 0xf0) >> 4;
	    dst[dpos++] = (hi > 9) ? 'A' + hi - 10 : '0' + hi;
	    lo = (c & 0x0f);
	    dst[dpos++] = (lo > 9) ? 'A' + lo - 10 : '0' + lo;
	    break;

	  default:
	    if (c < ' ' || c > 127)
	      {
		dst[dpos++] = '%';
		hi = (c & 0xf0) >> 4;
		dst[dpos++] = (hi > 9) ? 'A' + hi - 10 : '0' + hi;
		lo = (c & 0x0f);
		dst[dpos++] = (lo > 9) ? 'A' + lo - 10 : '0' + lo;
	      }
	    else
	      {
		dst[dpos++] = c;
	      }
	    break;
	}
    }
  [d setLength: dpos];
  return d;
}

- (unsigned) encodeURLEncodedForm: (NSDictionary*)dict
			     into: (NSMutableData*)data
{
  CREATE_AUTORELEASE_POOL(arp);
  NSEnumerator		*keyEnumerator;
  id			key;
  unsigned		valueCount = 0;
  NSMutableData		*md = [NSMutableData dataWithCapacity: 100];

  keyEnumerator = [dict keyEnumerator];
  while ((key = [keyEnumerator nextObject]) != nil)
    {
      id		values = [dict objectForKey: key];
      NSData		*keyData;
      NSEnumerator	*valueEnumerator;
      id		value;

      if ([key isKindOfClass: [NSData class]] == YES)
	{
	  keyData = key;
	}
      else
	{
	  key = [key description];
	  keyData = [key dataUsingEncoding: NSUTF8StringEncoding];
	}
      [md setLength: 0];
      escapeData([keyData bytes], [keyData length], md);
      keyData = md;

      if ([values isKindOfClass: [NSArray class]] == NO)
        {
	  values = [NSArray arrayWithObject: values];
	}

      valueEnumerator = [values objectEnumerator];

      while ((value = [valueEnumerator nextObject]) != nil)
	{
	  NSData	*valueData;

	  if ([data length] > 0)
	    {
	      [data appendBytes: "&" length: 1];
	    }
	  [data appendData: keyData];
	  [data appendBytes: "=" length: 1];
	  if ([value isKindOfClass: [NSData class]] == YES)
	    {
	      valueData = value;
	    }
	  else
	    {
	      value = [value description];
	      valueData = [value dataUsingEncoding: NSUTF8StringEncoding];
	    }
	  escapeData([valueData bytes], [valueData length], data);
	  valueCount++;
	}
    }
  RELEASE(arp);
  return valueCount;
}

- (NSString*) description
{
  return [NSString stringWithFormat:
    @"%@ on %@(%@), %u of %u connections active,"
    @" %u ended, %u requests, listening: %@",
    [super description], _port, ([self isSecure] ? @"https" : @"http"),
    NSCountMapTable(_connections),
    _maxConnections, _handled, _requests, _accepting == YES ? @"yes" : @"no"];
}

- (id) init
{
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];

  _hosts = RETAIN([defs arrayForKey: @"WebServerHosts"]);
  _quiet = RETAIN([defs arrayForKey: @"WebServerQuiet"]);
  _nc = RETAIN([NSNotificationCenter defaultCenter]);
  _connectionTimeout = 30.0;
  _maxPerHost = 32;
  _maxConnections = 128;
  _maxBodySize = 8*1024;
  _maxRequestSize = 4*1024*1024;
  _substitutionLimit = 4;
  _connections = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
    NSObjectMapValueCallBacks, 0);
  _processing = NSCreateMapTable(NSObjectMapKeyCallBacks,
    NSObjectMapValueCallBacks, 0);
  _perHost = [NSCountedSet new];
  _ticker = [NSTimer scheduledTimerWithTimeInterval: 0.8
					     target: self
					   selector: @selector(_timeout:)
					   userInfo: 0
					    repeats: YES];
  return self;
}

- (BOOL) isSecure
{
  if (_sslConfig == nil)
    {
      return NO;
    }
  return YES;
}

- (BOOL) produceResponse: (GSMimeDocument*)aResponse
	  fromStaticPage: (NSString*)aPath
		   using: (NSDictionary*)map
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString	*path = (_root == nil) ? (id)@"" : (id)_root;
  NSString	*ext = [aPath pathExtension];
  NSString	*type;
  NSString	*str;
  id		data;
  NSFileManager	*mgr;
  BOOL		string = NO;
  BOOL		result = YES;

  if (map == nil)
    {
      static NSDictionary	*defaultMap = nil;

      if (defaultMap == nil)
	{
	  defaultMap = [[NSDictionary alloc] initWithObjectsAndKeys:
	    @"image/gif", @"gif",
	    @"image/png", @"png",
	    @"image/jpeg", @"jpeg",
	    @"text/html", @"html",
	    @"text/plain", @"txt",
	    @"text/xml", @"xml",
	    nil];
	}
      map = defaultMap;
    }

  type = [map objectForKey: ext]; 
  if (type == nil)
    {
      type = [map objectForKey: [ext lowercaseString]]; 
    }
  if (type == nil)
    {
      type = @"application/octet-stream";
    }
  string = [type hasPrefix: @"text/"];

  path = [path stringByAppendingString: @"/"];
  str = [path stringByStandardizingPath];
  path = [path stringByAppendingPathComponent: aPath];
  path = [path stringByStandardizingPath];
  mgr = [NSFileManager defaultManager];
  if ([path hasPrefix: str] == NO)
    {
      [self _log: @"Illegal static page '%@' ('%@')", aPath, path];
      result = NO;
    }
  else if ([mgr isReadableFileAtPath: path] == NO)
    {
      [self _log: @"Can't read static page '%@' ('%@')", aPath, path];
      result = NO;
    }
  else if (string == YES
    && (data = [NSString stringWithContentsOfFile: path]) == nil)
    {
      [self _log: @"Failed to load string '%@' ('%@')", aPath, path];
      result = NO;
    }
  else if (string == NO
    && (data = [NSData dataWithContentsOfFile: path]) == nil)
    {
      [self _log: @"Failed to load data '%@' ('%@')", aPath, path];
      result = NO;
    }
  else
    {
      [aResponse setContent: data type: type name: nil];
    }
  DESTROY(arp);
  return result;
}

- (BOOL) produceResponse: (GSMimeDocument*)aResponse
	    fromTemplate: (NSString*)aPath
		   using: (NSDictionary*)map
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString	*path = (_root == nil) ? (id)@"" : (id)_root;
  NSString	*str;
  NSFileManager	*mgr;
  BOOL		result;

  path = [path stringByAppendingString: @"/"];
  str = [path stringByStandardizingPath];
  path = [path stringByAppendingPathComponent: aPath];
  path = [path stringByStandardizingPath];
  mgr = [NSFileManager defaultManager];
  if ([path hasPrefix: str] == NO)
    {
      [self _log: @"Illegal template '%@' ('%@')", aPath, path];
      result = NO;
    }
  else if ([mgr isReadableFileAtPath: path] == NO)
    {
      [self _log: @"Can't read template '%@' ('%@')", aPath, path];
      result = NO;
    }
  else if ((str = [NSString stringWithContentsOfFile: path]) == nil)
    {
      [self _log: @"Failed to load template '%@' ('%@')", aPath, path];
      result = NO;
    }
  else
    {
      NSMutableString	*m = [NSMutableString stringWithCapacity: [str length]];

      result = [self substituteFrom: str
			      using: map
			       into: m
			      depth: 0];
      if (result == YES)
	{
	  [aResponse setContent: m type: @"text/html" name: nil];
	  [[aResponse headerNamed: @"content-type"] setParameter: @"utf-8"
							  forKey: @"charset"];
	}
    }
  DESTROY(arp);
  return result;
}

- (NSMutableDictionary*) parameters: (GSMimeDocument*)request
{
  NSMutableDictionary	*params;
  NSString		*str = [[request headerNamed: @"x-http-query"] value];
  NSData		*data;

  params = [NSMutableDictionary dictionaryWithCapacity: 32];
  if ([str length] > 0)
    {
      data = [str dataUsingEncoding: NSASCIIStringEncoding];
      [self decodeURLEncodedForm: data into: params];
    }

  str = [[request headerNamed: @"content-type"] value];
  if ([str isEqualToString: @"application/x-www-form-urlencoded"] == YES)
    {
      data = [request convertToData];
      [self decodeURLEncodedForm: data into: params];
    }
  else if ([str isEqualToString: @"multipart/form-data"] == YES)
    {
      NSArray	*contents = [request content];
      unsigned	count = [contents count];
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  GSMimeDocument	*doc = [contents objectAtIndex: i];
	  GSMimeHeader		*hdr = [doc headerNamed: @"content-type"];
	  NSString		*k = [hdr parameterForKey: @"name"];

	  if (k == nil)
	    {
	      hdr = [doc headerNamed: @"content-disposition"];
	      k = [hdr parameterForKey: @"name"];
	    }
	  if (k != nil)
	    {
	      NSMutableArray	*a;

	      a = [params objectForKey: k];
	      if (a == nil)
		{
		  a = [[NSMutableArray alloc] initWithCapacity: 1];
		  [params setObject: a forKey: k];
		  RELEASE(a);
		}
	      [a addObject: [doc convertToData]];
	    }
	}
    }

  return params;
}

- (NSData*) parameter: (NSString*)name
		   at: (unsigned)index
		 from: (NSDictionary*)params
{
  NSArray	*a = [params objectForKey: name];

  if (a == nil)
    {
      NSEnumerator	*e = [params keyEnumerator];
      NSString		*k;

      while ((k = [e nextObject]) != nil)
	{
	  if ([k caseInsensitiveCompare: name] == NSOrderedSame)
	    {
	      a = [params objectForKey: k];
	      break;
	    }
	}
    }
  if (index >= [a count])
    {
      return nil;
    }
  return [a objectAtIndex: index];
}

- (NSData*) parameter: (NSString*)name from: (NSDictionary*)params
{
  return [self parameter: name at: 0 from: params];
}

- (NSString*) parameterString: (NSString*)name
			   at: (unsigned)index
			 from: (NSDictionary*)params
{
  return [self parameterString: name at: index from: params charset: nil];
}

- (NSString*) parameterString: (NSString*)name
			   at: (unsigned)index
			 from: (NSDictionary*)params
		      charset: (NSString*)charset
{
  NSData	*d = [self parameter: name at: index from: params];
  NSString	*s = nil;

  if (d != nil)
    {
      s = [NSString alloc];
      if (charset == nil || [charset length] == 0)
	{
	  s = [s initWithData: d encoding: NSUTF8StringEncoding];
	}
      else
	{
	  NSStringEncoding	enc;

	  enc = [GSMimeDocument encodingFromCharset: charset];
	  s = [s initWithData: d encoding: enc];
	}
    }
  return AUTORELEASE(s);
}

- (NSString*) parameterString: (NSString*)name from: (NSDictionary*)params
{
  return [self parameterString: name at: 0 from: params charset: nil];
}

- (NSString*) parameterString: (NSString*)name
			 from: (NSDictionary*)params
		      charset: (NSString*)charset
{
  return [self parameterString: name at: 0 from: params charset: charset];
}

- (void) setDelegate: (id)anObject
{
  _delegate = anObject;
}

- (void) setDurationLogging: (BOOL)aFlag
{
  _durations = aFlag;
}

- (void) setMaxBodySize: (unsigned)max
{
  _maxBodySize = max;
}

- (void) setMaxConnections: (unsigned)max
{
  _maxConnections = max;
}

- (void) setMaxConnectionsPerHost: (unsigned)max
{
  _maxPerHost = max;
}

- (void) setMaxConnectionsReject: (BOOL)reject
{
  _reject = (reject == YES) ? 1 : 0;
}

- (void) setMaxRequestSize: (unsigned)max
{
  _maxRequestSize = max;
}

- (BOOL) setPort: (NSString*)aPort secure: (NSDictionary*)secure
{
  BOOL	ok = YES;
  BOOL	update = NO;

  if (aPort == nil || [aPort isEqual: _port] == NO)
    {
      update = YES;
    }
  if ((secure == nil && _sslConfig != nil)
    || (secure != nil && [secure isEqual: _sslConfig] == NO))
    {
      update = YES;
    }

  if (update == YES)
    {
      ASSIGN(_sslConfig, secure);
      if (_listener != nil)
	{
	  [_nc removeObserver: self
			 name: NSFileHandleConnectionAcceptedNotification
		       object: _listener];
	  DESTROY(_listener);
	}
      _accepting = NO;	// No longer listening for connections.
      DESTROY(_port);
      if (aPort != nil)
	{
	  _port = [aPort copy];
	  if (_sslConfig != nil)
	    {
	      _listener = [[NSFileHandle sslClass]
		fileHandleAsServerAtAddress: nil
		service: _port
		protocol: @"tcp"];
	    }
	  else
	    {
	      _listener = [NSFileHandle fileHandleAsServerAtAddress: nil
							    service: _port
							   protocol: @"tcp"];
	    }

	  if (_listener == nil)
	    {
	      [self _alert: @"Failed to listen on port %@", _port];
	      DESTROY(_port);
	      ok = NO;
	    }
	  else
	    {
	      RETAIN(_listener);
	      [_nc addObserver: self
		      selector: @selector(_didConnect:)
			  name: NSFileHandleConnectionAcceptedNotification
			object: _listener];
	      if (_accepting == NO && (_maxConnections == 0
		|| NSCountMapTable(_connections) < (_maxConnections + _reject)))
		{
		  [_listener acceptConnectionInBackgroundAndNotify];
		  _accepting = YES;
		}
	    }
	}
    }
  return ok;
}

- (void) setRoot: (NSString*)aPath
{
  ASSIGN(_root, aPath);
}

- (void) setConnectionTimeout: (NSTimeInterval)aDelay
{
  _connectionTimeout = aDelay;
}

- (void) setSubstitutionLimit: (unsigned)depth
{
  _substitutionLimit = depth;
}

- (void) setVerbose: (BOOL)aFlag
{
  _verbose = aFlag;
  if (aFlag == YES)
    {
      [self setDurationLogging: YES];
    }
}

- (BOOL) substituteFrom: (NSString*)aTemplate
                  using: (NSDictionary*)map
		   into: (NSMutableString*)result
		  depth: (unsigned)depth
{
  unsigned	length;
  unsigned	pos = 0;
  NSRange	r = NSMakeRange(pos, length);

  if (depth > _substitutionLimit)
    {
      [self _alert: @"Substitution exceeded limit (%u)", _substitutionLimit];
      return NO;
    }

  length = [aTemplate length];
  r = NSMakeRange(pos, length);
  r = [aTemplate rangeOfString: @"<!--"
		       options: NSLiteralSearch
			 range: r];
  while (r.length > 0)
    {
      unsigned	start = r.location;

      if (start > pos)
	{
	  r = NSMakeRange(pos, r.location - pos);
	  [result appendString: [aTemplate substringWithRange: r]];
	}
      pos = start;
      r = NSMakeRange(start + 4, length - start - 4);
      r = [aTemplate rangeOfString: @"-->"
			   options: NSLiteralSearch
			     range: r];
      if (r.length > 0)
	{
	  unsigned	end = NSMaxRange(r);
	  NSString	*subFrom;
	  NSString	*subTo;

	  r = NSMakeRange(start + 4, r.location - start - 4);
	  subFrom = [aTemplate substringWithRange: r];
	  subTo = [map objectForKey: subFrom];
	  if (subTo == nil)
	    {
	      [result appendString: @"<!--"];
	      pos += 4;
	    }
	  else
	    {
	      /*
	       * Unless the value substituted in is a comment,
	       * perform recursive substitution.
	       */
	      if ([subTo hasPrefix: @"<!--"] == NO)
		{
		  BOOL	v;

		  v = [self substituteFrom: subTo
				     using: map
				      into: result
				     depth: depth + 1];
		  if (v == NO)
		    {
		      return NO;
		    }
		}
	      else
		{
		  [result appendString: subTo];
		}
	      pos = end;
	    }
	}
      else
	{
	  [result appendString: @"<!--"];
	  pos += 4;
	}
      r = NSMakeRange(pos, length - pos);
      r = [aTemplate rangeOfString: @"<!--"
			   options: NSLiteralSearch
			     range: r];
    }

  if (pos < length)
    {
      r = NSMakeRange(pos, length - pos);
      [result appendString: [aTemplate substringWithRange: r]];
    }
  return YES;
}
@end

@implementation	WebServer (Private)

- (void) _alert: (NSString*)fmt, ...
{
  va_list	args;

  va_start(args, fmt);
  if ([_delegate respondsToSelector: @selector(webAlert:for:)] == YES)
    {
      NSString	*s;

      s = [NSString stringWithFormat: fmt arguments: args];
      [_delegate webAlert: s for: self];
    }
  else
    {
      NSLogv(fmt, args);
    }
  va_end(args);
}

- (void) _audit: (WebServerConnection*)connection
{
  if ([_quiet containsObject: [connection address]] == NO)
    {
      if ([_delegate respondsToSelector: @selector(webAudit:for:)] == YES)
	{
	  [_delegate webAudit: [connection audit] for: self];
	}
      else
	{
	  fprintf(stderr, "%s\r\n", [[connection audit] UTF8String]);
	} 
    }
}

- (void) _completedWithResponse: (GSMimeDocument*)response
{
  WebServerConnection	*connection = nil;
  NSData		*result;

  connection = (WebServerConnection*)NSMapGet(_processing, (void*)response);
  _ticked = [NSDate timeIntervalSinceReferenceDate];
  [connection setTicked: _ticked];
  [connection setProcessing: NO];

  [response setHeader: @"content-transfer-encoding"
		value: @"binary"
	   parameters: nil];

  if ([connection simple] == YES)
    {
      /*
       * If we had a 'simple' request with no HTTP version, we must respond
       * with a 'simple' response ... just the raw data with no headers.
       */
      result = [response convertToData];
      [connection setResult: @""];
    } 
  else
    {
      NSMutableData	*out;
      NSMutableData	*raw;
      unsigned char	*buf;
      unsigned int	len;
      unsigned int	pos;
      unsigned int	contentLength;
      NSEnumerator	*enumerator;
      GSMimeHeader	*hdr;

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

      out = [NSMutableData dataWithCapacity: len + 1024];
      [response deleteHeaderNamed: @"mime-version"];
      [response deleteHeaderNamed: @"content-length"];
      [response deleteHeaderNamed: @"content-encoding"];
      [response deleteHeaderNamed: @"content-transfer-encoding"];
      if (contentLength > 0)
	{
	  NSString	*str;

	  str = [NSString stringWithFormat: @"%u", contentLength];
	  [response setHeader: @"content-length" value: str parameters: nil];
	}
      else
	{
	  [response deleteHeaderNamed: @"content-type"];
	}
      hdr = [response headerNamed: @"http"];
      if (hdr == nil)
	{
	  const char	*s;

	  if (contentLength == 0)
	    {
	      s = "HTTP/1.1 204 No Content\r\n";
	      [connection setResult: @"HTTP/1.1 204 No Content"];
	    }
	  else
	    {
	      s = "HTTP/1.1 200 Success\r\n";
	      [connection setResult: @"HTTP/1.1 200 Success"];
	    }
	  [out appendBytes: s length: strlen(s)];
	}
      else
	{
	  NSString	*s = [[hdr value] stringByTrimmingSpaces];

	  [connection setResult: s];
	  s = [s stringByAppendingString: @"\r\n"];
	  [out appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
	  [response deleteHeader: hdr];
	  /*
	   * If the http version has been set to be an old one,
	   * we must be prepared to close the connection at once.
	   */
	  if ([s hasPrefix: @"HTTP/"] == NO
	    || [[s substringFromIndex: 5] floatValue] < 1.1) 
	    {
	      [connection setShouldEnd: YES];
	    }
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
      result = out;
    }

  if (_verbose == YES && [_quiet containsObject: [connection address]] == NO)
    {
      [self _log: @"Response %@ - %@", connection, result];
    }
  [[connection handle] writeInBackgroundAndNotify: result];

  NSMapRemove(_processing, (void*)response);
}

- (void) _didConnect: (NSNotification*)notification
{
  NSDictionary		*userInfo = [notification userInfo];
  NSFileHandle		*hdl;
  NSString		*a;
  NSHost		*h;

  _ticked = [NSDate timeIntervalSinceReferenceDate];
  _accepting = NO;
  hdl = [userInfo objectForKey: NSFileHandleNotificationFileHandleItem];
  if (hdl == nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"[%@ -%@] missing handle",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  else
    {
      WebServerConnection	*connection = [WebServerConnection new];
      BOOL			refusal = NO;

      if (_sslConfig != nil)
	{
	  NSString	*address = [hdl socketLocalAddress];
	  NSDictionary	*primary = [_sslConfig objectForKey: address];
	  NSString	*certificateFile;
	  NSString	*keyFile;
	  NSString	*password;

	  certificateFile = [primary objectForKey: @"CertificateFile"];
	  if (certificateFile == nil)
	    {
	      certificateFile = [_sslConfig objectForKey: @"CertificateFile"];
	    }
	  keyFile = [primary objectForKey: @"KeyFile"];
	  if (keyFile == nil)
	    {
	      keyFile = [_sslConfig objectForKey: @"KeyFile"];
	    }
	  password = [primary objectForKey: @"Password"];
	  if (password == nil)
	    {
	      password = [_sslConfig objectForKey: @"Password"];
	    }
	  [hdl sslSetCertificate: certificateFile
		      privateKey: keyFile
		       PEMpasswd: password];
	}

      if ((a = [hdl socketAddress]) == nil)
	{
	  [self _alert: @"Unknown address for new connection."]; 
	  [connection setResult: @"HTTP/1.0 403 Unknown client host"];
	  [hdl writeInBackgroundAndNotify:
	    [@"HTTP/1.0 403 Unknown client host\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  refusal = YES;
	}
      else if ((h = [NSHost hostWithAddress: a]) == nil)
	{
	  /*
	   * Don't log this in quiet mode as it could just be a
	   * test connection that we are ignoring.
	   */
	  if ([_quiet containsObject: a] == NO)
	    {
	      [self _alert: @"Unknown host (%@) on new connection.", a];
	    }
	  [connection setResult: @"HTTP/1.0 403 Bad client host"];
	  [hdl writeInBackgroundAndNotify:
	    [@"HTTP/1.0 403 Bad client host\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  refusal = YES;
	}
      else if (_hosts != nil && [_hosts containsObject: a] == NO)
	{
	  /*
	   * Don't log this in quiet mode as it could just be a
	   * test connection that we are ignoring.
	   */
	  if ([_quiet containsObject: a] == NO)
	    {
	      [self _log: @"Invalid host (%@) on new connection.", a];
	    }
	  [connection setResult: @"HTTP/1.0 403 Not a permitted client host"];
	  [hdl writeInBackgroundAndNotify:
	    [@"HTTP/1.0 403 Not a permitted client host\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  refusal = YES;
	}
      else if (_maxConnections > 0
        && NSCountMapTable(_connections) >= _maxConnections)
	{
	  [self _alert: @"Too many connections in total for new connect.", a];
	  [connection setResult: @"HTTP/1.0 503 Too many existing connections"];
	  [hdl writeInBackgroundAndNotify:
	    [@"HTTP/1.0 503 Too many existing connections\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  refusal = YES;
	}
      else if (_maxPerHost > 0 && [_perHost countForObject: a] >= _maxPerHost)
	{
	  [self _alert: @"Too many connections from (%@) for new connect.", a];
	  [connection setResult:
	    @"HTTP/1.0 503 Too many existing connections from host"];
	  [hdl writeInBackgroundAndNotify:
	    [@"HTTP/1.0 503 Too many existing connections from host\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  refusal = YES;
	}
      else if (_sslConfig != nil && [hdl sslAccept] == NO)
	{
	  /*
	   * Don't log this in quiet mode as it could just be a
	   * test connection that we are ignoring.
	   */
	  if ([_quiet containsObject: a] == NO)
	    {
	      [self _log: @"SSL accept fail on new connection (%@).", a];
	    }
	  [hdl closeFile];
	  hdl = nil;
	}

      [connection setAddress: a == nil ? (id)@"unknown" : (id)a];
      [connection setTicked: _ticked];
      [connection setConnectionStart: _ticked];

      if (hdl == nil)
        {
          [self _audit: connection];
	  RELEASE(connection);
	}
      else
	{
	  [connection setHandle: hdl];
	  [connection setBuffer: [NSMutableData dataWithCapacity: 1024]];

	  NSMapInsert(_connections, (void*)hdl, (void*)connection);
	  [_perHost addObject: [connection address]];
	  RELEASE(connection);
	  [_nc addObserver: self
		  selector: @selector(_didWrite:)
		      name: GSFileHandleWriteCompletionNotification
		    object: hdl];
	  if (refusal == YES)
	    {
	      /*
	       * We are simply refusing a connection, so we should end as
	       * soon as the response has been written, and we should not
	       * read anything from the client.
	       */
	      [connection setShouldEnd: YES];
	    }
	  else
	    {
	      /*
	       * We have accepted the connection ... so we need to set up
	       * to read the incoming request and parse/handle it.
	       */
	      [_nc addObserver: self
		      selector: @selector(_didRead:)
			  name: NSFileHandleReadCompletionNotification
			object: hdl];
	      [hdl readInBackgroundAndNotify];
	    }
	  if (_verbose == YES && [_quiet containsObject: a] == NO)
	    {
	      [self _log: @"%@ connect", connection];
	    }
	}
    }
  if (_accepting == NO && (_maxConnections == 0
    || NSCountMapTable(_connections) < (_maxConnections + _reject)))
    {
      [_listener acceptConnectionInBackgroundAndNotify];
      _accepting = YES;
    }
}

- (void) _didRead: (NSNotification*)notification
{
  NSDictionary		*dict = [notification userInfo];
  NSFileHandle		*hdl = [notification object];
  NSData		*d;
  id			parser;
  NSString		*method = @"";
  NSString		*query = @"";
  NSString		*path = @"";
  NSString		*version = @"";
  WebServerConnection	*connection;
  GSMimeDocument	*doc;

  _ticked = [NSDate timeIntervalSinceReferenceDate];
  connection = (WebServerConnection*)NSMapGet(_connections, (void*)hdl);
  NSAssert(connection != nil, NSInternalInconsistencyException);
  parser = [connection parser];

  d = [dict objectForKey: NSFileHandleNotificationDataItem];

  if ([d length] == 0)
    {
      if (parser == nil)
	{
	  NSMutableData	*buffer = [connection buffer];

	  if ([buffer length] == 0)
	    {
	      /*
	       * Don't log if we have already reset after handling
	       * a request.
	       * Don't log this in quiet mode as it could just be a
	       * test connection that we are ignoring.
	       */
	      if ([connection hasReset] == NO
		&& [_quiet containsObject: [connection address]] == NO)
		{
		  [self _log: @"%@ read end-of-file in empty request",
		    connection];
		}
	    }
	  else
	    {
	      [self _log: @"%@ read end-of-file in partial request - %@",
		connection, buffer];
	    }
	}
      else
	{
	  [self _log: @"%@ read end-of-file in incomplete request - %@",
	    connection, [parser mimeDocument]];
	}
      [self _endConnection: connection];
      return;
    }
  // NSLog(@"Data read on %@ ... %@", connection, d);

  // Mark connection as having had I/O ... not idle.
  [connection setTicked: _ticked];

  if (parser == nil)
    {
      unsigned char	*bytes;
      unsigned int	length;
      unsigned int	pos;
      NSMutableData	*buffer;

      /*
       * If we are starting to read a new request, record the request
       * startup time.
       */
      if ([connection requestDuration: _ticked] == 0.0)
	{
	  [connection setRequestStart: _ticked];
	}
      /*
       * Add new data to any we already have and search for the end
       * of the initial request line.
       */
      buffer = [connection buffer];
      [buffer appendData: d];
      bytes = [buffer mutableBytes];
      length = [buffer length];
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
      if (pos >= _maxBodySize)
	{
	  [self _log: @"Request too long ... rejected"];
	  [connection setShouldEnd: YES];
	  [connection setResult: @"HTTP/1.0 413 Request data too long"];
	  [hdl writeInBackgroundAndNotify:
	    [@"HTTP/1.0 413 Request data too long\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  return;
	}

      if (pos == length)
	{
	  [hdl readInBackgroundAndNotify];	// Needs more data.
	  return;
	}
      else
	{
	  unsigned	back = pos;
	  unsigned	start = 0;
	  unsigned	end;

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
	  [connection setCommand:
	    [NSString stringWithUTF8String: (const char*)bytes]];

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
	      version = [NSString stringWithUTF8String: (char*)bytes + end];
	      if ([version floatValue] < 1.1)
		{
		  [connection setShouldEnd: YES];	// Not persistent.
		}
	    }
	  else
	    {
	      back = strlen((const char*)bytes);
	      [connection setSimple: YES];	// Old style simple request.
	      [connection setShouldEnd: YES];	// Not persistent.
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
	  method = [NSString stringWithUTF8String: (char*)bytes + start];

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
	      query = [NSString stringWithUTF8String: (char*)bytes + end];

	    }
	  else
	    {
	      bytes[end] = '\0';
	    }
	  path = [NSString stringWithUTF8String: (char*)bytes + start];

	  if ([method isEqualToString: @"GET"] == NO
	    && [method isEqualToString: @"POST"] == NO)
	    {
	      [connection setShouldEnd: YES];	// Not persistent.
	      [connection setResult: @"HTTP/1.0 501 Not Implemented"];
	      [hdl writeInBackgroundAndNotify:
		[@"HTTP/1.0 501 Not Implemented\r\n\r\n"
		dataUsingEncoding: NSASCIIStringEncoding]];
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
	  [doc setHeader: @"x-http-version"
		   value: version
	      parameters: nil];

	  [connection setParser: parser];
	  RELEASE(parser);

	  if (pos >= length)
	    {
	      [hdl readInBackgroundAndNotify];	// Needs more data.
	      return;
	    }
	  // Fall through to parse remaining data with mime parser
	}
    }

  doc = [parser mimeDocument];
  method = [[doc headerNamed: @"x-http-method"] value];

  if ([connection moreBytes: [d length]] > _maxRequestSize)
    {
      [self _log: @"Request body too long ... rejected"];
      [connection setShouldEnd: YES];	// Not persistent.
      [connection setResult: @"HTTP/1.0 413 Request body too long"];
      [hdl writeInBackgroundAndNotify:
	[@"HTTP/1.0 413 Request body too long\r\n\r\n"
	dataUsingEncoding: NSASCIIStringEncoding]];
      return;
    }
  else if ([parser parse: d] == NO)
    {
      if ([parser isComplete] == YES)
	{
	  [self _process: connection];
	}
      else
	{
	  [self _log: @"HTTP parse failure - %@", parser];
	  [self _endConnection: connection];
	}
    }
  else if (([parser isComplete] == YES)
    || ([parser isInHeaders] == NO && ([method isEqualToString: @"GET"])))
    {
      [self _process: connection];
    }
  else
    {
      [hdl readInBackgroundAndNotify];
    }
}

- (void) _didWrite: (NSNotification*)notification
{
  NSFileHandle		*hdl = [notification object];
  WebServerConnection	*connection;

  _ticked = [NSDate timeIntervalSinceReferenceDate];
  connection = (WebServerConnection*)NSMapGet(_connections, (void*)hdl);
  NSAssert(connection != nil, NSInternalInconsistencyException);

  if ([connection shouldEnd] == YES)
    {
      [self _endConnection: connection];
    }
  else
    {
      if (_durations == YES)
	{
	  NSTimeInterval	t = [connection requestDuration: _ticked];

	  if (t == 0.0)
	    {
	      if ([_quiet containsObject: [connection address]] == NO)
		{
		  [self _log: @"%@ reset", connection];
		}
	    }
	  else
	    {
	      [self _log: @"%@ end of request (duration %g)", connection, t];
	    }
	}
      [self _audit: connection];
      [connection reset];
      [hdl readInBackgroundAndNotify];	// Want another request.
    }
}

- (void) _endConnection: (WebServerConnection*)connection
{
  NSFileHandle	*hdl = [connection handle];

  if ([_quiet containsObject: [connection address]] == NO)
    {
      if (_durations == YES)
	{
	  NSTimeInterval	r = [connection requestDuration: _ticked];

	  if (r > 0.0)
	    {
	      [self _log: @"%@ end of request (duration %g)", connection, r];
	    }
	}
      if (_verbose == YES)
	{
	  NSTimeInterval	s = [connection connectionDuration: _ticked];

	  [self _log: @"%@ disconnect (duration %g)", connection, s];
	}
      [self _audit: connection];
      _handled++;
    }
  [_nc removeObserver: self
		 name: NSFileHandleReadCompletionNotification
	       object: hdl];
  [_nc removeObserver: self
		 name: GSFileHandleWriteCompletionNotification
	       object: hdl];
  [_perHost removeObject: [connection address]];
  NSMapRemove(_connections, (void*)hdl);
  if (_accepting == NO && (_maxConnections == 0
    || NSCountMapTable(_connections) < (_maxConnections + _reject)))
    {
      [_listener acceptConnectionInBackgroundAndNotify];
      _accepting = YES;
    }
}

- (void) _log: (NSString*)fmt, ...
{
  va_list	args;

  va_start(args, fmt);
  if ([_delegate respondsToSelector: @selector(webLog:for:)] == YES)
    {
      NSString	*s;

      s = [NSString stringWithFormat: fmt arguments: args];
      [_delegate webLog: s for: self];
    }
  va_end(args);
}

- (void) _process: (WebServerConnection*)connection
{
  GSMimeDocument	*request;
  GSMimeDocument	*response;
  NSString		*str;
  NSString		*con;
  BOOL			processed = YES;

  response = [GSMimeDocument new];
  NSMapInsert(_processing, (void*)response, (void*)connection);
  RELEASE(response);
  [connection setProcessing: YES];

  request = [connection request];
  [connection setAgent: [[request headerNamed: @"user-agent"] value]];

  /*
   * If the client specified that the connection should close, we don't
   * keep it open.
   */
  con = [[request headerNamed: @"connection"] value]; 
  if (con != nil && [con caseInsensitiveCompare: @"close"] == NSOrderedSame)
    {
      [connection setShouldEnd: YES];	// Not persistent.
    }

  /*
   * Provide more information about the connection.
   */
  [request setHeader: @"x-local-address"
	       value: [[connection handle] socketLocalAddress]
	  parameters: nil];
  [request setHeader: @"x-local-port"
	       value: [[connection handle] socketLocalService]
	  parameters: nil];
  [request setHeader: @"x-remote-address"
	       value: [[connection handle] socketAddress]
	  parameters: nil];
  [request setHeader: @"x-remote-port"
	       value: [[connection handle] socketService]
	  parameters: nil];

  str = [[request headerNamed: @"authorization"] value];
  if ([str length] > 6 && [[str substringToIndex: 6] caseInsensitiveCompare:
    @"Basic "] == NSOrderedSame)
    {
      str = [[str substringFromIndex: 6] stringByTrimmingSpaces];
      str = [GSMimeDocument decodeBase64String: str];
      if ([str length] > 0)
	{
	  NSRange	r = [str rangeOfString: @":"];

	  if (r.length > 0)
	    {
	      [request setHeader: @"x-http-username"
			   value: [str substringToIndex: r.location]
		      parameters: nil];
	      [request setHeader: @"x-http-password"
			   value: [str substringFromIndex: NSMaxRange(r)]
		      parameters: nil];
	    }
	}
    }

  [response setContent: [NSData data] type: @"text/plain" name: nil];

  if ([_quiet containsObject: [connection address]] == NO)
    {
      _requests++;
      if (_verbose == YES)
	{
	  [self _log: @"Request %@ - %@", connection, request];
	}
    }
  NS_DURING
    {
      [connection setTicked: _ticked];
      if ([self accessRequest: request response: response] == YES)
	{
	  processed = [_delegate processRequest: request
				       response: response
					    for: self];
	}
      _ticked = [NSDate timeIntervalSinceReferenceDate];
      [connection setTicked: _ticked];
    }
  NS_HANDLER
    {
      [self _alert: @"Exception %@, processing %@", localException, request];
      [response setHeader: @"http"
		    value: @"HTTP/1.0 500 Internal Server Error"
	       parameters: nil];
    }
  NS_ENDHANDLER

  if (processed == YES)
    {
      [self _completedWithResponse: response];
    }
}

- (void) _timeout: (NSTimer*)timer
{
  unsigned		count;

  _ticked = [NSDate timeIntervalSinceReferenceDate];

  count = NSCountMapTable(_connections);
  if (count > 0)
    {
      NSMapEnumerator	enumerator;
      WebServerConnection	*connection;
      NSFileHandle	*handle;
      NSMutableArray	*array;

      array = [NSMutableArray arrayWithCapacity: count];
      enumerator = NSEnumerateMapTable(_connections);
      while (NSNextMapEnumeratorPair(&enumerator,
	(void **)(&handle), (void**)(&connection)))
	{
	  if (_ticked - [connection ticked] > _connectionTimeout
	    && [connection processing] == NO)
	    {
	      [array addObject: connection];
	    }
	}
      NSEndMapTableEnumeration(&enumerator);
      while ([array count] > 0)
	{
	  connection = [array objectAtIndex: 0];
	  if (_verbose == YES)
	    {
	      [self _log: @"Connection timed out - %@", connection];
	    }
	  [self _endConnection: connection];
	  [array removeObjectAtIndex: 0];
	}
    }
}
@end

