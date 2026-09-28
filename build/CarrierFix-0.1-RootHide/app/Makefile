include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = CarrierFix
CarrierFix_FILES = main.m CFAppDelegate.m CFViewController.m CFCarrierManager.m
CarrierFix_FRAMEWORKS = UIKit Foundation
CarrierFix_CFLAGS = -fobjc-arc
CarrierFix_LDFLAGS += -lroothide
CarrierFix_RESOURCE_DIRS = Resources
CarrierFix_INSTALL_PATH = /Applications
CarrierFix_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
