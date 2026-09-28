#import "BLCCPreferences.h"
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>

NSString * const BLCCPreferencesChangedNotification = @"com.gokuencinar.bandlock.ccprefs.changed";

static CFStringRef const BLCCPreferencesDomain = CFSTR("com.gokuencinar.bandlock.ccprefs");
static CFStringRef const BLCCShow2GKey = CFSTR("Show2G");
static CFStringRef const BLCCShow3GKey = CFSTR("Show3G");
static CFStringRef const BLCCShowLTEKey = CFSTR("ShowLTE");
static CFStringRef const BLCCShow5GKey = CFSTR("Show5G");
static CFStringRef const BLCCAdvanced5GKey = CFSTR("Advanced5G");
static CFStringRef const BLCCLastModeCodeKey = CFSTR("LastModeCode");

void BLCCSynchronizePreferences(void) {
    CFPreferencesAppSynchronize(BLCCPreferencesDomain);
}

static BOOL BLCCReadBool(CFStringRef key, BOOL defaultValue) {
    BLCCSynchronizePreferences();
    CFPropertyListRef value = CFPreferencesCopyValue(key,
                                                     BLCCPreferencesDomain,
                                                     kCFPreferencesCurrentUser,
                                                     kCFPreferencesAnyHost);
    if (!value) return defaultValue;
    BOOL result = defaultValue;
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)value);
    else if (CFGetTypeID(value) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)value, kCFNumberCharType, &result);
    CFRelease(value);
    return result;
}

static void BLCCWriteBool(CFStringRef key, BOOL value) {
    CFPreferencesSetValue(key,
                          value ? kCFBooleanTrue : kCFBooleanFalse,
                          BLCCPreferencesDomain,
                          kCFPreferencesCurrentUser,
                          kCFPreferencesAnyHost);
    CFPreferencesSynchronize(BLCCPreferencesDomain,
                             kCFPreferencesCurrentUser,
                             kCFPreferencesAnyHost);
    notify_post(BLCCPreferencesChangedNotification.UTF8String);
}

static NSString *BLCCReadString(CFStringRef key) {
    BLCCSynchronizePreferences();
    CFPropertyListRef value = CFPreferencesCopyValue(key,
                                                     BLCCPreferencesDomain,
                                                     kCFPreferencesCurrentUser,
                                                     kCFPreferencesAnyHost);
    if (!value) return nil;
    NSString *result = nil;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        result = [(__bridge NSString *)value copy];
    }
    CFRelease(value);
    return result;
}

static void BLCCWriteString(CFStringRef key, NSString *value) {
    CFPreferencesSetValue(key,
                          value.length ? (__bridge CFStringRef)value : NULL,
                          BLCCPreferencesDomain,
                          kCFPreferencesCurrentUser,
                          kCFPreferencesAnyHost);
    CFPreferencesSynchronize(BLCCPreferencesDomain,
                             kCFPreferencesCurrentUser,
                             kCFPreferencesAnyHost);
    notify_post(BLCCPreferencesChangedNotification.UTF8String);
}

BOOL BLCCShow2G(void) { return BLCCReadBool(BLCCShow2GKey, YES); }
BOOL BLCCShow3G(void) { return BLCCReadBool(BLCCShow3GKey, YES); }
BOOL BLCCShowLTE(void) { return BLCCReadBool(BLCCShowLTEKey, YES); }
BOOL BLCCShow5G(void) { return BLCCReadBool(BLCCShow5GKey, YES); }
BOOL BLCCAdvanced5GModes(void) { return BLCCReadBool(BLCCAdvanced5GKey, NO); }
NSString *BLCCLastModeCode(void) { return BLCCReadString(BLCCLastModeCodeKey); }

void BLCCSetShow2G(BOOL value) { BLCCWriteBool(BLCCShow2GKey, value); }
void BLCCSetShow3G(BOOL value) { BLCCWriteBool(BLCCShow3GKey, value); }
void BLCCSetShowLTE(BOOL value) { BLCCWriteBool(BLCCShowLTEKey, value); }
void BLCCSetShow5G(BOOL value) { BLCCWriteBool(BLCCShow5GKey, value); }
void BLCCSetAdvanced5GModes(BOOL value) { BLCCWriteBool(BLCCAdvanced5GKey, value); }
void BLCCSetLastModeCode(NSString *modeCode) { BLCCWriteString(BLCCLastModeCodeKey, modeCode); }
