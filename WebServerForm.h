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

#ifndef	INCLUDED_WEBSERVERFORM_H
#define	INCLUDED_WEBSERVERFORM_H

#import	<WebServer/WebServer.h>

@class	NSMutableDictionary;

@class	WebServerField;
@class	WebServerFieldHidden;
@class	WebServerFieldPassword;
@class	WebServerFieldMenu;
@class	WebServerForm;

/** This is a basic field definition, a semi-abstract class upon which
 * elements of an HTML page are based.
 */
@interface	WebServerItem: NSObject
{
  NSString	*_name;
  id		_value;
}

/** <init />
 * Initialises the receiver with the specified name which must be a valid
 * field name (alphanumeric string plus a few characters).
 */
- (id) initWithName: (NSString*)name;

/** Returns the name with which the receiver was initialised.
 */
- (NSString*) name;

/** Sets a value in the map which is the text of the HTML input field needed
 * to provide data for the receiver.  The map may then be used to substitute
 * into an HTML template.
 */
- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form;

/** Sets the value for this field.  You do not usually call this method
 * directly as the -takeValueFrom: method populates the field value from
 * data provided by a browser.
 */
- (void) setValue: (id)value;

/** Gets the value for this field from a dictionary containing form
 * field contents submitted by a browser etc.
 */
- (void) takeValueFrom: (NSDictionary*)params;

/** Returns nil on success, a problem description on failure.
 */
- (NSString*) validate;

/** Returns the value set for this field.
 */
- (id) value;
@end

/** This class provides a framework for handling incoming form data
 * and substituting form fields into n html template being output
 * in a response.
 */
@interface	WebServerForm: WebServerItem
{
  NSURL			*_URL;
  BOOL			_get;
  NSMutableDictionary	*_fields;
}

/** Returns the existing field with the specified name, or nil if there
 * is no field with that name.
 */
- (WebServerField*) existingField: (NSString*)name;

/** Creates a new field with the specified name and adds it to the form.
 * Replaces any existing field with the same name.
 */
- (WebServerField*) fieldNamed: (NSString*)name;

/** Creates a new field with the specified name and adds it to the form.<br />
 * Replaces any existing field with the same name.<br />
 * The result is a hidden field withe the supplied prefilled value.
 */
- (WebServerFieldHidden*) fieldNamed: (NSString*)name
			      hidden: (NSString*)value;

/** Creates a new field with the specified name and adds it to the form.
 * Replaces any existing field with the same name.
 */
- (WebServerFieldMenu*) fieldNamed: (NSString*)name
			  menuKeys: (NSArray*)keys
			    values: (NSArray*)values;

/** Creates a new field with the specified name and adds it to the form.<br />
 * Replaces any existing field with the same name.<br />
 * The result is a menu whose keys are 'Yes' and 'No' (or equivalents in the
 * current language) and whose values are always 'Y' and 'N'.
 */
- (WebServerFieldMenu*) fieldNamed: (NSString*)name
			 menuYesNo: (NSString*)prefill;

/** Creates a new field with the specified name and adds it to the form.<br />
 * Replaces any existing field with the same name.<br />
 * The result is a password field withe the supplied prefilled value.
 */
- (WebServerFieldPassword*) fieldNamed: (NSString*)name
			      password: (NSString*)value;

/** Return the names of the fields on the form.
 */
- (NSArray*) fieldNames;

/** Initialise a new instance using ther specified name.
 */
- (id) initWithName: (NSString*)name;

/** Return the name of this form as set when the form was initialised.
 */
- (NSString*) name;

/** Places values from the form fields in the map dictionary.<br />
 * If the -setURL:get: method has been called, this method also adds
 * form start and end markup keyed on 'FormXStart' and 'FormXEnd'
 * where 'X' is the name of the form (which defaults to an empty string).<br />
 * Implemented as a call to -output:for: with self as the second argument.
 */
- (void) output: (NSMutableDictionary*)map;

/** Sets the URL for the form action and whether it should be a POST or GET.
 */
- (void) setURL: (NSURL*)URL get: (BOOL)get;

/** Takes values from the parameters dictionary and sets them into the
 * fields in the form.
 */
- (void) takeValuesFrom: (NSDictionary*)params;

/** Return the URL set by the -setURL:get: method.
 */
- (NSURL*) URL;

/** Validate all fields and return the result.
 */
- (NSString*) validate;

/** Convenience method to perform input, ooutput and validation.
 */
- (NSString*) validateFrom: (NSDictionary*)params
			to: (NSMutableDictionary*)map;

/** Returns a dictionary containing all the values previously set in fields
 */
- (NSMutableDictionary*) values;
@end

/** This is a basic field definition, usable for a simple text field
 * in an html form.
 */
@interface	WebServerField : WebServerItem
{
  id		_prefill;
  BOOL		_mayBeEmpty;
  uint16_t	_cols;
  uint16_t	_rows;
}

/** Return the number of columns set using the -setColumns: method or
 * zero if no value has been set.
 */
- (NSUInteger) columns;

/** Returns the value previously set by the -setMayBeEmpty: method,
 * or NO if that method was not called.
 */
- (BOOL) mayBeEmpty;

/** Returns the value set by an earlier call to the -setPrefill: method.
 */
- (id) prefill;

/** Return the number of rows set using the -setRows: method or
 * zero if no value has been set.
 */
- (NSUInteger) rows;

/** Set an advisory display width for the field.<br />
 * The default value of zero means that the field is unlimited.
 */
- (void) setColumns: (NSUInteger)cols;

/** Sets a flag to indicate whether the field value can be considered
 * valid if it is empty (or has not been filled in yet).  This is used
 * by the -validate method.
 */
- (void) setMayBeEmpty: (BOOL)flag;

/** Sets the value to be used to pre-fill the empty field on the form
 * before the user has entered anything.
 */
- (void) setPrefill: (id)value;

/** Set an advisory display height for the field.<br />
 * The default value of ero means that the field is unlimited.
 */
- (void) setRows: (NSUInteger)rows;

@end

/** This class provides a form field for hidden data
 */
@interface	WebServerFieldHidden : WebServerField
@end

/** <p>This class extends [WebServerForm] to provide a form field
 * as a menu for which a user can select from a fixed list of options.
 * </p>
 * <p>The -setPrefill: method of this class sets the value to be used
 * to pre-select a menu item.  This is <em>NOT</em> necessarily
 * the text seen by the user (the user sees the menu keys), but in the
 * case where the value does not match any of the menu values, it is used
 * as the key for a dummy value indicating no selection.
 * </p>
 */
@interface	WebServerFieldMenu : WebServerField
{
  NSArray	*_keys;
  NSArray	*_vals;
  BOOL		_multiple;
}
/** The options supported by this field are listed as keys (the text
 * that the user sees in their web browser) and values (the text
 * used by your program).  The two arguments must be arrays of the
 * same size, with no items repeated within an array ... so there is
 * a one to one mapping between keys and values.
 */
- (id) initWithName: (NSString*)name
	       keys: (NSArray*)keys
	     values: (NSArray*)values;

/** Returns YES if this field allows multiple values (in which case the
 * -value method returns an array of those values).
 */
- (BOOL) mayBeMultiple;

/** Used to change the set of keys and values in this field.<br />
 * The arguments are subject to the same constraints as when initialising
 * the receiver.
 */
- (void) setKeys: (NSArray*)keys andValues: (NSArray*)values;

/** Controls whether the field supports multiple selection of values.<br />
 * The default setting is NO.
 */
- (void) setMayBeMultiple: (BOOL)flag;

/** Orders the menu appearance in the browser on the basis of the keys
 * it was initialised with.
 */
- (void) sortUsingSelector: (SEL)aSelector;
@end

/** This class provides a form field for password data
 */
@interface	WebServerFieldPassword : WebServerField
@end

#endif

