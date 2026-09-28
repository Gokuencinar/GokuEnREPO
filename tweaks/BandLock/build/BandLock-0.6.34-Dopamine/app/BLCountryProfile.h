#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const BLSelectedCountryDidChangeNotification;

FOUNDATION_EXPORT NSDictionary *BLCountryRecordForISO(NSString *iso2);
FOUNDATION_EXPORT NSDictionary *BLSelectedCountryRecord(void);
FOUNDATION_EXPORT NSString *BLSelectedCountryISO(void);
FOUNDATION_EXPORT void BLSetSelectedCountry(NSDictionary *country);
FOUNDATION_EXPORT NSString *BLLocalizedCountryName(NSDictionary *country);
