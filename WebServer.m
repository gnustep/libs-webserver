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
#include <Performance/GSThreadPool.h>
#include "WebServer.h"
#include "Internal.h"

#define	MAXCONNECTIONS	10000

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
static	Class	WebServerHeaderClass = Nil;
static NSZone	*defaultMallocZone = 0;
static NSSet	*defaultPermittedMethods = nil;

#define	Alloc(X)	[(X) allocWithZone: defaultMallocZone]

@implementation	WebServer

+ (void) initialize
{
  if (NSDataClass == Nil)
    {
      static id	m[2] = { @"GET", @"POST" };

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
      WebServerHeaderClass = [WebServerHeader class];
      defaultPermittedMethods = [[NSSet alloc] initWithObjects: m count: 2];
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

+ (BOOL) matchIP: (NSString*)address to: (NSString*)pattern
{
  uint32_t	remote;
  NSArray	*parts;
  NSArray	*items;
  unsigned	count;
  unsigned	index;

  parts = [address componentsSeparatedByString: @"."];
  remote = [[parts objectAtIndex: 0] intValue];
  remote = remote * 256 + [[parts objectAtIndex: 1] intValue];
  remote = remote * 256 + [[parts objectAtIndex: 2] intValue];
  remote = remote * 256 + [[parts objectAtIndex: 3] intValue];

  items = [pattern componentsSeparatedByString: @","];
  count = [items count];
  for (index = 0; index < count; index++)
    {
      pattern = [[items objectAtIndex: index] stringByTrimmingSpaces];
      if ([pattern length] > 0)
	{
	  NSRange	r = [pattern rangeOfString: @"/"];
	  uint32_t	expect;
  
	  if (0 == r.length)
	    {
	      /* An IPv4 address in dot format (nnn.nnn.nnn.nnn)
	       */
	      parts = [address componentsSeparatedByString: @"."];
	      expect = [[parts objectAtIndex: 0] intValue];
	      expect = expect * 256 + [[parts objectAtIndex: 1] intValue];
	      expect = expect * 256 + [[parts objectAtIndex: 2] intValue];
	      expect = expect * 256 + [[parts objectAtIndex: 3] intValue];
	      if (remote == expect)
		{
		  return YES;
		}
	    }
	  else
	    {
	      int           bits;
	      uint32_t      want;
	      uint32_t      mask;
	      int           i;

	      /* An IPv4 mask in dot format with a number of bits specified
	       * after a slash (nnn.nnn.nnn.nnn/bits)
	       */
	      parts = [pattern componentsSeparatedByString: @"/"];
	      bits = [[parts objectAtIndex: 1] intValue];
	      pattern = [parts objectAtIndex: 0];
	      parts = [pattern componentsSeparatedByString: @"."];
	      want = [[parts objectAtIndex: 0] intValue];
	      want = want * 256 + [[parts objectAtIndex: 1] intValue];
	      want = want * 256 + [[parts objectAtIndex: 2] intValue];
	      want = want * 256 + [[parts objectAtIndex: 3] intValue];
	      mask = 0xffffffff;
	      bits = 32 - bits;
	      for (i = 0; i < bits; i++)
		{
		  mask &= ~(1<<i);
		}
	      NSAssert((want & mask) == want, NSInternalInconsistencyException);
	      if ((remote & mask) == want)
		{
		  return YES;
		}
	    }
	}
    }
  return NO;
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

- (void) closeConnectionAfter: (GSMimeDocument*)response
{
  [_lock lock];
  [[(WebServerResponse*)response webServerConnection] setShouldClose: YES];
  [_lock unlock];
}

- (void) completedWithResponse: (GSMimeDocument*)response
{
  if (YES == _doPostProcess)
    {
      [_pool scheduleSelector: @selector(_process4:)
		   onReceiver: self
		   withObject: response];
    }
  else
    {
      WebServerConnection	*connection;

      [_lock lock];
      _processingCount--;
      connection = [[(WebServerResponse*)response webServerConnection] retain];
      [_lock unlock];
      if (nil == connection)
	{
	  NSLog(@"Late response %@", response);
	}
      else
	{
	  [_pool scheduleSelector: @selector(respond)
		       onReceiver: connection
		       withObject: nil];
	  [connection release];
	}
    }
}

- (NSArray*) connections
{
  NSArray	*a;

  [_lock lock];
  a = [_connections allObjects];
  [_lock unlock];
  return a;
}

- (void) dealloc
{
  [self setPort: nil secure: nil];
  [self setIOThreads: 0 andPool: 0];
  DESTROY(_nc);
  DESTROY(_defs);
  DESTROY(_root);
  DESTROY(_conf);
  DESTROY(_perHost);
  DESTROY(_lock);
  if (nil != _ioMain)
    {
      [_ioMain->timer invalidate];
      _ioMain->timer = nil;
      DESTROY(_ioMain);
    }
  DESTROY(_ioThreads);
  DESTROY(_connections);
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
  NSString	*result;

  [_lock lock];
  result = [NSStringClass stringWithFormat:
    @"%@ on %@(%@), %u of %u connections active,"
    @" %u ended, %u requests, listening: %@%@%@",
    [super description], _port, ([self isSecure] ? @"https" : @"http"),
    [_connections count],
    _maxConnections, _handled, _requests, _accepting == YES ? @"yes" : @"no",
    [self _ioThreadDescription], [self _poolDescription]];
  [_lock unlock];
  return result;
}

- (id) init
{
  if (nil != (self = [super init]))
    {
      _reserved = 0;
      _nc = [[NSNotificationCenter defaultCenter] retain];
      _connectionTimeout = 30.0;
      _lock =  [NSLock new];
      _ioMain = [IOThread new];
      _ioMain->thread = [NSThread mainThread];
      _ioMain->server = self;
      _ioMain->cTimeout = _connectionTimeout;
      /* We need a timer so that the main thread can handle connection
       * timeouts.
       */
      _ioMain->timer
	= [NSTimer scheduledTimerWithTimeInterval: 0.8
					   target: _ioMain
					 selector: @selector(timeout:)
					 userInfo: 0
					  repeats: YES];

      _pool = [GSThreadPool new];
      [_pool setThreads: 0];
      _defs = [[NSUserDefaults standardUserDefaults] retain];
      _quiet = [[_defs arrayForKey: @"WebServerQuiet"] copy];
      _hosts = [[_defs arrayForKey: @"WebServerHosts"] copy];
      _conf = [WebServerConfig new];
      _conf->reverse = [_defs boolForKey: @"ReverseHostLookup"];
      _conf->permittedMethods = [defaultPermittedMethods copy];
      _conf->maxConnectionRequests = 100;
      _conf->maxConnectionDuration = 10.0;
      _conf->maxBodySize = 4*1024*1024;
      _conf->maxRequestSize = 8*1024;
      _maxPerHost = 32;
      _maxConnections = 128;
      _substitutionLimit = 4;
      _connections = [NSMutableSet new];
      _perHost = [NSCountedSet new];
      _ioThreads = [NSMutableArray new];
    }
  return self;
}

- (NSString*) _ioThreadDescription
{
  unsigned		counter = [_ioThreads count];

  if (0 == counter)
    {
      return @"";
    }
  else
    {
      NSMutableString	*s = [NSMutableString string];

      [s appendString: @"\nIO threads:"];
      while (counter-- > 0)
	{
	  [s appendString: @"\n  "];
	  [s appendString: [[_ioThreads objectAtIndex: counter] description]];
	}
      return s;
    }
}

- (BOOL) isSecure
{
  if (_sslConfig == nil)
    {
      return NO;
    }
  return YES;
}

- (NSString*) _poolDescription
{
  if (0 == [_pool maxThreads])
    {
      return @"";
    }
  return [NSString stringWithFormat: @"\nWorkers: %@", _pool];
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
  _doAudit = [_delegate respondsToSelector:
    @selector(webAudit:for:)];
  _doProcess = [_delegate respondsToSelector:
    @selector(processRequest:response:for:)];
  _doPreProcess = [_delegate respondsToSelector:
    @selector(preProcessRequest:response:for:)];
  _doPostProcess = [_delegate respondsToSelector:
    @selector(postProcessRequest:response:for:)];
}

- (void) setDurationLogging: (BOOL)aFlag
{
  if (aFlag != _conf->durations)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->durations = aFlag;
      [_conf release];
      _conf = c;
    }
}

- (void) setMaxBodySize: (NSUInteger)max
{
  if (max != _conf->maxBodySize)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->maxBodySize = max;
      [_conf release];
      _conf = c;
    }
}

- (void) setMaxConnectionDuration: (NSTimeInterval)max
{
  if (max != _conf->maxConnectionDuration)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->maxConnectionDuration = max;
      [_conf release];
      _conf = c;
    }
}

- (void) setMaxConnectionRequests: (NSUInteger)max
{
  if (max != _conf->maxConnectionRequests)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->maxConnectionRequests = max;
      [_conf release];
      _conf = c;
    }
}

- (void) setMaxConnections: (NSUInteger)max
{
  if (0 == max || max > MAXCONNECTIONS)
    {
      max = MAXCONNECTIONS;
    }
  _maxConnections = max;
  if (_maxPerHost > max)
    {
      _maxPerHost = max;
    }
  [_pool setOperations: max];
}

- (void) setMaxConnectionsPerHost: (NSUInteger)max
{
  if (0 == max || max > MAXCONNECTIONS)
    {
      max = MAXCONNECTIONS;
    }
  if (max > _maxConnections)
    {
      max = _maxConnections;
    }
  _maxPerHost = max;
  [_pool setOperations: max];
}

- (void) setMaxConnectionsReject: (BOOL)reject
{
  _reject = (reject == YES) ? 1 : 0;
}

- (void) setMaxKeepalives: (NSUInteger)max
{
  unsigned counter;

  /* Set the maximum number of keepalives per thread to be as specified
   */
  if (0 == max || max > 1000)
    {
      max = 100;
    }
  [_lock lock];
  _ioMain->keepaliveMax = max;
  counter = [_ioThreads count];
  while (counter-- > 0)
    {
      IOThread	*tmp = [_ioThreads objectAtIndex: counter];

      tmp->keepaliveMax = max;
    }
  [_lock unlock];
}

- (void) setMaxRequestSize: (NSUInteger)max
{
  if (max != _conf->maxRequestSize)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->maxRequestSize = max;
      [_conf release];
      _conf = c;
    }
}

- (void) setPermittedMethods: (NSSet*)s
{
  WebServerConfig	*c = [_conf copy];

  if (0 == [s count])
    {
      s = defaultPermittedMethods;
    }
  ASSIGNCOPY(c->permittedMethods, s);
  [_conf release];
  _conf = c;
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
      ASSIGNCOPY(_sslConfig, secure);
      if (_listener != nil)
	{
	  [_nc removeObserver: self
			 name: NSFileHandleConnectionAcceptedNotification
		       object: _listener];
	  [_listener closeFile];
	  DESTROY(_listener);
	}
      _accepting = NO;	// No longer listening for connections.
      DESTROY(_port);
      if (nil == aPort)
	{
	  NSEnumerator		*enumerator;
	  WebServerConnection	*connection;

	  [_lock lock];
	  /* If we have been shut down (port is nil) then we want any
	   * outstanding connections to close down as soon as possible.
	   */
	  enumerator = [_connections objectEnumerator];
	  while ((connection = [enumerator nextObject]) != nil)
	    {
	      [connection shutdown];
	    }
	  /* We also get rid of the headers which refer to us, so that
	   * we can be released as soon as any connections/requests using
	   * those headers have released us.
	   */
	  DESTROY(_xCountRequests);
	  DESTROY(_xCountConnections);
	  DESTROY(_xCountConnectedHosts);

	  [_lock unlock];
	}
      else
	{
	  _port = [aPort copy];

	  /* Set up headers to be used by requests on incoming connections
	   * to find information about this instance.
           */
	  _xCountRequests = [[WebServerHeader alloc]
	    initWithType: WSHCountRequests andObject: self];
	  _xCountConnections = [[WebServerHeader alloc]
	    initWithType: WSHCountConnections andObject: self];
	  _xCountConnectedHosts = [[WebServerHeader alloc]
	    initWithType: WSHCountConnectedHosts andObject: self];

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
	      [self _listen];
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
  if (aFlag != _conf->secureProxy)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->secureProxy = aFlag;
      [_conf release];
      _conf = c;
    }
}

- (void) setConnectionTimeout: (NSTimeInterval)aDelay
{
  if (aDelay != _connectionTimeout)
    {
      NSEnumerator	*e;
      NSArray		*a;
      IOThread		*t;

      _connectionTimeout = aDelay;
      [_ioMain->threadLock lock];
      _ioMain->cTimeout = _connectionTimeout;
      [_ioMain->threadLock unlock];
      [_lock lock];
      a = [_ioThreads copy];
      e = [a objectEnumerator];
      [a release];
      [_lock unlock];
      while ((t = [e nextObject]) != nil)
	{
	  [t->threadLock lock];
	  t->cTimeout = _connectionTimeout;
	  [t->threadLock unlock];
	}
    }
}

- (void) setSubstitutionLimit: (NSUInteger)depth
{
  _substitutionLimit = depth;
}

- (void) setIOThreads: (NSUInteger)threads andPool: (NSInteger)poolSize
{
  if (threads > 16)
    {
      threads = 16;
    }
  if (poolSize > 32)
    {
      poolSize = 32;
    }
  [_lock lock];
  if (poolSize != [_pool maxThreads])
    {
      if (poolSize > 0)
	{
	  [_pool setOperations: _maxConnections];
	}
      else
	{
	  [_pool setOperations: 0];
	}
      [_pool setThreads: poolSize];
    }
  if (threads != [_ioThreads count])
    {
      while ([_ioThreads count] > threads)
	{
	  IOThread	*t = [_ioThreads lastObject];

	  [t->timer invalidate];
	  [_ioThreads removeObjectIdenticalTo: t];
	}
      while ([_ioThreads count] < threads)
	{
	  IOThread	*t = [IOThread new];

	  t->server = self;
	  t->cTimeout = _connectionTimeout;
	  t->keepaliveMax = _ioMain->keepaliveMax;
          [NSThread detachNewThreadSelector: @selector(run)  
				   toTarget: t
				 withObject: nil];
	  [_ioThreads addObject: t];
	  [t release];
	}
    }
  [_lock unlock];
}

- (void) setUserInfo: (NSObject*)info forRequest: (GSMimeDocument*)request
{
  WebServerHeader	*h;

  h = [WebServerHeaderClass alloc];
  h = [h initWithType: WSHExtra andObject: info];
  [request addHeader: h];
  [h release];
}

- (void) setVerbose: (BOOL)aFlag
{
  if (aFlag != _conf->verbose)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->verbose = aFlag;
      if (YES == aFlag)
	{
	  c->durations = YES;
	}
      [_conf release];
      _conf = c;
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

- (NSObject*) userInfoForRequest: (GSMimeDocument*)request
{
  id	o = [request headerNamed: @"mime-version"];

  if (object_getClass(o) == WebServerHeaderClass)
    {
      return [o webServerExtra];
    }
  return nil;
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
  NSString	*msg = [connection audit];

  /* We only generate the audit log if the connection returns one to be
   * reported.
   */
  if (nil != msg)
    {
      if (YES == _doAudit)
	{
	  [_delegate webAudit: msg for: self];
	}
      else
	{
	  fprintf(stderr, "%s\r\n", [msg UTF8String]);
	} 
    }
}

- (void) _didConnect: (NSNotification*)notification
{
  NSDictionary		*userInfo = [notification userInfo];
  NSFileHandle		*hdl;

  _accepting = NO;
  _ticked = [NSDateClass timeIntervalSinceReferenceDate];
  hdl = [userInfo objectForKey: NSFileHandleNotificationFileHandleItem];
  if (hdl == nil)
    {
      /* Try to allow more connections to be accepted.
       */
      [self _listen];
      NSLog(@"[%@ -%@] missing handle ... %@",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd), userInfo);
    }
  else
    {
      WebServerConnection	*connection;
      NSString			*address;
      NSString			*refusal;
      BOOL			quiet;
      BOOL			ssl;
      IOThread			*ioThread = nil;
      NSUInteger		counter;
      NSUInteger		ioConns = NSNotFound;

      [_lock lock];
      if (nil == _sslConfig)
	{
	  ssl = NO;
	}
      else
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
	  ssl = YES;
	}

      address = [hdl socketAddress];
      if (nil == address)
	{
	  refusal = @"HTTP/1.0 403 Unable to determine client host address";
	}
      else if (_hosts != nil && [_hosts containsObject: address] == NO)
	{
	  refusal = @"HTTP/1.0 403 Not a permitted client host";
	}
      else if (_maxConnections > 0
        && [_connections count] >= _maxConnections)
	{
	  refusal =  @"HTTP/1.0 503 Too many existing connections";
	}
      else if (_maxPerHost > 0
	&& [_perHost countForObject: address] >= _maxPerHost)
	{
	  refusal = @"HTTP/1.0 503 Too many existing connections from host";
	}
      else
	{
	  refusal = nil;
	}
      quiet = [_quiet containsObject: address];

      /* Find the I/O thread handling the fewest connections and use that.
       */
      counter = [_ioThreads count];
      while (counter-- > 0)
	{
	  IOThread	*tmp = [_ioThreads objectAtIndex: counter];
	  NSUInteger	c;

	  c = tmp->readwrites->count
	    + tmp->handshakes->count
	    + tmp->processing->count;
	  if (c < ioConns)
	    {
	      ioThread = tmp;
	      ioConns = c;
	    }
	}
      if (nil == ioThread)
	{
	  ioThread = _ioMain;
	}

      connection = [WebServerConnection alloc]; 
      connection = [connection initWithHandle: hdl
				     onThread: ioThread
					  for: self
				      address: address
				       config: _conf
					quiet: quiet
					  ssl: ssl
				      refusal: refusal];
      [connection setTicked: _ticked];
      [connection setConnectionStart: _ticked];

      [_connections addObject: connection];
      [connection release];	// Retained in _connections map
      [_perHost addObject: address];
      [_lock unlock];

      /* Ensure we always have an 'accept' in progress unless we are already
       * handling the maximum number of connections.
       */
      [self _listen];

      /* Start the connection I/O on the correct thread.
       */
      [connection performSelector: @selector(start)
			 onThread: ioThread->thread
		       withObject: nil
		    waitUntilDone: NO];
    }
}

- (void) _endConnect: (WebServerConnection*)connection
{
  [_lock lock];
  /* Clear the response so any completion attempt will fail.
   */
  [(WebServerResponse*)[connection response] setWebServerConnection: nil];
  if (NO == [connection quiet])
    {
      [self _audit: connection];
      _handled++;
    }
  [_perHost removeObject: [connection address]];
  [_connections removeObject: connection];
  [_lock unlock];
  [self _listen];
}

- (void) _listen
{
  [_lock lock];
  if (_accepting == NO && (_maxConnections == 0
    || [_connections count] < (_maxConnections + _reject)))
    {
      _accepting = YES;
      [_lock unlock];
      [_listener performSelectorOnMainThread:
	@selector(acceptConnectionInBackgroundAndNotify)
	withObject: nil
	waitUntilDone: NO];
    }
  else
    {
      [_lock unlock];
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

- (void) _process1: (WebServerConnection*)connection
{
  NSFileHandle		*h;
  GSMimeDocument	*request;
  WebServerResponse	*response;
  NSString		*str;
  NSString		*con;

  [_lock lock];
  _processingCount++;
  [_lock unlock];

  request = [connection request];
  response = [connection response];
  [connection setExcess: [[connection parser] excess]];

  /*
   * Provide information and update the shared process statistics.
   */
  [request addHeader: _xCountRequests];
  [request addHeader: _xCountConnections];
  [request addHeader: _xCountConnectedHosts];
  h = [connection handle];
  str = [h socketAddress];
  str = [NSStringClass stringWithFormat: @"%u", [_perHost countForObject: str]];
  [request setHeader: @"x-count-host-connections"
	       value: str
	  parameters: nil];

  [connection setProcessing: YES];
  [connection setAgent: [[request headerNamed: @"user-agent"] value]];

  /*
   * If the client specified that the connection should close, we don't
   * keep it open.
   */
  con = [[request headerNamed: @"connection"] value]; 
  if (con != nil)
    {
      con = [con lowercaseString];
      if ([con compare: @"keep-alive"] == NSOrderedSame)
	{
	  [connection setShouldClose: NO];	// Persistent (even in HTTP 1.0)
	  [response setHeader: @"Connection"
		        value: @"Keep-Alive"
		   parameters: nil];
	}
      else if ([con compare: @"close"] == NSOrderedSame)
	{
	  [connection setShouldClose: YES];	// Not persistent.
	}
      else if ([con length] > 5)
	{
	  NSEnumerator	*e;

	  e = [[con componentsSeparatedByString: @","] objectEnumerator];
	  while (nil != (con = [e nextObject]))
	    {
	      con = [con stringByTrimmingSpaces];
	      if ([con compare: @"keep-alive"] == NSOrderedSame)
		{
		  [connection setShouldClose: NO];
		  [response setHeader: @"Connection"
				value: @"Keep-Alive"
			   parameters: nil];
		}
	      else if ([con compare: @"close"] == NSOrderedSame)
		{
		  [connection setShouldClose: YES];
		}
	    }
	}
    }

  /*
   * Provide more information about the connection.
   */
  [request setHeader: @"x-local-address"
	       value: [h socketLocalAddress]
	  parameters: nil];
  [request setHeader: @"x-local-port"
	       value: [h socketLocalService]
	  parameters: nil];
  [request setHeader: @"x-remote-address"
	       value: [h socketAddress]
	  parameters: nil];
  [request setHeader: @"x-remote-port"
	       value: [h socketService]
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
      [_lock lock];
      _requests++;
      [_lock unlock];
      if (YES == _conf->verbose)
	{
	  [self _log: @"Request %@ - %@", connection, request];
	}
    }

  if (YES == _doPreProcess)
    {
      [_pool scheduleSelector: @selector(_process2:)
		   onReceiver: self
		   withObject: connection];
    }
  else if (YES == _doProcess)
    {
      [self performSelectorOnMainThread: @selector(_process3:)
			     withObject: connection
			  waitUntilDone: NO];
    }
  else
    {
      NSLog(@"No delegate to process or pre-process request");
      [response setHeader: @"http"
		    value: @"HTTP/1.0 500 Internal Server Error"
	       parameters: nil];
      [self completedWithResponse: response];
    }
}

/* Perform any pre-processing.
 */
- (void) _process2: (WebServerConnection*)connection
{
  GSMimeDocument	*request;
  WebServerResponse	*response;
  BOOL			processed = YES;

  request = [connection request];
  response = [connection response];

  NS_DURING
    {
      [connection setTicked: _ticked];
      if ([self accessRequest: request response: response] == YES)
	{
	  processed = [_delegate preProcessRequest: request
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
      /* Request was completed at the pre-processing stage ... don't process
       */
      [self completedWithResponse: response];
    }
  else if (YES == _doProcess)
    {
      /* OK ... now process in main thread.
       */
      [self performSelectorOnMainThread: @selector(_process3:)
			     withObject: connection
			  waitUntilDone: NO];
    }
  else
    {
      NSLog(@"No delegate to process request");
      [response setHeader: @"http"
		    value: @"HTTP/1.0 500 Internal Server Error"
	       parameters: nil];
      [self completedWithResponse: response];
    }
}

/* Perform main processing.
 */
- (void) _process3: (WebServerConnection*)connection
{
  GSMimeDocument	*request;
  WebServerResponse	*response;
  BOOL			processed = YES;

  request = [connection request];
  response = [connection response];

  NS_DURING
    {
      [connection setTicked: _ticked];
      processed = [_delegate processRequest: request
				   response: response
					for: self];
      _ticked = [NSDateClass timeIntervalSinceReferenceDate];
      [connection setTicked: _ticked];
    }
  NS_HANDLER
    {
      [self _alert: @"Exception %@, processing %@", localException, request];
      [response setHeader: @"http"
		    value: @"HTTP/1.0 500 Internal Server Error"
	       parameters: nil];
      [connection setShouldClose: YES];	// Not persistent.
    }
  NS_ENDHANDLER

  if (processed == YES)
    {
      [self completedWithResponse: response];
    }
  else
    {
      // Delegate will complete processing later.
    }
}

/* Perform post processing.
 */
- (void) _process4: (WebServerResponse*)response
{
  GSMimeDocument	*request;
  WebServerConnection	*connection;

  [_lock lock];
  connection = [[response webServerConnection] retain];
  [_lock unlock];

  if (nil == response)
    {
      NSLog(@"Late response %@", response);
    }
  request = [connection request];

  NS_DURING
    {
      [connection setTicked: _ticked];
      [_delegate postProcessRequest: request
		           response: response
			        for: self];
      _ticked = [NSDateClass timeIntervalSinceReferenceDate];
      [connection setTicked: _ticked];
    }
  NS_HANDLER
    {
      [self _alert: @"Exception %@, processing %@", localException, request];
      [response setHeader: @"http"
		    value: @"HTTP/1.0 500 Internal Server Error"
	       parameters: nil];
      [connection setShouldClose: YES];	// Not persistent.
    }
  NS_ENDHANDLER

  [_lock lock];
  _processingCount--;
  [_lock unlock];
  [_pool scheduleSelector: @selector(respond)
	       onReceiver: connection
	       withObject: nil];
  [connection release];
}

- (NSString*) _xCountRequests
{
  NSString	*str;

  [_lock lock];
  str = [NSStringClass stringWithFormat: @"%u", _processingCount];
  [_lock unlock];
  return str;
}

- (NSString*) _xCountConnections
{
  NSString	*str;

  [_lock lock];
  str = [NSStringClass stringWithFormat: @"%u", [_connections count]];
  [_lock unlock];
  return str;
}

- (NSString*) _xCountConnectedHosts
{
  NSString	*str;

  [_lock lock];
  str = [NSStringClass stringWithFormat: @"%u", [_perHost count]];
  [_lock unlock];
  return str;
}

@end

@implementation	WebServerConfig
- (id) copyWithZone: (NSZone*)z
{
  WebServerConfig	*c;

  c = (WebServerConfig*)NSCopyObject(self, 0, z);
  c->permittedMethods = [c->permittedMethods copy];
  return c;
}
- (void) dealloc
{
  [permittedMethods release];
  [super dealloc];
}
@end

@implementation	IOThread

- (void) dealloc
{
  [thread release];
  [processing release];
  [handshakes release];
  [readwrites release];
  [keepalives release];
  [threadLock release];
  [super dealloc];
}

- (NSString*) description
{
  NSString	*s;

  [threadLock lock];
  s = [NSString stringWithFormat:
    @"%@ readwrites: %u, handshakes: %u, processing: %u",
    [super description],
    (unsigned)readwrites->count,
    (unsigned)handshakes->count,
    (unsigned)processing->count];
  [threadLock unlock];
  return s;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      processing = [GSLinkedList new];
      handshakes = [GSLinkedList new];
      readwrites = [GSLinkedList new];
      keepalives = [GSLinkedList new];
      keepaliveMax = 100;
      threadLock = [NSLock new];
    }
  return self;
}

- (void) run
{
  thread = [NSThread currentThread];
  /* We need a timer so that the run loop will run forever (or at least
   * until the timer is invalidated).
   * This is also used to handle connection timeouts on this thread.
   */
  timer = [NSTimer scheduledTimerWithTimeInterval: 0.8
					   target: self
					 selector: @selector(timeout:)
					 userInfo: 0
					  repeats: YES];
  [[NSRunLoop currentRunLoop] run];
}

- (void) timeout: (NSTimer*)t
{
  NSTimeInterval	now = [NSDateClass timeIntervalSinceReferenceDate];
  NSMutableArray	*ended = nil;
  NSTimeInterval	age;
  WebServerConnection	*con;

  [threadLock lock];

  /* Find any connections which have timed out waiting for I/O
   */
  age = now - cTimeout;
  for (con = (id)readwrites->head; nil != con; con = (id)con->next)
    {
      if (age > con->ticked)
	{
	  if (nil == ended)
	    {
	      ended = [NSMutableArray new];
	    }
	  [ended addObject: con];
	}
      else
	{
	  break;
	}
    }
  for (con = (id)keepalives->head; nil != con; con = (id)con->next)
    {
      if (age > con->ticked)
	{
	  if (nil == ended)
	    {
	      ended = [NSMutableArray new];
	    }
	  [ended addObject: con];
	}
      else
	{
	  break;
	}
    }

  /* Find any connections which have timed out waiting for SSL
   * handshake (allows 30 seconds more than basic timeout).
   */
  age -= 30.0;
  for (con = (id)handshakes->head; nil != con; con = (id)con->next)
    {
      if (age > con->ticked)
	{
	  if (nil == ended)
	    {
	      ended = [NSMutableArray new];
	    }
	  [ended addObject: con];
	}
      else
	{
	  break;
	}
    }

  /* Find any connections which have timed out waiting for processing.
   * We allow five minutes for processing (270 seconds more than for
   * SSL handshakes).
   */
  age -= 270.0;
  for (con = (id)processing->head; nil != con; con = (id)con->next)
    {
      if (age > con->ticked)
	{
	  if (nil == ended)
	    {
	      ended = [NSMutableArray new];
	    }
	  [ended addObject: con];
	}
      else
	{
	  break;
	}
    }
  [threadLock unlock];

  if (nil != ended)
    {
      NSEnumerator	*e = [ended objectEnumerator];

      [ended release];
      while (nil != (con = [e nextObject]))
	{
	  if (con->owner == processing)
	    {
	      [server _alert: @"%@ abort after %g seconds to process %@",
		con, now - con->extended, [con request]];
	    }
	  if (YES == [con verbose] && NO == [con quiet])
	    {
	      if (con->ticked > 0.0)
		{
	          [server _log: @"Connection timed out - %@", con];
		}
	      else
		{
	          [server _log: @"Connection shut down - %@", con];
		}
	    }
	  [con end];
	}
    }
}
@end

