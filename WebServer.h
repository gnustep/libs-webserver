/** 
   Copyright (C) 2004-2009 Free Software Foundation, Inc.
   
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

<title>WebServer documentation</title>
<chapter>
  <heading>The WebServer class</heading>
  <section>
    <heading>What is the WebServer class?</heading>
    <p>
      The WebServer class provides the framework for a GNUstep program to
      act as an HTTP or HTTPS server for simple applications.<br />
      It does not attempt to be a general-purpose web server, but is rather
      intended to permit a program to easily handle requests from automated
      systems which are intended to control, monitor, or use the services
      provided by the program in which the class is embedded.<br />
      The emphasis is on making it robust/reliable/simple, so you can rapidly
      develop software using it.  It is a single-threaded, single-process
      system using asynchronous I/O, so you can easily run it under
      debug in gdb to fix any bugs in your delegate object.<br />
    </p>
    <p>
      The class is controlled by a few straightforward settings and
      basically operates by handing over requests to its delegate.
      The delegate must at least implement the
      [(WebServerDelegate)-processRequest:response:for:] method.
    </p>
    <p>
      Built-in facilities include -
    </p>
    <list>
      <item>Parsing of parameter string in request URL</item>
      <item>Parsing of url encoded form data in a POST request</item>
      <item>Parsing of form encoded data in a POST request</item>
      <item>Substitution into template pages on output</item>
      <item>SSL support</item>
      <item>HTTP Basic authentication</item>
      <item>Limit access by IP address</item>
      <item>Limit total number of simultaneous connections</item>
      <item>Limit number of simultaneous connections from one address</item>
      <item>Limit idle time permitted on a connection</item>
      <item>Limit size of request headers permitted</item>
      <item>Limit size of request body permitted</item>
    </list>
  </section>
  <section>
    <heading>Performance and threading</heading>
    <p>
      The WebServer class essentially works using asynchronous I/O in a
      single thread.  The asynchronous I/O mechanism is capably of reading
      a request of up to the operating systems network buffer size in a
      single operation and similarly writing out a response of up to the
      operating system's network buffer size.<br />
      As long as requests and responses are within those limits, it can be
      assumed that low processing of a request in the 
      [(WebServerDelegate)-processRequest:response:for:] method will have
      little impact on efficiency as the WebServer read request and write
      responses as rapidly as the delegates processing can handle them.<br />
      If however the I/O sizes are larger than the buffers, then writing
      a response will need to be multiple operations and each buffer full
      of data may need to wait for the next call to the processing method
      before it can be sent.<br />
      So, for large request/response sizes, or other cases where processing 
      a single request at a time is a problem, the WebServer class provides
      a simple mechanism for supporting multithreaded use.
    </p>
    <p>To use multiple threads, all you need to do is have the delegate
      implementation of [(WebServerDelegate)-processRequest:response:for:]
      pass processing to another thread and return NO.  When processing is
      complete, the delegate calls -completedWithResponse: to pass the
      response back to the WebServer instance for delivery to the client.<br />
      NB. the -completedWithResponse: method is safe to call from any thread
      but all other methods of the class should be called only from the
      main thread.  If a delegate needs to call methods of the WebServer
      instance in order to handle a request, it should do so in the
      [(WebServerDelegate)-processRequest:response:for:] method before
      handing control to another thread.
    </p>
  </section>
</chapter>

   $Date$ $Revision$
   */ 

#ifndef	INCLUDED_WEBSERVER_H
#define	INCLUDED_WEBSERVER_H

#include	<Foundation/NSObject.h>
#include	<Foundation/NSMapTable.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSFileHandle.h>
#include	<Foundation/NSNotification.h>
#include	<Foundation/NSArray.h>
#include	<Foundation/NSSet.h>
#include	<Foundation/NSTimer.h>
#include	<GNUstepBase/GSMime.h>

@class	WebServer;
@class	WebServerField;
@class	WebServerFieldMenu;
@class	WebServerForm;
@class	NSUserDefaults;

/**
 * This protocol is implemented by a delegate of a WebServer instance
 * in order to allow the delegate to process requests which arrive
 * at the server.
 */
@protocol	WebServerDelegate
/**
 * Process the HTTP request whose headers and data are provided in
 * a GSMimeDocument.<br />
 * Extra headers are created as follows -
 * <deflist>
 *   <term>x-http-method</term>
 *   <desc>The method from the HTTP request (eg. GET or POST)</desc>
 *   <term>x-http-path</term>
 *   <desc>The path from the HTTP request, or an empty string if
 *     there was no path.</desc>
 *   <term>x-http-query</term>
 *   <desc>The query string from the HTTP request or an empty string
 *     if there was no query.</desc>
 *   <term>x-http-scheme</term>
 *   <desc>Returns the URL scheme used (http or https) to access the server.
 *     This is https if the request arrived on an ancrypted connection or if
 *     the server is configured as being behind a secure proxy.</desc>
 *   <term>x-http-version</term>
 *   <desc>The version from the HTTP request.</desc>
 *   <term>x-local-address</term>
 *   <desc>The IP address of the local host receiving the request.</desc>
 *   <term>x-local-port</term>
 *   <desc>The port of the local host receiving the request.</desc>
 *   <term>x-remote-address</term>
 *   <desc>The IP address of the host that the request came from.</desc>
 *   <term>x-remote-port</term>
 *   <desc>The port of the host that the request came from.</desc>
 *   <term>x-http-username</term>
 *   <desc>The username from the 'authorization' header if the request
 *     supplied HTTP basic authentication.</desc>
 *   <term>x-http-password</term>
 *   <desc>The password from the 'authorization' header if the request
 *     supplied HTTP basic authentication.</desc>
 *   <term>x-count-requests</term>
 *   <desc>The number of requests being precessed at the point when
 *      this request started (includes this request).</desc>
 *   <term>x-count-connections</term>
 *   <desc>The number of connections established to the WebServer at the
 *      point when this request started (including the connection this
 *      request arrived on).</desc>
 *   <term>x-count-connected-hosts</term>
 *   <desc>The number of connects hosts (IP addresses) at the point when
 *      this request started (including the host which sent this request).
 *   </desc>
 *   <term>x-count-host-connections</term>
 *   <desc>The number of connections to the web server from the host which
 *     sent this request at the point when this request started (includes the
 *     connection that this request arrived on).</desc>
 * </deflist>
 * On completion, the method must modify response to contain the data
 * and headers to be sent out.<br />
 * The 'content-length' header need not be set in the response as it will
 * be overridden anyway.<br />
 * The special 'HTTP' header will be used as the response/status line.
 * If not supplied, 'HTTP/1.1 200 Success' or 'HTTP/1.1 204 No Content' will
 * be used as the response line, depending on whether the data is empty or
 * not.<br />
 * If an exception is raised by this method, the response produced will
 * be set to 'HTTP/1.0 500 Internal Server Error' and the connection will
 * be closed.<br />
 * If the method returns YES, the WebServer instance sends the response to
 * the client process which made the request.<br />
 * If the method returns NO, the WebServer instance assumes that the
 * delegate is processing the request in another thread (perhaps it will
 * take a long time to process) and takes no action until the delegate
 * calls [WebServer-completedWithResponse:] to let it know that processing
 * is complete and the response should at last be sent out. 
 */
- (BOOL) processRequest: (GSMimeDocument*)request
	       response: (GSMimeDocument*)response
		    for: (WebServer*)http;
/**
 * Log an error or warning ... if the delegate does not implement this
 * method, the message is logged to stderr using the NSLog function.
 */
- (void) webAlert: (NSString*)message for: (WebServer*)http;

/**
 * Log an audit record ... if the delegate does not implement this
 * method, the message is logged to stderr.<br />
 * The logged record is similar to the Apache common log format,
 * though it differs after the timestamp:
 * <deflist>
 *   <term>ip address</term>
 *   <desc>the address of the client host making the request</desc>
 *   <term>ident</term>
 *   <desc>not currently implemented ... '-' as placeholder</desc>
 *   <term>ident</term>
 *   <desc>not currently implemented ... '-' as placeholder</desc>
 *   <term>user</term>
 *   <desc>the remote user name from the authorization header, or '-'</desc>
 *   <term>timestamp</term>
 *   <desc>the date/time enclosed in square brackets</desc>
 *   <term>command</term>
 *   <desc>The command sent in the request ... as a quoted string</desc>
 *   <term>agent</term>
 *   <desc>The user-agent header from the request ... as a quoted string</desc>
 *   <term>result</term>
 *   <desc>The initial response line ... as a quoted string</desc>
 * </deflist>
 */
- (void) webAudit: (NSString*)message for: (WebServer*)http;

/**
 * Log a debug ... if the delegate does not implement this
 * method, no logging is done.
 */
- (void) webLog: (NSString*)message for: (WebServer*)http;
@end

/**
 * <p>You create an instance of the WebServer class in order to handle
 * incoming HTTP or HTTPS requests on a single port.
 * </p>
 * <p>Before use, it must be configured using the -setPort:secure: method
 * to specify the port and if/how SSL is to be used.
 * </p>
 * <p>You must also set a delegate to handle incoming requests,
 * and may specify a maximum number of simultaneous connections
 * which may be in progress etc.
 * </p>
 * <p>In addition to the options which may be set directly in the class,
 * you can provide some configuration via the standard NSDefaults class.
 * This information is set at initialisation of an instance and the
 * class recognises the following defaults keys -
 * </p>
 * <deflist>
 *   <term>WebServerHosts</term>
 *   <desc>An array of host IP addresses to list the hosts permitted to
 *   send requests to the server.  If defined, requests from other hosts
 *   will be rejected (with an HTTP 403 response).
 *   It may be better to use firewalling to control this sort of thing.
 *   </desc>
 *   <term>WebServerQuiet</term>
 *   <desc>An array of host IP addresses to refrain from logging ...
 *   this is useful if (for instance) you have a monitoring process which
 *   sends requests to the server to be sure it's alive, and don't want
 *   to log all the connections from this monitor.<br />
 *   Not only do we refrain from logging anything but exceptional events
 *   about these hosts, connections and requests by these hosts are not
 *   counted in statistics we generate.
 *   </desc>
 *   <term>ReverseHostLookup</term>
 *   <desc>A boolean (default NO) which specifies whether the server should
 *   lookup the host name for each incoming connection, and refuse
 *   connections where no host can be found.  The downside of enabling this
 *   is that host lookups can be slow and cause performance problems.
 *   </desc>
 * </deflist>
 * <p>To shut down the WebServer, you should call -setPort:secure: with
 * nil arguments.  This will stop the server listening for incoming
 * connections and wait for any existing connections to be closed
 * (or to time out), after which the timer used to check connection
 * timeouts will be stopped, releasing the WebServer instance (which
 * may cause it to be deallocated if you haven't retained it).
 * </p>
 */
@interface	WebServer : NSObject
{
@private
  NSNotificationCenter	*_nc;
  NSUserDefaults	*_defs;
  NSString		*_port;
  BOOL			_accepting;
  BOOL			_verbose;
  BOOL			_durations;
  BOOL                  _reverse;
  BOOL			_secureProxy;
  uint8_t		_reject;
  NSDictionary		*_sslConfig;
  NSArray		*_quiet;
  NSArray		*_hosts;
  NSUInteger		_substitutionLimit;
  NSUInteger		_maxBodySize;
  NSUInteger		_maxRequestSize;
  NSUInteger		_maxConnections;
  NSUInteger		_maxConnectionRequests;
  NSTimeInterval	_maxConnectionDuration;
  NSUInteger		_maxPerHost;
  id			_delegate;
  NSFileHandle		*_listener;
  NSMapTable		*_connections;
  NSMapTable		*_processing;
  NSUInteger		_handled;
  NSUInteger		_requests;
  NSString		*_root;
  NSTimer		*_ticker;
  NSTimeInterval	_connectionTimeout;
  NSTimeInterval	_ticked;
  NSCountedSet		*_perHost;
  void			*_reserved;
}

/** Returns the base URL used by the remote client to send the request.
 */
+ (NSURL*) baseURLForRequest: (GSMimeDocument*)request;

/**
 * Same as the instance method of the same name.
 */
+ (NSUInteger) decodeURLEncodedForm: (NSData*)data
			       into: (NSMutableDictionary*)dict;

/**
 * Same as the instance method of the same name.
 */
+ (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
			       into: (NSMutableData*)data;


/**
 * Same as the instance method of the same name.
 */
+ (NSString*) escapeHTML: (NSString*)str;

/**
 * Returns a new URL formed by putting the newPath in the oldURL and
 * appending a query string containing the fields specified in the
 * fields argument (optionally extended/overridden by any other fields 
 * defined as key/value pairs in the nil terminated list of additional
 * arguments.<br />
 * If the oldURL is nil, then the new URL will be a relative URL
 * containing just the path and query string.<br />
 * If newPath is an absolute path, it replaces the path from oldURL,
 * otherwise it replaces the last path component from uldURL.
 */
+ (NSURL*) linkPath: (NSString*)newPath
	   relative: (NSURL*)oldURL
	      query: (NSDictionary*)fields, ...;

/**
 * Same as the instance method of the same name.
 */
+ (NSData*) parameter: (NSString*)name
		   at: (NSUInteger)index
		 from: (NSDictionary*)params;

/**
 * Same as the instance method of the same name.
 */
+ (NSString*) parameterString: (NSString*)name
			   at: (NSUInteger)index
			 from: (NSDictionary*)params
		      charset: (NSString*)charset;

/** Convenience method to set up a temporary redirect to the specified URL
 * using the supplied response data.  The method returns YES so that it is
 * reasonable to pass its return value back directly as the return value
 * for a call to the -processRequest:response:for: method. 
 */
+ (BOOL) redirectRequest: (GSMimeDocument*)request
		response: (GSMimeDocument*)response
		      to: (NSURL*)destination;

/**
 * This method is called for each incoming request, and checks that the
 * requested resource is accessible (basic user/password access control).<br />
 * The method returns YES if access is granted, or returns NO and sets the
 * appropriate response values if access is refused.<br />
 * If access is refused by this method, the delegate is not informed of the
 * request at all ... so this forms an initial access control mechanism,
 * but if it is passed, the delegate is still free to implement its own
 * additional access control within the
 * [(WebServerDelegate)-processRequest:response:for:] method.<br />
 * The access control is managed by the <code>WebServerAccess</code>
 * user default, which is a dictionary whose keys are paths, and whose
 * values are dictionaries specifying the access control for those paths.
 * Access control is done on the basis of the longest matching path.<br />
 * Each access control dictionary contains an authentication realm string
 * (keyed on <em>Realm</em>) and a dictionary containing username/password
 * pairs (keyed on <em>Users</em>).<br />
 * eg.
 * <example>
 * WebServerAccess = {
 *   "" = {
 *     Realm = "general";
 *     Users = {
 *       Fred = 1942;
 *     };
 *   };
 * };
 * </example>
 */
- (BOOL) accessRequest: (GSMimeDocument*)request
	      response: (GSMimeDocument*)response;

/**
 * <p>This may only be called in the case where a call to the delegate's
 * [(WebServerDelegate)-processRequest:response:for:] method
 * to process a request returned NO, indicating that the delegate
 * would handle the request in another thread and complete it later.
 * </p>
 * <p>In such a case, the thread handling the request in the delegate
 * <em>must</em> call this method upon completion (passing in the same
 * request parameter that was passed to the delegate) to inform the
 * WebServer instance that processing of the request has been completed
 * and that it should now take over the job of sending the response to
 * the client process.
 * </p>
 */
- (void) completedWithResponse: (GSMimeDocument*)response;

/**         
 * Decode an application/x-www-form-urlencoded form and store its
 * contents into the supplied dictionary.<br />
 * The resulting dictionary keys are strings.<br />
 * The resulting dictionary values are arrays of NSData objects.<br />
 * You probably don't need to call this method yourself ... more likely
 * you will use the -parameters: method instead.<br />
 * NB. For forms POST-ed using <code>multipart/form-data</code> you don't
 * need to perform any explicit decoding as this will already have been
 * done for you and the decoded form will be presented as the request
 * GSMimeDocument.  The fields of the form will be the component parts
 * of the content of the request and can be accessed using the standard
 * GSMimeDocument methods.<br />
 * This method returns the number of fields actually decoded.
 */         
- (NSUInteger) decodeURLEncodedForm: (NSData*)data
			       into: (NSMutableDictionary*)dict;

/**         
 * Encode an application/x-www-form-urlencoded form and store its
 * representation in the supplied data object.<br />
 * The dictionary contains the form, with keys as data objects or strings,
 * and values as arrays of values to be placed in the data.
 * Each value in the array may be a data object or a string.<br />
 * As a special case, a value may be a data object or a string rather
 * than an array ... this is treated like an array of one value.<br />
 * All non data keys and values are converted to data using
 * utf-8 encoding.<br />
 * This method returns the number of values actually encoded.
 */         
- (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
			       into: (NSMutableData*)data;

/** Escapes special characters in str for use in an HTML page.<br />
 * This converts &amp; to &amp;amp; for instance, and replaces
 * non-ascii characters with the appropriate numeric entity references.
 */
- (NSString*) escapeHTML: (NSString*)str;

/**
 * Returns YES if the server is for HTTPS (encrypted connections),
 * NO otherwise.
 */
- (BOOL) isSecure;

/**
 * Extracts request parameters from the HTTP query string and from the
 * request body (if it was application/x-www-form-urlencoded or
 * multipart/form-data) and return the extracted parameters as a
 * mutable dictionary whose keys are the parameter names and whose
 * values are arrays containing the data for each parameter.<br />
 * You should call this no more than once per request, storing the result
 * and using it as an argument to the methods used to extract particular
 * parameters.<br />
 * Parameters from the request data are <em>added</em> to any found in the
 * query string.<br />
 * Values provided as <code>multipart/form-data</code> are also available
 * in a more flexible format as the content of the request.
 */
- (NSMutableDictionary*) parameters: (GSMimeDocument*)request;

/**
 * Returns the index'th data parameter for the specified name.<br />
 * Matching of names is case-insensitive<br />
 * If there are no data items for the name, or if the index is
 * too large for the number of items which exist, this returns nil.
 */
- (NSData*) parameter: (NSString*)name
		   at: (NSUInteger)index
		 from: (NSDictionary*)params;

/**
 * Calls -parameter:at:from: with an index of zero.
 */
- (NSData*) parameter: (NSString*)name from: (NSDictionary*)params;

/**
 * Calls -parameterString:at:from:charset: with a nil charset so that
 * UTF-8 encoding is used for string conversion.
 */
- (NSString*) parameterString: (NSString*)name
			   at: (NSUInteger)index
			 from: (NSDictionary*)params;
/**
 * Calls -parameter:at:from: and, if the result is non-nil
 * converts the data to a string using the specified mime
 * characterset, (if charset is nil, UTF-8 is used).
 */
- (NSString*) parameterString: (NSString*)name
			   at: (NSUInteger)index
			 from: (NSDictionary*)params
		      charset: (NSString*)charset;
/**
 * Calls -parameterString:at:from:charset: with an index of zero and
 * a nil value for charset (which causes data to be treated as UTF-8).
 */
- (NSString*) parameterString: (NSString*)name
			 from: (NSDictionary*)params;

/**
 * Calls -parameterString:at:from:charset: with an index of zero.
 */
- (NSString*) parameterString: (NSString*)name
			 from: (NSDictionary*)params
		      charset: (NSString*)charset;

/**
 * Loads a template file from disk and places it in aResponse as content
 * whose mime type is determined from the file extension using the
 * provided mapping (or a simple built-in default mapping if map is nil).<br />
 * If you have a dedicated web server for handling static pages (eg images)
 * it is better to use that rather than vending static pages using this
 * method.  It's unlikely that this method can be as efficient as a dedicated
 * server.  However this mechanism is adequate for moderate throughputs.
 */
- (BOOL) produceResponse: (GSMimeDocument*)aResponse
	  fromStaticPage: (NSString*)aPath
		   using: (NSDictionary*)map;

/**
 * Loads a template file from disk and places it in aResponse as content
 * of type 'text/html' with a charset of 'utf-8'.<br />
 * The argument aPath is a path relative to the root path set using
 * the -setRoot: method.<br />
 * Substitutes values into the template from map using the
 * -substituteFrom:using:into:depth: method.<br />
 * Returns NO if them template could not be read or if any substitution
 * failed.  In this case no value is set in the response.<br />
 * If the response is actually text of another type, or you want another
 * characterset used, you can change the content type header in the
 * request after you call this method.
 */
- (BOOL) produceResponse: (GSMimeDocument*)aResponse
	    fromTemplate: (NSString*)aPath
		   using: (NSDictionary*)map;

/**
 * Sets the time after which an idle connection should be shut down.<br />
 * Default is 30.0
 */
- (void) setConnectionTimeout: (NSTimeInterval)aDelay;

/**
 * Sets the delegate object which processes requests for the receiver.
 */
- (void) setDelegate: (id)anObject;

/**
 * Sets a flag to determine whether logging of request and connection
 * durations is to be performed.<br />
 * If this is YES then the duration of requests and connections will
 * be logged using the [(WebServerDelegate)-webLog:for:] method.<br />
 * The request duration is calculated from the point where the first byte
 * of data in the request is read to the point where the response has
 * been completely written.<br />
 * This is useful for debugging and where a full audit trail is required.
 */
- (void) setDurationLogging: (BOOL)aFlag;

/**
 * Sets the maximum size of an uploaded request body.<br />
 * The default is 4M bytes.<br />
 * The HTTP failure response for too large a body is 413.
 */
- (void) setMaxBodySize: (NSUInteger)max;

/**
 * Sets the maximum total duration  of the incoming requests handled on an
 * individual connection.  After this many requests are handled, the
 * connection is closed (so another client may get a chance to connect).<br />
 * The default is 10.0 seconds.
 */
- (void) setMaxConnectionDuration: (NSTimeInterval)max;

/**
 * Sets the maximum size number of incoming requests to be handled on an
 * individual connection.  After this many requests are handled, the
 * connection is closed (so another client may get a chance to connect).<br />
 * The default is 100 requests.
 */
- (void) setMaxConnectionRequests: (NSUInteger)max;

/**
 * Sets the maximum number of simultaneous connections with clients.<br />
 * The default is 128.<br />
 * A value of zero permits unlimited connections.<br />
 * If this limit is reached, the behavior of the software depends upon
 * the value set by the -setMaxConnectionsReject: method.
 */
- (void) setMaxConnections: (NSUInteger)max;

/**
 * Sets the maximum number of simultaneous connections with a particular
 * remote host.<br />
 * The default is 32.<br />
 * A value of zero permits unlimited connections.<br />
 * If this value is greater than that of -setMaxConnections: then it will
 * have no effect as the maximum number of connections from one host
 * cannot be reached.<br />
 * The HTTP failure response for too many connections from a host is 503.
 */
- (void) setMaxConnectionsPerHost: (NSUInteger)max;

/**
 * <p>This setting (default value NO) determines the behavior of the software
 * when the number of simultaneous incoming connections exceeds the value
 * set by the -setMaxConnections: method.
 * </p>
 * <p>If reject is NO, the software will simply not accept the incoming
 * connections until some earlier connection is terminated, so the
 * incoming connections will be queued by the operating system and
 * may time-out if no connections become free quickly enough for them
 * to be handled.  In the case of a huge number of incoming connections
 * the 'listen' queue of the operating system may fill up and connections
 * may be lost altogether.
 * </p>
 * <p>If reject is yes, then the service will set aside a slot for one
 * extra connection and, when the number of permitted connections is
 * exceeded, the server will accept the first additional connection,
 * send back an HTTP 503 response, and drop the additional connection
 * again. This means that clients should receive a 503 response rather
 * than finding that their connection attempts block and possible time out.
 * </p>
 */
- (void) setMaxConnectionsReject: (BOOL)reject;

/**
 * Sets the maximum size of an incoming request (including all headers,
 * but not the body).<br />
 * The default is 8K bytes.<br />
 * The HTTP failure response for too large a request is 413.
 */
- (void) setMaxRequestSize: (NSUInteger)max;

/**
 * Sets the port and security information for the receiver ... without
 * this the receiver will not listen for incoming requests.<br />
 * If secure is nil then the receiver listens on aPort for HTTP requests.<br />
 * If secure is not nil, the receiver listens for HTTPS instead.<br />
 * If secure is a dictionary containing <code>CertificateFile</code>,
 * <code>KeyFile</code> and <code>Password</code> then the server will
 * use the specified certificate and key files (which it will access
 * using the password).<br />
 * The <em>secure</em> dictionary may also contain other dictionaries
 * keyed on IP addresses, and if the address that an incoming connection
 * arrived on matches the key of a dictionary, that dictionary is used
 * to provide the certificate information, with the top-level values
 * being used as a fallback.<br />
 * This method returns YES on success, NO on failure ... if it returns NO
 * then the receiver will <em>not</em> be capable of handling incoming
 * web requests!<br />
 * Typically a failure will be due to an invalid port being specified ...
 * a port may not already be in use and may not be in the range up to 1024
 * (unless running as the super-user).<br />
 * Call this with a nil port argument to shut the server down as soon as
 * all current connections are closed.
 */
- (BOOL) setPort: (NSString*)aPort secure: (NSDictionary*)secure;

/** Configures a flag to say whether the receiver is running behind a
 * secure proxy and all connections are to be considered as having come
 * in via https.
 */
- (void) setSecureProxy: (BOOL)aFlag;

/**
 * Sets the maximum recursion depth allowed for substitutions into
 * templates.  This defaults to 4.
 */
- (void) setSubstitutionLimit: (NSUInteger)depth;

/**
 * Set root path for loading template files from.<br />
 * Templates may only be loaded from within this directory.
 */
- (void) setRoot: (NSString*)aPath;

/**
 * Sets a flag to determine whether verbose logging is to be performed.<br />
 * If this is YES then all incoming requests and their responses will
 * be logged using the [(WebServerDelegate)-webLog:for:] method.<br />
 * Setting this to YES automatically sets duration logging to YES as well,
 * though you can then call -setDurationLogging: to set it back to NO.<br />
 * This is useful for debugging and where a full audit trail is required.
 */
- (void) setVerbose: (BOOL)aFlag;

/**
 * Perform substitutions replacing the markup in aTemplate with the
 * values supplied by map and appending the results to the result.<br />
 * Substitutions are recursive, and the depth argument is used to
 * specify the current recursion depth (you should normally call this
 * method with a depth of zero at the start of processing a template).<br />
 * Any value inside SGML comment delimiters ('&lt;!--' and '--&gt;') is
 * treated as a possible key in map and the entire comment is replaced
 * by the corresponding map value (unless it is nil).  Recursive substitution
 * is done unless the mapped value <em>starts</em> with an SGML comment.<br />
 * While the map is nominally a dictionary, in fact it may be any
 * object which responds to the objectForKey: method by returning
 * an NSString or nil.<br />
 * The method returns YES on success, NO on failure (depth too great).<br />
 * You don't normally need to use this method directly ... call the
 * -produceResponse:fromTemplate:using: method instead.
 */
- (BOOL) substituteFrom: (NSString*)aTemplate
		  using: (NSDictionary*)map
		   into: (NSMutableString*)result
		  depth: (NSUInteger)depth;

@end

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
- (BOOL) processRequest: (GSMimeDocument*)request
               response: (GSMimeDocument*)response
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

/** This class provides a framework for handling incoming form data
 * and substituting form fields into n html template being output
 * in a response.
 */
@interface	WebServerForm: NSObject
{
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

/** Creates a new field with the specified name and adds it to the form.
 * Replaces any existing field with the same name.
 */
- (WebServerFieldMenu*) fieldNamed: (NSString*)name
			  menuKeys: (NSArray*)keys
			    values: (NSArray*)values;

/** Creates a new field with the specified name and adds it to the form.
 * Replaces any existing field with the same name.
 */
- (WebServerFieldMenu*) fieldNamed: (NSString*)name
			 menuYesNo: (NSString*)prefill;

/** Return the names of the fields on the form.
 */
- (NSArray*) fieldNames;

/** Places values from the form fields in the map dictionary.
 */
- (void) output: (NSMutableDictionary*)map;

/** Takes values from the parameters dictionary and sets them into the
 * fields in the form.
 */
- (void) takeValuesFrom: (NSDictionary*)params;

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
@interface	WebServerField: NSObject
{
  NSString	*_name;
  id		_value;
  id		_prefill;
  BOOL		_mayBeEmpty;
  uint16_t	_cols;
  uint16_t	_rows;
}

/** Return the number of columns set using the -setColumns: method or
 * zero if no value has been set.
 */
- (NSUInteger) columns;

/** <init />
 * Initialises the receiver with the specified name which must be a valid
 * field name (alphanumeric string plus a few characters).
 */
- (id) initWithName: (NSString*)name;

/** Returns the value previously set by the -setMayBeEmpty: method,
 * or NO if that method was not called.
 */
- (BOOL) mayBeEmpty;

/** Returns the name with which the receiver was initialised.
 */
- (NSString*) name;

/** Sets a value in the map which is the text of the HTML input field needed
 * to provide data for the receiver.  The map may then be used to substitute
 * into an HTML template.
 */
- (void) output: (NSMutableDictionary*)map for: (WebServerForm*)form;

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

/** This class extends [WebServerForm] to provide a form field
 * as a menu for which a user can select from a fixed list of options.
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

#endif

