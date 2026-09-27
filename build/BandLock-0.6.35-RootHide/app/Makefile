include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BandLock

BandLock_FILES = \
	main.m \
	BLBreadcrumb.c \
	BLAppDelegate.m \
	BLLocalization.m \
	BLCountryProfile.m \
	BLTelephonyManager.m \
	BLControlViewController.m \
	BLBandPickerViewController.m \
	BLCountryBandsViewController.m \
	BLCountriesViewController.m \
	BLCountryDetailViewController.m \
	BLInfoViewController.m \
	BLLanguageViewController.m \
	BLFrequencyGlossaryViewController.m \
	../shared/BLGBandMetadata.m
BandLock_FRAMEWORKS = UIKit Foundation
BandLock_CFLAGS = -fobjc-arc -I../shared -DBL_APP_LOCALIZATION=1
BandLock_LDFLAGS += -lroothide
BandLock_RESOURCE_DIRS = Resources
BandLock_INSTALL_PATH = /Applications
BandLock_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
