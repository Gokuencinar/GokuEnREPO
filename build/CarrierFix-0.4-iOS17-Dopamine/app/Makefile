include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = CarrierFix17Test
CarrierFix17Test_FILES = \
    ../../CarrierFix-shared/main.m \
    ../../CarrierFix-shared/CFAppDelegate.m \
    ../../CarrierFix-shared/CFViewController.m \
    ../../CarrierFix-shared/CFCarrierManager.m \
    CFCarrierUpdateManager.m
CarrierFix17Test_FRAMEWORKS = UIKit Foundation
CarrierFix17Test_CFLAGS = -fobjc-arc -DCARRIERFIX_IOS17_UPDATE=1 -I../../CarrierFix-shared -I.
CarrierFix17Test_RESOURCE_DIRS = Resources
CarrierFix17Test_INSTALL_PATH = /Applications
CarrierFix17Test_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
