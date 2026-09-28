ARCHS = arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
