#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *BLGFrequencyForBand(NSNumber *band);
FOUNDATION_EXPORT NSString *BLGDuplexForBand(NSNumber *band);
FOUNDATION_EXPORT NSString *BLGBandTitle(NSNumber *band);
FOUNDATION_EXPORT NSArray<NSNumber *> *BLGBandsForDuplex(NSArray<NSNumber *> *bands, NSString *duplex);
FOUNDATION_EXPORT NSString *BLGNRFrequencyForBand(NSNumber *band);
FOUNDATION_EXPORT NSString *BLGNRDuplexForBand(NSNumber *band);
FOUNDATION_EXPORT NSString *BLGNRBandTitle(NSNumber *band);
