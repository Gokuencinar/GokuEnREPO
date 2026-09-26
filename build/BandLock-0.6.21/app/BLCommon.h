#import <Foundation/Foundation.h>

static inline BOOL BLUsesSpanish(void) {
    NSString *language = NSLocale.preferredLanguages.firstObject.lowercaseString ?: @"";
    return [language hasPrefix:@"es"];
}

static inline NSString *BLT(NSString *es, NSString *en) {
    return BLUsesSpanish() ? es : en;
}

static inline NSArray<NSNumber *> *BLSortedBands(id bands) {
    if (![bands isKindOfClass:[NSArray class]] && ![bands isKindOfClass:[NSSet class]]) return @[];
    NSArray *input = [bands isKindOfClass:[NSSet class]] ? [(NSSet *)bands allObjects] : (NSArray *)bands;
    NSMutableOrderedSet *normalized = [NSMutableOrderedSet orderedSet];
    for (id item in input) {
        if ([item respondsToSelector:@selector(integerValue)]) {
            NSInteger value = [item integerValue];
            if (value > 0) [normalized addObject:@(value)];
        }
    }
    return [[normalized array] sortedArrayUsingSelector:@selector(compare:)];
}

static inline NSArray<NSNumber *> *BLIntersectBands(NSArray<NSNumber *> *source, NSArray<NSNumber *> *wanted) {
    NSSet *sourceSet = [NSSet setWithArray:source ?: @[]];
    NSMutableArray *result = [NSMutableArray array];
    for (NSNumber *band in wanted ?: @[]) if ([sourceSet containsObject:band]) [result addObject:band];
    return BLSortedBands(result);
}

static inline NSString *BLBandList(NSArray<NSNumber *> *bands) {
    if (!bands.count) return @"—";
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:bands.count];
    for (NSNumber *band in BLSortedBands(bands)) [parts addObject:[NSString stringWithFormat:@"B%@", band]];
    return [parts componentsJoinedByString:@", "];
}

static NSString * const BLPendingSelectionDidChangeNotification = @"BLPendingSelectionDidChangeNotification";
