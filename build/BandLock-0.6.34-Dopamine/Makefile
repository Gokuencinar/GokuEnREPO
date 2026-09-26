ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += app daemon launcher fieldbridge
include $(THEOS_MAKE_PATH)/aggregate.mk
