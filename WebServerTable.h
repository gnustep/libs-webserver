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

#ifndef	INCLUDED_WEBSERVERTABLE_H
#define	INCLUDED_WEBSERVERTABLE_H

#import	<WebServer/WebServer.h>

@class	NSMutableDictionary;


/** This class provides a framework for handling incoming form data
 * and substituting form fields into an html template being output
 * in a response.
 */
@interface	WebServerTable: WebServerItem
{
  NSString		*_name;  
  NSArray		*_titles;
  NSUInteger		_cols;
  NSUInteger		_rows;
  NSUInteger		_offset;
  NSUInteger		_total;
  NSArray		*_contents;
  id			_delegate;	// Not retained.
  WebServerForm		*_form;		// Not retained.
}

/** Returns the contents of the table in the process of being output.
 */
- (NSArray*) contents;

/** Returns the form for which this table is being output, or nil if
 * the table is not in the process of being output.
 */
- (WebServerForm*) form;

/** Initialises the receiver as a named table with the supplied column
 * titles and able to display the specified number of rows.
 */
- (id) initWithName: (NSString*)name
       columnTitles: (NSArray*)titles
	   rowCount: (NSUInteger)rows;

/** Generates html output to display the table contents on behalf of
 * the specified form.  Stores the resultes (keyed on the table name)
 * in the map.
 */
- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form;

/** Sets the content of the table to be an array of rows of data starting
 * at the specified row number (counting from zero).
 */
- (void) setContents: (NSArray*)contents
	    atOffset: (NSUInteger)rowNumber
	       total: (NSUInteger)totalRows;

/** Sets the delegate which controls drawing of the table.
 */
- (void) setDelegate: (id)anObject;
@end

/** An informal protocol declaring the methods which a table delegate may
 * implement in order to control presentation of a table.
 */
@interface	NSObject (WebServerTable)

/** This method is called after the delegate has supplied replacement
 * text and html for a cell, and allows the delegate to specify a URL
 * to which the cell contents will be linked.  The link argument will
 * be the URL the table proposes to use, or nil if id does not propose
 * to use one.
 */
- (NSURL*) webServerTable: (WebServerTable*)table
	      replaceLink: (NSURL*)link
	           forRow: (NSUInteger)row
		      col: (NSUInteger)col;

/** With this method the table informs the delegate of the HTML cell
 * content it intends to use, and allows the delegate to supply
 * replacement 'highlighted' content ... perhaps by making the contents
 * bold or even by replacing them with a link to an image.<br />
 * The replacement provided by the delegate will appear unchanged
 * (though possibly as a link) as the cell content without HTML escaping,
 * so it is important that the delegate introduces no error into the markup.
 */
- (NSString*) webServerTable: (WebServerTable*)table
	         replaceHTML: (NSString*)html
		      forRow: (NSUInteger)row
			 col: (NSUInteger)col;

/** With this method the table informs the delegate of the raw text data
 * for a particular cell and allows the delegate to provide replacement
 * text to be used when displaying the cell.  The replacement text must
 * not have special characters escaped as the table will escape it later.
 */
- (NSString*) webServerTable: (WebServerTable*)table
		 replaceText: (NSString*)text
		      forRow: (NSUInteger)row
			 col: (NSUInteger)col;


@end

#endif

