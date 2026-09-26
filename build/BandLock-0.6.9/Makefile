ARCHS = arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += app daemon launcher clientprobe
include $(THEOS_MAKE_PATH)/aggregate.mk
