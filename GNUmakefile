
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

-include config.make

PACKAGE_NAME = WebServer
PACKAGE_VERSION = 1.6.0
WebServer_INTERFACE_VERSION=1.6
CVS_MODULE_NAME = gnustep/dev-libs/WebServer
CVS_TAG_NAME = WebServer
SVN_BASE_URL=svn+ssh://svn.gna.org/svn/gnustep/libs
SVN_MODULE_NAME=webserver

NEEDS_GUI = NO

TEST_TOOL_NAME=

LIBRARY_NAME=WebServer
DOCUMENT_NAME=WebServer

WebServer_OBJC_FILES +=\
	WebServer.m\
	WebServerConnection.m\
	WebServerBundles.m\
	WebServerForm.m\
	WebServerField.m\
	WebServerHeader.m\
	WebServerTable.m\


WebServer_HEADER_FILES +=\
	WebServer.h\
	WebServerBundles.h\
	WebServerHTML.h\

WebServer_AGSDOC_FILES +=\
	WebServer.h\
	WebServerBundles.h\
	WebServerHTML.h\

# Optional Java wrappers for the library
JAVA_WRAPPER_NAME = WebServer

# If we are not using the GNUstep foundation library,
# we need to use its extensions to build WebServer stuff.
#
ifneq ($(FOUNDATION_LIB),gnu)
ADDITIONAL_OBJC_LIBS += -lgnustep-baseadd
WebServer_LIBRARIES_DEPEND_UPON += -lgnustep-baseadd
endif

ADDITIONAL_OBJC_LIBS += -lPerformance
WebServer_LIBRARIES_DEPEND_UPON += -lPerformance

WebServer_HEADER_FILES_INSTALL_DIR = WebServer

WebServer_TEST_DIR = Tests

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/test-tool.make
include $(GNUSTEP_MAKEFILES)/documentation.make

-include GNUmakefile.postamble
