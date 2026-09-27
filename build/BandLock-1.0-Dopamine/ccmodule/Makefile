include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BandLockCCModule
BandLockCCModule_BUNDLE_EXTENSION = bundle
BandLockCCModule_FILES = Module.m
BandLockCCModule_FRAMEWORKS = UIKit Foundation QuartzCore CoreTelephony
BandLockCCModule_PRIVATE_FRAMEWORKS = ControlCenterUIKit
BandLockCCModule_CFLAGS = -fobjc-arc $(BANDLOCK_VARIANT_CFLAGS)
BandLockCCModule_INSTALL_PATH = /Library/ControlCenter/Bundles
BandLockCCModule_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
