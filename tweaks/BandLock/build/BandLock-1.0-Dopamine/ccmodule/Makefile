include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BandLockCCModule
BandLockCCModule_BUNDLE_EXTENSION = bundle
BandLockCCModule_FILES = Module.m ../shared/BLCCPreferences.m
BandLockCCModule_FRAMEWORKS = UIKit Foundation QuartzCore
BandLockCCModule_PRIVATE_FRAMEWORKS = ControlCenterUIKit
BandLockCCModule_CFLAGS = -fobjc-arc -I../shared $(BANDLOCK_VARIANT_CFLAGS)
BandLockCCModule_INSTALL_PATH = /Library/ControlCenter/Bundles
BandLockCCModule_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
