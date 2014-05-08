/** 
   Copyright (C) 2009 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	September 2009
   
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

   $Date: 2009-09-07 10:01:34 +0100 (Mon, 07 Sep 2009) $ $Revision: 28619 $
   */ 

#import <Foundation/Foundation.h>

#define WEBSERVERINTERNAL       1

#import "WebServer.h"
#import "WebServerHTML.h"

@implementation	WebServerForm

- (void) dealloc
{
  [_fields release];
  [_URL release];
  [super dealloc];
}

- (WebServerField*) existingField: (NSString*)name
{
  return [_fields objectForKey: name];
}

- (WebServerField*) fieldNamed: (NSString*)name
{
  WebServerField	*f;

  f = [[WebServerField alloc] initWithName: name];
  [_fields setObject: f forKey: [f name]];
  [f release];
  return f;
}

- (WebServerFieldHidden*) fieldNamed: (NSString*)name
			      hidden: (NSString*)value
{
  WebServerFieldHidden	*f;

  f = [[WebServerFieldHidden alloc] initWithName: name];
  if (value != nil)
    {
      [f setPrefill: value];
    }
  [_fields setObject: f forKey: [f name]];
  [f release];
  return f;
}

- (WebServerFieldMenu*) fieldNamed: (NSString*)name
			  menuKeys: (NSArray*)keys
			    values: (NSArray*)values
{
  WebServerFieldMenu	*f;

  if ([keys count] != [values count])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] counts of keys and values do not match",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  f = [[WebServerFieldMenu alloc] initWithName: name
				          keys: keys
				        values: values];
  [_fields setObject: f forKey: [f name]];
  [f release];
  return f;
}

- (WebServerFieldMenu*) fieldNamed: (NSString*)name
			 menuYesNo: (NSString*)prefill
{
  WebServerFieldMenu	*f;
  static NSArray	*vals = nil;
  static NSArray	*keys = nil;

  if (vals == nil)
    {
      vals = [[NSArray alloc] initWithObjects: @"Y", @"N", nil];
    }
  if (keys == nil)
    {
      keys = [[NSArray alloc] initWithObjects: _(@"Yes"), _(@"No"), nil];
    }
  f = [self fieldNamed: name menuKeys: keys values: vals];
  [f setPrefill: prefill];
  return f;
}

- (WebServerFieldPassword*) fieldNamed: (NSString*)name
			      password: (NSString*)value
{
  WebServerFieldPassword	*f;

  f = [[WebServerFieldPassword alloc] initWithName: name];
  if (value != nil)
    {
      [f setPrefill: value];
    }
  [_fields setObject: f forKey: [f name]];
  [f release];
  return f;
}

- (NSArray*) fieldNames
{
  return [_fields allKeys];
}

- (id) initWithName: (NSString*)name
{
  self = [super initWithName: name];
  if (nil != self)
    {
      _fields = [NSMutableDictionary new];
    }
  return self;
}

- (void) output: (NSMutableDictionary*)map
{
  [self output: map for: self];
}

- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form
{
  NSEnumerator		*enumerator = [_fields objectEnumerator];
  WebServerField	*f;

  if (_URL != nil)
    {
      NSString	*key;
      NSString	*val;

      key = [@"Form" stringByAppendingString: [self name]];
      val = [NSString stringWithFormat:
	@"<form action=\"%@\" method=\"%@\">",
	[WebServer escapeHTML: [_URL absoluteString]],
	(_get ? @"GET" : @"POST")];
      [map setObject: val forKey: [key stringByAppendingString: @"Start"]];
      [map setObject: @"</form>" forKey: [key stringByAppendingString: @"End"]];
    }

  while ((f = [enumerator nextObject]) != nil)
    {
      [f output: map for: self];
    }
}

- (void) setURL: (NSURL*)URL get: (BOOL)get
{
  ASSIGNCOPY(_URL, URL);
  _get = get;
}

- (void) takeValuesFrom: (NSDictionary*)params
{
  NSEnumerator		*enumerator = [_fields objectEnumerator];
  WebServerField	*f;
  
  while ((f = [enumerator nextObject]) != nil)
    {
      [f takeValueFrom: params];
    }
}

- (NSURL*) URL
{
  return _URL;
}

- (NSString*) validate
{
  NSEnumerator		*enumerator = [_fields objectEnumerator];
  NSMutableString	*m = nil;
  WebServerField	*f;
  
  while ((f = [enumerator nextObject]) != nil)
    {
      NSString	*s = [f validate];

      if (s != nil)
	{
	  if (m == nil)
	    {
	      m = [NSMutableString stringWithCapacity: 1024];
	    }
	  [m appendString: s];
	}
    }
  return m;
}

- (NSString*) validateFrom: (NSDictionary*)params
			to: (NSMutableDictionary*)map
{
  [self takeValuesFrom: params];
  [self output: map];
  return [self validate];
}

- (NSMutableDictionary*) values
{
  NSEnumerator		*enumerator = [_fields objectEnumerator];
  NSMutableDictionary	*m;
  WebServerField	*f;
  
  m = [NSMutableDictionary dictionaryWithCapacity: [_fields count]];
  while ((f = [enumerator nextObject]) != nil)
    {
      id	v = [f value];

      if (v != nil)
	{
	  [m setObject: v forKey: [f name]];
	}
    }
  return m;
}
@end

