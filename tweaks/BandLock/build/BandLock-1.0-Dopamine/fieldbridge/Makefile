include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BandLockFieldBridge

BandLockFieldBridge_FILES = FieldBridge.m
BandLockFieldBridge_FRAMEWORKS = UIKit Foundation
BandLockFieldBridge_CFLAGS = -fobjc-arc $(BANDLOCK_VARIANT_CFLAGS)
INSTALL_TARGET_PROCESSES = MobilePhone

include $(THEOS_MAKE_PATH)/tweak.mk
