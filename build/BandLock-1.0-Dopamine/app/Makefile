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
	BLNRBandPickerViewController.m \
	BLCountryBandsViewController.m \
	BLCountriesViewController.m \
	BLCountryDetailViewController.m \
	BLInfoViewController.m \
	BLCCSettingsViewController.m \
	BLLanguageViewController.m \
	BLFrequencyGlossaryViewController.m \
	../shared/BLCCPreferences.m \
	../shared/BLGBandMetadata.m
BandLock_FRAMEWORKS = UIKit Foundation
BandLock_CFLAGS = -fobjc-arc -I../shared -DBL_APP_LOCALIZATION=1 $(BANDLOCK_VARIANT_CFLAGS)
BandLock_RESOURCE_DIRS = Resources
BandLock_INSTALL_PATH = /Applications
BandLock_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
