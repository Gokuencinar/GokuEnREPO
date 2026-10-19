include $(THEOS)/makefiles/common.mk

TOOL_NAME = BandLockDaemon

BandLockDaemon_FILES = \
	main.m \
	BLTelephonyCore.m \
	../shared/BLGBandMetadata.m
ifneq ($(BANDLOCK_VARIANT_CFLAGS),-DBL_VARIANT_ROOTFUL=1)
BandLockDaemon_FILES += BLSignalScan.m
endif
BandLockDaemon_FRAMEWORKS = Foundation UIKit
BandLockDaemon_CFLAGS = -fobjc-arc -I. -I../app -I../shared $(BANDLOCK_VARIANT_CFLAGS)
ifneq ($(BANDLOCK_VARIANT_CFLAGS),-DBL_VARIANT_ROOTFUL=1)
BandLockDaemon_CFLAGS += -DBL_SIGNAL_SCAN_TEST=1
endif
BandLockDaemon_INSTALL_PATH = /usr/libexec
ifeq ($(BANDLOCK_VARIANT_CFLAGS),-DBL_VARIANT_ROOTFUL=1)
BandLockDaemon_CODESIGN_FLAGS = -S../../BandLock-1.0-Rootful/daemon/Entitlements.plist
else
BandLockDaemon_CODESIGN_FLAGS = -SEntitlements.plist
endif

include $(THEOS_MAKE_PATH)/tool.mk
