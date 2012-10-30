/** 
   Copyright (C) 2009 Free Software Foundation, Inc.
   
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

   $Date: 2009-09-25 11:17:32 +0100 (Fri, 25 Sep 2009) $ $Revision: 28737 $
   */ 

#ifndef	INCLUDED_WEBSERVERBUNDLES_H
#define	INCLUDED_WEBSERVERBUNDLES_H

#import	<Foundation/NSObject.h>

#import	"WebServer.h"
#import	"WebServerBundles.h"

/**
 * WebServerBundles is an example delegate for the WebServer class.<br />
 * This is intended to act as a convenience for a scheme where the
 * WebServer instance in a program is configured by values obtained
 * from the user defaults system, and incoming requests may be handled
 * by different delegate objects depending on the path information
 * supplied in the request.  The WebServerBundles instance is responsible
 * for loading the bundles (based on information in the WebServerBundles
 * dictionary in the user defaults system) and for forwarding requests
 * to the appropriate bundles for processing.<br />
 * If a request comes in which is not an exact match for the path of any
 * handler, the request path is repeatedly shortened by chopping off the
 * last path component until a matching handler is found.<br />
 * The paths in the dictionary must <em>not</em> end with a slash...
 * an empty string will match all requests which do not match a handler
 * with a longer path.
 * <example>
 * </example>
 */
@interface	WebServerBundles : NSObject <WebServerDelegate>
{
  NSMutableDictionary	*_handlers;
  WebServer		*_http;
}

/**
 * Handle a notification that the defaults have been updated ... change
 * WebServer configuration if necessary.<br />
 * <list>
 *   <item>
 *     WebServerPort must be used to specify the port that the server
 *     listens on.  See [WebServer-setPort:secure:] for details.
 *   </item>
 *   <item>
 *     WebServerSecure may be supplied to make the server operate as an
 *     HTTPS server rather than an HTTP server.
 *     See [WebServer-setPort:secure:] for details.
 *   </item>
 *   <item>
 *     WebServerBundles is a dictionary keyed on path strings, whose
 *     values are dictionaries, each containing per-handler configuration
 *     information and the name of the bundle containing the code to handle
 *     requests sent to the path.  NB. the bundle name listed should
 *     omit the <code>.bundle</code> extension.
 *   </item>
 * </list>
 * Returns YES on success, NO on failure (if the port of the WebServer
 * cannot be set).
 */
- (BOOL) defaultsUpdate: (NSNotification *)aNotification;

/**
 * Returns the handler to be used for the specified path, or nil if there
 * is no handler available.<br />
 * If the info argument is non-null, it is used to return additional
 * information, either the path actually matched, or an error string.
 */
- (id) handlerForPath: (NSString*)path info: (NSString**)info;

/**
 * Return dictionary of all handlers by name (path in request which maps
 * to that handler instance).
 */
- (NSMutableDictionary*) handlers;

/**
 * Return the WebServer instance that the receiver is acting as a
 * delegate for.
 */
- (WebServer*) http;

/** <init />
 * Initialises the receiver as the delegate of HTTP and configures
 * the WebServer based upon the settings found in the user defaults
 * system by using the -defaultsUpdate: method.
 */
- (id) initAsDelegateOf: (WebServer*)http;

/**
 * <p>Handles an incoming request by forwarding it to another handler.<br />
 * If a direct mapping is available from the path in the request to
 * an existing handler, that handler is used to process the request.
 * Otherwise, the WebServerBundles dictionary (obtained from the
 * defaults system) is used to map the request path to configuration
 * information listing the bundle containing the handler to be used.
 * </p>
 * <p>The configuration information is a dictionary containing the name
 * of the bundle (keyed on 'Name'), and this is used to locate the
 * bundle in the applications resources.<br />
 * Before a request is passed on to a handler, two extra headers are set
 * in it ... <code>x-http-path-base</code> and <code>x-http-path-info</code>
 * being the actual path matched for the handler, and the remainder of the
 * path after that base part.
 * </p>
 */
- (BOOL) processRequest: (WebServerRequest*)request
               response: (WebServerResponse*)response
		    for: (WebServer*)http;

/**
 * Registers an object as the handler for a particular path.<br />
 * Registering a nil handler destroys any existing handler for the path.
 */
- (void) registerHandler: (id)handler forPath: (NSString*)path;

/**
 * Just write to stderr using NSLog.
 */
- (void) webAlert: (NSString*)message for: (WebServer*)http;

/**
 * Log an audit record as UTF8 data on stderr.
 */
- (void) webAudit: (NSString*)message for: (WebServer*)http;

/**
 * Just discard the message ... please subclass or use a category to
 * override this method if you wish to used the logged messages.
 */
- (void) webLog: (NSString*)message for: (WebServer*)http;

@end


#endif

