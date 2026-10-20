export TARGET := iphone:clang:latest:16.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME := rootless
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = COSSettings18
COSSettings18_FILES = Tweak.xm
COSSettings18_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
COSSettings18_FRAMEWORKS = UIKit QuartzCore
COSSettings18_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
