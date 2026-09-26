#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *BLGFrequencyForBand(NSNumber *band);
FOUNDATION_EXPORT NSString *BLGDuplexForBand(NSNumber *band);
FOUNDATION_EXPORT NSString *BLGBandTitle(NSNumber *band);
FOUNDATION_EXPORT NSArray<NSNumber *> *BLGBandsForDuplex(NSArray<NSNumber *> *bands, NSString *duplex);

