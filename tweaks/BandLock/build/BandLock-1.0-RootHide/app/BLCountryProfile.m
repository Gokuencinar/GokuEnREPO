#import "BLCountryProfile.h"
#import "BLLocalization.h"

NSString * const BLSelectedCountryDidChangeNotification = @"BLSelectedCountryDidChangeNotification";
static NSString * const BLSelectedCountryISOKey = @"BandLockSelectedCountryISO";

static NSDictionary<NSString *, NSDictionary *> *BLCountryIndex(void) {
    static NSDictionary *index;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [NSBundle.mainBundle pathForResource:@"countries" ofType:@"json"];
        NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
        NSDictionary *root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSArray *countries = [root[@"countries"] isKindOfClass:[NSArray class]] ? root[@"countries"] : @[];
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:countries.count];
        for (NSDictionary *country in countries) {
            NSString *iso = [country[@"iso2"] isKindOfClass:[NSString class]] ? [country[@"iso2"] uppercaseString] : nil;
            if (iso.length == 2) result[iso] = country;
        }
        index = [result copy];
    });
    return index ?: @{};
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
    else if ([country[@"iso2"] isEqualToString:@"ES"]) {
        // Spain GSM 900/DCS 1800 and UMTS I/VIII; actual service varies.
        raw = [rat isEqualToString:@"2G"] ? @[@8, @3] :
              ([rat isEqualToString:@"3G"] ? @[@1, @8] : nil);
    }
    if (![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSNumber *> *validated = [NSMutableArray array];
    for (id item in raw) {
        if (![item isKindOfClass:NSNumber.class] || [item integerValue] < 1 ||
            [item integerValue] > 1024 || ![item isEqual:@([item integerValue])]) continue;
        if (![validated containsObject:item]) [validated addObject:item];
    }
    return validated;
}
