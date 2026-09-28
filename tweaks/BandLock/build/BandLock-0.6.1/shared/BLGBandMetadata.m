#import "BLGBandMetadata.h"
#import <dispatch/dispatch.h>

// Informational labels only. The authoritative list of selectable LTE bands is
// always read from CTBandInfo.supportedBands on the device at runtime.
static NSDictionary<NSNumber *, NSDictionary<NSString *, NSString *> *> *BLGMetadata(void) {
    static NSDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @1:  @{@"frequency": @"2100 MHz",          @"duplex": @"FDD"},
            @2:  @{@"frequency": @"1900 MHz PCS",      @"duplex": @"FDD"},
            @3:  @{@"frequency": @"1800 MHz",          @"duplex": @"FDD"},
            @4:  @{@"frequency": @"AWS-1 1700/2100",   @"duplex": @"FDD"},
            @5:  @{@"frequency": @"850 MHz",           @"duplex": @"FDD"},
            @7:  @{@"frequency": @"2600 MHz",          @"duplex": @"FDD"},
            @8:  @{@"frequency": @"900 MHz",           @"duplex": @"FDD"},
            @11: @{@"frequency": @"1500 MHz",          @"duplex": @"FDD"},
            @12: @{@"frequency": @"700 MHz",           @"duplex": @"FDD"},
            @13: @{@"frequency": @"700 MHz",           @"duplex": @"FDD"},
            @14: @{@"frequency": @"700 MHz",           @"duplex": @"FDD"},
            @17: @{@"frequency": @"700 MHz",           @"duplex": @"FDD"},
            @18: @{@"frequency": @"850 MHz",           @"duplex": @"FDD"},
            @19: @{@"frequency": @"850 MHz",           @"duplex": @"FDD"},
            @20: @{@"frequency": @"800 MHz",           @"duplex": @"FDD"},
            @21: @{@"frequency": @"1500 MHz",          @"duplex": @"FDD"},
            @25: @{@"frequency": @"1900 MHz PCS",      @"duplex": @"FDD"},
            @26: @{@"frequency": @"850 MHz",           @"duplex": @"FDD"},
            @28: @{@"frequency": @"700 MHz APT",       @"duplex": @"FDD"},
            @29: @{@"frequency": @"700 MHz",           @"duplex": @"SDL"},
            @30: @{@"frequency": @"2300 MHz WCS",      @"duplex": @"FDD"},
            @32: @{@"frequency": @"1500 MHz",          @"duplex": @"SDL"},
            @34: @{@"frequency": @"2000 MHz",          @"duplex": @"TDD"},
            @38: @{@"frequency": @"2600 MHz",          @"duplex": @"TDD"},
            @39: @{@"frequency": @"1900 MHz",          @"duplex": @"TDD"},
            @40: @{@"frequency": @"2300 MHz",          @"duplex": @"TDD"},
            @41: @{@"frequency": @"2500 MHz",          @"duplex": @"TDD"},
            @42: @{@"frequency": @"3500 MHz",          @"duplex": @"TDD"},
            @46: @{@"frequency": @"5 GHz LAA",         @"duplex": @"TDD"},
            @48: @{@"frequency": @"3500 MHz CBRS",     @"duplex": @"TDD"},
            @53: @{@"frequency": @"2.5 GHz",           @"duplex": @"TDD"},
            @66: @{@"frequency": @"AWS-3 1700/2100",   @"duplex": @"FDD"},
            @71: @{@"frequency": @"600 MHz",           @"duplex": @"FDD"}
        };
    });
    return map;
}

NSString *BLGFrequencyForBand(NSNumber *band) {
    return BLGMetadata()[band][@"frequency"] ?: @"";
}

NSString *BLGDuplexForBand(NSNumber *band) {
    NSString *known = BLGMetadata()[band][@"duplex"];
    if (known.length) return known;

    NSInteger value = band.integerValue;
    if (value >= 33 && value <= 53) return @"TDD";
    if (value == 29 || value == 32 || value == 67 || value == 69 || value == 75 || value == 76) return @"SDL";
    if ((value >= 1 && value <= 32) || (value >= 65 && value <= 88)) return @"FDD";
    return @"LTE";
}

NSString *BLGBandTitle(NSNumber *band) {
    NSString *frequency = BLGFrequencyForBand(band);
    NSString *duplex = BLGDuplexForBand(band);
    if (frequency.length) return [NSString stringWithFormat:@"B%@ · %@ · %@", band, frequency, duplex];
    return [NSString stringWithFormat:@"B%@ · %@", band, duplex];
}

NSArray<NSNumber *> *BLGBandsForDuplex(NSArray<NSNumber *> *bands, NSString *duplex) {
    NSMutableArray *result = [NSMutableArray array];
    for (NSNumber *band in bands ?: @[]) {
        if ([[BLGDuplexForBand(band) uppercaseString] isEqualToString:[duplex uppercaseString]]) {
            [result addObject:band];
        }
    }
    return result;
}
