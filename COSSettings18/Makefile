export TARGET := iphone:clang:latest:16.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME := rootless
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = COSSettings18
COSSettings18_FILES = Tweak.xm
COSSettings18_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
COSSettings18_FRAMEWORKS = UIKit QuartzCore
# Theos SDKs do not ship the private Preferences.framework link stub.
# Preferences.app already loads it; resolve its Objective-C symbols there.
COSSettings18_LDFLAGS += -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
