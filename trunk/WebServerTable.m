/** 
   Copyright (C) 2009 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	June 2009
   
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

   $Date: 2009-09-25 11:17:32 +0100 (Fri, 25 Sep 2009) $ $Revision: 28737 $
   */ 

#import <Foundation/Foundation.h>

#define WEBSERVERINTERNAL       1

#import "WebServer.h"
#import "WebServerHTML.h"

@implementation	WebServerTable

- (NSArray*) contents
{
  return _contents;
}

- (void) dealloc
{
  [_titles release];
  [_contents release];
  [super dealloc];
}

- (WebServerForm*) form
{
  return _form;
}

- (id) initWithName: (NSString*)name
       columnTitles: (NSArray*)titles
	   rowCount: (NSUInteger)rows
{
  if ((self = [super initWithName: name]) != nil)
    {
      _titles = [titles copy];
      _cols = [_titles count];
      _rows = rows;
    }
  return self;
}

- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form
{
  NSMutableString	*m;
  NSUInteger		col;
  NSUInteger		row;
  NSUInteger		maxRow;

  m = [NSMutableString stringWithCapacity: 1024];
  [m appendString: @"<table>\n"];
  [m appendString: @"  <th>\n"];
  for (col = 0; col < _cols; col++)
    {
      NSString	*str = [_titles objectAtIndex: col];
      NSString	*tmp;
      NSURL	*u;

      [m appendString: @"    <td>\n"];
      tmp = [_delegate webServerTable: self
			  replaceText: str
			       forRow: NSNotFound
				  col: col];
      if (tmp != nil)
	{
	  str = tmp;
	}
      str = [WebServer escapeHTML: str];

      tmp = [_delegate webServerTable: self
			  replaceHTML: str
			       forRow: NSNotFound
				  col: col];
      if (tmp != nil)
	{
	  str = tmp;
	}

      u = nil;
      u = [_delegate webServerTable: self
			replaceLink: u
		             forRow: NSNotFound
				col: col];
      if (u != nil)
	{
	  str = [NSString stringWithFormat: @"<a href=\"%@\">%@</a>",
	    [WebServer escapeHTML: [u absoluteString]], str];
	}
      [m appendString: str];
      [m appendString: @"</td>\n"];
    }
  [m appendString: @"  </th>\n"];

  maxRow = [_contents count];
  if (maxRow > _rows)
    {
      maxRow = _rows;
    }
  for (row = 0; row < maxRow; row++)
    {
      NSArray		*line = [_contents objectAtIndex: row];
      NSUInteger	maxCol = [line count];

      [m appendString: @"  <tr>\n"];
      if (maxCol > _cols)
	{
	  maxCol = _cols;
	}
      for (col = 0; col < maxCol; col++)
	{
	  NSString	*str = [line objectAtIndex: col];
	  NSString	*tmp;
	  NSURL	*u;

          [m appendString: @"    <td>"];
	  tmp = [_delegate webServerTable: self
			      replaceText: str
				   forRow: row
				      col: col];
	  if (tmp != nil)
	    {
	      str = tmp;
	    }
	  str = [WebServer escapeHTML: str];

	  tmp = [_delegate webServerTable: self
			      replaceHTML: str
				   forRow: row
				      col: col];
	  if (tmp != nil)
	    {
	      str = tmp;
	    }

	  u = [_delegate webServerTable: self
			    replaceLink: nil
		                 forRow: row
				    col: col];
	  if (u != nil)
	    {
	      str = [NSString stringWithFormat: @"<a href=\"%@\">%@</a>",
		[WebServer escapeHTML: [u absoluteString]], str];
	    }
          [m appendString: str];
          [m appendString: @"</td>\n"];
	}
      while (col < _cols)
	{
          [m appendString: @"    <td></td>\n"];
	}
      [m appendString: @"  </tr>\n"];
    }

  [m appendString: @"</table>\n"];
  [map setObject: m forKey: [self name]];
}

- (void) setContents: (NSArray*)contents
	    atOffset: (NSUInteger)rowNumber
	       total: (NSUInteger)totalRows
{
  contents = [contents copy];
  [_contents release];
  _contents = contents;
  _offset = rowNumber;
  _total = totalRows;
}

- (void) setDelegate: (id)anObject
{
  if (anObject == nil)
    {
      anObject = self;
    }
  _delegate = anObject;
}

@end

@implementation	NSObject (WebServerTable)

- (NSString*) webServerTable: (WebServerTable*)table
	         replaceHTML: (NSString*)html
		      forRow: (NSUInteger)row
			 col: (NSUInteger)col
{
  return html;
}

- (NSURL*) webServerTable: (WebServerTable*)table
	      replaceLink: (NSURL*)link
		   forRow: (NSUInteger)row
		      col: (NSUInteger)col
{
  return link;
}

- (NSString*) webServerTable: (WebServerTable*)table
		 replaceText: (NSString*)text
		      forRow: (NSUInteger)row
			 col: (NSUInteger)col
{
  return text;
}

@end

