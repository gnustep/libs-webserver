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

#define WEBSERVERINTERNAL       1

#import "WebServer.h"
#import "Internal.h"


@implementation	WebServerHeader

- (id) copyWithZone: (NSZone*)z
{
  return [self retain];
}

- (void) dealloc
{
  id	o = wshObject;

  wshObject = nil;
  [o release];
  [super dealloc];
}

- (NSString*) fullValue
{
  return [self value];
}

- (id) initWithType: (WSHType)t andObject: (NSObject*)o
{
  if (nil == o)
    {
      [self release];
      [NSException raise: NSInvalidArgumentException
		  format:
	@"[WebServerHeader-initWithType:andObject:] nil object"];
    }
  if (nil != (self = [super initWithName: @"" value: @"" parameters: nil]))
    {
      if (nil != name)
	{
	  [name release];
	  name = nil;
	}
      if (nil != value)
	{
	  [value release];
	  value = nil;
	}
      wshObject = [o retain];
      switch (t)
	{
	  case WSHCountRequests:
	    name = @"x-count-requests";
	    break;

	  case WSHCountConnections:
	    name = @"x-count-connections";
	    break;

	  case WSHCountConnectedHosts:
	    name = @"x-count-connected-hosts";
	    break;

	  default:
	    [self release];
	    [NSException raise: NSInvalidArgumentException
		        format:
	      @"[WebServerHeader-initWithType:andObject:] bad type %d", t];
	}
    }
  return self;
}

- (NSString*) name
{
  return name;
}

- (NSString*) namePreservingCase: (BOOL)preserve
{
  return name;
}

- (id) objectForKey: (NSString*)k
{
  return nil;
}

- (NSDictionary*) objects
{
  return nil;
}

- (NSString*) parameterForKey: (NSString*)k
{
  return nil;
}

- (NSDictionary*) parameters
{
  return nil;
}

- (NSDictionary*) parametersPreservingCase: (BOOL)preserve
{
  return nil;
}

- (NSMutableData*) rawMimeData
{
  return [[[[self text] dataUsingEncoding: NSASCIIStringEncoding]
    mutableCopy] autorelease];
}

- (NSMutableData*) rawMimeDataPreservingCase: (BOOL)preserve
{
  return [[[[self text] dataUsingEncoding: NSASCIIStringEncoding]
    mutableCopy] autorelease];
}

- (void) setName: (NSString*)s
{
  return;
}

- (void) setObject: (id)o forKey: (NSString*)k
{
  return;
}

- (void) setParameter: (NSString*)v forKey: (NSString*)k
{
  return;
}

- (void) setParameters: (NSDictionary*)d
{
  return;
}

- (void) setValue: (NSString*)s
{
  return;
}

- (NSString*) text
{
  return [NSString stringWithFormat: @"%@: %@\r\n", name, [self value]];
}

- (NSString*) value
{
  switch (wshType)
    {
      case WSHCountRequests:
	return [(WebServer*)wshObject _xCountRequests];

      case WSHCountConnections:
	return [(WebServer*)wshObject _xCountConnections];

      case WSHCountConnectedHosts:
	return [(WebServer*)wshObject _xCountConnectedHosts];
	break;

      default:
	return nil;
    }
}

@end

