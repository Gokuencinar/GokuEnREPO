include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = BetterSettingsPrefs
BetterSettingsPrefs_FILES = BetterRootListController.m
BetterSettingsPrefs_CFLAGS = -fobjc-arc
BetterSettingsPrefs_FRAMEWORKS = UIKit PhotosUI
BetterSettingsPrefs_LDFLAGS += -Wl,-undefined,dynamic_lookup
BetterSettingsPrefs_INSTALL_PATH = /Library/PreferenceBundles
include $(THEOS_MAKE_PATH)/bundle.mk
