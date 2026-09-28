#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const BLCCPreferencesChangedNotification;

BOOL BLCCShow2G(void);
BOOL BLCCShow3G(void);
BOOL BLCCShowLTE(void);
BOOL BLCCShow5G(void);
BOOL BLCCAdvanced5GModes(void);

void BLCCSetShow2G(BOOL value);
void BLCCSetShow3G(BOOL value);
void BLCCSetShowLTE(BOOL value);
void BLCCSetShow5G(BOOL value);
void BLCCSetAdvanced5GModes(BOOL value);
void BLCCSynchronizePreferences(void);
