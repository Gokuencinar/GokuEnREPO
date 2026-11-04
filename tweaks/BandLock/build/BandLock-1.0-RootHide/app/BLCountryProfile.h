#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const BLSelectedCountryDidChangeNotification;

FOUNDATION_EXPORT NSDictionary *BLCountryRecordForISO(NSString *iso2);
FOUNDATION_EXPORT NSDictionary *BLSelectedCountryRecord(void);
FOUNDATION_EXPORT NSString *BLSelectedCountryISO(void);
FOUNDATION_EXPORT void BLSetSelectedCountry(NSDictionary *country);
FOUNDATION_EXPORT NSString *BLLocalizedCountryName(NSDictionary *country);
// Country candidates, not evidence of local transmission.
FOUNDATION_EXPORT NSArray<NSNumber *> *BLCountryBandsForRAT(NSDictionary *country, NSString *rat);
