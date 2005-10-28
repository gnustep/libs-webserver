/** 
   Copyright (C) 2005 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	September 2005
   
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
#include	<GNUstepBase/GSMime.h>
#include	"WebServer.h"

@interface	Handler: NSObject
- (BOOL) processRequest: (GSMimeDocument*)request
               response: (GSMimeDocument*)response
		    for: (WebServer*)http;
@end
@implementation	Handler
- (BOOL) processRequest: (GSMimeDocument*)request
               response: (GSMimeDocument*)response
		    for: (WebServer*)http
{
  NSString		*s;

  s = [[NSString alloc] initWithData: [request rawMimeData]
			    encoding: NSISOLatin1StringEncoding];
  NSLog(@"Got request -\n%@\n", s);
  [response setContent: s type: @"text/plain" name: nil];
  RELEASE(s);

  return YES;
}
@end

int
main()
{
  CREATE_AUTORELEASE_POOL(pool);
  WebServer		*server;
  Handler		*handler;
  NSUserDefaults	*defs;

  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults:
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"80", @"Port",
      nil]
    ];

  server = [WebServer new];
  {
    NSData *d = [NSData dataWithContentsOfFile: @"/home/richard/web.log"];
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    [server decodeURLEncodedForm: d into: p];
    NSLog(@"Params: %@", p);
    exit(0);
  }

  handler = [Handler new];
  [server setDelegate: handler];
  [server setPort: [defs stringForKey: @"Port"] secure: nil];

  [[NSRunLoop currentRunLoop] run];

  RELEASE(pool);
  return 0;
}

