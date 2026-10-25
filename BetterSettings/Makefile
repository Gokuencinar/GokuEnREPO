export TARGET := iphone:clang:latest:16.0
# Preferences is an arm64e system process on iOS 18.7.1 (verified by dyld).
# The injected tweak and its preference bundle must contain the arm64e slice.
export ARCHS := arm64e
export THEOS_PACKAGE_SCHEME := rootless
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BetterSettings
BetterSettings_FILES = Tweak.xm
BetterSettings_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
BetterSettings_FRAMEWORKS = UIKit QuartzCore
# Theos SDKs do not ship the private Preferences.framework link stub.
# Preferences.app already loads it; resolve its Objective-C symbols there.
BetterSettings_LDFLAGS += -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
