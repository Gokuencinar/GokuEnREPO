include $(THEOS)/makefiles/common.mk

TOOL_NAME = BandLockHelper

BandLockHelper_FILES = \
	main.m \
	BLTelephonyCore.m \
	../shared/BLGBandMetadata.m
BandLockHelper_FRAMEWORKS = Foundation UIKit
BandLockHelper_CFLAGS = -fobjc-arc -I. -I../app -I../shared
BandLockHelper_INSTALL_PATH = /Applications/BandLock.app
BandLockHelper_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
