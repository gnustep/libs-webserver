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

#include <Foundation/Foundation.h>
#include "WebServer.h"

@implementation	WebServerForm
- (void) dealloc
{
  [_fields release];
  [super dealloc];
}

- (WebServerField*) existingField: (NSString*)name
{
  return [_fields objectForKey: name];
}

- (id) init
{
  _fields = [NSMutableDictionary new];
  return self;
}

- (WebServerField*) fieldNamed: (NSString*)name
{
  WebServerField	*f;

  f = [[WebServerField alloc] initWithName: name];
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
		  format: @"counts of keys and values do not match"];
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
      vals = [[NSArray alloc] initWithObjects: @"Yes", @"No", nil];
    }
  if (keys == nil)
    {
      keys = [[NSArray alloc] initWithObjects: _(@"Yes"), _(@"No"), nil];
    }
  f = [self fieldNamed: name menuKeys: keys values: vals];
  [f setPrefill: prefill];
  return f;
}

- (NSArray*) fieldNames
{
  return [_fields allKeys];
}

- (void) output: (NSMutableDictionary*)map
{
  NSEnumerator		*enumerator = [_fields objectEnumerator];
  WebServerField	*f;
  
  while ((f = [enumerator nextObject]) != nil)
    {
      [f output: map for: self];
    }
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

@implementation	WebServerField: NSObject

- (void) dealloc
{
  [_prefill release];
  [_value release];
  [_name release];
  [super dealloc];
}

- (id) init
{
  return [self initWithName: nil];
}

- (id) initWithName: (NSString*)name
{
  unsigned	count = [name length];
  unichar	c;

  if (count == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] empty name",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  while (count-- > 1)
    {
      c = [name characterAtIndex: count];
      if (c != '_' && !isalnum(c))
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"[%@-%@] illegal character in name",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
    }
  c = [name characterAtIndex: 0];
  if (c != '_' && !isalpha(c))
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] bad initial character in name",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  _name = [name copy];
  return self;
}

- (BOOL) mayBeEmpty
{
  return _mayBeEmpty;
}

- (NSString*) name
{
  return _name;
}

- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form
{
  NSString	*f;
  NSString	*v = _value;

  if (v == nil)
    {
      v = _prefill;
      if (v == nil)
	{
	  v = @"";
	}
    }
  f = [[NSString alloc] initWithFormat:
    @"<input type=\"text\" name=\"%@\" value=\"%@\" />",
    _name, [WebServer escapeHTML: v]];
  [map setObject: f forKey: _name];
  [f release];
}

- (id) prefill
{
  return _prefill;
}

- (void) setMayBeEmpty: (BOOL)flag
{
  _mayBeEmpty = flag;
}

- (void) setPrefill: (id)value
{
  id	tmp = [value copy];

  [_prefill release];
  _prefill = tmp;
}

- (void) setValue: (id)value
{
  id	tmp = [value copy];

  [_value release];
  _value = tmp;
}

- (void) takeValueFrom: (NSDictionary*)params
{
  NSString	*v;

  v = [WebServer parameterString: _name at: 0 from: params charset: nil];
  [self setValue: v];
}

- (NSString*) validate
{
  if (_mayBeEmpty == NO && _value == nil)
    {
      return @"empty";
    }
  return nil;
}

- (id) value
{
  return _value;
}
@end

@implementation	WebServerFieldMenu
- (void) dealloc
{
  [_keys release];
  [_vals release];
  [super dealloc];
}

- (id) initWithName: (NSString*)name
	       keys: (NSArray*)keys
	     values: (NSArray*)values
{
  unsigned	c = [keys count];
  unsigned	i;
  NSSet		*s;

  if (c == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] empty keys array",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (c != [values count])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] size of keys and values array do not match",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if ([keys containsObject: @""])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] empty string in keys array",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if ([values containsObject: @""])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] empty string in values array",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  s = [[NSSet alloc] initWithArray: keys];
  i = [s count];
  [s release];
  if (i != c)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] duplicate strings in keys array",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  s = [[NSSet alloc] initWithArray: values];
  i = [s count];
  [s release];
  if (i != c)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] duplicate strings in values array",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }

  if ((self = [super initWithName: name]) != nil)
    {
      _keys = [keys copy];
      _vals = [values copy];
    }
  return self;
}

- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form
{
  NSMutableString	*f;
  NSString		*v;
  NSUInteger		c;
  NSUInteger		i;

  f = [[NSMutableString alloc] initWithFormat:
    @"<select name=\"%@\">\n", _name];

  v = _value;
  if ([v length] == 0)
    {
      v = nil;
    }

  if ([_prefill length] > 0)
    {
      i = [_keys indexOfObject: _prefill];
      if (i == NSNotFound)
	{
	  /* No value matching the prefill text ... 
	   * Generate a menu option for the prefill text with an empty value.
	   */
	  if (v == nil)
	    {
	      /* No value set ... so use prefill as selected item.
	       */
	      [f appendFormat:
	        @"<option selected=\"selected\" value=\"\">%@</option>\n",
	        [WebServer escapeHTML: _prefill]];
	    }
	  else
	    {
	      [f appendFormat:
	        @"<option value=\"\">%@</option>\n",
	        [WebServer escapeHTML: _prefill]];
	    }
	}
      else if (v == nil)
	{
	  /* Default selected value is determined by prefill text.
	   */
	  v = [_vals objectAtIndex: i]; 
	}
    }

  c = [_keys count];
  for (i = 0; i < c; i++)
    {
      NSString	*val = [_vals objectAtIndex: i];
      NSString	*key = [_keys objectAtIndex: i];

      if (v != nil &&  [v isEqualToString: val])
	{
	  [f appendFormat:
	    @"<option selected=\"selected\" value=\"%@\">%@</option>\n",
	    [WebServer escapeHTML: val],
	    [WebServer escapeHTML: key]];
	}
      else
	{
	  [f appendFormat:
	    @"<option value=\"%@\">%@</option>\n",
	    [WebServer escapeHTML: val],
	    [WebServer escapeHTML: key]];
	}
    }
  [f appendString: @"</select>"];
  [map setObject: f forKey: _name];
  [f release];
}

- (void) sortUsingSelector: (SEL)aSelector
{
  NSArray		*nk = [_keys sortedArrayUsingSelector: aSelector];
  NSMutableArray	*nv;
  unsigned		c;
  unsigned		i;

  nk = [_keys sortedArrayUsingSelector: aSelector];
  c = [nk count];
  nv = [[NSMutableArray alloc] initWithCapacity: c];
  for (i = 0; i < c; i++)
    {
      NSString	*k = [nk objectAtIndex:	i];

      [nv addObject: [_vals objectAtIndex: [_keys indexOfObject: k]]];
    }
  [_keys release];
  _keys = [nk copy];
  [nk release];
  [_vals release];
  _vals = [nv copy];
  [nv release];
}

- (void) takeValueFrom: (NSDictionary*)params
{
  NSString	*v;

  v = [WebServer parameterString: _name at: 0 from: params charset: nil];
  [self setValue: v];
  if ([_vals containsObject: [self value]] == NO)
    {
      [self setValue: nil];
    }
}

@end

