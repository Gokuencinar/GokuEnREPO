#import "BLCountryProfile.h"
#import "BLLocalization.h"

NSString * const BLSelectedCountryDidChangeNotification = @"BLSelectedCountryDidChangeNotification";
static NSString * const BLSelectedCountryISOKey = @"BandLockSelectedCountryISO";

static NSDictionary *BLJSONResource(NSString *name) {
    NSString *path = [NSBundle.mainBundle pathForResource:name ofType:@"json"];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
}

static NSDictionary<NSString *, NSDictionary *> *BLCountryIndex(void) {
    static NSDictionary *index;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *spectrumRoot = BLJSONResource(@"country-spectrum");
        NSArray *spectrumCountries = [spectrumRoot[@"countries"] isKindOfClass:NSArray.class]
            ? spectrumRoot[@"countries"] : @[];
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:spectrumCountries.count];
        for (NSDictionary *country in spectrumCountries) {
            NSString *iso = [country[@"iso2"] isKindOfClass:[NSString class]] ? [country[@"iso2"] uppercaseString] : nil;
            if (iso.length == 2) result[iso] = [country mutableCopy];
        }

        NSDictionary *legacyRoot = BLJSONResource(@"countries");
        NSArray *legacyCountries = [legacyRoot[@"countries"] isKindOfClass:NSArray.class]
            ? legacyRoot[@"countries"] : @[];
        for (NSDictionary *country in legacyCountries) {
            NSString *iso = [country[@"iso2"] isKindOfClass:NSString.class] ? [country[@"iso2"] uppercaseString] : nil;
            if (iso.length != 2) continue;
            NSMutableDictionary *merged = [result[iso] mutableCopy] ?: [NSMutableDictionary dictionary];
            [merged addEntriesFromDictionary:country];
            result[iso] = merged;
        }
        index = [result copy];
    });
    return index ?: @{};
}

NSArray<NSDictionary *> *BLAllCountryRecords(void) {
    NSDictionary *index = BLCountryIndex();
    return [[index allValues] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSString *left = [a[@"name"] isKindOfClass:NSString.class] ? a[@"name"] : @"";
        NSString *right = [b[@"name"] isKindOfClass:NSString.class] ? b[@"name"] : @"";
        return [left localizedCaseInsensitiveCompare:right];
    }];
}

NSDictionary *BLCountryRecordForISO(NSString *iso2) {
    if (![iso2 isKindOfClass:[NSString class]]) return nil;
    return BLCountryIndex()[iso2.uppercaseString];
}

NSString *BLSelectedCountryISO(void) {
    NSString *iso = [NSUserDefaults.standardUserDefaults stringForKey:BLSelectedCountryISOKey];
    return iso.length == 2 ? iso.uppercaseString : nil;
}

NSDictionary *BLSelectedCountryRecord(void) {
    return BLCountryRecordForISO(BLSelectedCountryISO());
}

void BLSetSelectedCountry(NSDictionary *country) {
    NSString *iso = [country[@"iso2"] isKindOfClass:[NSString class]] ? [country[@"iso2"] uppercaseString] : nil;
    if (iso.length != 2 || !BLCountryRecordForISO(iso)) return;
    [NSUserDefaults.standardUserDefaults setObject:iso forKey:BLSelectedCountryISOKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    [NSNotificationCenter.defaultCenter postNotificationName:BLSelectedCountryDidChangeNotification object:nil];
}

NSString *BLLocalizedCountryName(NSDictionary *country) {
    NSString *iso = [country[@"iso2"] isKindOfClass:[NSString class]] ? country[@"iso2"] : nil;
    if (iso.length == 2) {
        NSString *localized = [BLLocaleForCurrentLanguage() localizedStringForCountryCode:iso.uppercaseString];
        if (localized.length) return localized;
    }
    NSString *fallback = [country[@"name"] isKindOfClass:[NSString class]] ? country[@"name"] : nil;
    return fallback.length ? fallback : @"—";
}

NSArray<NSNumber *> *BLCountryBandsForRAT(NSDictionary *country, NSString *rat) {
    if (![country isKindOfClass:NSDictionary.class] || ![rat isKindOfClass:NSString.class]) return @[];
    id raw = nil;
    if ([rat isEqualToString:@"LTE"]) raw = country[@"bands"];
    else if ([rat isEqualToString:@"NR"]) raw = country[@"nr_bands"];
    // CoreTelephony uses a private numeric namespace for GSM/UTRAN band masks.
    // Do not guess those IDs from LTE band numbers. 2G/3G country filtering is
    // therefore frequency-based until a device readback proves the mapping.
    else raw = @[];
    if (![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSNumber *> *validated = [NSMutableArray array];
    for (id item in raw) {
        if (![item isKindOfClass:NSNumber.class] || [item integerValue] < 1 ||
            [item integerValue] > 1024 || ![item isEqual:@([item integerValue])]) continue;
        if (![validated containsObject:item]) [validated addObject:item];
    }
    return validated;
}

NSArray<NSNumber *> *BLCountryFrequenciesForRAT(NSDictionary *country, NSString *rat) {
    if (![country isKindOfClass:NSDictionary.class] || ![rat isKindOfClass:NSString.class]) return @[];
    NSDictionary *all = [country[@"frequencies_mhz"] isKindOfClass:NSDictionary.class] ? country[@"frequencies_mhz"] : nil;
    NSArray *raw = [all[rat] isKindOfClass:NSArray.class] ? all[rat] : @[];
    NSMutableArray *result = [NSMutableArray array];
    for (id value in raw) {
        if (![value isKindOfClass:NSNumber.class]) continue;
        NSInteger mhz = [value integerValue];
        if (mhz < 300 || mhz > 100000 || ![value isEqual:@(mhz)]) continue;
        if (![result containsObject:value]) [result addObject:value];
    }
    return [result sortedArrayUsingSelector:@selector(compare:)];
}
