include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = CarrierFix
CarrierFix_FILES = \
    ../../CarrierFix-shared/main.m \
    ../../CarrierFix-shared/CFAppDelegate.m \
    ../../CarrierFix-shared/CFViewController.m \
    ../../CarrierFix-shared/CFCarrierManager.m
CarrierFix_FRAMEWORKS = UIKit Foundation
CarrierFix_CFLAGS = -fobjc-arc -I../../CarrierFix-shared
CarrierFix_RESOURCE_DIRS = Resources
CarrierFix_INSTALL_PATH = /Applications
CarrierFix_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/application.mk