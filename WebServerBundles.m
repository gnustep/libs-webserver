/** 
   Copyright (C) 2004 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	June 2004
   
   This file is part of the SQLClient Library.

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
#include	<Foundation/Foundation.h>
#include	"WebServer.h"

@implementation WebServerBundles
- (void) dealloc
{
  RELEASE(_http);
  RELEASE(_handlers);
  [super dealloc];
}

- (BOOL) defaultsUpdate: (NSNotification *)aNotification
{
  NSUserDefaults	*defs = [aNotification object];
  NSString		*port;
  NSDictionary		*secure;

  port = [defs stringForKey: @"WebServerPort"];
  if ([port length] == 0)
    {
      return NO;	// Can't make web server active.
    }
  secure = [defs dictionaryForKey: @"WebServerSecure"];
  return [_http setPort: port secure: secure];
}

- (id) handlerForPath: (NSString*)path info: (NSString**)info
{
  NSString		*error = nil;
  NSMutableDictionary	*handlers;
  id			handler;

  if (info != 0)
    {
      *info = path;
    }
  handlers = [self handlers];
  handler = [handlers objectForKey: path];
  if (handler == nil)
    {
      NSUserDefaults	*defs;
      NSDictionary	*conf;
      NSDictionary	*byPath;

      defs = [NSUserDefaults standardUserDefaults];
      conf = [defs dictionaryForKey: @"WebServerBundles"];
      byPath = [conf objectForKey: path];
      if ([byPath isKindOfClass: [NSDictionary class]] == NO)
	{
	  NSRange	r;

	  r = [path rangeOfString: @"/" options: NSBackwardsSearch];
	  if (r.length > 0)
	    {
	      path = [path substringToIndex: r.location];
	      handler = [self handlerForPath: path info: info];
	    }
	  else
	    {
	      error = [NSString stringWithFormat:
		@"Unable to find handler in Bundles config for '%@'", path];
	    }
	}
      else
	{
	  NSString	*name;

	  name = [byPath objectForKey: @"Name"];

	  if ([name length] == 0)
	    {
	      error = [NSString stringWithFormat:
		@"Unable to find Name in Bundles config for '%@'", path];
	    }
	  else
	    {
	      NSBundle	*mb = [NSBundle mainBundle];
	      NSString	*p = [mb pathForResource: name ofType: @"bundle"];
	      NSBundle	*b = [NSBundle bundleWithPath: p];
	      Class	c = [b principalClass];

	      if (c == 0)
		{
		  error = [NSString stringWithFormat:
		    @"Unable to find class in '%@' for '%@'", p, path];
		}
	      else
		{
		  handler = [c new];
		  [self registerHandler: handler forPath: path];
		  RELEASE(handler);
		}
	    }
	}
    }
  if (handler == nil && info != 0)
    {
      *info = error;
    }
  return handler;
}

- (NSMutableDictionary*) handlers
{
  if (_handlers == nil)
    {
      _handlers = [NSMutableDictionary new];
    }
  return _handlers;
}

- (WebServer*) http
{
  return _http;
}

- (id) init
{
  return [self initAsDelegateOf: nil];
}

- (id) initAsDelegateOf: (WebServer*)http
{
  if (http == nil)
    {
      DESTROY(self);
    }
  else
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
      NSUserDefaults		*defs = [NSUserDefaults standardUserDefaults];
      NSNotification		*n;

      ASSIGN(_http, http);
      [_http setDelegate: self];

      /*
       * Watch for config changes, and set initial config by sending a
       * faked change notification.
       */
      [nc addObserver: self
	     selector: @selector(defaultsUpdate:)
		 name: NSUserDefaultsDidChangeNotification
	       object: defs];
      n = [NSNotification
	notificationWithName: NSUserDefaultsDidChangeNotification
		      object: defs
		    userInfo: nil];
      if ([self defaultsUpdate: n] == NO)
	{
	  DESTROY(self);
	}
    }
  return self;
}

/**
 * We handle the incoming requests here.
 */
- (BOOL) processRequest: (GSMimeDocument*)request
	       response: (GSMimeDocument*)response
		    for: (WebServer*)http
{
  NSString		*path;
  NSString		*info;
  id			handler;

  path = [[request headerNamed: @"x-http-path"] value];
  handler = [self handlerForPath: path info: &info];
  if (handler == nil)
    {
      NSString	*error = @"bad path";

      /*
       * Log the error message.
       */
      [self webAlert: info for: (WebServer*)http];

      /*
       * Return status code 400 (Bad Request) with the informative error
       */
      error = [NSString stringWithFormat: @"HTTP/1.0 400 %@", error];
      [response setHeader: @"http" value: error parameters: nil];
      return YES;
    }
  else
    {
      NSString	*extra = [path substringFromIndex: [info length]];

      /*
       * Provide extra information about the exact path used to match
       * the handler, and any remaining path information beyond it.
       */
      [request setHeader: @"x-http-path-base"
		   value: info
	      parameters: nil];
      [request setHeader: @"x-http-path-info"
		   value: extra
	      parameters: nil];

      return [handler processRequest: request
			    response: response
				 for: http];
    }
}

- (void) registerHandler: (id)handler forPath: (NSString*)path
{
  if (handler == nil)
    {
      [[self handlers] removeObjectForKey: path];
    }
  else
    {
      [[self handlers] setObject: handler forKey: path];
    }
}

- (void) webAlert: (NSString*)message for: (WebServer*)http
{
  NSLog(@"%@", message);
}
@end

