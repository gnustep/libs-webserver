
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
 
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

-include config.make

PACKAGE_NAME = WebServer
PACKAGE_VERSION = 1.3.0
CVS_MODULE_NAME = gnustep/dev-libs/WebServer
CVS_TAG_NAME = WebServer
SVN_BASE_URL=svn+ssh://svn.gna.org/svn/gnustep/libs
SVN_MODULE_NAME=webserver

NEEDS_GUI = NO

TEST_TOOL_NAME=

LIBRARY_NAME=WebServer
DOCUMENT_NAME=WebServer

WebServer_INTERFACE_VERSION=1.3

WebServer_OBJC_FILES += WebServer.m WebServerBundles.m WebServerForms.m
WebServer_HEADER_FILES += WebServer.h
WebServer_AGSDOC_FILES += WebServer.h

# Optional Java wrappers for the library
JAVA_WRAPPER_NAME = WebServer

#
# Assume that the use of the gnu runtime means we have the gnustep
# base library and can use its extensions to build WebServer stuff.
#
ifeq ($(OBJC_RUNTIME_LIB),gnu)
APPLE=0
else
APPLE=1
endif

ifeq ($(APPLE),1)
ADDITIONAL_OBJC_LIBS += -lgnustep-baseadd
WebServer_LIBRARIES_DEPEND_UPON = -lgnustep-baseadd
endif

WebServer_HEADER_FILES_INSTALL_DIR = WebServer

TEST_TOOL_NAME+=testWebServer
testWebServer_OBJC_FILES = testWebServer.m
testWebServer_TOOL_LIBS += -lWebServer
testWebServer_LIB_DIRS += -L./$(GNUSTEP_OBJ_DIR)

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/test-tool.make
include $(GNUSTEP_MAKEFILES)/documentation.make

-include GNUmakefile.postamble
