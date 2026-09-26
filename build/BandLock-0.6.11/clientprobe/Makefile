include $(THEOS)/makefiles/common.mk

TOOL_NAME = BandLockClientProbe
BandLockClientProbe_FILES = main.m
BandLockClientProbe_FRAMEWORKS = Foundation
BandLockClientProbe_CFLAGS = -fobjc-arc
BandLockClientProbe_LDFLAGS += -lroothide
BandLockClientProbe_INSTALL_PATH = /usr/bin
BandLockClientProbe_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
