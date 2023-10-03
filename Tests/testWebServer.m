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

#import	"WebServer.h"
#import "Testing.h"

int
main()
{
  CREATE_AUTORELEASE_POOL(pool);

  START_SET("Match IP addresses")
 
  PASS(NO == [WebServer matchIP: @"1.2.3.4" to: @"4.5.6.7"], "Match1");
  PASS([WebServer matchIP: @"1.2.3.4" to: @"1.2.3.4"], "Match2");
  PASS([WebServer matchIP: @"1.2.3.4" to: @"1.2.3.0/24"], "Match3");
  PASS([WebServer matchIP: @"1.2.4.4" to: @"1.2.0.0/16"], "Match4");

  END_SET("Match IP addresses")

  RELEASE(pool);
  return 0;
}

