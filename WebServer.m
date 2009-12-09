/** 
   Copyright (C) 2004 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	June 2004
   
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

   $Date$ $Revision$
   */ 

#include <Foundation/Foundation.h>
#include "WebServer.h"

static	Class	NSArrayClass = Nil;
static	Class	NSDataClass = Nil;
static	Class	NSDateClass = Nil;
static	Class	NSDictionaryClass = Nil;
static	Class	NSMutableArrayClass = Nil;
static	Class	NSMutableDataClass = Nil;
static	Class	NSMutableDictionaryClass = Nil;
static	Class	NSMutableStringClass = Nil;
static	Class	NSStringClass = Nil;
static	Class	GSMimeDocumentClass = Nil;
static NSZone	*defaultMallocZone = 0;

#define	Alloc(X)	[(X) allocWithZone: defaultMallocZone]


@interface	WebServerConnection : NSObject
{
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
  NSTimeInterval	ticked;
  NSTimeInterval	extended;
  NSTimeInterval	requestStart;
  NSTimeInterval	connectionStart;
  NSTimeInterval	duration;
  NSUInteger		requests;
  BOOL			processing;
  BOOL			shouldClose;
  BOOL			hasReset;
  BOOL			simple;
  BOOL			ssl;
}
- (NSString*) address;
- (NSString*) audit;
- (NSMutableData*) buffer;
- (NSTimeInterval) connectionDuration: (NSTimeInterval)now;
- (NSTimeInterval) duration;	/* Of all requests */
- (NSData*) excess;
- (void) extend: (NSTimeInterval)when;
- (NSTimeInterval) extended;
- (NSFileHandle*) handle;
- (BOOL) hasReset;
- (NSUInteger) identity;
- (NSUInteger) moreBytes: (NSUInteger)count;
- (GSMimeParser*) parser;
- (BOOL) processing;
- (GSMimeDocument*) request;
- (NSUInteger) requests;
- (NSTimeInterval) requestDuration: (NSTimeInterval)now;
- (void) reset;
- (void) setAddress: (NSString*)aString;
- (void) setAgent: (NSString*)aString;
- (void) setBuffer: (NSMutableData*)aBuffer;
- (void) setCommand: (NSString*)aString;
- (void) setConnectionStart: (NSTimeInterval)when;
- (void) setExcess: (NSData*)d;
- (void) setHandle: (NSFileHandle*)aHandle;
- (void) setParser: (GSMimeParser*)aParser;
- (void) setProcessing: (BOOL)aFlag;
- (void) setRequestEnd: (NSTimeInterval)when;
- (void) setRequestStart: (NSTimeInterval)when;
- (void) setResult: (NSString*)aString;
- (void) setShouldClose: (BOOL)aFlag;
- (void) setSimple: (BOOL)aFlag;
- (void) setTicked: (NSTimeInterval)when;
- (void) setUser: (NSString*)aString;
- (BOOL) shouldClose;
- (BOOL) simple;
- (BOOL) ssl;
- (NSTimeInterval) ticked;
@end

@implementation	WebServerConnection

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

- (NSMutableData*) buffer
{
  return buffer;
}

- (void) dealloc
{
  [handle closeFile];
  DESTROY(excess);
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
  return [NSStringClass stringWithFormat: @"WebServerConnection: %08x [%@] ",
    [self identity], [self address]];
}

- (NSTimeInterval) duration
{
  return duration;
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

- (NSTimeInterval) extended
{
  return extended == 0.0 ? ticked : extended;
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

- (id) init
{
  static NSUInteger	connectionIdentity = 0;

  identity = ++connectionIdentity;
  requestStart = 0.0;
  duration = 0.0;
  requests = 0;
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
  DESTROY(agent);
  DESTROY(result);
  byteCount = 0;
  [self setRequestStart: 0.0];
  [self setBuffer: [NSMutableDataClass dataWithCapacity: 1024]];
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

- (void) setExcess: (NSData*)d
{
  ASSIGNCOPY(excess, d);
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

  ssl = YES;			// Avoid timeouts during handshake
  r = [handle sslAccept];
  ssl = NO;
  if (r == YES)			// Reset timer of last I/O
    {
      [self setTicked: [NSDateClass timeIntervalSinceReferenceDate]];
    }
  return r;
}

- (NSTimeInterval) ticked
{
  /* If we are doing an SSL handshake, we add 30 seconds to the timestamp
   * to allow for the fact that the handshake may take up to 30 seconds
   * itsself.  This prevents the connection from being removed during
   * a slow handshake.
   */
  return ticked + (YES == ssl ? 30.0 : 0.0);
}
@end

@interface	WebServer (Private)
- (void) _alert: (NSString*)fmt, ...;
- (void) _audit: (WebServerConnection*)connection;
- (void) _completedWithResponse: (GSMimeDocument*)response;
- (void) _didConnect: (NSNotification*)notification;
- (void) _didData: (NSData*)d for: (WebServerConnection*)connection;
- (void) _didRead: (NSNotification*)notification;
- (void) _didWrite: (NSNotification*)notification;
- (void) _endConnection: (WebServerConnection*)connection;
- (void) _log: (NSString*)fmt, ...;
- (void) _process: (WebServerConnection*)connection;
- (void) _timeout: (NSTimer*)timer;
@end

@implementation	WebServer

+ (void) initialize
{
  if (NSDataClass == Nil)
    {
      defaultMallocZone = NSDefaultMallocZone();
      NSStringClass = [NSString class];
      NSArrayClass = [NSArray class];
      NSDataClass = [NSData class];
      NSDateClass = [NSDate class];
      NSDictionaryClass = [NSDictionary class];
      NSMutableArrayClass = [NSMutableArray class];
      NSMutableDataClass = [NSMutableData class];
      NSMutableDictionaryClass = [NSMutableDictionary class];
      NSMutableStringClass = [NSMutableString class];
      GSMimeDocumentClass = [GSMimeDocument class];
    }
}

static NSUInteger
unescapeData(const uint8_t *bytes, NSUInteger length, uint8_t *buf)
{
  NSUInteger	to = 0;
  NSUInteger	from = 0;

  while (from < length)
    {
      uint8_t	c = bytes[from++];

      if (c == '+')
	{
	  c = ' ';
	}
      else if (c == '%' && from < length - 1)
	{
	  uint8_t	tmp;

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

+ (NSURL*) baseURLForRequest: (GSMimeDocument*)request
{
  NSString	*scheme = [[request headerNamed: @"x-http-scheme"] value];
  NSString	*host = [[request headerNamed: @"host"] value];
  NSString	*path = [[request headerNamed: @"x-http-path"] value];
  NSString	*query = [[request headerNamed: @"x-http-query"] value];
  NSString	*str;
  NSURL		*url;

  /* An HTTP/1.1 request MUST contain the host header, but older requests
   * may not ... in which case we have to use our local IP address and port.
   */
  if ([host length] == 0)
    {
      host = [NSString stringWithFormat: @"%@:%@",
	[[request headerNamed: @"x-local-address"] value],
	[[request headerNamed: @"x-local-port"] value]];
    }

  if ([query length] > 0)
    {
      str = [NSString stringWithFormat: @"%@://%@%@?%@",
	scheme, host, path, query];
    }
  else
    {
      str = [NSString stringWithFormat: @"%@://%@%@", scheme, host, path];
    }

  url = [NSURL URLWithString: str];
  return url;
}

+ (NSUInteger) decodeURLEncodedForm: (NSData*)data
			     into: (NSMutableDictionary*)dict
{
  const uint8_t		*bytes = (const uint8_t	*)[data bytes];
  NSUInteger		length = [data length];
  NSUInteger		pos = 0;
  NSUInteger		fields = 0;

  while (pos < length)
    {
      NSUInteger	keyStart = pos;
      NSUInteger	keyEnd;
      NSUInteger	valStart;
      NSUInteger	valEnd;
      uint8_t		*buf;
      NSUInteger	buflen;
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
	  d = [Alloc(NSDataClass) initWithBytesNoCopy: buf
						length: buflen
					  freeWhenDone: YES];
	}
      else
	{
	  d = [Alloc(NSDataClass) initWithBytesNoCopy: (void*)&bytes[keyStart]
						length: keyEnd - keyStart
					  freeWhenDone: NO];
	}
      k = [Alloc(NSStringClass) initWithData: d
				     encoding: NSUTF8StringEncoding];
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
	  d = [Alloc(NSDataClass) initWithBytesNoCopy: buf
						length: buflen
					  freeWhenDone: YES];
	}
      else
	{
	  d = [NSDataClass new];
	}
      a = [dict objectForKey: k];
      if (a == nil)
	{
	  a = [Alloc(NSMutableArrayClass) initWithCapacity: 1];
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
escapeData(const uint8_t *bytes, NSUInteger length, NSMutableData *d)
{
  uint8_t	*dst;
  NSUInteger	spos = 0;
  NSUInteger	dpos = [d length];

  [d setLength: dpos + 3 * length];
  dst = (uint8_t *)[d mutableBytes];
  while (spos < length)
    {
      uint8_t		c = bytes[spos++];
      NSUInteger	hi;
      NSUInteger	lo;

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

+ (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
			       into: (NSMutableData*)data
{
  CREATE_AUTORELEASE_POOL(arp);
  NSEnumerator		*keyEnumerator;
  id			key;
  NSUInteger		valueCount = 0;
  NSMutableData		*md = [NSMutableDataClass dataWithCapacity: 100];

  keyEnumerator = [dict keyEnumerator];
  while ((key = [keyEnumerator nextObject]) != nil)
    {
      id		values = [dict objectForKey: key];
      NSData		*keyData;
      NSEnumerator	*valueEnumerator;
      id		value;

      if ([key isKindOfClass: NSDataClass] == YES)
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

      if ([values isKindOfClass: NSArrayClass] == NO)
        {
	  values = [NSArrayClass arrayWithObject: values];
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
	  if ([value isKindOfClass: NSDataClass] == YES)
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

+ (NSString*) escapeHTML: (NSString*)str
{
  NSUInteger	length = [str length];
  NSUInteger	output = 0;
  unichar	*from;
  NSUInteger	i = 0;
  BOOL		escape = NO;

  if (length == 0)
    {
      return str;
    }
  from = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unichar) * length);
  [str getCharacters: from];

  for (i = 0; i < length; i++)
    {
      unichar	c = from[i];

      if ((c >= 0x20 && c <= 0xd7ff)
	|| c == 0x9 || c == 0xd || c == 0xa
	|| (c >= 0xe000 && c <= 0xfffd))
	{
	  switch (c)
	    {
	      case '"':
	      case '\'':
		output += 6;
		escape = YES;
	        break;

	      case '&':
		output += 5;
		escape = YES;
	        break;

	      case '<':
	      case '>':
		output += 4;
		escape = YES;
	        break;

	      default:
		/*
		 * For non-ascii characters, we can use &#nnnn; escapes
		 */
		if (c > 127)
		  {
		    output += 5;
		    while (c >= 1000)
		      {
			output++;
			c /= 10;
		      }
		    escape = YES;
		  }
		output++;
		break;
	    }
	}
      else
	{
	  escape = YES;	// Need to remove bad characters
	}
    }

  if (escape == YES)
    {
      unichar	*to;
      NSUInteger	j = 0;

      to = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unichar) * output);

      for (i = 0; i < length; i++)
	{
	  unichar	c = from[i];

	  if ((c >= 0x20 && c <= 0xd7ff)
	    || c == 0x9 || c == 0xd || c == 0xa
	    || (c >= 0xe000 && c <= 0xfffd))
	    {
	      switch (c)
		{
		  case '"':
		    to[j++] = '&';
		    to[j++] = 'q';
		    to[j++] = 'u';
		    to[j++] = 'o';
		    to[j++] = 't';
		    to[j++] = ';';
		    break;

		  case '\'':
		    to[j++] = '&';
		    to[j++] = 'a';
		    to[j++] = 'p';
		    to[j++] = 'o';
		    to[j++] = 's';
		    to[j++] = ';';
		    break;

		  case '&':
		    to[j++] = '&';
		    to[j++] = 'a';
		    to[j++] = 'm';
		    to[j++] = 'p';
		    to[j++] = ';';
		    break;

		  case '<':
		    to[j++] = '&';
		    to[j++] = 'l';
		    to[j++] = 't';
		    to[j++] = ';';
		    break;

		  case '>':
		    to[j++] = '&';
		    to[j++] = 'g';
		    to[j++] = 't';
		    to[j++] = ';';
		    break;

		  default:
		    if (c > 127)
		      {
			char	buf[12];
			char	*ptr = buf;

			to[j++] = '&';
			to[j++] = '#';
			sprintf(buf, "%u", c);
			while (*ptr != '\0')
			  {
			    to[j++] = *ptr++;
			  }
			to[j++] = ';';
		      }
		    else
		      {
			to[j++] = c;
		      }
		    break;
		}
	    }
	}
      str = [[NSString alloc] initWithCharacters: to length: output];
      NSZoneFree (NSDefaultMallocZone (), to);
      [str autorelease];
    }
  NSZoneFree (NSDefaultMallocZone (), from);
  return str;
}

+ (NSURL*) linkPath: (NSString*)newPath
	   relative: (NSURL*)oldURL
	      query: (NSDictionary*)fields, ...
{
  va_list		ap;
  NSMutableDictionary	*m;
  id			key;
  id			val;
  NSRange		r;

  m = [fields mutableCopy];
  va_start (ap, fields);
  while ((key = va_arg(ap, id)) != nil && (val = va_arg(ap, id)) != nil)
    {
      if (m == nil)
	{
	  m = [[NSMutableDictionary alloc] initWithCapacity: 2];
	}
      [m setObject: val forKey: key];
    }
  va_end (ap);

  /* The new path must NOT contain a query string.
   */
  r = [newPath rangeOfString: @"?"];
  if (r.length > 0)
    {
      newPath = [newPath substringToIndex: r.location];
    }

  if ([m count] > 0)
    {
      NSMutableData	*data;

      data = [[newPath dataUsingEncoding: NSUTF8StringEncoding] mutableCopy];
      [data appendBytes: "?" length: 1];
      [self encodeURLEncodedForm: m into: data];
      newPath = [NSString alloc];
      newPath = [newPath initWithData: data encoding: NSUTF8StringEncoding];
      [newPath autorelease];
      [data release];
    }
  [m release];

  if (oldURL == nil)
    {
      return [NSURL URLWithString: newPath];
    }
  else
    {
      return [NSURL URLWithString: newPath relativeToURL: oldURL];
    }
}

+ (NSData*) parameter: (NSString*)name
		   at: (NSUInteger)index
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

+ (NSString*) parameterString: (NSString*)name
			   at: (NSUInteger)index
			 from: (NSDictionary*)params
		      charset: (NSString*)charset
{
  NSData	*d = [self parameter: name at: index from: params];
  NSString	*s = nil;

  if (d != nil)
    {
      s = Alloc(NSStringClass);
      if (charset == nil || [charset length] == 0)
	{
	  s = [s initWithData: d encoding: NSUTF8StringEncoding];
	}
      else
	{
	  NSStringEncoding	enc;

	  enc = [GSMimeDocumentClass encodingFromCharset: charset];
	  s = [s initWithData: d encoding: enc];
	}
    }
  return AUTORELEASE(s);
}

+ (BOOL) redirectRequest: (GSMimeDocument*)request
		response: (GSMimeDocument*)response
		      to: (id)destination
{
  NSString	*s;
  NSString	*type;
  NSString	*body;

  /* If the destination is not an NSURL, take it as a string defining a
   * relative URL from the request base URL.
   */
  if (NO == [destination isKindOfClass: [NSURL class]])
    {
      s = [destination description];
      destination = [self baseURLForRequest: request];
      if (s != nil)
	{
	  destination = [NSURL URLWithString: s relativeToURL: destination];
	}
    }
  s = [destination absoluteString];

  [response setHeader: @"Location" value: s parameters: nil];
  [response setHeader: @"http"
		value: @"HTTP/1.1 302 Found"
	   parameters: nil];

  type = @"text/html";
  body = [NSString stringWithFormat: @"<a href=\"%@\">continue</a>",
    [self escapeHTML: s]];
  s = [[request headerNamed: @"accept"] value];
  if ([s length] > 0)
    {
      NSEnumerator      *e;

      /* Enumerate through all the supported types.
       */
      e = [[s componentsSeparatedByString: @","] objectEnumerator];
      while ((s = [e nextObject]) != nil)
        {
          /* Separate the type from any parameters.
           */
          s = [[[s componentsSeparatedByString: @";"] objectAtIndex: 0]
            stringByTrimmingSpaces];
          if ([s isEqualToString: @"text/html"] == YES
            || [s isEqualToString: @"text/xhtml"] == YES
            || [s isEqualToString: @"application/xhtml+xml"] == YES
            || [s isEqualToString: @"application/vnd.wap.xhtml+xml"] == YES
            || [s isEqualToString: @"text/vnd.wap.wml"] == YES)
            {
              type = s;
	      break;
            }
        }
    }
  [response setContent: body type: type];
  return YES;
}

- (BOOL) accessRequest: (GSMimeDocument*)request
	      response: (GSMimeDocument*)response
{
  NSDictionary		*conf = [_defs dictionaryForKey: @"WebServerAccess"];
  NSString		*path = [[request headerNamed: @"x-http-path"] value];
  NSDictionary		*access = nil;
  NSString		*stored = nil;
  NSString		*username;
  NSString		*password;

  while (access == nil)
    {
      access = [conf objectForKey: path];
      if ([access isKindOfClass: NSDictionaryClass] == NO)
	{
	  NSRange	r;

	  access = nil;
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

      auth = [NSStringClass stringWithFormat: @"Basic realm=\"%@\"", realm];

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
      modes = [Alloc(NSArrayClass) initWithObjects: objs count: 1];
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
  DESTROY(_defs);
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

- (NSUInteger) decodeURLEncodedForm: (NSData*)data
			     into: (NSMutableDictionary*)dict
{
  return [[self class] decodeURLEncodedForm: data into: dict];
}

- (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
			       into: (NSMutableData*)data
{
  return [[self class] encodeURLEncodedForm: dict into: data];
}

- (NSString*) escapeHTML: (NSString*)str
{
  return [[self class] escapeHTML: str];
}

- (NSString*) description
{
  return [NSStringClass stringWithFormat:
    @"%@ on %@(%@), %u of %u connections active,"
    @" %u ended, %u requests, listening: %@",
    [super description], _port, ([self isSecure] ? @"https" : @"http"),
    NSCountMapTable(_connections),
    _maxConnections, _handled, _requests, _accepting == YES ? @"yes" : @"no"];
}

- (id) init
{
  _defs = RETAIN([NSUserDefaults standardUserDefaults]);
  _hosts = RETAIN([_defs arrayForKey: @"WebServerHosts"]);
  _quiet = RETAIN([_defs arrayForKey: @"WebServerQuiet"]);
  _nc = RETAIN([NSNotificationCenter defaultCenter]);
  _connectionTimeout = 30.0;
  _reverse = [_defs boolForKey: @"ReverseHostLookup"];
  _maxPerHost = 32;
  _maxConnections = 128;
  _maxConnectionRequests = 100;
  _maxConnectionDuration = 10.0;
  _maxBodySize = 4*1024*1024;
  _maxRequestSize = 8*1024;
  _substitutionLimit = 4;
  _connections = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
    NSObjectMapValueCallBacks, 0);
  _processing = NSCreateMapTable(NSObjectMapKeyCallBacks,
    NSObjectMapValueCallBacks, 0);
  _perHost = [NSCountedSet new];
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
  id		data = nil;
  NSString	*type;
  NSString	*str;
  NSFileManager	*mgr;
  BOOL		string = NO;
  BOOL		result = YES;

  if (map == nil)
    {
      static NSDictionary	*defaultMap = nil;

      if (defaultMap == nil)
	{
	  defaultMap = [Alloc(NSDictionaryClass) initWithObjectsAndKeys:
	    @"image/gif", @"gif",
	    @"image/png", @"png",
	    @"image/jpeg", @"jpeg",
	    @"image/jpeg", @"jpg",
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
    && (data = [NSStringClass stringWithContentsOfFile: path]) == nil)
    {
      [self _log: @"Failed to load string '%@' ('%@')", aPath, path];
      result = NO;
    }
  else if (string == NO
    && (data = [NSDataClass dataWithContentsOfFile: path]) == nil)
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
  else if ((str = [NSStringClass stringWithContentsOfFile: path]) == nil)
    {
      [self _log: @"Failed to load template '%@' ('%@')", aPath, path];
      result = NO;
    }
  else
    {
      NSMutableString	*m;

      m = [Alloc(NSMutableStringClass) initWithCapacity: [str length]];
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
      RELEASE(m);
    }
  DESTROY(arp);
  return result;
}

- (NSMutableDictionary*) parameters: (GSMimeDocument*)request
{
  NSMutableDictionary	*params;
  NSString		*str = [[request headerNamed: @"x-http-query"] value];
  NSData		*data;

  params = [NSMutableDictionaryClass dictionaryWithCapacity: 32];
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
      NSUInteger	count = [contents count];
      NSUInteger	i;

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
		  a = [Alloc(NSMutableArrayClass) initWithCapacity: 1];
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
		   at: (NSUInteger)index
		 from: (NSDictionary*)params
{
  return [[self class] parameter: name at: index from: params];
}

- (NSData*) parameter: (NSString*)name from: (NSDictionary*)params
{
  return [self parameter: name at: 0 from: params];
}

- (NSString*) parameterString: (NSString*)name
			   at: (NSUInteger)index
			 from: (NSDictionary*)params
{
  return [self parameterString: name at: index from: params charset: nil];
}

- (NSString*) parameterString: (NSString*)name
			   at: (NSUInteger)index
			 from: (NSDictionary*)params
		      charset: (NSString*)charset
{
  return [[self class] parameterString: name
				    at: index
				  from: params
			       charset: charset];
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

- (void) setMaxBodySize: (NSUInteger)max
{
  _maxBodySize = max;
}

- (void) setMaxConnectionDuration: (NSTimeInterval)max
{
  _maxConnectionDuration = max;
}

- (void) setMaxConnectionRequests: (NSUInteger)max
{
  _maxConnectionRequests = max;
}

- (void) setMaxConnections: (NSUInteger)max
{
  _maxConnections = max;
}

- (void) setMaxConnectionsPerHost: (NSUInteger)max
{
  _maxPerHost = max;
}

- (void) setMaxConnectionsReject: (BOOL)reject
{
  _reject = (reject == YES) ? 1 : 0;
}

- (void) setMaxRequestSize: (NSUInteger)max
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

- (void) setSecureProxy: (BOOL)aFlag
{
  _secureProxy = aFlag;
}

- (void) setConnectionTimeout: (NSTimeInterval)aDelay
{
  _connectionTimeout = aDelay;
}

- (void) setSubstitutionLimit: (NSUInteger)depth
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
		  depth: (NSUInteger)depth
{
  NSUInteger	length;
  NSUInteger	pos = 0;
  NSRange	r;

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
      NSUInteger	start = r.location;

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
	  NSUInteger	end = NSMaxRange(r);
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

      s = [NSStringClass stringWithFormat: fmt arguments: args];
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
  _ticked = [NSDateClass timeIntervalSinceReferenceDate];
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
	   * we must be prepared to close the connection at once
	   * unless connection keep-alive has been set.
	   */
	  if ([s hasPrefix: @"HTTP/"] == NO)
	    {
	      [connection setShouldClose: YES];
	    }
	  else if ([[s substringFromIndex: 5] floatValue] < 1.1) 
	    {
	      s = [[response headerNamed: @"connection"] value]; 
	      if (s == nil
	        || ([s caseInsensitiveCompare: @"keep-alive"] != NSOrderedSame))
		{
		  [connection setShouldClose: YES];
		}
	    }
	}

      /* We will close this connection if the maximum number of requests
       * or maximum request duration has been exceeded.
       */
      if ([connection requests] >= _maxConnectionRequests)
	{
	  [connection setShouldClose: YES];
	}
      else if ([connection duration] >= _maxConnectionDuration)
	{
	  [connection setShouldClose: YES];
	}

      /* Ensure that we send a connection close if we are about to drop
       * the connection.
       */
      if ([connection shouldClose] == YES)
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
      result = out;
    }

  if (_verbose == YES && [_quiet containsObject: [connection address]] == NO)
    {
      [self _log: @"Response %@ - %@", connection, result];
    }
  [_nc removeObserver: self
		 name: NSFileHandleReadCompletionNotification
	       object: [connection handle]];
  [[connection handle] writeInBackgroundAndNotify: result];
  [connection retain];
  NSMapRemove(_processing, (void*)response);

  /* If this connection is not closing and excess data has been read,
   * we may continue dealing with incoming data before the write
   * has completed.
   */
  if ([connection shouldClose] == YES)
    {
      [connection setExcess: nil];
    }
  else
    {
      NSData	*more = [connection excess];

      if (more != nil)
	{
          [self _didData: more for: connection];
	}
    }
  [connection release];
}

- (void) _didConnect: (NSNotification*)notification
{
  NSDictionary		*userInfo = [notification userInfo];
  NSFileHandle		*hdl;
  NSString		*a;
  NSHost		*h = nil;

  if (_ticker == nil)
    {
      _ticker = [NSTimer scheduledTimerWithTimeInterval: 0.8
        target: self
        selector: @selector(_timeout:)
        userInfo: 0
        repeats: YES];
    }
  _ticked = [NSDateClass timeIntervalSinceReferenceDate];
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
      else if (_reverse == YES && ((h = [NSHost hostWithAddress: a]) == nil))
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
	    [@"HTTP/1.0 503 Too many existing connections\r\n"
            @"Retry-After: 120\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  refusal = YES;
	}
      else if (_maxPerHost > 0 && [_perHost countForObject: a] >= _maxPerHost)
	{
	  [self _alert: @"Too many connections from (%@) for new connect.", a];
	  [connection setResult:
	    @"HTTP/1.0 503 Too many existing connections from host"];
	  [hdl writeInBackgroundAndNotify:
	    [@"HTTP/1.0 503 Too many existing connections from host\r\n"
            @"Retry-After: 120\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  refusal = YES;
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
	  NSMapInsert(_connections, (void*)hdl, (void*)connection);
	  [_perHost addObject: [connection address]];
	  RELEASE(connection);

	  if (_sslConfig != nil)
	    {
	      /* Initiate a new accept *before* performing SSL handshake so
	       * that we can accept more connections during a slow handshake.
	       */
	      if (_accepting == NO && (_maxConnections == 0
		|| NSCountMapTable(_connections) < (_maxConnections + _reject)))
		{
		  [_listener acceptConnectionInBackgroundAndNotify];
		  _accepting = YES;
		}

	      /* Tell the connection to perform SSL handshake.
	       */
	      if ([connection ssl] == NO)
		{
		  /* Don't log this in quiet mode as it could just be a
		   * test connection that we are ignoring.
		   */
		  if ([_quiet containsObject: a] == NO)
		    {
		      [self _log: @"SSL accept fail on connection (%@).", a];
		    }
	          [self _endConnection: connection];
		  connection = nil;
		  hdl = nil;
		}
	    }
	  
	  if (hdl != nil)
	    {
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
		  [connection setShouldClose: YES];
		}
	      else
		{
		  /*
		   * We have accepted the connection ... so we need to set up
		   * to read the incoming request and parse/handle it.
		   */
		  [connection setBuffer:
		    [NSMutableDataClass dataWithCapacity: 1024]];
		  [_nc addObserver: self
			  selector: @selector(_didRead:)
			      name: NSFileHandleReadCompletionNotification
			    object: hdl];
		  [hdl readInBackgroundAndNotify];
		}
	      if (_verbose == YES && [_quiet containsObject: a] == NO)
		{
		  if (h == nil)
		    {
		      [self _log: @"%@ connect", connection];
		    }
		  else
		    {
		      [self _log: @"%@ connect from %@", connection, [h name]];
		    }
		}
	    }
	}
    }

  /* Ensure we always have an 'accept' in progress unless we are already
   * handling the maximum number of connections.
   */
  if (_accepting == NO && (_maxConnections == 0
    || NSCountMapTable(_connections) < (_maxConnections + _reject)))
    {
      [_listener acceptConnectionInBackgroundAndNotify];
      _accepting = YES;
    }
}

- (void) _didData: (NSData*)d for: (WebServerConnection*)connection
{
  id			parser;
  NSString		*method = @"";
  NSString		*query = @"";
  NSString		*path = @"";
  NSString		*version = @"";
  GSMimeDocument	*doc;

  // Mark connection as having had I/O ... not idle.
  [connection setTicked: _ticked];
  parser = [connection parser];
  if (parser == nil)
    {
      uint8_t		*bytes;
      NSUInteger	length;
      NSUInteger	pos;
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
      if (pos >= _maxRequestSize)
	{
	  [self _log: @"Request too long ... rejected"];
	  [connection setShouldClose: YES];
	  [connection setResult: @"HTTP/1.0 413 Request data too long"];
	  [[connection handle] writeInBackgroundAndNotify:
	    [@"HTTP/1.0 413 Request data too long\r\n\r\n"
	    dataUsingEncoding: NSASCIIStringEncoding]];
	  return;
	}

      if (pos == length)
	{
	  /* Needs more data.
	   */
	  [[connection handle] readInBackgroundAndNotify];
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
	  [connection setCommand:
	    [NSStringClass stringWithUTF8String: (const char*)bytes]];

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
		  [connection setShouldClose: YES];	// Not persistent.
		}
	    }
	  else
	    {
	      back = strlen((const char*)bytes);
	      [connection setSimple: YES];	// Old style simple request.
	      [connection setShouldClose: YES];	// Not persistent.
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

	    }
	  else
	    {
	      bytes[end] = '\0';
	    }
	  path = [NSStringClass stringWithUTF8String: (char*)bytes + start];

	  if ([method isEqualToString: @"GET"] == NO
	    && [method isEqualToString: @"POST"] == NO)
	    {
	      [connection setShouldClose: YES];	// Not persistent.
	      [connection setResult: @"HTTP/1.0 501 Not Implemented"];
	      [[connection handle] writeInBackgroundAndNotify:
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
		   value: ((_secureProxy||[self isSecure]) ? @"https" : @"http")
	      parameters: nil];
	  [doc setHeader: @"x-http-version"
		   value: version
	      parameters: nil];

	  [connection setParser: parser];
	  RELEASE(parser);

	  if (pos >= length)
	    {
	      // Needs more data.
	      [[connection handle] readInBackgroundAndNotify];
	      return;
	    }
	  // Fall through to parse remaining data with mime parser
	}
    }

  doc = [parser mimeDocument];
  method = [[doc headerNamed: @"x-http-method"] value];

  if ([connection moreBytes: [d length]] > _maxBodySize)
    {
      [self _log: @"Request body too long ... rejected"];
      [connection setShouldClose: YES];	// Not persistent.
      [connection setResult: @"HTTP/1.0 413 Request body too long"];
      [[connection handle] writeInBackgroundAndNotify:
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
          [connection setShouldClose: YES];	// Not persistent.
          [connection setResult: @"HTTP/1.0 400 Bad Request"];
          [[connection handle] writeInBackgroundAndNotify:
            [@"HTTP/1.0 400 Bad Request\r\n\r\n"
            dataUsingEncoding: NSASCIIStringEncoding]];
	  return;
	}
    }
  else if (([parser isComplete] == YES)
    || ([parser isInHeaders] == NO && ([method isEqualToString: @"GET"])))
    {
      [self _process: connection];
    }
  else
    {
      [[connection handle] readInBackgroundAndNotify];
    }
}

- (void) _didRead: (NSNotification*)notification
{
  NSDictionary		*dict = [notification userInfo];
  NSFileHandle		*hdl = [notification object];
  NSData		*d;
  id			parser;
  WebServerConnection	*connection;

  _ticked = [NSDateClass timeIntervalSinceReferenceDate];
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

  if (_verbose == YES
    && [_quiet containsObject: [connection address]] == NO)
    {
      [self _log: @"Data read on %@ ... %@", connection, d];
    }

  [self _didData: d for: connection];
}

- (void) _didWrite: (NSNotification*)notification
{
  NSFileHandle		*hdl = [notification object];
  WebServerConnection	*connection;

  _ticked = [NSDateClass timeIntervalSinceReferenceDate];
  connection = (WebServerConnection*)NSMapGet(_connections, (void*)hdl);
  NSAssert(connection != nil, NSInternalInconsistencyException);

  if ([connection shouldClose] == YES)
    {
      [self _endConnection: connection];
    }
  else
    {
      NSTimeInterval	t = [connection requestDuration: _ticked];

      if (t > 0.0)
	{
	  [connection setRequestEnd: _ticked];
	  if (_durations == YES)
	    {
	      if ([_quiet containsObject: [connection address]] == NO)
		{
		  [self _log: @"%@ end of request (duration %g)",
		    connection, t];
		}
	    }
	}
      else
	{
	  if (_durations == YES)
	    {
	      if ([_quiet containsObject: [connection address]] == NO)
		{
		  [self _log: @"%@ reset", connection];
		}
	    }
	}
      [self _audit: connection];
      [connection reset];
      [_nc addObserver: self
	      selector: @selector(_didRead:)
		  name: NSFileHandleReadCompletionNotification
		object: hdl];
      [hdl readInBackgroundAndNotify];	// Want another request.
    }
}

- (void) _endConnection: (WebServerConnection*)connection
{
  NSFileHandle	*hdl = [connection handle];

  if ([_quiet containsObject: [connection address]] == NO)
    {
      NSTimeInterval	r = [connection requestDuration: _ticked];

      if (r > 0.0)
	{
	  [connection setRequestEnd: _ticked];
	  if (_durations == YES)
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

      s = [NSStringClass stringWithFormat: fmt arguments: args];
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
  [connection setExcess: [[connection parser] excess]];
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
  if (con != nil)
    {
      if ([con caseInsensitiveCompare: @"keep-alive"] == NSOrderedSame)
	{
	  [connection setShouldClose: NO];	// Persistent (even in HTTP 1.0)
	  [response setHeader: @"Connection"
		        value: @"Keep-Alive"
		   parameters: nil];
	}
      else if ([con caseInsensitiveCompare: @"close"] == NSOrderedSame)
	{
	  [connection setShouldClose: YES];	// Not persistent.
	}
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

  /*
   * Provide more information about the process statistics.
   */
  str = [NSStringClass stringWithFormat: @"%u", NSCountMapTable(_processing)];
  [request setHeader: @"x-count-requests"
	       value: str
	  parameters: nil];
  str = [NSStringClass stringWithFormat: @"%u", NSCountMapTable(_connections)];
  [request setHeader: @"x-count-connections"
	       value: str
	  parameters: nil];
  str = [NSStringClass stringWithFormat: @"%u", [_perHost count]];
  [request setHeader: @"x-count-connected-hosts"
	       value: str
	  parameters: nil];
  str = [[connection handle] socketAddress];
  str = [NSStringClass stringWithFormat: @"%u", [_perHost countForObject: str]];
  [request setHeader: @"x-count-host-connections"
	       value: str
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
	      NSString	*user = [str substringToIndex: r.location];

	      [connection setUser: user];
	      [request setHeader: @"x-http-username"
			   value: user
		      parameters: nil];
	      [request setHeader: @"x-http-password"
			   value: [str substringFromIndex: NSMaxRange(r)]
		      parameters: nil];
	    }
	}
    }

  [response setContent: [NSDataClass data] type: @"text/plain" name: nil];

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
      _ticked = [NSDateClass timeIntervalSinceReferenceDate];
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
  NSUInteger		count;

  _ticked = [NSDateClass timeIntervalSinceReferenceDate];

  count = NSCountMapTable(_connections);
  if (count > 0)
    {
      NSMapEnumerator		enumerator;
      WebServerConnection	*connection;
      NSFileHandle		*handle;
      NSMutableArray		*array;

      array = [NSMutableArrayClass arrayWithCapacity: count];
      enumerator = NSEnumerateMapTable(_connections);
      while (NSNextMapEnumeratorPair(&enumerator,
	(void **)(&handle), (void**)(&connection)))
	{
	  NSTimeInterval	age = _ticked - [connection ticked];

	  if (age > _connectionTimeout)
	    {
	      if ([connection processing] == NO)
		{
		  [array addObject: connection];
		}
	      else if (_ticked - [connection extended] > _connectionTimeout)
		{
		  [connection extend: 300.0];
		  [self _alert: @"%@ abort after %g seconds to process %@",
		    connection, age, [connection request]];
		}
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
  else
    {
      /* No open connections ... so we should invalidate the timer.
       */
      _ticker = nil;
      [timer invalidate];
    }
}
@end

