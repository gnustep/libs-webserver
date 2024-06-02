/** 
   Copyright (C) 2004-2010 Free Software Foundation, Inc.
   
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
      develop software using it.<br />
      By default, it is a single-threaded, single-process
      system using asynchronous I/O, so you can easily run it under
      debug in gdb to fix any bugs in your delegate object.<br />
      For performance, it can also operate as a massively multi-threaded
      process, with separate I/O threads handling groups of hundreds
      or thousands of simultaneous connections, and a pool of processing
      threads handling parsing of incoming requests.
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
      assumed that slow processing of a request in the 
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
      master thread.  If a delegate needs to call methods of the WebServer
      instance in order to handle a request, it should do so in the
      [(WebServerDelegate)-processRequest:response:for:] method before
      handing control to another thread.
    </p>
    <p>If the simple threading outlined above is not sufficient for your
      appplication, a more agressive threading scheme is available.<br />
      You may call the -setIOThreads:andPool: method to ask the WebServer
      instance to use threading internally itself.  In this case the
      low-level I/O operations will be shared across the specified number
      of I/O threads instead of occurring in the master thread (makes sense
      if you need to handle a very large number of simultaneous connections).
      In addition, the parsing of the incoming HTTP request and the generation
      of the raw data of the outgoing response are performed using threads
      from the thread pool, so that the I/O threads can concentrate on the
      low level communications.
    </p>
    <p>With the use of a thread pool, you muse be aware that the 
      -preProcessRequest:response:for: method will be
      executed by a thread from the pool rather than by the master thread.<br />
      This may be useful if you wish to split the processing into part
      which is thread-safe, and part which uses complex interacting data
      structures which are hard to make safe (done in the main processing
      method).
    </p>
  </section>
</chapter>

   $Date$ $Revision$
   */ 

#ifndef	INCLUDED_WEBSERVER_H
#define	INCLUDED_WEBSERVER_H

#include	<Foundation/NSObject.h>
#include	<GNUstepBase/GSMime.h>

@class	GSThreadPool;
@class	IOThread;
@class	WebServer;
@class	WebServerConfig;
@class	WebServerRequest;
@class	WebServerResponse;
@class  WebServerAuthenticationFailureLog;
@class	NSArray;
@class	NSCountedSet;
@class	NSDictionary;
@class	NSFileHandle;
@class	NSLock;
@class	NSMutableSet;
@class	NSNotification;
@class	NSNotificationCenter;
@class	NSSet;
@class	NSString;
@class	NSTimer;
@class	NSThread;
@class	NSUserDefaults;

/** This protocol is implemented by a delegate of a WebServer instance
 * in order to allow the delegate to process requests which arrive
 * at the server.
 */
@protocol	WebServerDelegate <NSObject>

/**
 * Process the HTTP request whose headers and data are provided in
 * a GSMimeDocument subclass.<br />
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
 *     This is https if the request arrived on an encrypted connection or if
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
 *   <term>x-cert-issuer</term>
 *   <desc>The certificate issuer (RFC4514) if the request connection was
 *     authenticated with a TLS/SSL certificate or if a secure proxy is in
 *     use and the proxy set this header. NB the header from a secure proxy
 *     takes precedence.</desc>
 *   <term>x-cert-owner</term>
 *   <desc>The certificate subject/owner (RFC4514) if the request connection
 *     was authenticated with a TLS/SSL certificate or if a secure proxy is in
 *     use and the proxy set this header. NB the header from a secure proxy
 *     takes precedence.</desc>
 *   <term>x-cert-owner-proxy</term>
 *   <desc>Used if the proxy provides a certificate to identify itself.</desc>
 *   <term>x-cert-issuer-proxy</term>
 *   <desc>Used if the proxy provides a certificate to identify itself.</desc>
 *   <term>x-count-requests</term>
 *   <desc>The number of requests being processed at the point when
 *      this request started (includes this request).</desc>
 *   <term>x-count-connections</term>
 *   <desc>The number of connections established to the WebServer at the
 *      point when this request started (including the connection this
 *      request arrived on).</desc>
 *   <term>x-count-connected-hosts</term>
 *   <desc>The number of connected hosts (IP addresses) at the point when
 *      this request started (including the host which sent this request).
 *   </desc>
 *   <term>x-count-host-connections</term>
 *   <desc>The number of connections to the web server from the host which
 *     sent this request at the point when this request started (includes the
 *     connection that this request arrived on).</desc>
 * </deflist>
 * On completion, the method must modify response (an instance of a subclass
 * of GSMimeDocument) to contain the data and headers to be sent out.<br />
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
 * delegate is processing the request asynchronously, either in another
 * thread or with completion being triggered by an asynchronous I/O event.
 * The server takes no action respond to the request until the delegate
 * calls [WebServer-completedWithResponse:] to let it know that processing
 * is complete and the response should at last be sent out.<br />
 * This method is always called in the master thread of your WebServer
 * instance (usually the main thread of your application).
 */
- (BOOL) processRequest: (WebServerRequest*)request
	       response: (WebServerResponse*)response
		    for: (WebServer*)http;
@end

/** This is an informal protocol documenting optional methods which will
 * be used if implemented by the delegate.
 */
@interface	NSObject(WebServerDelegate)

/** Informs the handler (if any) associated with the response that the
 * server has written the response to the network.  The timeInterval
 * is measured between the point when the server started reading the
 * request and the point at which it finished writing the response.
 */
- (void) completedResponse: (WebServerResponse*)response
		  duration: (NSTimeInterval)timeInterval;

/** If your delegate implements this method it will be called before the
 * first call to handle a request (ie before -preProcessRequest:response:for:
 * or -processRequest:response:for:) if (and only if) the request contains an
 * Expect header asking whether the request should continue.<br />
 * The supplied request object contains the headers provided by the client,
 * while the supplied response object contains the proposed response to
 * the client (usually a 100 Continue response).<br />
 * The delegate may then modify the response in order to override the default
 * behavior as follows:<br />
 * Removing the HTTP header from the response will cause the Expect header to
 * be ignored (a well behaved client will send the remainder of the request
 * after a short delay).<br />
 * Setting the HTTP header in the response to indicate a 100 status (or leaving
 * a header containing that status unmodified) will cause the server to send
 * the response to the client and then wait for the client to send the
 * remainder of the request as normal.<br />
 * Setting the HTTP header in the response to indicate any other status (or
 * leaving the header with a status other than 100) will cause the response to
 * be sent to the client and the connection to the client to be closed.
 */
- (void) continueRequest: (WebServerRequest*)request
		response: (WebServerResponse*)response
		     for: (WebServer*)http;

/** If your delegate implements this method, it will be called before the
 * first call to handle a request (ie before -preProcessRequest:response:for:
 * or -processRequest:response:for:) to provide the delegate with the
 * request header information and allow it to decide whether the request
 * body should be processed incrementally (return value is non-zero) or not
 * (return value is zero).  The returned value is treated as a guide
 * to how much request data should be buffered at a time.<br />
 * This method is called <em>before</em> any HTTP basic authentication
 * is done, and may (if threading is turned on) be called from a thread
 * other than the master one.<br />
 * If your delegate turns on incremental parsing for a request, then any
 * time that more incoming data is read, the web server class will look
 * at how much data it has and decide (based on the return value from this
 * method) to call your  -processRequest:response:for: method (preceded
 * by -preProcessRequest:response:for: if it is implemented) so that you 
 * can handle the new request data.<br />
 * Your code can check to see if the request is complete by using the
 * -isCompletedRequest: method, and can check for the latest data added
 * to the request body using the * -incrementalDataForRequest: method.
 */
- (uint32_t) incrementalRequest: (WebServerRequest*)request
                            for: (WebServer*)http;

/**
 * If your delegate implements this method, it will be called by the
 * -completedWithResponse: method before the response data is actually
 * written to the client.<br />
 * This method may re-write the response, changing the result of the
 * earlier methods.<br />
 * You may use the [WebServer-userInfoForRequest:] method to obtain
 * any information passed from an earlier stage of processing.<br />
 * NB. if threading is turned on this method may be called from a thread
 * other than the master one.
 */
- (void) postProcessRequest: (WebServerRequest*)request
	           response: (WebServerResponse*)response
		        for: (WebServer*)http;

/**
 * If your delegate implements this method, it will be called before the
 * [(WebServerDelegate)-processRequest:response:for:] method and with the
 * same parameters.<br />
 * If this method returns YES, then it is assumed to have completed the
 * processing of the request and the main
 * [(WebServerDelegate)-processRequest:response:for:]
 * method is not called.  Otherwise processing continues as normal.<br />
 * You may use the [WebServer-setUserInfo:forRequest:] method to pass
 * information to the [(WebServerDelegate)-processRequest:response:for:]
 * and/or -postProcessRequest:response:for: methods.<br />
 * NB. This method is called <em>before</em> any HTTP basic authentication
 * is done, and may (if threading is turned on) be called from a thread
 * other than the master one.
 */
- (BOOL) preProcessRequest: (WebServerRequest*)request
	          response: (WebServerResponse*)response
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

/*
 * For interoperability with ARC code, we must tag the two unused id*
 * instance variables as not participating in ARC.
 */
#if __has_feature(objc_arc)
#define UNUSED_QUAL __unsafe_unretained
#else
#define UNUSED_QUAL
#endif

/**
 * <p>You create an instance of the WebServer class in order to handle
 * incoming HTTP or HTTPS requests on a single port.
 * </p>
 * <p>Before use, it must be configured using the -setAddress:port:secure:
 * method to specify the address and port and if/how SSL is to be used.
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
 *   <term>WebServerFrameOptions</term>
 *   <desc>A string defining the frame options setting for responses produced
 *   by the server (application code can always override this).<br />
 *   If this is not defined, the value <code>DENY</code> is used to prevent
 *   responses from being presented inside frames.<br />
 *   If this is defined as an empty string, no X-Frame-Options header is set
 *   (unless application code explicitly sets the header in the response).<br />
 *   Unless you use this option (or your application code explicitly
 *   sets/removes the header), all responses will have the frame option DENY,
 *   which will at least tend to keep security auditors who are afraid of
 *   click-jacking attacks happy, even if it serves no other purpose.
 *   </desc>
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
 * <p>To shut down the WebServer, you must call -setAddress:port:secure: with
 * nil arguments.  This will stop the server listening for incoming
 * connections and wait for any existing connections to be closed
 * (or to time out).<br />
 * NB. Once a WebServer instance has been started listening on a port,
 * it is not OK to simply release it without shutting it down ... doing
 * that will cause a leak of memory and resources as the instance will
 * continue to operate.
 * </p>
 */
@interface	WebServer : NSObject
{
@private
  NSNotificationCenter	*_nc;
  NSUserDefaults	*_defs;
  NSString		*_addr;
  NSString		*_port;
  NSLock		*_lock;
  IOThread		*_ioMain;
  NSMutableArray	*_ioThreads;
  GSThreadPool		*_pool;
  WebServerConfig	*_conf;
  id		        UNUSED_QUAL *_unused1;
  id		        UNUSED_QUAL *_unused2;
  NSDictionary		*_sslConfig;
  BOOL			_accepting;
  BOOL			_doPostProcess;
  BOOL			_doPreProcess;
  BOOL			_doProcess;
  uint8_t		_reject;
  BOOL			_pad1;
  BOOL			_pad2;
  BOOL			_doAudit;
  BOOL			_doIncremental;
  NSUInteger		_substitutionLimit;
  NSUInteger		_maxConnections;
  NSUInteger		_maxPerHost;
  id			_delegate;
  NSFileHandle		*_listener;
  NSMutableSet		*_connections;
  NSUInteger		_processingCount;
  NSUInteger		_handled;
  NSUInteger		_requests;
  NSString		*_root;
  NSTimeInterval	_ticked;
  NSTimeInterval	_connectionTimeout;
  NSCountedSet		*_perHost;
  id			_xCountRequests;
  id			_xCountConnections;
  id			_xCountConnectedHosts;
  NSLock                *_userInfoLock;
  NSMutableDictionary   *_userInfoMap;
  NSLock                *_incrementalDataLock;
  NSMutableDictionary   *_incrementalDataMap;
  NSUInteger            _strictTransportSecurity;
  NSString              *_frameOptions;
  WebServerAuthenticationFailureLog	*_authFailureLog;
  NSTimeInterval        _authFailureBanTime;
  NSTimeInterval        _authFailureFindTime;
  NSUInteger            _authFailureMaxRetry;
  void			*_reserved;
}

/** Returns the base URL used by the remote client to send the request.
 */
+ (NSURL*) baseURLForRequest: (WebServerRequest*)request;

/**
 * Same as the instance method of the same name.
 */
+ (NSUInteger) decodeURLEncodedForm: (NSData*)data
			       into: (NSMutableDictionary*)dict;

/**
 * Same as the instance method of the same name.
 */
+ (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
                            charset: (NSString*)charset
			       into: (NSMutableData*)data;

/** DEPRECATED ... use +encodeURLEncodedForm:charset:into: instead.<br />
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

/** Convenience function to check to see if a particular IP address matches
 * anything in a comma separated list of IP addresses or masks.<br />
 * This currently handles simple IPv4 addresses, and masks in the format
 * nnn.nnn.nnn.nnn/bb where bb is the number of bits of the mask to match
 * against the address (eg. 192.168.11.0/24).
 */
+ (BOOL) matchIP: (NSString*)address to: (NSString*)pattern;

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
 * for a call to the [(WebServerDelegate)-processRequest:response:for:]
 * method.<br />
 * If destination is an NSURL, the redirection is done to the specified
 * location, otherwise arguments description is taken as a local path to
 * be used with the base URL of the request.
 */
+ (BOOL) redirectRequest: (WebServerRequest*)request
		response: (WebServerResponse*)response
		      to: (id)destination;

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
- (BOOL) accessRequest: (WebServerRequest*)request
	      response: (WebServerResponse*)response;

/** Return the address the receiver listens for connections on, or nil
 * if it is not listening.
 */
- (NSString*) address;

/** If greater than zero, the returned value is the number of seconds for
 * which the server should block subsequent requests from the offending
 * address, otherwise (returned value is zero) blocking is not performed
 * when an authentication attempt fails.<br />
 * Blocked requests will get a 429 response.
 */
- (NSTimeInterval) authenticationFailureBanTime;

/** The number of failed authentications before blocking is enabled. 
 * If this is zero, then the first failed authentication will result in the 
 * subsequent request being blocked.
 */
- (NSUInteger) authenticationFailureMaxRetry;

/** The number of seconds in the past for which the server should look
 * for failed authentication attempts when deciding whether to block
 * a request.
 */
- (NSTimeInterval) authenticationFailureFindTime;

/**
 * Instructs the server that the connection handlind the current request
 * should be closed once the response has been sent back to the client.
 */
- (void) closeConnectionAfter: (WebServerResponse*)response;

/**
 * <p>This may only be called in the case where a call to the delegate's
 * [(WebServerDelegate)-processRequest:response:for:] method
 * to process a request returned NO, indicating that the delegate
 * would handle the request asynchronously and complete it later.
 * </p>
 * <p>In such a case, the thread handling the request in the delegate
 * <em>must</em> call this method upon completion (passing in the same
 * request parameter that was passed to the delegate) to inform the
 * WebServer instance that processing of the request has been completed
 * and that it should now take over the job of sending the response to
 * the client process.
 * </p>
 * <p>If the -streamData:withResponse: method has been called with the
 * supplied response object, calling this method terminated the streamed
 * response to the client.
 * </p>
 */
- (void) completedWithResponse: (WebServerResponse*)response;

/** Returns an array containing an object representing each connection
 * currently active for this server instance.
 */
- (NSArray*) connections;

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
 * GSMimeDocument subclass.  The fields of the form will be the component parts
 * of the content of the request and can be accessed using the standard
 * GSMimeDocument methods.<br />
 * This method returns the number of fields actually decoded.
 */         
- (NSUInteger) decodeURLEncodedForm: (NSData*)data
			       into: (NSMutableDictionary*)dict;

/** Return this web server's delegate.
 */
- (id) delegate;

/**         
 * Encode an application/x-www-form-urlencoded form and store its
 * representation in the supplied data object.<br />
 * The dictionary contains the form, with keys as data objects or strings,
 * and values as arrays of values to be placed in the data.
 * Each value in the array may be a data object or a string.<br />
 * As a special case, a value may be a data object or a string rather
 * than an array ... this is treated like an array of one value.<br />
 * All non data keys and values are converted to data using the specified
 * charset (or utf-8 if charset is nil/unrecognized or where the key/value
 * cannot be represented using the specified charset).<br />
 * This method returns the number of values actually encoded.
 */
- (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
                            charset: (NSString*)charset
			       into: (NSMutableData*)data;

/** DEPRECATED ... use -encodeURLEncodedForm:charset:into: instead.<br />
 */         
- (NSUInteger) encodeURLEncodedForm: (NSDictionary*)dict
			       into: (NSMutableData*)data;

/** Escapes special characters in str for use in an HTML page.<br />
 * This converts &amp; to &amp;amp; for instance, and replaces
 * non-ascii characters with the appropriate numeric entity references.
 */
- (NSString*) escapeHTML: (NSString*)str;

/** Returns a data object containing any data read for the body of a
 * partially read request since the last call for the same request.
 */
- (NSData*) incrementalDataForRequest: (WebServerRequest*)request;

/** Initialises the receiver to run on the processes main thread (as
 * returned by [NSThread+mainThread].
 */
- (id) init;

/** <init />
 * Initialises the WebServer instance to operate using the specified thread
 * as the 'master' thread.  If aThread is nil, [NSThread+mainThread] is used
 * as the master thread for the newly initialised instance.<br />
 * If the current thread is not the same as the specified master thread,
 * this method will not return until the master thread's run loop had run
 * to handle the initialisation.
 */
- (id) initForThread: (NSThread*)aThread;

/** Returns YES if the request has been completely read, NO if it still
 * needs more data to be read from the client and parsed before it is
 * complete (ie incremental parsing is in progress).
 */
- (BOOL) isCompletedRequest: (WebServerRequest*)request;

/**
 * Returns YES if the server is for HTTPS (encrypted connections),
 * NO otherwise.
 */
- (BOOL) isSecure;

/**
 * Returns YES if the server is running behind a secure proxy inside
 * a demilitarised zone (DMZ).
 */
- (BOOL) isTrusted;

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
 * in a more flexible format (see [GSMimeDocument]) as the content of
 * the request.
 */
- (NSMutableDictionary*) parameters: (WebServerRequest*)request;

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

/** Return the port the receiver listens for connections on, or nil
 * if it is not listening.
 */
- (NSString*) port;

/**
 * Loads a template file from disk and places it in aResponse as content
 * whose mime type is determined from the file extension using the
 * provided mapping (or a simple built-in default mapping if map is nil).<br />
 * Text responses use utf-8 enmcoding.<br />
 * If you have a dedicated web server for handling static pages (eg images)
 * it is better to use that rather than vending static pages using this
 * method.  It's unlikely that this method can be as efficient as a dedicated
 * server.  However this mechanism is adequate for moderate throughputs.
 */
- (BOOL) produceResponse: (WebServerResponse*)aResponse
	  fromStaticPage: (NSString*)aPath
		   using: (NSDictionary*)map;

/**
 * Loads a template file from disk and places it in aResponse as content
 * of type 'text/html' with a charset of 'utf-8'.<br />
 * The argument aPath is a path relative to the root path set using
 * the -setRoot: method.<br />
 * Substitutes values into the template from map using the
 * -substituteFrom:using:into:depth: method.<br />
 * Returns NO if the template could not be read or if any substitution
 * failed.  In this case no value is set in the response.<br />
 * If the response is actually text of another type, or you want another
 * characterset used, you can change the content type header in the
 * request after you call this method.<br />
 * Note that, although the map is nominally an NSDictionary instance, it
 * can in fact be any object which responds to the [NSDictionary-objectForKey:]
 * message by returning a string or nil.
 */
- (BOOL) produceResponse: (WebServerResponse*)aResponse
	    fromTemplate: (NSString*)aPath
		   using: (NSDictionary*)map;

/** Sets the time for which requests from the same host should be blocked
 * if a request from the host attempts to authenticate and fails.<br />
 * The default is 1 second but setting a value of zero or less turns this
 * feature off (sets the blocking interval to zero).
 */
- (void) setAuthenticationFailureBanTime: (NSTimeInterval)ti;

/** Sets the number of failed authentications before blocking is enabled. 
 * The default is 0, i.e. the first failed authentication will result in the 
 * subsequent requests being blocked.
 */
- (void) setAuthenticationFailureMaxRetry: (NSUInteger)maxRetry;

/** Sets the number of seconds in the past for which the server should look
 * for failed authentication attempts when deciding whether to block
 * a request. The default is 1 second.
 */
- (void) setAuthenticationFailureFindTime: (NSTimeInterval)ti;

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
 * Sets the listening address, port and security information for the
 * receiver ... without this the receiver will not listen for incoming
 * requests.<br />
 * If anAddress is nil or empty, the receiver will listen on
 * all available network interfaces.<br />
 * If secure is nil then the receiver listens on aPort for HTTP requests.<br />
 * If secure is a dictionary, it may contain a combination of the following:
 * <deflist>
 * <term>Proxy</term>
 * <desc>A boolean which if set to YES configures the receiver trust
 * request as having come from a trusted proxy and therefore having
 * trusted request headers specifying where the request originated etc.
 * </desc>
 * <term>HSTS</term>
 * <desc>A non-negative integer value specifying the number of seconds
 * to set in the Strict-Transport-Security header (defaults to 1 year).
 * when responding to requests.
 * </desc>
 * <term>CertificateFile</term>
 * <desc>Along with <code>KeyFile</code> and <code>Password</code> this
 * configures the server to use the specified certificate and key files
 * (which it will access using the password) to support HTTPS rather
 * than HTTP.<br />
 * The <em>secure</em> dictionary may also contain other dictionaries
 * keyed on IP addresses, and if the address that an incoming connection
 * arrived on matches the key of a dictionary, that dictionary is used
 * to provide the certificate information, with the top-level values
 * being used as a fallback.<br />
 * </desc>
 * </deflist>
 * This method returns YES on success, NO on failure ... if it returns NO
 * then the receiver will <em>not</em> be capable of handling incoming
 * web requests!<br />
 * Typically a failure will be due to an invalid address or port being
 * specified ...  a port may not already be in use and may not be in the
 * range up to 1024 (unless running as the super-user).<br />
 * Call this with a nil/empty port argument to shut the server down as soon
 * as all current connections are closed (and refuse new incoming
 * connections).<br />
 * NB. Changing of this configuration must only occur in the master thread
 * so this method, if called from another thread, will need to perform some
 * internal operations in the master thread before it returns.
 */
- (BOOL) setAddress: (NSString*)anAddress
	       port: (NSString*)aPort
	     secure: (NSDictionary*)secure;
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
 * Sets a flag to determine whether the header lines in responses are
 * folded if they are over 78 characters (off by default).<br />
 * Some buggy clients don't support folding, but do accept long header
 * lines, and this compatibility setting may be used to allow such clients
 * to handle the server's responses (though this may of course break
 * things for other clients).<br />
 * This setting applies to any connection established after the setting
 * is changed.<br />
 * Because use of this setting could result in a faulty response (one
 * with a long header) being sent to a client which correctly handles
 * folded headers, it's also controllable individually for each response,
 * so the same process can respond both to clients which expect folded
 * headers and clients which expect long headers (see
 * [WebServerResponse-setFoldHeaders:]).
 */
- (void) setFoldHeaders: (BOOL)aFlag;

/**
 * Sets the number of threads used to process basic I/O and the size of
 * the thread pool used by the receiver for handling parsing of incoming
 * requests, generation of outgoing responses, and pre/post processing
 * of requests by the delegate.<br />
 * This defaults to no use of threads.<br />
 * NB. Since each thread typically uses two file descriptors to handle any
 * inter-thread message dispatch, enabling threading will use at least two
 * extra file descriptors per thread ... this may easily cause you
 * to go beyound the per-process limit imposed by the operating system and
 * you may wish to configure a smaller connection limit or tune the O/S to
 * allow more descriptors.
 */
- (void) setIOThreads: (NSUInteger)threads andPool: (NSInteger)poolSize;

/**
 * Sets a flag to determine whether I/O logging is to be performed.<br />
 * If this is YES then all incoming requests and their responses will
 * be logged using the [(WebServerDelegate)-webLog:for:] method.
 */
- (void) setLogRawIO: (BOOL)aFlag;

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
 * Sets the maximum number of connections in each I/O thread which are
 * to be kept in a 'keepalive' state waiting for a new request once a
 * request completes.<br />
 * The permitted range is currently from 0 to 1000, with settings being
 * limited to that range.  The default value is 0, which means that the
 * number of idle connections per thread is unlimited (though the total
 * number of connections and number per host is still constrained).
 */
- (void) setMaxKeepalives: (NSUInteger)max;

/**
 * Sets the maximum size of an incoming request (including all headers,
 * but not the body).<br />
 * The default is 8K bytes.<br />
 * The HTTP failure response for too large a request is 413.
 */
- (void) setMaxRequestSize: (NSUInteger)max;

/** Sets the HTTP methods which may be used by the server.<br />
 * Any incoming request using a method not listed in the permitted set is
 * rejected with an HTTP 405 response and an Allow header saying which
 * methods ARE allowed.<br />
 * The default set contains only the GET and POST methods.
 */
- (void) setPermittedMethods: (NSSet*)s;

/** Deprecated ... use -setAddress:port:secure: instead.
 */
- (BOOL) setPort: (NSString*)aPort secure: (NSDictionary*)secure;

/**
 * Set root path for loading template files from.<br />
 * Templates may only be loaded from within this directory.
 */
- (void) setRoot: (NSString*)aPath;

/** Configures a flag to say whether the receiver is running behind a
 * secure proxy (in a DMZ) and all connections are to be considered as
 * having come in via https.<br />
 * If this is not set, requests are not trusted and some headers may be
 * deleted from them.
 */
- (void) setSecureProxy: (BOOL)aFlag;

/**
 * Specifies the number of seconds HSTS is to be turned on for when responding
 * to a request on a secure connection (including via a secure proxy).<br />
 * The Strict-Transport-Security header is automatically set in the response
 * to any incoming request (but code handling the request may alter that).<br />
 * The default setting is 1 year (31536000 seconds), while a setting of zero
 * turns off HSTS.
 */
- (void) setStrictTransportSecurity: (NSUInteger)seconds;

/**
 * Sets the maximum recursion depth allowed for substitutions into
 * templates.  This defaults to 4.
 */
- (void) setSubstitutionLimit: (NSUInteger)depth;

/**
 * Sets the number of threads used to process basic I/O and the size of
 * the thread pool used by the receiver for handling parsing of incoming
 * requests, generation of outgoing responses, and pre/post processing
 * of requests by the delegate.<br />
 * This defaults to no use of threads.<br />
 * NB. Since each thread typically uses two file descriptors to handle any
 * inter-thread message dispatch, enabling threading will use at least two
 * extra file descriptors per thread ... this may easily cause you
 * to go beyound the per-process limit imposed by the operating system and
 * you may wish to configure a smaller connection limit or tune the O/S to
 * allow more descriptors.
 */
- (void) setIOThreads: (NSUInteger)threads andPool: (NSInteger)poolSize;

/**
 * Sets a flag to determine whether I/O logging is to be performed.<br />
 * If this is YES then all incoming requests and their responses will
 * be logged using the [(WebServerDelegate)-webLog:for:] method.
 */
- (void) setLogRawIO: (BOOL)aFlag;

/**
 * Stores additional user information with a request.<br />
 * This information may be retrieved later using the -userInfoForRequest:
 * method.
 */
- (void) setUserInfo: (NSObject*)info forRequest: (WebServerRequest*)request;

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
 * <p>This may only be called in the case where a call to the delegate's
 * [(WebServerDelegate)-processRequest:response:for:] method
 * to process a request returned NO, indicating that the delegate
 * would handle the request asynchronously and complete it later.
 * </p>
 * <p>In this case the response content should be empty, and instead of
 * sending the response in one go the server will send the response header
 * followed by the supplied data.  Subsequent calls to this method using
 * the same response object will send more data to the client.<br />
 * The code which calls this method <em>must</em> terminate the sequence
 * of calls with a call to the -completedWithResponse: method.
 * </p>
 * <p>The method returns YES is the data is scheduled for sending to the
 * client, NO if the client has already dropped the connection and there
 * is no point attempting to stream more data.
 * </p>
 */
- (BOOL) streamData: (NSData*)data withResponse: (WebServerResponse*)response;

/**
 * Returns the number of seconds set for HSTS for this server.<br />
 * This will be zero if the server is not using a secure connection or
 * if HSTS has been disabled by the -setStrictTransportSecurity: method.
 */
- (NSUInteger) strictTransportSecurity;

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
 * an NSString or nil, you can therefore use it to dynamically replace
 * tokens within a template page in an intelligent manner.<br />
 * The method returns YES on success, NO on failure (depth too great).<br />
 * You don't normally need to use this method directly ... call the
 * -produceResponse:fromTemplate:using: method instead.
 */
- (BOOL) substituteFrom: (NSString*)aTemplate
		  using: (NSDictionary*)map
		   into: (NSMutableString*)result
		  depth: (NSUInteger)depth;

/** Returns the thread pool used by this instance.
 */
- (GSThreadPool*) threadPool;

/**
 * Retrieves additional user information (previously set using the
 * -setUserInfo:forRequest: method) from a request.
 */
- (NSObject*) userInfoForRequest: (WebServerRequest*)request;

@end

#ifndef WEBSERVERINTERNAL
/** Do not attempt to subclass the WebServerRequest class to add instance
 * variables ... the public interface is intended to keep your compiler
 * happy, but does not guarantee that the instance variable layout is
 * actually what it seems.
 */
@interface      WebServerRequest : GSMimeDocument
/** Convenience method returning the address of the client.<br />
 * This is taken from the x-forwarded-for header if possible, but from the
 * x-remote-address header if the request was not forwarded through a proxy.
 */
- (NSString*) address;
@end

/** Do not attempt to subclass the WebServerResponse class to add instance
 * variables ... the public interface is intended to keep your compiler
 * happy, but does not guarantee that the instance variable layout is
 * actually what it seems.
 */
@interface      WebServerResponse : GSMimeDocument
/** Blocks (for the time interval specified) further incoming requests
 * from the same source as the one we are responding to.<br />
 * A ti value more than zero establishes a new blocking.<br />
 * A ti value of zero cancels any existing blocking.<br />
 * A ti value of less than zero is ignored and the value returned by
 * the -[WebServer authenticationFailureBanTime] method is used instead.<br />
 * Subsequent requests from the blocked source will be responded to with
 * a 429 status code until the blocking expires.
 */ 
- (void) block: (NSTimeInterval)ti;

/** Behaves as [WebServer-setFoldHeaders:] but applies only to the headers
 * in the receiver.
 */
- (void) setFoldHeaders: (BOOL)aFlag;

/** Sets additional information attached to the response which may then be
 * retrieved with the -userInfo method.
 */
- (void) setUserInfo: (NSObject*)info;

/** Returns the obect previously set with the -setUserInfo: method or nil
 * if nothing has been set.
 */
- (NSObject*) userInfo;
@end
#endif

#endif

