include $(THEOS)/makefiles/common.mk

TOOL_NAME = BandLockA9TestDaemon

BandLockA9TestDaemon_FILES = \
	main.m \
	BLTelephonyCore.m \
	../shared/BLGBandMetadata.m
BandLockA9TestDaemon_FRAMEWORKS = Foundation UIKit
BandLockA9TestDaemon_CFLAGS = -fobjc-arc -I. -I../app -I../shared $(BANDLOCK_VARIANT_CFLAGS)
BandLockA9TestDaemon_INSTALL_PATH = /usr/libexec
BandLockA9TestDaemon_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
