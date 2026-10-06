include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BandLockA9Test

BandLockA9Test_FILES = \
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
	BLLanguageViewController.m \
	BLFrequencyGlossaryViewController.m \
	../shared/BLCCPreferences.m \
	../shared/BLGBandMetadata.m
BandLockA9Test_FRAMEWORKS = UIKit Foundation
BandLockA9Test_CFLAGS = -fobjc-arc -I../shared -DBL_APP_LOCALIZATION=1 $(BANDLOCK_VARIANT_CFLAGS)
BandLockA9Test_RESOURCE_DIRS = Resources
BandLockA9Test_INSTALL_PATH = /Applications
BandLockA9Test_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
