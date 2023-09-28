/** 
   Copyright (C) 2005 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	September 2005
   
   This file is part of the SQLClient Library.

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

   $Date$ $Revision$
   */ 

#import	<Foundation/Foundation.h>
#import	<GNUstepBase/GSMime.h>

#import "Testing.h"
#import	"WebServer.h"

#define BAN_TIME 2.0
#define MAX_RETRY 3
#define FIND_TIME 2.0

@interface	Handler: NSObject

- (BOOL) processRequest: (WebServerRequest*)request
               response: (WebServerResponse*)response
		                for: (WebServer*)http;

@end

@implementation	Handler

- (BOOL) processRequest: (WebServerRequest*)request
               response: (WebServerResponse*)response
		                for: (WebServer*)http
{
  [response setHeader: @"http" 
                value: @"HTTP/1.0 200 OK"
           parameters: nil];

  return YES;
}

@end

@interface	HandlerWithAuth: NSObject

- (BOOL) processRequest: (WebServerRequest*)request
               response: (WebServerResponse*)response
		                for: (WebServer*)http;

@end

@implementation	HandlerWithAuth

- (BOOL) processRequest: (WebServerRequest*)request
               response: (WebServerResponse*)response
		                for: (WebServer*)http
{
  NSData        *jsonData;
  NSDictionary  *body;
  BOOL          authenticated = NO;

  jsonData = [request convertToData];
  if (nil != jsonData)
    {
      body = [NSJSONSerialization JSONObjectWithData: jsonData 
                                             options: 0 
                                               error: NULL];
      if (nil != body)
        {
          if ([body objectForKey: @"key"] != nil)
            {
              if ([[body objectForKey: @"key"] isEqualToString: @"ValidKey"])
                {
                  authenticated = YES;
                }
            }
        }
    } 

  if (authenticated)
    {
      [response setHeader: @"http" 
                    value: @"HTTP/1.0 200 OK"
               parameters: nil];
    }
  else
    {
      [response block: BAN_TIME];
      [response setHeader: @"http" 
                    value: @"HTTP/1.0 401 Unauthorized"
               parameters: nil];
    }
  
  return YES;
}

@end

static NSHTTPURLResponse* post(NSString *user, NSString *password, NSDictionary *body)
{
  NSURL                      *url;
  NSMutableURLRequest        *request;
  NSData                     *bodyData;
  NSHTTPURLResponse          *response;
  NSString                   *authStr;
  NSData                     *authData; 
  NSString                   *authValue;

  url = [NSURL URLWithString: @"http://localhost:8888/"];
  request = [NSMutableURLRequest requestWithURL: url];
  [request setHTTPMethod: @"POST"];
  [request setValue: @"application/json" forHTTPHeaderField: @"Content-Type"];
  authStr = [NSString stringWithFormat: @"%@:%@", user, password];
  authData = [authStr dataUsingEncoding: NSUTF8StringEncoding];
  authValue = [NSString stringWithFormat: @"Basic %@", 
    [authData base64EncodedStringWithOptions: 0]];
  [request setValue: authValue forHTTPHeaderField: @"Authorization"];
  if (nil != body)
    {
      bodyData = [NSJSONSerialization dataWithJSONObject: body 
                                                 options: 0 
                                                   error: NULL];
      [request setHTTPBody: bodyData];
    }
  [NSURLConnection sendSynchronousRequest: request 
                        returningResponse: &response 
                                    error: NULL];
  return response;
}

int
main()
{
  CREATE_AUTORELEASE_POOL(pool);
  WebServer		        *server;
  Handler		          *handler;
  HandlerWithAuth     *handlerWithAuth;
  NSUserDefaults	    *defs;
  NSHTTPURLResponse   *response;

  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults: @{
    @"Port": @"8888",
    @"WebServerAccess": @{
      @"": @{
        @"Realm": @"general",
        @"Users": @{
          @"user": @"ValidPassword"
        }
      }
    }}];

  server = [WebServer new];
  [server setPort: [defs stringForKey: @"Port"] secure: nil];
  [server setVerbose: [defs boolForKey: @"Debug"]];

  START_SET("Set block on authentication failure")

  // set handler without custom authentication
  handler = [Handler new];
  [server setDelegate: handler];

  [server setAuthenticationFailureBanTime: BAN_TIME];
  [server setAuthenticationFailureMaxRetry: MAX_RETRY];
  [server setAuthenticationFailureFindTime: FIND_TIME];
  PASS([server authenticationFailureBanTime] == BAN_TIME, "Ban time");
  PASS([server authenticationFailureMaxRetry] == MAX_RETRY, "Max retry");
  PASS([server authenticationFailureFindTime] == FIND_TIME, "Find time");
  
  END_SET("Set block on authentication failure")

  START_SET("Block on HTTP authentication failure")

  // check that the password is valid
  response = post(@"user", @"ValidPassword", nil);
  PASS([response statusCode] == 200, "Response is 200");

  // make MAX_RETRY + 1 invalid password attempts
  for (int i = 0; i <= MAX_RETRY; i++) 
    {
      response = post(@"user", @"InvalidPassword", nil);
      PASS([response statusCode] == 401, "Response is 401");
    }

  // check even a request with valid password is now blocked
  response = post(@"user", @"ValidPassword", nil);
  PASS([response statusCode] == 429, "Response is 429");

  // wait for BAN_TIME seconds
  [NSThread sleepForTimeInterval: BAN_TIME];

  // check that a reqeuest with a valid password is accepted
  response = post(@"user", @"ValidPassword", nil);
  PASS([response statusCode] == 200, "Response is 200");
  
  END_SET("Block on HTTP authentication failure")

  START_SET("Block on custom authentication failure")

  // set handler for custom authentication
  handlerWithAuth = [HandlerWithAuth new];
  [server setDelegate: handlerWithAuth];

  // check a valid password and key are accepted
  response = post(@"user", @"ValidPassword", @{@"key": @"ValidKey"});
  PASS([response statusCode] == 200, "Response is 200");

  // make MAX_RETRY + 1 invalid key attempts
  for (int i = 0; i <= MAX_RETRY; i++) 
    {
      response = post(@"user", @"ValidPassword", @{@"key": @"InvalidKey"});
      PASS([response statusCode] == 401, "Response is 401");
    }

  // check even a request with valid password and key is now blocked
  response = post(@"user", @"ValidPassword", @{@"key": @"ValidKey"});
  PASS([response statusCode] == 429, "Response is 429");

  // wait for BAN_TIME seconds
  [NSThread sleepForTimeInterval: BAN_TIME];

  // check that a reqeuest with a valid password and key is accepted
  response = post(@"user", @"ValidPassword", @{@"key": @"ValidKey"});
  PASS([response statusCode] == 200, "Response is 200");

  END_SET("Block on custom authentication failure")

  RELEASE(handler);
  RELEASE(handlerWithAuth);
  RELEASE(server);
  RELEASE(pool);
  return 0;
}

