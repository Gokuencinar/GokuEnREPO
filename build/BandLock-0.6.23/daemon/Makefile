include $(THEOS)/makefiles/common.mk

TOOL_NAME = BandLockDaemon

BandLockDaemon_FILES = \
	main.m \
	BLTelephonyCore.m \
	../shared/BLGBandMetadata.m
BandLockDaemon_FRAMEWORKS = Foundation UIKit
BandLockDaemon_CFLAGS = -fobjc-arc -I. -I../app -I../shared
BandLockDaemon_INSTALL_PATH = /usr/libexec
BandLockDaemon_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
