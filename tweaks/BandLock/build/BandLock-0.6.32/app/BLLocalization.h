#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const BLLanguageDidChangeNotification;

FOUNDATION_EXPORT NSString *BLCurrentLanguageCode(void);
FOUNDATION_EXPORT void BLSetLanguageCode(NSString *code);
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSString *> *> *BLLanguageOptions(void);
FOUNDATION_EXPORT NSLocale *BLLocaleForCurrentLanguage(void);
FOUNDATION_EXPORT NSString *BLLocalizedPair(NSString *es, NSString *en);
