include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BandLockCCModule
BandLockCCModule_BUNDLE_EXTENSION = bundle
BandLockCCModule_FILES = ../../BandLock-1.0-Dopamine/ccmodule/Module.m
BandLockCCModule_FRAMEWORKS = UIKit Foundation QuartzCore CoreTelephony
BandLockCCModule_PRIVATE_FRAMEWORKS = ControlCenterUIKit
BandLockCCModule_CFLAGS = -fobjc-arc -DBL_VARIANT_ROOTHIDE=1
BandLockCCModule_LDFLAGS += -lroothide
BandLockCCModule_INSTALL_PATH = /Library/ControlCenter/Bundles
BandLockCCModule_RESOURCE_DIRS = ../../BandLock-1.0-Dopamine/ccmodule/Resources

include $(THEOS_MAKE_PATH)/bundle.mk
