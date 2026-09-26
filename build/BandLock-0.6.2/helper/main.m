#import <Foundation/Foundation.h>
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import <stdlib.h>
#import <string.h>

@interface BLTelephonyManager (BandLockHelperPrivate)
- (NSDictionary *)queryCoreTelephony;
- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query;
- (BOOL)setRatSelectionSync:(NSString *)selection preferred:(NSString *)preferred errorText:(NSString **)errorText;
- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
- (NSArray<NSNumber *> *)activeLTEFromQuery:(NSDictionary *)query;
@end

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLRATAutomatic = @"kCTRegistrationRATSelectionAutomatic";
static NSString * const BLRATLTE = @"kCTRegistrationRATSelectionLTE";

static void BLEmit(NSDictionary *payload, int exitCode) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload ?: @{} options:0 error:&error];
    if (!data) {
        NSString *fallback = [NSString stringWithFormat:@"{\"success\":false,\"message\":\"JSON error: %@\"}\n", error.localizedDescription ?: @"unknown"];
        fwrite(fallback.UTF8String, 1, strlen(fallback.UTF8String), stdout);
    } else {
        fwrite(data.bytes, 1, data.length, stdout);
        fwrite("\n", 1, 1, stdout);
    }
    fflush(stdout);
    exit(exitCode);
}

static NSArray<NSNumber *> *BLParseBands(NSString *csv) {
    NSMutableArray<NSNumber *> *result = [NSMutableArray array];
    for (NSString *piece in [csv componentsSeparatedByString:@","]) {
        NSInteger value = [piece integerValue];
        if (value > 0) [result addObject:@(value)];
    }
    return BLSortedBands(result);
}

static NSDictionary *BLStatusPayload(BLTelephonyManager *manager, NSDictionary *query) {
    if (query[@"error"]) return @{@"success": @NO, @"message": [query[@"error"] description] ?: @"CoreTelephony error"};
    NSDictionary *snapshot = [manager snapshotFromQuery:query];
    return @{
        @"success": @YES,
        @"supported": snapshot[@"supported"] ?: @[],
        @"active": snapshot[@"active"] ?: @[],
        @"rat": snapshot[@"rat"] ?: @"—",
        @"serving": snapshot[@"serving"] ?: @"—",
        @"mode": snapshot[@"mode"] ?: @"—"
    };
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        @try {
            if (argc < 2) BLEmit(@{@"success": @NO, @"message": @"Missing command"}, 2);
            NSString *command = [NSString stringWithUTF8String:argv[1]] ?: @"";
            BLTelephonyManager *manager = BLTelephonyManager.sharedManager;

            if ([command isEqualToString:@"status"]) {
                NSDictionary *query = [manager queryCoreTelephony];
                NSDictionary *payload = BLStatusPayload(manager, query);
                BLEmit(payload, [payload[@"success"] boolValue] ? 0 : 3);
            }

            if ([command isEqualToString:@"rat"]) {
                if (argc < 3) BLEmit(@{@"success": @NO, @"message": @"Missing RAT mode"}, 2);
                NSString *mode = [NSString stringWithUTF8String:argv[2]] ?: @"";
                NSString *selection = [mode isEqualToString:@"lte"] ? BLRATLTE : BLRATAutomatic;
                NSString *preferred = [mode isEqualToString:@"lte"] ? BLLTERAT : nil;
                NSString *errorText = nil;
                if (![manager setRatSelectionSync:selection preferred:preferred errorText:&errorText]) {
                    BLEmit(@{@"success": @NO, @"message": errorText ?: @"RAT write failed"}, 4);
                }
                [NSThread sleepForTimeInterval:0.35];
                NSDictionary *query = [manager queryCoreTelephony];
                NSMutableDictionary *payload = [BLStatusPayload(manager, query) mutableCopy];
                if ([payload[@"success"] boolValue]) payload[@"message"] = payload[@"mode"] ?: @"RAT updated";
                BLEmit(payload, [payload[@"success"] boolValue] ? 0 : 5);
            }

            if ([command isEqualToString:@"apply"]) {
                if (argc < 3) BLEmit(@{@"success": @NO, @"message": @"Missing LTE band list"}, 2);
                NSArray<NSNumber *> *bands = BLParseBands([NSString stringWithUTF8String:argv[2]] ?: @"");
                if (!bands.count) BLEmit(@{@"success": @NO, @"message": @"Empty LTE band list"}, 2);
                BOOL allSDL = YES;
                for (NSNumber *band in bands) {
                    if (![[BLGDuplexForBand(band) uppercaseString] isEqualToString:@"SDL"]) { allSDL = NO; break; }
                }
                if (allSDL) BLEmit(@{@"success": @NO, @"message": @"SDL-only LTE selections are not allowed"}, 2);

                NSDictionary *query = [manager queryCoreTelephony];
                if (query[@"error"]) BLEmit(@{@"success": @NO, @"message": [query[@"error"] description]}, 3);
                NSDictionary *before = [manager snapshotFromQuery:query];
                NSArray<NSNumber *> *supported = before[@"supported"] ?: @[];
                NSSet *supportedSet = [NSSet setWithArray:supported];
                for (NSNumber *band in bands) {
                    if (![supportedSet containsObject:band]) {
                        BLEmit(@{@"success": @NO, @"message": [NSString stringWithFormat:@"B%@ is not supported by this modem", band]}, 6);
                    }
                }

                NSArray<NSNumber *> *previous = [manager activeLTEFromQuery:query] ?: @[];
                NSString *writeError = nil;
                if (![manager writeLTEBands:bands usingQuery:query errorText:&writeError]) {
                    BLEmit(@{@"success": @NO, @"message": writeError ?: @"LTE write failed"}, 7);
                }

                [NSThread sleepForTimeInterval:0.8];
                NSDictionary *verify = [manager queryCoreTelephony];
                if (verify[@"error"]) BLEmit(@{@"success": @NO, @"message": [verify[@"error"] description]}, 8);
                NSArray<NSNumber *> *readback = [manager activeLTEFromQuery:verify] ?: @[];
                BOOL matches = [[NSSet setWithArray:bands] isEqualToSet:[NSSet setWithArray:readback]];

                if (!matches) {
                    NSString *retryError = nil;
                    if (![manager writeLTEBands:bands usingQuery:verify errorText:&retryError]) {
                        BLEmit(@{@"success": @NO, @"message": retryError ?: @"LTE retry failed"}, 9);
                    }
                    [NSThread sleepForTimeInterval:1.0];
                    verify = [manager queryCoreTelephony];
                    if (verify[@"error"]) BLEmit(@{@"success": @NO, @"message": [verify[@"error"] description]}, 10);
                    readback = [manager activeLTEFromQuery:verify] ?: @[];
                    matches = [[NSSet setWithArray:bands] isEqualToSet:[NSSet setWithArray:readback]];
                }

                NSMutableDictionary *payload = [BLStatusPayload(manager, verify) mutableCopy];
                if (!payload) payload = [NSMutableDictionary dictionary];
                payload[@"success"] = @(matches);
                payload[@"previous"] = previous;
                payload[@"message"] = matches
                    ? [NSString stringWithFormat:@"Active LTE bands: %@", BLBandList(readback)]
                    : [NSString stringWithFormat:@"Requested %@; read back %@", BLBandList(bands), BLBandList(readback)];
                BLEmit(payload, matches ? 0 : 11);
            }

            if ([command isEqualToString:@"fieldtest"]) {
                NSString *errorText = nil;
                BOOL ok = [manager openFieldTestWithError:&errorText];
                BLEmit(@{@"success": @(ok), @"message": ok ? @"Field Test requested" : (errorText ?: @"Could not open Field Test")}, ok ? 0 : 12);
            }

            BLEmit(@{@"success": @NO, @"message": @"Unknown command"}, 2);
        }
        @catch (NSException *exception) {
            BLEmit(@{@"success": @NO,
                     @"message": exception.reason ?: exception.name ?: @"NSException",
                     @"exception": exception.name ?: @"NSException"}, 90);
        }
    }
}
