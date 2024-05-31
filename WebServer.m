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

#import <Foundation/Foundation.h>
#import <Performance/GSThreadPool.h>

#define WEBSERVERINTERNAL       1

#import "WebServer.h"
#import "Internal.h"

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
static	Class	WebServerResponseClass = Nil;
static NSZone	*defaultMallocZone = 0;
static NSSet	*defaultPermittedMethods = nil;

#define	Alloc(X)	[(X) allocWithZone: defaultMallocZone]

static void
untrusted(WebServerRequest *request, NSString *key, NSMutableArray **array)
{
  if (nil != [[request headerNamed: key] value])
    {
      if (nil == *array)
	{
	  *array = [NSMutableArray array];
	}
      [*array addObject: key];
      [request deleteHeaderNamed: key];
    }
}

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
      WebServerResponseClass = [WebServerResponse class];
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

+ (NSURL*) baseURLForRequest: (WebServerRequest*)request
{
  NSString	*host = [request address];
  NSString	*scheme = [[request headerNamed: @"x-http-scheme"] value];
  NSString	*path = [[request headerNamed: @"x-http-path"] value];
  NSString	*query = [[request headerNamed: @"x-http-query"] value];
  NSString	*str;
  NSURL		*url;

  if (nil == host)
    {
      host = [[request headerNamed: @"host"] value];
    }

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

      if (escape)
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
		      format: @"Bad UTF-8 form data (key of field %"PRIuPTR")",
            fields];
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

  /* RFC3986 says that alphanumeric, hyphen, dot, underscore and tilde
   * are the only characters that should not be escaped in a URL.
   */

  [d setLength: dpos + 3 * length];
  dst = (uint8_t *)[d mutableBytes];
  while (spos < length)
    {
      uint8_t		c = bytes[spos++];

      if (isalnum(c) || '-' == c || '.' == c || '_' == c || '~' == c)
        {
          dst[dpos++] = c;
        }
      else
	{
          uint8_t	hi;
          uint8_t	lo;

          dst[dpos++] = '%';
          hi = (c & 0xf0) >> 4;
          dst[dpos++] = (hi > 9) ? 'A' + hi - 10 : '0' + hi;
          lo = (c & 0x0f);
          dst[dpos++] = (lo > 9) ? 'A' + lo - 10 : '0' + lo;
	}
    }
  [d setLength: dpos];
  return d;
}

+ (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
                            charset: (NSString*)charset
			       into: (NSMutableData*)data
{
  CREATE_AUTORELEASE_POOL(arp);
  NSEnumerator		*keyEnumerator;
  NSStringEncoding      enc;
  id			key;
  NSUInteger		valueCount = 0;
  NSMutableData		*md = [NSMutableDataClass dataWithCapacity: 100];

  if (nil == charset)
    {
      enc = NSUTF8StringEncoding;
    }
  else
    {
      enc = [GSMimeDocument encodingFromCharset: charset];
      if (GSUndefinedEncoding == enc)
        {
          enc = NSUTF8StringEncoding;
        }
    }

  keyEnumerator = [dict keyEnumerator];
  while ((key = [keyEnumerator nextObject]) != nil)
    {
      id		values = [dict objectForKey: key];
      NSData		*keyData;
      NSEnumerator	*valueEnumerator;
      id		value;

      if ([key isKindOfClass: NSDataClass])
	{
	  keyData = key;
	}
      else
	{
	  key = [key description];
	  keyData = [key dataUsingEncoding: enc];
          if (nil == keyData)
            {
              keyData = [key dataUsingEncoding: NSUTF8StringEncoding];
            }
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
	  if ([value isKindOfClass: NSDataClass])
	    {
	      valueData = value;
	    }
	  else
	    {
	      value = [value description];
	      valueData = [value dataUsingEncoding: enc];
              if (nil == valueData)
                {
                  valueData = [value dataUsingEncoding: NSUTF8StringEncoding];
                }
	    }
	  escapeData([valueData bytes], [valueData length], data);
	  valueCount++;
	}
    }
  RELEASE(arp);
  return valueCount;
}

+ (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
			       into: (NSMutableData*)data
{
  return [self encodeURLEncodedForm: dict
                            charset: nil
			       into: data];
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

  if (escape)
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
	  uint32_t	want;
  
	  if (0 == r.length)
	    {
	      /* An IPv4 address in dot format (nnn.nnn.nnn.nnn)
	       */
	      parts = [pattern componentsSeparatedByString: @"."];
	      want = [[parts objectAtIndex: 0] intValue];
	      want = want * 256 + [[parts objectAtIndex: 1] intValue];
	      want = want * 256 + [[parts objectAtIndex: 2] intValue];
	      want = want * 256 + [[parts objectAtIndex: 3] intValue];
	      if (remote == want)
		{
		  return YES;
		}
	    }
	  else
	    {
	      int           bits;
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
      [self encodeURLEncodedForm: m charset: nil into: data];
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

+ (BOOL) redirectRequest: (WebServerRequest*)request
		response: (WebServerResponse*)response
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
  body = [NSString stringWithFormat:
    @"<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
    @"<html><head><title>continue</title>"
    @"</head><body><a href=\"%@\">continue</a></body></html>",
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
          if ([s isEqualToString: @"text/html"]
            || [s isEqualToString: @"text/xhtml"]
            || [s isEqualToString: @"application/xhtml+xml"]
            || [s isEqualToString: @"application/vnd.wap.xhtml+xml"]
            || [s isEqualToString: @"text/vnd.wap.wml"])
            {
              type = s;
	      break;
            }
        }
    }
  [response setContent: body type: type];
  return YES;
}

- (BOOL) accessRequest: (WebServerRequest*)request
	      response: (WebServerResponse*)response
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

- (NSString*) address
{
  NSString      *s;

  [_lock lock];
  s = [_addr retain];
  [_lock unlock];
  return [s autorelease];
}

- (NSTimeInterval) authenticationFailureBanTime
{
  return _authFailureBanTime;
}

- (NSUInteger) authenticationFailureMaxRetry
{
  return _authFailureMaxRetry;
}

- (NSTimeInterval) authenticationFailureFindTime
{
  return _authFailureFindTime;
}

- (void) closeConnectionAfter: (WebServerResponse*)response
{
  [_lock lock];
  [[response webServerConnection] setShouldClose: YES];
  [_lock unlock];
}

- (void) completedWithResponse: (WebServerResponse*)response
{
  if (NO == [response isKindOfClass: WebServerResponseClass])
    {
      [NSException raise: NSInvalidArgumentException
        format: @"[%@-%@] argument is not a valid response object",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (YES == [response completing])
    {
      [NSException raise: NSInvalidArgumentException
        format: @"[%@-%@] argument is already completing",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (YES == _doPostProcess)
    {
      [_pool scheduleSelector: @selector(_process4:)
		   onReceiver: self
		   withObject: response];
    }
  else
    {
      WebServerConnection	*connection = nil;
      BOOL                      wasCompleting;

      [_lock lock];
      wasCompleting = [response completing];
      if (NO == wasCompleting)
        {
          [response setCompleting];
          _processingCount--;
          connection = [[response webServerConnection] retain];
        }
      [response setWebServerConnection: nil];
      [_lock unlock];
      if (YES == wasCompleting)
        {
          if (YES == _conf->verbose)
            {
              [self _log: @"Called -completedWithResponse: for a response"
                @" which is already complete: %@", response];
            }
        }
      else if (nil == connection)
	{
          if (YES == _conf->verbose)
            {
              [self _log: @"The client has already closed the connection"
                @" for response: %@", response];
            }
	}
      else
	{
	  [_pool scheduleSelector: @selector(respond:)
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
  [self setAddress: nil port: nil secure: nil];
  [self setIOThreads: 0 andPool: 0];
  DESTROY(_authFailureLog);
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
  DESTROY(_userInfoMap);
  DESTROY(_incrementalDataMap);
  DESTROY(_userInfoLock);
  DESTROY(_incrementalDataLock);
  DESTROY(_connections);
  [super dealloc];
}

- (NSUInteger) decodeURLEncodedForm: (NSData*)data
			       into: (NSMutableDictionary*)dict
{
  return [[self class] decodeURLEncodedForm: data into: dict];
}

- (id) delegate
{
  return _delegate;
}

- (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
                            charset: (NSString*)charset
			       into: (NSMutableData*)data
{
  return [[self class] encodeURLEncodedForm: dict charset: charset into: data];
}

- (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
			       into: (NSMutableData*)data
{
  return [[self class] encodeURLEncodedForm: dict charset: nil into: data];
}

- (NSString*) escapeHTML: (NSString*)str
{
  return [[self class] escapeHTML: str];
}

- (NSString*) description
{
  NSString	        *result;
  NSUInteger	        active;
  NSUInteger	        idle;
  NSUInteger 	        count;
  NSEnumerator          *e;
  NSString              *h;
  NSMutableString       *byHost;

  [_lock lock];

  idle = _ioMain->keepaliveCount;
  count = [_ioThreads count];
  while (count-- > 0)
    {
      IOThread	*tmp = [_ioThreads objectAtIndex: count];

      idle += tmp->keepaliveCount;
    }
  count = [_connections count];
  if (count > idle)
    {
      active = count - idle;
    }
  else
    {
      active = 0;
    }

  /* Build count of connections by host
   */
  byHost = [NSMutableString stringWithCapacity: 50 * count];
  [byHost appendString: @"("];
  e = [_perHost objectEnumerator];
  while (nil != (h = [e nextObject]))
    {
      if ([byHost length] > 1)
        {
          [byHost appendString: @","];
        }
      [byHost appendFormat: @"%@:%"PRIuPTR, h, [_perHost countForObject: h]];
    }
  [byHost appendString: @")"];

  result = [NSStringClass stringWithFormat: @"%@ on %@(%@),"
    @"\n  %"PRIuPTR" %@ of %"PRIuPTR" (%"PRIuPTR"/host) connections,"
    @"\n  %"PRIuPTR" active, %"PRIuPTR" idle, %"PRIuPTR" ended,"
    @" %"PRIuPTR " requests,"
    @" listening: %@%@%@",
    [super description], _port, ([self isSecure] ? @"https" : @"http"),
    count, byHost, _maxConnections, _maxPerHost, active, idle,
    _handled, _requests, _accepting ? @"yes" : @"no",
    [self _ioThreadDescription], [self _poolDescription]];
  [_lock unlock];
  return result;
}

- (NSData*) incrementalDataForRequest: (WebServerRequest*)request
{
  NSMutableData *m;
  NSData        *d;

  [_incrementalDataLock lock];
  m = [_incrementalDataMap objectForKey: request];
  if (0 == [m length])
    {
      d = nil;
    }
  else
    {
      d = [m copy];
      [m setLength: 0];
    }
  [_incrementalDataLock unlock];
  return [d autorelease];
}

- (id) init
{
  return [self initForThread: nil];
}

- (id) initForThread: (NSThread*)aThread
{
  if (NO == [aThread isKindOfClass: [NSThread class]])
    {
      aThread = [NSThread mainThread];
    }
  if (nil != (self = [super init]))
    {
      [self performSelector: @selector(_setup)
		   onThread: aThread
		 withObject: nil
	      waitUntilDone: YES];
    }
  return self;
}

- (BOOL) isCompletedRequest: (WebServerRequest*)request
{
  return [[[request headerNamed: @"x-webserver-completed"] value] boolValue];
}

- (BOOL) isSecure
{
  if (_sslConfig == nil)
    {
      return NO;
    }
  return YES;
}

- (BOOL) isTrusted
{
  return _conf->secureProxy;
}

- (NSString*) _poolDescription
{
  if (0 == [_pool maxThreads])
    {
      return @"";
    }
  return [NSString stringWithFormat: @"\nWorkers: %@", _pool];
}

- (BOOL) produceResponse: (WebServerResponse*)aResponse
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
            @"application/json", @"json",
            @"application/pdf", @"pdf",
	    @"image/gif", @"gif",
	    @"image/png", @"png",
	    @"image/jpeg", @"jpeg",
	    @"image/jpeg", @"jpg",
	    @"text/html", @"html",
	    @"text/plain", @"txt",
	    @"text/css", @"xml",
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
  if (NO == string && [type isEqualToString: @"application/json"])
    {
      string = YES;     // A JSON document is actually text
    }

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
  else if (YES == string
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
      if (YES == string)
        {
	  [[aResponse headerNamed: @"content-type"] setParameter: @"utf-8"
							  forKey: @"charset"];
        }
    }
  DESTROY(arp);
  return result;
}

- (BOOL) produceResponse: (WebServerResponse*)aResponse
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
      if (result)
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

- (NSMutableDictionary*) parameters: (WebServerRequest*)request
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
  if ([str isEqualToString: @"application/x-www-form-urlencoded"])
    {
      data = [request convertToData];
      [self decodeURLEncodedForm: data into: params];
    }
  else if ([str isEqualToString: @"multipart/form-data"])
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

- (NSString*) port
{
  NSString      *s;

  [_lock lock];
  s = [_port retain];
  [_lock unlock];
  return [s autorelease];
}

/* For internal use ... must be called in the main I/O thread.
 */
- (void) _setupIO: (NSArray*)a
{
  ENTER_POOL
  NSString		*anAddress = [a objectAtIndex: 0];
  NSString		*aPort = [a objectAtIndex: 1];
  NSDictionary		*secure = [a objectAtIndex: 2];
  BOOL			update = NO;
  NSMutableDictionary	*m;
  NSString		*s;

  if ([anAddress length] == 0)
    {
      anAddress = nil;
    }
  if (anAddress != _addr && [anAddress isEqual: _addr] == NO)
    {
      update = YES;
    }
  if ([aPort length] == 0)
    {
      aPort = nil;
    }
  if (aPort != _port && [aPort isEqual: _port] == NO)
    {
      update = YES;
    }
  if (NO == [secure isKindOfClass: [NSDictionary class]])
    {
      secure = nil;
    }
  m = AUTORELEASE([secure mutableCopy]);

  /* HSTS header support for security.
   */
  if ((s = [secure objectForKey: @"HSTS"]) != nil)
    {
      NSUInteger        seconds;

      seconds = (NSUInteger)[s integerValue];
      [self setStrictTransportSecurity: seconds];
      [m removeObjectForKey: @"HSTS"];
    }

  /* Whether we are hidden behind a proxy ensuring that extension
   * headers in requests can be trusted.
   */
  if ((s = [secure objectForKey: @"Proxy"]) != nil)
    {
      [self setSecureProxy: [s boolValue]];
      [m removeObjectForKey: @"Proxy"];
    }
  else
    {
      [self setSecureProxy: NO];
    }

  /* Check to see if we still have TLS related config.
   */
  if ([m count])
    {
      secure = AUTORELEASE([m copy]);
    }
  else
    {
      secure = nil;
    }
 
  if ((secure == nil && _sslConfig != nil)
    || (secure != nil && [secure isEqual: _sslConfig] == NO))
    {
      update = YES;
    }

  if (update)
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
      DESTROY(_addr);
      DESTROY(_port);
      if (nil == aPort)
	{
	  NSEnumerator		*enumerator;
	  WebServerConnection	*connection;
          NSDate                *limit = nil;

	  [_lock lock];
	  /* If we have been shut down (port is nil) then we want any
	   * outstanding connections to close down as soon as possible.
	   */
	  enumerator = [_connections objectEnumerator];
	  while ((connection = [enumerator nextObject]) != nil)
	    {
              if (nil == limit)
                {
                  limit = [NSDate dateWithTimeIntervalSinceNow: 30.0];
                }
	      [connection shutdown];
	    }
	  [_lock unlock];

          /* Wait for all connections to close.
           */
          while (nil != limit && [limit timeIntervalSinceNow] > 0.0)
            {
              [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                       beforeDate: limit];
              [_lock lock];
              if (0 == [_connections count])
                {
                  limit = nil;  // No more to close

                  /* Now that all connections which have been using them are
                   * closed, we can get rid of the headers which refer to us,
                   * so that we break retain cycles and can be deallocated if
                   * nothing else is using this instance.
                   */
                  DESTROY(_xCountRequests);
                  DESTROY(_xCountConnections);
                  DESTROY(_xCountConnectedHosts);
                }
              [_lock unlock];
            }
	}
      else
	{
	  _addr = [anAddress copy];
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
	      _listener = [NSFileHandle fileHandleAsServerAtAddress: _addr
							    service: _port
							   protocol: @"tcp"];
	    }

	  if (_listener == nil)
	    {
	      if (nil == _addr)
		{
		  [self _alert: @"Failed to listen on port %@", _port];
		}
	      else
		{
		  [self _alert: @"Failed to listen on %@:%@", _addr, _port];
		}
	      DESTROY(_addr);
	      DESTROY(_port);
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
  LEAVE_POOL
}
 
- (BOOL) setAddress: (NSString*)anAddress
	       port: (NSString*)aPort
	     secure: (NSDictionary*)secure
{
  BOOL		ok = YES;

  ENTER_POOL
  NSArray	*a;

  a = [NSArray arrayWithObjects:
    ((nil == anAddress) ? @"" : anAddress), 
    ((nil == aPort) ? @"" : aPort), 
    ((nil == secure) ? (id)@"" : (id)secure), 
    nil];

  [self performSelector: @selector(_setupIO:)
	       onThread: _ioMain->thread
	     withObject: a
	  waitUntilDone: YES];

  if ([aPort length] == 0)
    {
      aPort = nil;
    }
  if (nil != aPort && nil == _listener)
    {
      ok = NO;	// Failed to listen on port
    }
  LEAVE_POOL
  return ok;
}

- (void) setAuthenticationFailureBanTime: (NSTimeInterval)ti
{
  if (ti > 0.0)
    {
      _authFailureBanTime = ti;
    }
  else
    {
      _authFailureBanTime = 0.0;
    }
}

- (void) setAuthenticationFailureMaxRetry: (NSUInteger)max
{
  if (max > 0)
    {
      _authFailureMaxRetry = max;
    }
  else
    {
      _authFailureMaxRetry = 0;
    }
}

- (void) setAuthenticationFailureFindTime: (NSTimeInterval)ti
{
  if (ti > 0.0)
    {
      _authFailureFindTime = ti;
    }
  else
    {
      _authFailureFindTime = 1.0;
    }
  [_authFailureLog setFindTime: _authFailureFindTime];
}

- (void) setContinue: (BOOL)aFlag
{
  _doContinue = (aFlag ? YES : NO);
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
  _doIncremental = [_delegate respondsToSelector:
    @selector(incrementalRequest:for:)];
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
  [_pool setOperations: _maxConnections];
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
  [_pool setOperations: _maxConnections];
}

- (void) setMaxConnectionsReject: (BOOL)reject
{
  _reject = (reject ? 1 : 0);
}

- (void) setMaxKeepalives: (NSUInteger)max
{
  unsigned counter;

  /* Set the maximum number of keepalives per thread to be as specified
   */
  if (max > 1000)
    {
      max = 1000;
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
  return [self setAddress: nil port: aPort secure: secure];
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

- (void) setStrictTransportSecurity: (NSUInteger)seconds
{
  _strictTransportSecurity = seconds;
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

- (void) setFoldHeaders: (BOOL)aFlag
{
  if (NO != aFlag)
    {
      aFlag = YES;
    }
  if (aFlag != _conf->foldHeaders)
    {
      WebServerConfig	*c;

      c = [_conf copy];
      c->foldHeaders = aFlag;
      [_conf release];
      _conf = c;
    }
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
      unsigned  c;

      while ([_ioThreads count] > threads)
	{
	  IOThread	*t = [_ioThreads lastObject];

	  [t->timer invalidate];
	  [_ioThreads removeObjectIdenticalTo: t];
	}
      while ((c = [_ioThreads count]) < threads)
	{
	  IOThread	*t = [IOThread new];
          IOThread      *e[c];
          NSThread      *thread;
          unsigned      n = c + 1;

          [_ioThreads getObjects: e];
          for (;;)
            {
              int       j;

              for (j = 0; j < c; j++)
                {
                  if (e[j]->number == n)
                    {
                      break;
                    }
                }
              if (j < c)
                {
                  n--;  // Try another
                }
              else
                {
                  break;
                }
            }

	  t->number = n;
	  t->server = self;
	  t->cTimeout = _connectionTimeout;
	  t->keepaliveMax = _ioMain->keepaliveMax;
          thread = [[NSThread alloc] initWithTarget: t
                                           selector: @selector(run)  
                                             object: nil];
          [thread setName: [NSString stringWithFormat: @"websvrio-%u", n]];
          [thread start];
          [thread autorelease];
	  [_ioThreads addObject: t];
	  [t release];
	}
    }
  [_lock unlock];
}

- (void) setLogRawIO: (BOOL)aFlag
{
  if (aFlag != _conf->logRawIO)
    {
      WebServerConfig	*c = [_conf copy];
  
      c->logRawIO = aFlag;
      [_conf release];
      _conf = c;
    }
}

- (void) setSubstitutionLimit: (NSUInteger)depth
{
  _substitutionLimit = depth;
}

- (void) setUserInfo: (NSObject*)info forRequest: (WebServerRequest*)request
{
  if (nil != info && NO == [info isKindOfClass: [NSObject class]])
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"[%@-%@] bad info argument",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (NO == [request isKindOfClass: [WebServerRequest class]])
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"[%@-%@] bad request argument",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  [_userInfoLock lock];
  if (nil == info)
    {
      [_userInfoMap removeObjectForKey: request];
    }
  else
    {
      [_userInfoMap setObject: info forKey: request];
    }
  [_userInfoLock unlock];
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

- (BOOL) streamData: (NSData*)data withResponse: (WebServerResponse*)response
{
  WebServerConnection	*connection;

  if (NO == [data isKindOfClass: [NSData class]] || 0 == [data length])
    {
      [NSException raise: NSInvalidArgumentException
        format: @"[%@-%@] data argument is not valid for streaming",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (NO == [response isKindOfClass: WebServerResponseClass])
    {
      [NSException raise: NSInvalidArgumentException
        format: @"[%@-%@] argument is not a valid response object",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }

  [_lock lock];
  connection = [[response webServerConnection] retain];
  [_lock unlock];
  if (nil == connection)
    {
      if (YES == _conf->verbose)
        {
          [self _log: @"The client has already closed the connection"
            @" for response: %@", response];
        }
      return NO;
    }
  else
    {
      [_pool scheduleSelector: @selector(respond:)
                   onReceiver: connection
                   withObject: data];
      [connection release];
      return YES;
    }
}

- (NSUInteger) strictTransportSecurity
{
  return _strictTransportSecurity;
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

- (GSThreadPool*) threadPool
{
  return _pool;
}

- (NSObject*) userInfoForRequest: (WebServerRequest*)request
{
  NSObject      *o;

  [_userInfoLock lock];
  o = [[_userInfoMap objectForKey: request] retain];
  [_userInfoLock unlock];
  return [o autorelease];
}

@end

@implementation	WebServer (Private)


- (void) _alert: (NSString*)fmt, ...
{
  va_list	args;

  va_start(args, fmt);
  if ([_delegate respondsToSelector: @selector(webAlert:for:)])
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

- (void) _blockAddress: (NSString*)address forInterval: (NSTimeInterval)ti
{
  if (_authFailureBanTime <= 0.0)
    {
      return;
    }

  if (nil == _authFailureLog)
    {
      _authFailureLog = [WebServerAuthenticationFailureLog new];
      [_authFailureLog setFindTime: _authFailureFindTime];
    }

  /* For a bad time interval, we use the value set for authentication failures.
   */
  if (ti < 0.0)
    {
      ti = _authFailureBanTime;
    }
  
  if (ti > 0.0)
    {
      [_authFailureLog addFailureForAddress: address
                                    banTime: ti];
    }
  else
    {
      [_authFailureLog removeFailuresForAddress: address];
    }
}

- (NSDate*) _blocked: (NSString*)address
{
  NSDate        *until;
  NSUInteger    count;

  if (_authFailureBanTime <= 0.0)
    {
      return nil;
    }

  if (nil != (until = [_authFailureLog isBanned: address]))
    {
      return until;
    }

  count = [_authFailureLog failureCountForAddress: address
                                       blockUntil: &until];
  if (count > _authFailureMaxRetry)
    {
      if (nil != until && [until timeIntervalSinceNow] <= 0.0)
        {
          until = nil;
        }
    }
  else
    {
      until = nil;
    }

  if (nil != until)
    {
      [_authFailureLog banAddress: address until: until];
    }

  return until;
}

- (void) _completedResponse: (WebServerResponse*)r duration: (NSTimeInterval)t
{
  if ([_delegate respondsToSelector: @selector(completedResponse:duration:)])
    {
      [_delegate completedResponse: r duration: t];
    }
}

/* Adjust the per-host connection count, returning YES
 * if this causes the server to exceed the per-host limit.
 * This is used only where the connection is from a
 * trusted proxy.
 */
- (BOOL) _connection: (WebServerConnection*)conn
  changedAddressFrom: (NSString*)oldAddress
{
  NSString      *newAddress = [conn address];
  BOOL		excessive = NO;

  [_lock lock];
  [_perHost removeObject: oldAddress];
  [_perHost addObject: newAddress];
  if (_maxPerHost > 0
    && [_perHost countForObject: newAddress] > _maxPerHost)
    {
      excessive = YES;
    }
  [conn setQuiet:
    [[_defs arrayForKey: @"WebServerQuiet"] containsObject: newAddress]];
  [_lock unlock];

  return excessive;
}

- (int) _continue: (WebServerConnection*)connection
{
  if ([_delegate respondsToSelector: @selector(continueRequest:response:for:)])
    {
      WebServerRequest	*request = [connection request];
      WebServerResponse	*template = [connection response];
      WebServerResponse	*response;

      [template setHeader: @"http"
		    value: @"HTTP/1.0 417 Expectation failed"
	       parameters: nil];
      response = [_delegate continueRequest: request
				   response: template
				        for: self];
      if (response)
	{
	  [self completedWithResponse: response];
	  return 0;	// Do not continue the request
	}
      [template deleteHeaderNamed: @"http"];
      return 1;		// Send '100 continue'
    }
  else
    {
      if (_doContinue)
	{
	  return 1;	// Send '100 continue'
	}
      return -1;	// Ignore the expect header
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
      NSArray                   *hosts;
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
          NSMutableDictionary   *options = [NSMutableDictionary dictionary];
	  NSString	        *locAddr = [hdl socketLocalAddress];
	  NSDictionary	        *primary = [_sslConfig objectForKey: locAddr];
	  NSString	        *s;

	  if (nil == (s = [primary objectForKey: @"CAFile"]))
            {
              s = [_sslConfig objectForKey: @"CAFile"];
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSCAFile];
            }

	  if (nil == (s = [primary objectForKey: @"CertificateFile"]))
            {
              s = [_sslConfig objectForKey: @"CertificateFile"];
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSCertificateFile];
            }

	  if (nil == (s = [primary objectForKey: @"CertificateKeyFile"]))
            {
              if (nil == (s = [_sslConfig objectForKey: @"CertificateKeyFile"]))
                {
                  if (nil == (s = [primary objectForKey: @"KeyFile"]))
                    {
                      s = [_sslConfig objectForKey: @"KeyFile"];
                    }
                }
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSCertificateKeyFile];
            }

	  if (nil == (s = [primary objectForKey: @"CertificateKeyPassword"]))
            {
              if (nil
                == (s = [_sslConfig objectForKey: @"CertificateKeyPassword"]))
                {
                  if (nil == (s = [primary objectForKey: @"KeyPassword"]))
                    {
                      s = [_sslConfig objectForKey: @"KeyPassword"];
                    }
                }
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSCertificateKeyPassword];
            }

	  if (nil == (s = [primary objectForKey: @"Debug"]))
            {
              s = [_sslConfig objectForKey: @"Debug"];
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSDebug];
            }

	  if (nil == (s = [primary objectForKey: @"Priority"]))
            {
              s = [_sslConfig objectForKey: @"Priority"];
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSPriority];
            }

	  if (nil == (s = [primary objectForKey: @"RemoteHosts"]))
            {
              s = [_sslConfig objectForKey: @"RemoteHosts"];
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSRemoteHosts];
            }

	  if (nil == (s = [primary objectForKey: @"RevokeFile"]))
            {
              s = [_sslConfig objectForKey: @"RevokeFile"];
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSRevokeFile];
            }

	  if (nil == (s = [primary objectForKey: @"Verify"]))
            {
              s = [_sslConfig objectForKey: @"Verify"];
            }
          if (nil != s)
            {
              [options setObject: s forKey: GSTLSVerify];
            }

          if (nil == [options objectForKey: GSTLSCertificateFile])
            {
              /* No certificate supplied;  this is not a secure connection
               */
              ssl = NO;
            }
          else
            {
              [hdl sslSetOptions: options];
              ssl = YES;
            }
	}

      address = [hdl socketAddress];
      if (nil == address)
	{
	  refusal = @"HTTP/1.0 403 Unable to determine client host address";
          address = @"unknown";
	}
      else if (nil != (hosts = [_defs arrayForKey: @"WebServerHosts"])
        && [hosts containsObject: address] == NO)
	{
	  refusal = @"HTTP/1.0 403 Not a permitted client host";
	}
      else if (_maxConnections > 0
        && [_connections count] >= _maxConnections)
	{
	  refusal =  @"HTTP/1.0 503 Too many existing connections";
	}
      else if (_maxPerHost > 0 && NO == [self isTrusted]
	&& [_perHost countForObject: address] >= _maxPerHost)
	{
	  refusal = @"HTTP/1.0 503 Too many existing connections from host";
	}
      else
	{
	  refusal = nil;
	}
      quiet = [[_defs arrayForKey: @"WebServerQuiet"] containsObject: address];

      /* Record the new connection by the remote host IP address.
       * This may be adjusted as requests arrive for a proxied connection.
       */
      [_perHost addObject: address];

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
				       config: _conf
					quiet: quiet
					  ssl: ssl
				      refusal: refusal];
      [connection setTicked: _ticked];
      [connection setConnectionStart: _ticked];
      [_connections addObject: connection];
      [connection release];	// Retained in _connections map
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
  [[connection response] setWebServerConnection: nil];
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

- (void) _listen
{
  [_lock lock];
  if (_accepting == NO && (_maxConnections == 0
    || [_connections count] < (_maxConnections + _reject)))
    {
      _accepting = YES;
      [_lock unlock];
      [_listener performSelector:
	@selector(acceptConnectionInBackgroundAndNotify)
	onThread: _ioMain->thread
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
  if ([_delegate respondsToSelector: @selector(webLog:for:)])
    {
      NSString	*s;

      s = [NSStringClass stringWithFormat: fmt arguments: args];
      [_delegate webLog: s for: self];
    }
  va_end(args);
}

/* This is called from the _process1: and _incremental: methods, both of
 * which must only be called from the connection I/O thread.  That makes
 * it safe for this method to modify the state of the connection.
 */
- (void) _prepareRequest: (WebServerRequest*)request
                response: (WebServerResponse*)response
          withConnection: (WebServerConnection*)connection
{
  NSFileHandle  *handle = [connection handle];
  NSString	*str;
  NSString	*con;

  /*
   * Provide information and update the shared process statistics.
   */
  [request setHeader: _xCountRequests];
  [request setHeader: _xCountConnections];
  [request setHeader: _xCountConnectedHosts];
  str = [connection address];
  str = [NSStringClass stringWithFormat: @"%"PRIuPTR,
    [_perHost countForObject: str]];
  [request setHeader: @"x-count-host-connections"
	       value: str
	  parameters: nil];

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
	       value: [connection localAddress]
	  parameters: nil];
  [request setHeader: @"x-local-port"
	       value: [connection localPort]
	  parameters: nil];
  [request setHeader: @"x-remote-address"
	       value: [connection remoteAddress]
	  parameters: nil];
  [request setHeader: @"x-remote-port"
	       value: [connection remotePort]
	  parameters: nil];

  if (YES == _conf->secureProxy)
    {
      NSString  *s;

      /* Find the protocol of the request coming in to the proxy.
       * The proxy may provide that in the X-Forwarded-Proto header.
       */
      s = [[request headerNamed: @"x-forwarded-proto"] value];
      if (nil != s)
        {
          [request setHeader: @"x-http-scheme"
                       value: s
                  parameters: nil];
        }

      s = [[request headerNamed: @"forwarded"] value];
      if (nil != s)
        {
          NSRange       r = [s rangeOfString: @"proto"];

          /* The value from 'Forwarded' overrided that from 'X-Forwarded-Proto'
           */
          if (r.length > 0)
            {
              s = [s substringFromIndex: NSMaxRange(r)];
              s = [s stringByTrimmingSpaces];
              if ([s hasPrefix: @"="])
                {
                  s = [s substringFromIndex: 1];
                  s = [s stringByTrimmingSpaces];
                  r = [s rangeOfString: @";"];
                  if (r.length > 0)
                    {
                      s = [s substringToIndex: r.location];
                    }
                  s = [s stringByReplacingString: @"\"" withString: @""];
                  [request setHeader: @"x-http-scheme"
                               value: s
                          parameters: nil];
                }
            }
        }
    }
  else
    {
      NSMutableArray	*a = nil;

      untrusted(request, @"x-cert-issuer", &a);
      untrusted(request, @"x-cert-owner", &a);

      if (nil != a)
	{
	  [self _log: @"Secure Proxy configuration not set;"
	    @" Removed untrusted header information %@ from %@",
	    a, request];
	}
    }

  if ([handle respondsToSelector: @selector(sslIssuer)])
    {
      NSString  *s;

      if (nil != (s = [handle performSelector: @selector(sslIssuer)]))
        {
          if (nil == [request headerNamed: @"x-cert-issuer"])
            {
              [request setHeader: @"x-cert-issuer"
                           value: s
                      parameters: nil];
            }
          else
            {
              [request setHeader: @"x-cert-issuer-proxy"
                           value: s
                      parameters: nil];
            }
        }
      if (nil != (s = [handle performSelector: @selector(sslOwner)]))
        {
          if (nil == [request headerNamed: @"x-cert-owner"])
            {
              [request setHeader: @"x-cert-owner"
                           value: s
                      parameters: nil];
            }
          else
            {
              [request setHeader: @"x-cert-owner-proxy"
                           value: s
                      parameters: nil];
            }
        }
    }

  str = [[request headerNamed: @"authorization"] value];
  if ([str length] > 6 && [[str substringToIndex: 6] caseInsensitiveCompare:
    @"Basic "] == NSOrderedSame)
    {
      str = [[str substringFromIndex: 6] stringByTrimmingSpaces];
      str = [GSMimeDocumentClass decodeBase64String: str];
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
  [response setPrepared];
}

- (uint32_t) _incremental: (WebServerConnection*)connection
{
  WebServerRequest	*request;
  WebServerResponse	*response;

  request = [connection request];
  response = [connection response];
  if (NO == [response prepared])
    {
      [self _prepareRequest: request
                   response: response
             withConnection: connection];
    }

  if (YES == _doIncremental)
    {
      uint32_t  i = [_delegate incrementalRequest: request for: self];

      if (i > 1024 * 1024)
        {
          i = 1024 * 1024;
        }
    }

  return 0;
}

- (void) _process1: (WebServerConnection*)connection
{
  WebServerRequest	*request;
  WebServerResponse	*response;

  request = [connection request];
  response = [connection response];
  if (NO == [response prepared])
    {
      [self _prepareRequest: request
                   response: response
             withConnection: connection];
    }

  [_lock lock];
  _processingCount++;
  [_lock unlock];

  [response setContent: [NSDataClass data] type: @"text/plain" name: nil];
  if (YES == [self isCompletedRequest: request])
    {
      [connection setExcess: [[connection parser] excess]];
    }
  [connection setProcessing: YES];

  if ([[_defs arrayForKey: @"WebServerQuiet"]
    containsObject: [connection remoteAddress]] == NO)
    {
      [_lock lock];
      _requests++;
      [_lock unlock];
      if (YES == _conf->verbose
        && NO == _conf->logRawIO
        && NO == [connection quiet])
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
      /* OK ... now process in main thread.
       */
      [self performSelector: @selector(_process3:)
		   onThread: _ioMain->thread
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
  WebServerRequest	*request;
  WebServerResponse	*response;
  BOOL			processed = YES;

  request = [connection request];
  response = [connection response];

  NS_DURING
    {
      [connection setTicked: _ticked];
      if ([self accessRequest: request response: response])
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

  if (processed)
    {
      /* Request was completed at the pre-processing stage ... don't process
       */
      [self completedWithResponse: response];
    }
  else if (YES == _doProcess)
    {
      /* OK ... now process in main thread.
       */
      [self performSelector: @selector(_process3:)
		   onThread: _ioMain->thread
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
  WebServerRequest	*request;
  WebServerResponse	*response;
  BOOL			processed = YES;

  request = [connection request];
  response = [connection response];

  NS_DURING
    {
      [connection setTicked: _ticked];
      if (YES == _doPreProcess
        || YES == [self accessRequest: request response: response])
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
      [connection setShouldClose: YES];	// Not persistent.
    }
  NS_ENDHANDLER

  if (processed)
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
  WebServerRequest	*request;
  WebServerConnection	*connection;

  [_lock lock];
  connection = [[response webServerConnection] retain];
  [_lock unlock];

  if (nil == connection)
    {
      if (YES == _conf->verbose)
        {
          [self _log: @"The client has already closed the connection"
            @" for response: %@", response];
        }
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

- (NSUInteger) _setIncrementalBytes: (const void*)bytes
                             length: (NSUInteger)length
                         forRequest: (WebServerRequest*)request
{
  if (NO == [request isKindOfClass: [WebServerRequest class]])
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"[%@-%@] bad request argument",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  [_incrementalDataLock lock];
  if (0 == bytes)
    {
      [_incrementalDataMap removeObjectForKey: request];
      length = 0;
    }
  else
    {
      NSMutableData     *d = [_incrementalDataMap objectForKey: request];

      if (nil == d)
        {
          d = [[NSMutableData alloc] initWithCapacity: length];
          [_incrementalDataMap setObject: d forKey: request];
          [d release];
        }
      [d appendBytes: bytes length: length];
      length = [d length];
    }
  [_incrementalDataLock unlock];
  return length;
}

- (void) _setup
{
  _reserved = 0;
  _nc = [[NSNotificationCenter defaultCenter] retain];
  _connectionTimeout = 30.0;
  _lock =  [NSLock new];
  _ioMain = [IOThread new];
  _ioMain->thread = [[NSThread currentThread] retain];
  _ioMain->server = self;
  _ioMain->cTimeout = _connectionTimeout;
  _pool = [GSThreadPool new];
  [_pool setPoolName: @"websvr"];
  [_pool setThreads: 0];
  _defs = [[NSUserDefaults standardUserDefaults] retain];
  _conf = [WebServerConfig new];
  _conf->foldHeaders = NO;
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
  _incrementalDataMap = [NSMutableDictionary new];
  _userInfoMap = [NSMutableDictionary new];
  _incrementalDataLock = [NSLock new];
  _userInfoLock = [NSLock new];
  _strictTransportSecurity = 31536000;  // Default is 1 year
  _authFailureBanTime = 1.0;
  _authFailureMaxRetry = 0;
  _authFailureFindTime = 1.0;

  /* We need a timer so that the main thread can handle connection
   * timeouts.
   */
  _ioMain->timer = [NSTimer scheduledTimerWithTimeInterval: 0.8
						    target: _ioMain
						  selector: @selector(timeout:)
						  userInfo: 0
						   repeats: YES];
}

- (NSString*) _xCountRequests
{
  NSString	*str;

  [_lock lock];
  str = [NSStringClass stringWithFormat: @"%"PRIuPTR, _processingCount];
  [_lock unlock];
  return str;
}

- (NSString*) _xCountConnections
{
  NSString	*str;

  [_lock lock];
  str = [NSStringClass stringWithFormat: @"%"PRIuPTR, [_connections count]];
  [_lock unlock];
  return str;
}

- (NSString*) _xCountConnectedHosts
{
  NSString	*str;

  [_lock lock];
  str = [NSStringClass stringWithFormat: @"%"PRIuPTR, [_perHost count]];
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

@implementation WebServerAuthenticationFailure

- (id) initWithDate: (NSDate*)date
            banTime: (NSTimeInterval)banTime
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_date, date);
      _banTime = banTime;
    }
  return self;
}

- (void) dealloc
{
  DESTROY(_date);
  [super dealloc];
}

- (NSDate*) date
{
  return _date;
}

- (NSTimeInterval) banTime
{
  return _banTime;
}

- (NSDate*) blockUntil
{
  return [_date dateByAddingTimeInterval: _banTime];
}

+ (id) failureWithBanTime: (NSTimeInterval)banTime
{
  return AUTORELEASE([[self alloc] initWithDate: [NSDate date] banTime: banTime]);
}

@end

@implementation WebServerAuthenticationFailureLog

- (id) init
{
  if (nil != (self = [super init]))
    {
      _findTime = 1.0;
      _failuresByAddress = [NSMutableDictionary new];
      _banUntilByAddress = [NSMutableDictionary new];
      _lock = [NSLock new];
      _cleanupInterval = 60.0;
      [self setupCleanupTimer];
    }
  return self;
}

- (void) dealloc
{
  [_cleanupTimer invalidate];
  _cleanupTimer = nil;
  DESTROY(_failuresByAddress);
  DESTROY(_banUntilByAddress);
  DESTROY(_lock);
  [super dealloc];
}

- (NSTimeInterval) findTime
{
  return _findTime;
}

- (NSTimeInterval) cleanupInterval
{
  return _cleanupInterval;
}

- (void) setupCleanupTimer
{
  [_cleanupTimer invalidate];
  _cleanupTimer = [NSTimer scheduledTimerWithTimeInterval: _cleanupInterval
                                                   target: self
                                                 selector: @selector(cleanup)
                                                 userInfo: 0
                                                  repeats: YES];
}

- (void) setFindTime: (NSTimeInterval)findTime
{
  _findTime = findTime;
}

- (void) setCleanupInterval: (NSTimeInterval)cleanupInterval
{
  _cleanupInterval = cleanupInterval;
  [self setupCleanupTimer];
}

- (BOOL) isValidAddress: (NSString*)address
{
  BOOL  isValid = YES;

  if (NO == [address isKindOfClass: [NSString class]]
    || [address isEqualToString: @"_"])
    {
      isValid = NO;
    }
 
  return isValid;
}

- (void) addFailureForAddress: (NSString*)address
                      banTime: (NSTimeInterval)banTime
{
  NSMutableArray                  *failures;
  WebServerAuthenticationFailure  *failure;
  
  if (NO == [self isValidAddress: address])
    {
      return;
    }

  failure = [WebServerAuthenticationFailure failureWithBanTime: banTime];

  [_lock lock];
  if (nil != (failures = [_failuresByAddress objectForKey: address]))
    {
      [failures addObject: failure];
    }
  else
    {
      failures = [NSMutableArray arrayWithObject: failure];
      [_failuresByAddress setObject: failures forKey: address];
    }
  [_lock unlock];
}

- (void) removeFailuresForAddress: (NSString*)address
{
  if (NO == [self isValidAddress: address])
    {
      return;
    }

  [_lock lock];
  [_failuresByAddress removeObjectForKey: address];
  [_lock unlock];
}

- (NSUInteger) failureCountForAddress: (NSString*)address
                           blockUntil: (NSDate**)until
{
  NSMutableArray                  *failures;
  NSUInteger                      count = 0;
  WebServerAuthenticationFailure  *failure;
  NSDate                          *since;
  NSDate                          *latest = nil;
  NSDate                          *blockUntil;
  
  if (NO == [self isValidAddress: address])
    {
      if (NULL != until)
        {
          *until = nil;
        }
      return 0;
    }

  [_lock lock];
  if (nil != (failures = [_failuresByAddress objectForKey: address]))
    {
      since = [NSDate dateWithTimeIntervalSinceNow: -_findTime];
      for (NSInteger i = [failures count] - 1; i >= 0; i--)
        {
          failure = [failures objectAtIndex: i];
          if ([[failure date] compare: since] == NSOrderedDescending)
            {
              count++;
              blockUntil = [failure blockUntil];
              if (nil == latest 
                || [blockUntil compare: latest] == NSOrderedDescending)
                {
                  latest = [failure blockUntil];
                }
            }
          else
            {
              break;
            }
        }
    }
  if (NULL != until)
    {
      *until = AUTORELEASE(RETAIN(latest));
    }
  [_lock unlock];

  return count;
}

- (void) banAddress: (NSString*)address
              until: (NSDate*)until
{
  if (NO == [self isValidAddress: address])
    {
      return;
    }

  [_lock lock];
  if (nil != until)
    {
      [_banUntilByAddress setObject: until forKey: address];
    }
  else
    {
      [_banUntilByAddress removeObjectForKey: address];
    }
  [_lock unlock];
}

- (NSDate*) isBanned: (NSString*)address
{
  NSDate  *until;

  if (NO == [self isValidAddress: address])
    {
      return nil;
    }

  [_lock lock];
  until = RETAIN([_banUntilByAddress objectForKey: address]);
  if (nil != until && [until compare: [NSDate date]] == NSOrderedAscending)
    {
      RELEASE(until);
      until = nil;
    }
  [_lock unlock];

  return AUTORELEASE(until);
}

- (void) cleanup
{
  NSString                        *address;
  NSMutableArray                  *failures;
  WebServerAuthenticationFailure  *failure;
  NSDate                          *since;
  NSArray                         *addresses;
  NSDate                          *until;

  since = [NSDate dateWithTimeIntervalSinceNow: -_findTime];

  [_lock lock];

  addresses = [_failuresByAddress allKeys];
  for (address in addresses)
    {
      failures = [_failuresByAddress objectForKey: address];
      for (NSInteger j = [failures count] - 1; j >= 0; j--)
        {
          failure = [failures objectAtIndex: j];
          if ([[failure date] compare: since] == NSOrderedAscending)
            {
              [failures removeObjectAtIndex: j];
            }
        }
      if ([failures count] == 0)
        {
          [_failuresByAddress removeObjectForKey: address];
        }
    }

  addresses = [_banUntilByAddress allKeys];
  for (address in addresses)
    {
      until = [_banUntilByAddress objectForKey: address];
      if ([until compare: [NSDate date]] == NSOrderedAscending)
        {
          [_banUntilByAddress removeObjectForKey: address];
        }
    }
  
  [_lock unlock];
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
      keepaliveMax = 0;
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

