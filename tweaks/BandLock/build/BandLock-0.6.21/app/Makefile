include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BandLock

BandLock_FILES = \
	main.m \
	BLBreadcrumb.c \
	BLAppDelegate.m \
	BLTelephonyManager.m \
	BLControlViewController.m \
	BLBandPickerViewController.m \
	BLCountriesViewController.m \
	BLCountryDetailViewController.m \
	../shared/BLGBandMetadata.m
BandLock_FRAMEWORKS = UIKit Foundation
BandLock_CFLAGS = -fobjc-arc -I../shared
BandLock_LDFLAGS += -lroothide
BandLock_RESOURCE_DIRS = Resources
BandLock_INSTALL_PATH = /Applications
BandLock_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
