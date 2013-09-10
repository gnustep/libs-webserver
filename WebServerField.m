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

static id null = nil;

@implementation	WebServerItem

+ (void) initialize
{
  if (null == nil) null = [[NSNull null] retain];
}

- (void) dealloc
{
  [_value release];
  [_name release];
  [super dealloc];
}

- (id) init
{
  NSString	*c = NSStringFromClass([self class]);

  [self release];
  [NSException raise: NSInvalidArgumentException
	      format: @"[%@-init] should not be used ... init with a name", c];
  return nil;
}

- (id) initWithName: (NSString*)name
{
  if (nil != (self = [super init]))
    {
      NSUInteger	count = [name length];
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
    }
  return self;
}

- (NSString*) name
{
  return _name;
}

- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form
{
}

- (void) setValue: (id)value
{
  id	tmp;

  if (value == null) value = nil;
  tmp = [value copy];
  [_value release];
  _value = tmp;
}

- (void) takeValueFrom: (NSDictionary*)params
{
}

- (NSString*) validate
{
  return nil;
}

- (id) value
{
  return _value;
}
@end


@implementation	WebServerField

- (NSUInteger) columns
{
  return _cols;
}

- (void) dealloc
{
  [_prefill release];
  [super dealloc];
}

- (BOOL) mayBeEmpty
{
  return _mayBeEmpty;
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
  if (_cols == 0)
    {
      f = [[NSString alloc] initWithFormat:
        @"<input type=\"text\" name=\"%@\" value=\"%@\" />",
        _name, [WebServer escapeHTML: v]];
    }
  else
    {
      f = [[NSString alloc] initWithFormat:
        @"<input size=\"%u\" type=\"text\" name=\"%@\" value=\"%@\" />",
        _cols, _name, [WebServer escapeHTML: v]];
    }
  [map setObject: f forKey: _name];
  [f release];
}

- (id) prefill
{
  return _prefill;
}

- (NSUInteger) rows
{
  return _rows;
}

- (void) setMayBeEmpty: (BOOL)flag
{
  _mayBeEmpty = flag;
}

- (void) setColumns: (NSUInteger)cols
{
  _cols = cols;
}

- (void) setPrefill: (id)value
{
  id	tmp;

  if (value == null) value = nil;
  tmp = [value copy];
  [_prefill release];
  _prefill = tmp;
}

- (void) setRows: (NSUInteger)rows
{
  _rows = rows;
}

- (void) setValue: (id)value
{
  id	tmp;

  if (value == null) value = nil;
  tmp = [value copy];
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
      return _(@"empty");
    }
  return nil;
}

@end

@implementation	WebServerFieldHidden

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
    @"<input type=\"hidden\" name=\"%@\" value=\"%@\" />",
    _name, [WebServer escapeHTML: v]];
  [map setObject: f forKey: _name];
  [f release];
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
  if ((self = [super initWithName: name]) != nil)
    {
      [self setKeys: keys andValues: values];
    }
  return self;
}

- (BOOL) mayBeMultiple
{
  return _multiple;
}

- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form
{
  NSMutableString	*f;
  id			v;
  NSUInteger		c;
  NSUInteger		i;
  NSString		*mult;

  mult = (_multiple ? @" multiple=\"multiple\" " : @"");

  if (_rows == 0)
    {
      f = [[NSMutableString alloc] initWithFormat:
        @"<select %@ name=\"%@\">\n", mult, _name];
    }
  else
    {
      f = [[NSMutableString alloc] initWithFormat:
        @"<select %@ size=\"%u\" name=\"%@\">\n", mult, _rows, _name];
    }

  v = _value;
  if ([_prefill length] > 0)
    {
      i = [_vals indexOfObject: _prefill];
      if (i == NSNotFound)
	{
	  /* No value matching the prefill text ... 
	   * Generate a menu option with the prefill text as key
	   * and with an empty value.
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
	  /* Default selected value is equal to prefill text.
	   */
	  v = [_vals objectAtIndex: i]; 
	}
    }

  /* make sure we are working with an array of selected values.
   */
  if ([v isKindOfClass: [NSString class]])
    {
      v = [NSArray arrayWithObject: v];
    }

  c = [_keys count];
  for (i = 0; i < c; i++)
    {
      NSString	*val = [_vals objectAtIndex: i];
      NSString	*key = [_keys objectAtIndex: i];

      if (v != nil && [v containsObject: val])
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

- (void) setKeys: (NSArray*)keys andValues: (NSArray*)values
{
  NSUInteger	c = [keys count];
  NSUInteger	i;
  NSSet		*s;
  id		o;

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

  o = [keys copy];
  [_keys release];
  _keys = o;
  o = [values copy];
  [_vals release];
  _vals = o;
}

- (void) setMayBeMultiple: (BOOL)flag
{
  if (_multiple != flag)
    {
      _multiple = flag;
      if (YES == _multiple)
	{
	  if (_value != nil)
	    {
	      id	old = _value;

	      _value = [[NSArray alloc] initWithObjects: &old count: 1];
	      [old release];
	    } 
	}
      else
	{
	  if ([_value count] > 0)
	    {
	      id	old = _value;

	      _value = [[old objectAtIndex: 0] copy];
	      [old release];
	    } 
	}
    }
}

- (void) setValue: (id)value
{
  if (value == null) value = nil;
  if (YES == _multiple)
    {
      NSUInteger	count;
      NSUInteger	index;
      NSMutableArray	*array;

      if (value != nil && NO == [value isKindOfClass: [NSArray class]])
	{ 
	  [NSException raise: NSInvalidArgumentException
		      format: @"[%@-%@] value is not an array",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
      index = count = [value count];
      array = [[value mutableCopy] autorelease];
      while (index-- > 0)
	{
	  id	v = [array objectAtIndex: index];

	  if (NO == [v isKindOfClass: [NSString class]])
	    {
	      [NSException raise: NSInvalidArgumentException
                format: @"[%@-%@] value item %"PRIuPTR" is not a string",
		NSStringFromClass([self class]), NSStringFromSelector(_cmd),
		index];
	    }
	  v = [v stringByTrimmingSpaces];
	  if ([_vals containsObject: v] == NO)
	    {
	      [array removeObjectAtIndex: index];
	    }
	  else
	    {
	      [array replaceObjectAtIndex: index withObject: v];
	    }
	}
      if ([array count] == 0)
	{
	  value = nil;
	}
      else
	{
	  value = array;
	}
    }
  else
    {
      if (value != nil && NO == [value isKindOfClass: [NSString class]])
	{ 
	  [NSException raise: NSInvalidArgumentException
		      format: @"[%@-%@] value is not a string",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
      value = [value stringByTrimmingSpaces];
      if ([value length] == 0)
	{
	  value = nil;
	}
      if ([_vals containsObject: value] == NO)
	{
	  value = nil;
	}
    }
  [super setValue: value];
}

- (void) sortUsingSelector: (SEL)aSelector
{
  NSArray		*nk;
  NSMutableArray	*nv;
  NSUInteger		c;
  NSUInteger		i;

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
  [_vals release];
  _vals = [nv copy];
  [nv release];
}

- (void) takeValueFrom: (NSDictionary*)params
{
  NSString	*v;

  if (YES == _multiple)
    {
      NSMutableArray	*a = [NSMutableArray array];
      int		i = 0;

      while ((v = [WebServer parameterString: _name
					  at: i++
				        from: params
				     charset: nil]) != nil)
	{
	  [a addObject: v];
	}
      [self setValue: a];
    }
  else
    {
      v = [WebServer parameterString: _name at: 0 from: params charset: nil];
      [self setValue: v];
    }
}

@end

@implementation	WebServerFieldPassword
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
    @"<input type=\"password\" name=\"%@\" value=\"%@\" />",
    _name, [WebServer escapeHTML: v]];
  [map setObject: f forKey: _name];
  [f release];
}
@end

