include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BandLockGlobalPrefs
BandLockGlobalPrefs_FILES = BLGRootListController.m BLGBandSelectionController.m BLGBandMetadata.m
BandLockGlobalPrefs_FRAMEWORKS = UIKit Foundation
BandLockGlobalPrefs_INSTALL_PATH = /Library/PreferenceBundles
BandLockGlobalPrefs_CFLAGS = -fobjc-arc
BandLockGlobalPrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
