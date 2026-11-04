#import "BLRHSignalScan.h"
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <errno.h>
#import <stdio.h>
#import <objc/message.h>
#import <roothide.h>
#import <CommonCrypto/CommonDigest.h>
#import <stdlib.h>
#import <dlfcn.h>
#import <limits.h>
#import <stdint.h>
#import <string.h>
#import "../../BLHardwareCapabilities.h"

@interface BLTelephonyManager (BLRHSignalScanPrivate)
- (NSDictionary *)queryCoreTelephony;
- (NSDictionary *)queryCoreTelephonyForPassiveObservation;
- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query;
- (NSArray<NSNumber *> *)activeLTEFromQuery:(NSDictionary *)query;
- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
- (BOOL)setModeCodeSync:(NSString *)mode errorText:(NSString **)errorText;
- (NSArray<NSNumber *> *)supportedBandsForTargetRAT:(NSString *)targetRAT fromQuery:(NSDictionary *)query;
- (NSArray<NSNumber *> *)activeBandsForTargetRAT:(NSString *)targetRAT fromQuery:(NSDictionary *)query;
- (BOOL)writeBands:(NSArray<NSNumber *> *)bands
      forTargetRAT:(NSString *)targetRAT
        usingQuery:(NSDictionary *)query
         errorText:(NSString **)errorText;
- (NSDictionary *)bandConfigurationSnapshotFromQuery:(NSDictionary *)query;
- (BOOL)restoreBandConfiguration:(NSDictionary *)snapshot
                      usingQuery:(NSDictionary *)query
                       errorText:(NSString **)errorText;
@end

static NSString *BLScanDirectory(void) {
    return jbroot(@"/var/mobile/Library/Application Support/BandLockGlobal");
}
static NSString *BLScanJournal(void) {
    return [BLScanDirectory() stringByAppendingPathComponent:@"signal-scan-recovery.plist"];
}
static const NSUInteger BLScanMaxBands = 2;

// A crash-safe, private journal must exist before ANY modem write. A plain
// NSUserDefaults synchronize is not an adequate rollback guarantee.
static BOOL BLScanWriteJournal(NSDictionary *state) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    NSString *directoryPath = BLScanDirectory();
    NSString *journalPath = BLScanJournal();
    // Never assume the randomly generated RootHide root contains a particular
    // textual prefix. Validate the path using jbroot's live resolution.
    if (!directoryPath.isAbsolutePath || !journalPath.isAbsolutePath ||
        ![journalPath hasPrefix:[directoryPath stringByAppendingString:@"/"]]) return NO;
    if (![fm createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:&error]) return NO;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!data.length) return NO;
    NSString *temp = [journalPath stringByAppendingFormat:@".%@.tmp", NSUUID.UUID.UUIDString];
    int fd = open(temp.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) return NO;
    BOOL written = YES;
    const uint8_t *bytes = data.bytes;
    size_t remaining = data.length;
    while (remaining) {
        ssize_t count = write(fd, bytes, remaining);
        if (count <= 0) { if (count < 0 && errno == EINTR) continue; written = NO; break; }
        bytes += count;
        remaining -= (size_t)count;
    }
    if (written && fsync(fd) != 0) written = NO;
    if (close(fd) != 0) written = NO;
    if (written && rename(temp.fileSystemRepresentation, journalPath.fileSystemRepresentation) != 0) written = NO;
    if (!written) { unlink(temp.fileSystemRepresentation); return NO; }
    int directory = open(directoryPath.fileSystemRepresentation, O_RDONLY);
    if (directory < 0) return NO;
    BOOL durable = fsync(directory) == 0;
    close(directory);
    return durable;
}

static BOOL BLScanClearJournal(void) {
    // First synchronize the directory so we never erase a recovery record
    // without being able to verify that the directory was accessible.
    int directory = open(BLScanDirectory().fileSystemRepresentation, O_RDONLY);
    if (directory < 0) return NO;
    BOOL durable = fsync(directory) == 0;
    if (durable) durable = (unlink(BLScanJournal().fileSystemRepresentation) == 0 || errno == ENOENT);
    // A failed post-unlink directory fsync may resurrect the journal after
    // a crash. Replaying an already-verified original mask is idempotent.
    // Do not report recovery failure after successfully unlinking it.
    if (durable) (void)fsync(directory);
    close(directory);
    return durable;
}

static NSDictionary *BLScanReadJournal(void) {
    id value = [NSDictionary dictionaryWithContentsOfFile:BLScanJournal()];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static BOOL BLScanJournalExists(void) {
    return access(BLScanJournal().fileSystemRepresentation, F_OK) == 0;
}

static BOOL BLScanMatches(NSArray *a, NSArray *b) {
    if (![a isKindOfClass:NSArray.class] || ![b isKindOfClass:NSArray.class]) return NO;
    return [[NSSet setWithArray:a] isEqualToSet:[NSSet setWithArray:b]];
}

// The data line can switch between CT queries. A persistent, opaque CT
// subscription UUID is needed before we may write or recover band settings.
// If the private API lacks it, the active scan is disabled (read-only works).
static NSString *BLScanSubscriptionUUID(NSDictionary *query) {
    id context = query[@"context"];
    if (!context || context == NSNull.null) return nil;
    SEL selector = NSSelectorFromString(@"uuid");
    if (![context respondsToSelector:selector]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(context, selector);
    NSString *identifier = nil;
    if ([value isKindOfClass:NSUUID.class]) identifier = [value UUIDString];
    else if ([value isKindOfClass:NSString.class]) identifier = value;
    if (!identifier.length || identifier.length > 128) return nil;
    // Journal must not contain the private subscription UUID verbatim.
    typedef unsigned char *(*BLHashFunction)(const void *, CC_LONG, unsigned char *);
    static BLHashFunction hashFunction = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        hashFunction = (BLHashFunction)dlsym(RTLD_DEFAULT, "CC_SHA256");
        if (!hashFunction) {
            void *library = dlopen("/usr/lib/system/libcommonCrypto.dylib", RTLD_NOW | RTLD_LOCAL);
            if (library) hashFunction = (BLHashFunction)dlsym(library, "CC_SHA256");
        }
    });
    if (!hashFunction) return nil; // No stable hash, no modem changes.
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    NSData *data = [identifier dataUsingEncoding:NSUTF8StringEncoding];
    if (!hashFunction(data.bytes, (CC_LONG)data.length, digest)) return nil;
    NSMutableString *fingerprint = [NSMutableString stringWithCapacity:64];
    for (NSUInteger i = 0; i < sizeof(digest); i++) {
        [fingerprint appendFormat:@"%02x", digest[i]];
    }
    return fingerprint;
}

static BOOL BLScanHasPower(NSDictionary *row) {
    return [row[@"rsrp"] isKindOfClass:NSNumber.class] ||
           [row[@"rssi"] isKindOfClass:NSNumber.class] ||
           [row[@"rscp"] isKindOfClass:NSNumber.class];
}

static BOOL BLScanHasAnyMetric(NSDictionary *row) {
    for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
        if ([row[metric] isKindOfClass:NSNumber.class]) return YES;
    }
    return NO;
}

static BOOL BLScanStatusIsMeasured(id status) {
    return [status isKindOfClass:NSString.class] &&
        ([(NSString *)status isEqualToString:@"measured"] ||
         [(NSString *)status isEqualToString:@"measured_frequency_unknown"] ||
         [(NSString *)status isEqualToString:@"measured_pre_sweep"]);
}
static const NSUInteger BLPassiveMaxRows = 8;
static const NSUInteger BLTechnologyScanSamples = 16;

static NSString *BLModeForTargetRAT(NSString *targetRAT) {
    if ([targetRAT isEqualToString:@"2G"]) return @"2g";
    if ([targetRAT isEqualToString:@"3G"]) return @"3g";
    if ([targetRAT isEqualToString:@"LTE"]) return @"lte";
    if ([targetRAT isEqualToString:@"NR"]) return @"5g-on";
    return nil;
}

static NSString *BLDisplayTargetRAT(NSString *targetRAT) {
    if ([targetRAT isEqualToString:@"AUTO"]) return @"Auto";
    if ([targetRAT isEqualToString:@"LTE"]) return @"4G";
    if ([targetRAT isEqualToString:@"NR"]) return @"5G";
    return targetRAT ?: @"Red";
}

static NSArray<NSDictionary *> *BLSortedObservedBands(NSDictionary<NSNumber *, NSDictionary *> *byBand) {
    NSArray<NSNumber *> *keys = [[byBand allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [a compare:b];
    }];
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray arrayWithCapacity:keys.count];
    for (NSNumber *band in keys) {
        NSDictionary *row = byBand[band];
        if (row) [rows addObject:row];
    }
    return rows;
}

static BOOL BLPassiveCellMatches(NSDictionary *existing, NSDictionary *measurement) {
    if (![existing isKindOfClass:NSDictionary.class] || ![measurement isKindOfClass:NSDictionary.class]) return NO;
    if (![existing[@"rat"] isEqual:measurement[@"rat"]] ||
        ![existing[@"role"] isEqual:measurement[@"role"]]) return NO;
    NSNumber *existingBand = [existing[@"band"] isKindOfClass:NSNumber.class] ? existing[@"band"] : nil;
    NSNumber *newBand = [measurement[@"band"] isKindOfClass:NSNumber.class] ? measurement[@"band"] : nil;
    if (existingBand && newBand && ![existingBand isEqual:newBand]) return NO;

    BOOL sharedIdentity = NO;
    for (NSString *key in @[@"cell_id", @"physical_cell_id", @"psc", @"channel"]) {
        NSNumber *left = [existing[key] isKindOfClass:NSNumber.class] ? existing[key] : nil;
        NSNumber *right = [measurement[key] isKindOfClass:NSNumber.class] ? measurement[key] : nil;
        if (!left || !right) continue;
        sharedIdentity = YES;
        if (![left isEqual:right]) return NO;
    }
    if (sharedIdentity) return YES;

    // There is only one serving cell per RAT in a passive snapshot. When
    // CoreTelephony reveals identifiers gradually, keep enriching that row
    // instead of creating duplicate cards. Neighbours require a shared ID.
    return [existing[@"role"] isEqualToString:@"serving"];
}

static void BLEnrichPassiveCell(NSMutableDictionary *record, NSDictionary *measurement) {
    if (![record isKindOfClass:NSMutableDictionary.class] || ![measurement isKindOfClass:NSDictionary.class]) return;
    for (NSString *field in @[@"band", @"cell_id", @"physical_cell_id", @"psc", @"tac", @"lac", @"channel"]) {
        id value = measurement[field];
        if ([value isKindOfClass:NSNumber.class] && !record[field]) record[field] = value;
    }
    for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
        id value = measurement[metric];
        if ([value isKindOfClass:NSNumber.class]) record[metric] = value;
    }
    if ([measurement[@"source"] isEqualToString:@"typed"] ||
        ![record[@"source"] isKindOfClass:NSString.class]) {
        record[@"source"] = measurement[@"source"] ?: @"legacy";
    }
    record[@"status"] = @"measured";
}

static NSNumber *BLReferenceFrequencyForMeasurement(NSDictionary *measurement,
                                                    NSString *targetRAT,
                                                    NSArray<NSNumber *> *allowedFrequencies) {
    NSNumber *channel = [measurement[@"channel"] isKindOfClass:NSNumber.class] ? measurement[@"channel"] : nil;
    if (!channel) return nil;
    NSInteger n = channel.integerValue;
    if ([targetRAT isEqualToString:@"2G"]) {
        if ((n >= 0 && n <= 124) || (n >= 975 && n <= 1023)) return @900;
        if (n >= 128 && n <= 251) return @850;
        if (n >= 811 && n <= 885) return @1800;
        if (n >= 512 && n <= 810) {
            BOOL dcs = [allowedFrequencies containsObject:@1800];
            BOOL pcs = [allowedFrequencies containsObject:@1900];
            if (dcs != pcs) return dcs ? @1800 : @1900;
            return nil; // Same ARFCN range: country profile must disambiguate.
        }
        return nil;
    }
    if ([targetRAT isEqualToString:@"3G"]) {
        // 3GPP TS 25.101 general downlink UARFCN ranges.
        if (n >= 10562 && n <= 10838) return @2100; // UTRA I
        if (n >= 9662 && n <= 9938) return @1900;  // UTRA II
        if (n >= 1162 && n <= 1513) return @1800;  // UTRA III
        if (n >= 1537 && n <= 1738) return @1700;  // UTRA IV / AWS
        if (n >= 4357 && n <= 4458) return @850;   // UTRA V
        if (n >= 2937 && n <= 3088) return @900;   // UTRA VIII
        return nil;
    }
    return nil;
}

static void BLMergeObservedBand(NSMutableDictionary<NSNumber *, NSDictionary *> *byBand,
                                NSDictionary *measurement,
                                NSString *targetRAT,
                                NSArray<NSNumber *> *allowedFrequencies) {
    if (![measurement isKindOfClass:NSDictionary.class] ||
        ![measurement[@"rat"] isEqualToString:targetRAT]) return;
    NSNumber *band = [measurement[@"band"] isKindOfClass:NSNumber.class] ? measurement[@"band"] : nil;
    if (band && (band.integerValue < 1 ||
        band.integerValue > ([targetRAT isEqualToString:@"NR"] ? 1024 : 255))) return;
    NSNumber *referenceFrequency = BLReferenceFrequencyForMeasurement(measurement, targetRAT, allowedFrequencies);
    BOOL legacyFrequencyUnknown = ([targetRAT isEqualToString:@"2G"] || [targetRAT isEqualToString:@"3G"]) &&
        allowedFrequencies.count && !referenceFrequency;
    if (([targetRAT isEqualToString:@"2G"] || [targetRAT isEqualToString:@"3G"]) &&
        referenceFrequency && allowedFrequencies.count &&
        ![allowedFrequencies containsObject:referenceFrequency]) return;
    NSNumber *channel = [measurement[@"channel"] isKindOfClass:NSNumber.class] ? measurement[@"channel"] : nil;
    NSNumber *psc = [measurement[@"psc"] isKindOfClass:NSNumber.class] ? measurement[@"psc"] : nil;
    NSNumber *physicalCell = [measurement[@"physical_cell_id"] isKindOfClass:NSNumber.class]
        ? measurement[@"physical_cell_id"] : nil;
    NSNumber *cellID = [measurement[@"cell_id"] isKindOfClass:NSNumber.class] ? measurement[@"cell_id"] : nil;
    NSNumber *rowKey = band ? band :
        (channel ? @(1000000LL + channel.longLongValue) :
        (psc ? @(2000000LL + psc.longLongValue) :
        (physicalCell ? @(3000000LL + physicalCell.longLongValue) :
        (cellID ? @(4000000LL + cellID.longLongValue) : nil))));
    if (!rowKey) return;
    NSString *role = [measurement[@"role"] isKindOfClass:NSString.class] ? measurement[@"role"] : @"unknown";
    if (![role isEqualToString:@"serving"] && ![role isEqualToString:@"neighbor"]) return;

    NSMutableDictionary *record = [@{
        @"rat": targetRAT,
        @"role": role,
        @"source": [measurement[@"source"] isKindOfClass:NSString.class] ? measurement[@"source"] : @"unknown",
        @"status": legacyFrequencyUnknown
            ? (BLScanHasPower(measurement) ? @"measured_frequency_unknown" : @"detected_frequency_unknown")
            : (BLScanHasPower(measurement) ? @"measured" : @"detected")
    } mutableCopy];
    if (band) record[@"band"] = band;
    if (referenceFrequency) record[@"reference_frequency_mhz"] = referenceFrequency;
    if (legacyFrequencyUnknown) record[@"frequency_unverified"] = @YES;
    for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
        id value = measurement[metric];
        if ([value isKindOfClass:NSNumber.class]) record[metric] = value;
    }
    for (NSString *field in @[@"cell_id", @"physical_cell_id", @"psc", @"tac", @"lac", @"channel"]) {
        if ([measurement[field] isKindOfClass:NSNumber.class]) record[field] = measurement[field];
    }

    NSDictionary *existing = byBand[rowKey];
    // Prefer serving-cell data over a neighbor row. Otherwise retain the
    // first real metric set instead of fabricating an average across cells.
    BOOL replace = !existing ||
        ([existing[@"role"] isEqualToString:@"neighbor"] && [role isEqualToString:@"serving"]) ||
        (!BLScanStatusIsMeasured(existing[@"status"]) && BLScanStatusIsMeasured(record[@"status"]));
    if (replace) byBand[rowKey] = record;
}

static NSNumber *BLRHSlotNumber(id context) {
    if (!context || context == NSNull.null) return nil;
    SEL slotSelector = NSSelectorFromString(@"slotID");
    if (![context respondsToSelector:slotSelector]) return nil;
    NSMethodSignature *signature = [context methodSignatureForSelector:slotSelector];
    if (!signature || signature.numberOfArguments != 2) return nil;
    const char *type = signature.methodReturnType;
    // ObjC runtime type encodings can be qualified. Only signed and unsigned
    // scalar slotIDs with an exactly matching return width are accepted.
    while (type && strchr("rnNoORV", type[0])) type++;
    if (!type) return nil;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = slotSelector;
    invocation.target = context;
    [invocation invoke];
    unsigned long long result = ULLONG_MAX;
    if (type[0] == 'i' && signature.methodReturnLength == sizeof(int32_t)) {
        int32_t value = -1;
        [invocation getReturnValue:&value];
        if (value >= 0) result = (unsigned long long)value;
    } else if (type[0] == 'I' && signature.methodReturnLength == sizeof(uint32_t)) {
        uint32_t value = UINT32_MAX;
        [invocation getReturnValue:&value];
        result = value;
    } else if (type[0] == 'q' && signature.methodReturnLength == sizeof(int64_t)) {
        int64_t value = -1;
        [invocation getReturnValue:&value];
        if (value >= 0) result = (unsigned long long)value;
    } else if (type[0] == 'Q' && signature.methodReturnLength == sizeof(uint64_t)) {
        uint64_t value = UINT64_MAX;
        [invocation getReturnValue:&value];
        result = value;
    }
    // A real modem slot is small. Unknown ABI / out-of-range => fail closed.
    return result <= 16 ? @(result) : nil;
}

// A carrier-provider dictionary lists plans, including disabled eSIMs.
// It is NOT authoritative for how many lines are active. iPhone XS hardware
// showed: 2 configured plans, 1 registered RAT, 1 ACTIVE CT context.
// Require one actual active CTXPCContextInfo and SAME slot as data context.
static NSDictionary *BLRHActiveLineCheck(NSDictionary *query) {
    id client = query[@"client"];
    id dataContext = query[@"context"];
    NSDictionary *rat = [query[@"ratRaw"] isKindOfClass:NSDictionary.class] ? query[@"ratRaw"] : nil;
    Class infoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    id info = infoClass ? [[infoClass alloc] init] : nil;
    SEL dataSelector = NSSelectorFromString(@"dataServiceIdentifier");
    id service = [info respondsToSelector:dataSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(info, dataSelector) : nil;
    BOOL serviceInRAT = [service isKindOfClass:NSString.class] &&
                         [service length] && rat[service] != nil;
    BOOL singleRegistered = rat.count == 1;
    NSNumber *dataSlot = BLRHSlotNumber(dataContext);
    BOOL activeAPI = [client respondsToSelector:NSSelectorFromString(@"getActiveContexts:")];
    BOOL singleActive = NO;
    BOOL slotMatched = NO;
    NSUInteger activeContextCount = NSNotFound;
    NSString *status = @"api_unavailable";
    if (activeAPI) {
        @try {
            NSError *error = nil;
            id contexts = ((id (*)(id, SEL, NSError **))objc_msgSend)(
                client, NSSelectorFromString(@"getActiveContexts:"), &error);
            SEL subscriptionsSelector = NSSelectorFromString(@"subscriptions");
            id subscriptions = [contexts respondsToSelector:subscriptionsSelector]
                ? ((id (*)(id, SEL))objc_msgSend)(contexts, subscriptionsSelector) : nil;
            if (error) {
                status = @"error";
            } else if ([subscriptions isKindOfClass:NSArray.class]) {
                status = @"array";
                activeContextCount = [(NSArray *)subscriptions count];
                singleActive = [(NSArray *)subscriptions count] == 1;
                if (singleActive && dataSlot) {
                    NSNumber *activeSlot = BLRHSlotNumber([(NSArray *)subscriptions firstObject]);
                    slotMatched = activeSlot && [activeSlot isEqualToNumber:dataSlot];
                }
            } else {
                status = @"unsupported_container";
            }
        } @catch (__unused NSException *exception) {
            status = @"exception";
        }
    }
    return @{@"verified": @(singleRegistered && singleActive && serviceInRAT &&
                            slotMatched && BLScanSubscriptionUUID(query).length == 64),
             @"one_registered_rat": @(singleRegistered),
             @"one_active_context": @(singleActive),
             @"active_context_count": activeContextCount == NSNotFound ? NSNull.null : @(activeContextCount),
             @"active_context_matches_data_slot": @(slotMatched),
             @"data_service_matches_registered_rat": @(serviceInRAT),
             @"active_context_check_status": status};
}

static BOOL BLScanSingleActiveLine(NSDictionary *query) {
    return [BLRHActiveLineCheck(query)[@"verified"] boolValue];
}

// Recovery is allowed to run while the modem is detached. Requiring one
// registered RAT before requesting the saved mode creates a circular failure:
// a 3G-only scan may lose service precisely because the carrier no longer
// registers 3G. Keep the identity checks fail-closed for a changed/multiple
// line, but allow zero registered RATs when the same hashed data context is
// still present. This helper is for recovery only; scan preflight remains
// strict via BLScanSingleActiveLine().
static BOOL BLScanRecoveryIdentityCompatible(NSDictionary *query,
                                             NSString *subscription) {
    if (![subscription isKindOfClass:NSString.class] || subscription.length != 64) return NO;
    NSString *fingerprint = BLScanSubscriptionUUID(query);
    if (!fingerprint.length || ![fingerprint isEqualToString:subscription]) return NO;

    NSDictionary *rat = [query[@"ratRaw"] isKindOfClass:NSDictionary.class]
        ? query[@"ratRaw"] : nil;
    if (rat && rat.count > 1) return NO;

    NSDictionary *lineCheck = BLRHActiveLineCheck(query);
    id activeCountValue = lineCheck[@"active_context_count"];
    if ([activeCountValue isKindOfClass:NSNumber.class]) {
        NSUInteger activeCount = [activeCountValue unsignedIntegerValue];
        if (activeCount > 1) return NO;
        if (activeCount == 1 && ![lineCheck[@"active_context_matches_data_slot"] boolValue]) return NO;
    }
    if (rat.count == 1 && ![lineCheck[@"data_service_matches_registered_rat"] boolValue]) return NO;
    return YES;
}

// Privacy-preserving preflight: only counts, selector availability and
// consistency booleans. Never expose service IDs, provider names, SIM IDs,
// subscription UUIDs or raw CoreTelephony object descriptions.
static NSDictionary *BLRHLineDiagnostics(NSDictionary *query) {
    NSMutableDictionary *result = [@{@"success": @YES,
      @"read_only": @YES, @"diagnostic_version": @3,
      @"message": @"Cellular service inventory (counts only; no radio changes)"} mutableCopy];
    // Selection categories and a numeric RAT bitmask are deliberately
    // limited to allowlisted metadata. Raw CoreTelephony objects, selected
    // strings, service identifiers and cell/SIM data NEVER leave the daemon.
    for (NSString *key in @[@"ratReadSource", @"ratReadStatus",
                            @"ratSelectionKind", @"ratSyncKind",
                            @"ratSyncStatus", @"ratAsyncKind",
                            @"ratAsyncStatus", @"ratMaskStatus"]) {
        if ([query[key] isKindOfClass:NSString.class]) {
            NSString *publicName = @{@"ratReadSource": @"rat_read_source",
                  @"ratReadStatus": @"rat_read_status",
                  @"ratSelectionKind": @"rat_selection_kind",
                  @"ratSyncKind": @"rat_sync_kind",
                  @"ratSyncStatus": @"rat_sync_status",
                  @"ratAsyncKind": @"rat_async_kind",
                  @"ratAsyncStatus": @"rat_async_status",
                  @"ratMaskStatus": @"rat_mask_status"}[key];
            // Explicit allowlist so raw SIM/service identifiers can never
            // accidentally leak if a future change reuses a query field.
            NSString *safe = query[key];
            NSSet *allow = [NSSet setWithArray:@[
                @"mask_sync", @"async_fallback", @"none", @"ok",
                @"timeout", @"error", @"empty", @"unavailable",
                @"explicit_unknown", @"unrecognized", @"unrecognized_or_missing",
                @"unknown_selection", @"descriptor_unavailable", @"exception",
                @"not_needed", @"missing", @"invalid_type", @"lte",
                @"automatic", @"umts", @"gsm", @"nr", @"nr_sa", @"nr_nsa"
            ]];
            if (publicName) result[publicName] = [allow containsObject:safe] ? safe : @"unrecognized";
        }
    }
    if ([query[@"ratMaskByte"] isKindOfClass:NSNumber.class] &&
        [query[@"ratMaskByte"] integerValue] >= 0 &&
        [query[@"ratMaskByte"] integerValue] <= 255) {
        result[@"rat_mask_byte_diagnostic_only"] = query[@"ratMaskByte"];
    }
    result[@"rat_mode_code"] = [query[@"ratSelectionKind"] isEqualToString:@"lte"]
        ? @"lte" : @"unknown_or_other";
    id rawRAT = query[@"ratRaw"];
    BOOL ratValid = [rawRAT isKindOfClass:NSDictionary.class];
    NSDictionary *rat = ratValid ? rawRAT : nil;
    result[@"registered_rat_available"] = @(ratValid);
    result[@"registered_rat_count"] = @(rat.count);
    id client = query[@"client"];
    id context = query[@"context"];
    result[@"subscription_context_present"] = @(context && context != NSNull.null);
    result[@"subscription_fingerprint_available"] = @(BLScanSubscriptionUUID(query).length == 64);
    result[@"lte_mode"] = @([[query[@"ratSelection"] description] rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound);
    result[@"scan_gate_current"] = @(BLScanSingleActiveLine(query));
    [result addEntriesFromDictionary:BLRHActiveLineCheck(query)];

    Class infoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    id info = infoClass ? [[infoClass alloc] init] : nil;
    SEL providerSelector = NSSelectorFromString(@"serviceSubscriberCellularProviders");
    id rawProviders = info && [info respondsToSelector:providerSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(info, providerSelector) : nil;
    NSDictionary *providers = [rawProviders isKindOfClass:NSDictionary.class] ? rawProviders : nil;
    result[@"provider_inventory_available"] = @(providers != nil);
    result[@"provider_inventory_count"] = @(providers.count);
    SEL dataSelector = NSSelectorFromString(@"dataServiceIdentifier");
    id dataService = info && [info respondsToSelector:dataSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(info, dataSelector) : nil;
    BOOL hasData = [dataService isKindOfClass:NSString.class] && [dataService length] > 0;
    result[@"data_service_present"] = @(hasData);
    result[@"data_service_in_rat"] = @(hasData && rat[dataService] != nil);
    result[@"data_service_in_providers"] = @(hasData && providers[dataService] != nil);

    // getActiveContexts: exists in iOS 16 CoreTelephonyClient headers.
    // CTXPCContexts.subscriptions contains ACTUAL active CTXPCContextInfo,
    // unlike serviceSubscriberCellularProviders (provisioned carriers).
    SEL activeSelector = NSSelectorFromString(@"getActiveContexts:");
    result[@"active_context_api_available"] = @([client respondsToSelector:activeSelector]);
    if ([client respondsToSelector:activeSelector]) {
        @try {
            NSError *error = nil;
            id active = ((id (*)(id, SEL, NSError **))objc_msgSend)(client, activeSelector, &error);
            SEL subs = NSSelectorFromString(@"subscriptions");
            id items = active && [active respondsToSelector:subs]
                ? ((id (*)(id, SEL))objc_msgSend)(active, subs) : nil;
            result[@"active_context_status"] = error ? @"error" :
                ([items isKindOfClass:NSArray.class] ? @"array" : (active ? @"unsupported_container" : @"empty"));
            if ([items isKindOfClass:NSArray.class]) {
                result[@"active_context_count"] = @([(NSArray *)items count]);
            }
        } @catch (__unused NSException *exception) {
            result[@"active_context_status"] = @"exception";
        }
    }

    SEL subscriptionSelector = NSSelectorFromString(@"getSubscriptionInfoWithError:");
    result[@"subscription_info_api_available"] = @([client respondsToSelector:subscriptionSelector]);
    if ([client respondsToSelector:subscriptionSelector]) {
        @try {
            NSError *error = nil;
            id subscriptions = ((id (*)(id, SEL, NSError **))objc_msgSend)(client, subscriptionSelector, &error);
            SEL subs = NSSelectorFromString(@"subscriptions");
            id items = subscriptions && [subscriptions respondsToSelector:subs]
                ? ((id (*)(id, SEL))objc_msgSend)(subscriptions, subs) : nil;
            result[@"subscription_info_status"] = error ? @"error" :
                ([items isKindOfClass:NSArray.class] ? @"array" : (subscriptions ? @"unsupported_container" : @"empty"));
            if ([items isKindOfClass:NSArray.class]) {
                result[@"configured_context_count"] = @([(NSArray *)items count]);
            }
        } @catch (__unused NSException *exception) {
            result[@"subscription_info_status"] = @"exception";
        }
    }
    return result;
}

static NSArray *BLScanMeasurements(BLTelephonyManager *manager, NSDictionary *query) {
    NSDictionary *probe = [manager signalProbeFromQuery:query];
    return [probe[@"success"] boolValue] && [probe[@"measurements"] isKindOfClass:NSArray.class]
        ? probe[@"measurements"] : @[];
}

static BOOL BLScanHasServingRAT(BLTelephonyManager *manager, NSDictionary *query, NSString *targetRAT) {
    if (![targetRAT isKindOfClass:NSString.class] || !targetRAT.length) return NO;
    for (NSDictionary *measurement in BLScanMeasurements(manager, query)) {
        if ([measurement[@"rat"] isEqualToString:targetRAT] &&
            [measurement[@"role"] isEqualToString:@"serving"]) return YES;
    }
    return NO;
}

static BOOL BLScanHasConflictingServingRAT(BLTelephonyManager *manager,
                                            NSDictionary *query,
                                            NSString *targetRAT) {
    for (NSDictionary *measurement in BLScanMeasurements(manager, query)) {
        if (![measurement[@"role"] isEqualToString:@"serving"]) continue;
        NSString *rat = [measurement[@"rat"] isKindOfClass:NSString.class]
            ? measurement[@"rat"] : nil;
        if (rat.length && ![rat isEqualToString:targetRAT]) return YES;
    }
    return NO;
}

static NSString *BLTargetRATForMode(NSString *mode) {
    if ([mode isEqualToString:@"2g"]) return @"2G";
    if ([mode isEqualToString:@"3g"]) return @"3G";
    if ([mode isEqualToString:@"lte"]) return @"LTE";
    if ([mode isEqualToString:@"5g-on"] || [mode isEqualToString:@"5g-only"]) return @"NR";
    return nil; // Automatic / 5G Auto may legitimately register on several RATs.
}

static BOOL BLScanBandConfigurationMatches(BLTelephonyManager *manager,
                                           NSDictionary *query,
                                           NSDictionary *savedConfiguration) {
    NSDictionary *current = [manager bandConfigurationSnapshotFromQuery:query];
    NSDictionary *savedActive = [savedConfiguration[@"active"] isKindOfClass:NSDictionary.class]
        ? savedConfiguration[@"active"] : nil;
    NSDictionary *currentActive = [current[@"active"] isKindOfClass:NSDictionary.class]
        ? current[@"active"] : nil;
    return savedActive && currentActive && [savedActive isEqualToDictionary:currentActive];
}

static BOOL BLScanTargetBandsMatch(BLTelephonyManager *manager,
                                   NSDictionary *query,
                                   NSString *targetRAT,
                                   NSArray<NSNumber *> *originalBands) {
    if (!targetRAT.length || !originalBands.count) return NO;
    return BLScanMatches([manager activeBandsForTargetRAT:targetRAT fromQuery:query],
                         originalBands);
}

// A registered LTE serving cell is NOT proof of LTE-only selection. A
// transiently unavailable selection may be retried, but absolutely no
// further modem writes occur until an explicit LTE-only selection is read.
static NSDictionary *BLRHWritableQuery(BLTelephonyManager *manager,
                                       NSDictionary *initial,
                                       NSString *subscription,
                                       NSString *expectedMode,
                                       NSString **failure) {
    NSDictionary *candidate = initial;
    for (NSUInteger attempt = 0; attempt < 3; attempt++) {
        if (candidate[@"error"]) {
            if (failure) *failure = @"Cellular query failed before a band write; restoring";
            return nil;
        }
        if (!BLScanSingleActiveLine(candidate) ||
            ![BLScanSubscriptionUUID(candidate) isEqualToString:subscription]) {
            if (failure) *failure = @"Cellular subscription is no longer verified; restoring";
            return nil;
        }
        NSString *mode = [manager snapshotFromQuery:candidate][@"mode_code"];
        if ([mode isEqualToString:expectedMode]) return candidate;
        if (![mode isEqualToString:@"unknown"]) {
            if (failure) *failure = @"A different network mode was explicitly reported; restoring";
            return nil;
        }
        if (attempt < 2) {
            [NSThread sleepForTimeInterval:0.7];
            candidate = [manager queryCoreTelephony];
        }
    }
    if (failure) *failure = @"LTE-only mode could not be verified (CoreTelephony read unavailable); restoring";
    return nil;
}

@interface BLRHSignalScan ()
@property (nonatomic, strong) NSMutableDictionary *scanState;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL cancelRequested;
@property (nonatomic, assign) BOOL recovering;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, assign) NSUInteger automaticRecoveryRetries;
@property (nonatomic, strong) dispatch_queue_t scanQueue;
- (NSDictionary *)startPreparedWithManager:(BLTelephonyManager *)manager;
- (BOOL)restoreJournalWithManager:(BLTelephonyManager *)manager
                           failure:(NSString **)failureReason;
- (void)runTechnologyScanForTarget:(NSString *)targetRAT
                       restoreMode:(NSString *)restoreMode
                      subscription:(NSString *)subscription
                           manager:(BLTelephonyManager *)manager;
@end

@implementation BLRHSignalScan

+ (instancetype)sharedScan {
    static BLRHSignalScan *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[BLRHSignalScan alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _scanQueue = dispatch_queue_create("com.gokuencinar.bandlock.signal-scan", DISPATCH_QUEUE_SERIAL);
        _scanState = [@{@"success": @YES, @"running": @NO, @"phase": @"idle",
                        @"rows": @[], @"message": @"No scan started"} mutableCopy];
    }
    return self;
}

- (BOOL)isRunning { @synchronized(self) { return self.running; } }
- (BOOL)isRecovering { @synchronized(self) { return self.recovering; } }
- (BOOL)hasPendingRecovery { return BLScanJournalExists(); }

- (NSDictionary *)status {
    @synchronized(self) {
        NSMutableDictionary *status = [self.scanState mutableCopy];
        status[@"running"] = @(self.running);
        status[@"recovery_required"] = @(BLScanJournalExists() && !self.running);
        return status;
    }
}

- (NSDictionary *)probeWithManager:(BLTelephonyManager *)manager {
    NSDictionary *query = [manager queryCoreTelephony];
    return [manager signalProbeFromQuery:query];
}

- (NSDictionary *)lineDiagnosticsWithManager:(BLTelephonyManager *)manager {
    if ([self isRunning] || [self isRecovering] || [self hasPendingRecovery])
        return @{@"success": @NO, @"message": @"Wait for the original bands to be restored first"};
    NSDictionary *query = [manager queryCoreTelephony];
    if (query[@"error"])
        return @{@"success": @NO, @"message": @"CoreTelephony read failed (no radio changes)"};
    return BLRHLineDiagnostics(query);
}

- (NSDictionary *)bandInventoryWithManager:(BLTelephonyManager *)manager {
    if ([self isRunning] || [self isRecovering] || [self hasPendingRecovery])
        return @{@"success": @NO, @"message": @"Wait for scan/recovery to finish"};
    NSDictionary *query = [manager queryCoreTelephonyForPassiveObservation];
    if (query[@"error"])
        return @{@"success": @NO, @"read_only": @YES,
                 @"message": @"CoreTelephony band inventory unavailable"};
    NSMutableDictionary *rats = [NSMutableDictionary dictionary];
    for (NSString *rat in @[@"2G", @"3G", @"LTE", @"NR"]) {
        NSArray *supported = [manager supportedBandsForTargetRAT:rat fromQuery:query] ?: @[];
        NSArray *active = [manager activeBandsForTargetRAT:rat fromQuery:query] ?: @[];
        rats[rat] = @{@"supported": supported, @"active": active};
    }
    return @{@"success": @YES, @"read_only": @YES,
             @"message": @"Sanitized CTBandInfo inventory", @"rats": rats};
}

- (NSDictionary *)startPassiveObservationWithManager:(BLTelephonyManager *)manager
                                              target:(NSString *)targetRAT {
    if (![@[@"AUTO", @"2G", @"3G", @"LTE", @"NR"] containsObject:targetRAT]) {
        return @{@"success": @NO, @"message": @"Tecnología de red no válida"};
    }
    if ([targetRAT isEqualToString:@"NR"] && BLDeviceIsKnownLTEOnly()) {
        return @{@"success": @NO, @"message": @"Este iPhone no dispone de módem 5G"};
    }
    @synchronized(self) {
        if (self.running || self.recovering || BLScanJournalExists()) {
            return @{@"success": @NO,
                     @"message": @"Finish the current scan/recovery before passive observation"};
        }
        self.running = YES; // Share the lock with active scanning and all modem writes.
        self.cancelRequested = NO;
        self.scanState = [@{@"success": @YES, @"running": @YES,
            @"read_only": @YES, @"phase": @"observing",
            @"rows": @[], @"total": @12, @"completed": @0,
            @"target_rat": targetRAT,
            @"message": [targetRAT isEqualToString:@"AUTO"]
                ? @"Observando la red actual en Auto"
                : [NSString stringWithFormat:@"Observando %@", BLDisplayTargetRAT(targetRAT)]} mutableCopy];
    }
    dispatch_async(self.scanQueue, ^{
        NSMutableArray *rows = [NSMutableArray array];
        NSString *stop = nil;
        NSString *subscription = nil;
        NSUInteger samplesCompleted = 0;
        @try {
            // 12 bounded observations. No retry may write bands or RAT.
            // On NR-capable hardware, collect real serving NR observations,
            // never synthesize NR from an LTE anchor.
            for (NSUInteger sample = 0; sample < 12; sample++) {
                @autoreleasepool {
                    if ([self shouldStop]) { stop = @"Observation cancelled"; break; }
                    NSDictionary *query = [manager queryCoreTelephonyForPassiveObservation];
                    if (query[@"error"]) {
                        stop = @"CoreTelephony temporarily unavailable; observation stopped";
                        break;
                    }
                    // Read-only observation does not require a writable band
                    // context. Keep the identity invariant when available,
                    // but do not reject older 2G/3G observations simply
                    // because a private LTE subscription getter is missing.
                    NSString *fingerprint = BLScanSubscriptionUUID(query);
                    if (!subscription) subscription = fingerprint;
                    if (subscription && fingerprint && ![subscription isEqualToString:fingerprint]) {
                        stop = @"The data subscription changed; observation stopped";
                        break;
                    }
                    BOOL supportsNR = !BLDeviceIsKnownLTEOnly() &&
                        [[manager snapshotFromQuery:query][@"supports_5g"] boolValue];
                    for (NSDictionary *measurement in BLScanMeasurements(manager, query)) {
                        NSString *rat = measurement[@"rat"];
                        BOOL matchesTarget = [targetRAT isEqualToString:@"AUTO"] ||
                            [rat isEqualToString:targetRAT];
                        NSString *role = [measurement[@"role"] isKindOfClass:NSString.class]
                            ? measurement[@"role"] : @"";
                        BOOL roleAllowed = [role isEqualToString:@"serving"] ||
                            ([targetRAT isEqualToString:@"AUTO"] && [role isEqualToString:@"neighbor"]);
                        if (!roleAllowed ||
                            !matchesTarget ||
                            ([rat isEqualToString:@"NR"] && !supportsNR) ||
                            !BLScanHasPower(measurement)) continue;
                        // LTE requires a typed measurement. NR can use legacy
                        // values when CoreTelephony supplies a genuinely
                        // identified serving NR cell, never a guessed band.
                        BOOL autoLegacyLTENeighbor = [targetRAT isEqualToString:@"AUTO"] &&
                            [rat isEqualToString:@"LTE"] &&
                            [role isEqualToString:@"neighbor"];
                        if ([rat isEqualToString:@"LTE"] &&
                            ![measurement[@"source"] isEqualToString:@"typed"] &&
                            !autoLegacyLTENeighbor) continue;
                        NSNumber *band = measurement[@"band"];
                        if (band && (band.integerValue < 1 ||
                            band.integerValue > ([rat isEqual:@"NR"] ? 1024 : 255))) continue;
                        NSMutableDictionary *matched = nil;
                        for (NSMutableDictionary *previous in rows) {
                            if (BLPassiveCellMatches(previous, measurement)) {
                                matched = previous;
                                break;
                            }
                        }
                        if (matched) {
                            BLEnrichPassiveCell(matched, measurement);
                        } else if (rows.count < BLPassiveMaxRows) {
                            NSMutableDictionary *record = [@{
                                @"rat": rat,
                                @"role": role, @"source": measurement[@"source"] ?: @"legacy",
                            @"status": @"measured", @"read_only": @YES
                            } mutableCopy];
                            if (band) record[@"band"] = band;
                            for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
                                id value = measurement[metric];
                                if ([value isKindOfClass:NSNumber.class]) record[metric] = value;
                            }
                            for (NSString *field in @[@"cell_id", @"physical_cell_id", @"psc", @"tac", @"lac", @"channel"]) {
                                if ([measurement[field] isKindOfClass:NSNumber.class]) record[field] = measurement[field];
                            }
                            [rows addObject:record];
                        }
                        // LTE and NR may coexist in an NSA sample.
                    }
                    @synchronized(self) {
                        samplesCompleted = sample + 1;
                        self.scanState[@"rows"] = [rows copy];
                        self.scanState[@"completed"] = @(samplesCompleted);
                        self.scanState[@"message"] = [NSString stringWithFormat:
                            @"Muestra %lu/12 · %lu celdas/portadoras",
                            (unsigned long)(sample + 1), (unsigned long)rows.count];
                    }
                    if (sample < 11) [NSThread sleepForTimeInterval:2.0];
                } // Release CoreTelephony objects from this sample promptly.
            }
        } @catch (__unused NSException *exception) {
            stop = @"Read-only observation failed; no modem settings were changed";
        } @finally {
            @synchronized(self) {
                self.running = NO;
                self.cancelRequested = NO;
                self.scanState[@"running"] = @NO;
                self.scanState[@"rows"] = [rows copy];
                self.scanState[@"completed"] = @(samplesCompleted);
                BOOL cancelled = [stop isEqualToString:@"Observation cancelled"];
                self.scanState[@"success"] = @(!stop || cancelled);
                self.scanState[@"phase"] = stop
                    ? (cancelled ? @"observation_cancelled" : @"observation_stopped")
                    : @"observation_complete";
                self.scanState[@"message"] = stop ? stop :
                    (rows.count
                     ? ([targetRAT isEqualToString:@"AUTO"] ? @"Observación Auto completada" : @"Observación completada")
                     : ([targetRAT isEqualToString:@"AUTO"]
                        ? @"No se ha observado una celda servidora con métricas válidas; no se ha modificado la red"
                        : [NSString stringWithFormat:
                            @"No se ha observado señal %@ en la conexión actual; no se ha forzado ninguna red",
                            BLDisplayTargetRAT(targetRAT)]));
                self.scanState[@"recovery_required"] = @NO;
            }
        }
    });
    return @{@"success": @YES, @"read_only": @YES,
             @"message": @"Observación de señal iniciada"};
}

- (NSDictionary *)startTechnologyScanWithManager:(BLTelephonyManager *)manager
                                           target:(NSString *)targetRAT
                                      restoreMode:(NSString *)restoreMode
                                       countryISO:(NSString *)countryISO
                                      targetBands:(NSArray<NSNumber *> *)targetBands
                                targetFrequencies:(NSArray<NSNumber *> *)targetFrequencies {
    // Reject malformed client-supplied masks before any modem changes.
    if (![countryISO isKindOfClass:NSString.class] || countryISO.length != 2 ||
        ![targetBands isKindOfClass:NSArray.class] || targetBands.count > 64 ||
        ![targetFrequencies isKindOfClass:NSArray.class] || targetFrequencies.count > 64 ||
        (!targetBands.count && !targetFrequencies.count)) {
        return @{@"success": @NO, @"message": @"Selecciona país y frecuencias de referencia válidos"};
    }
    for (id band in targetBands) {
        if (![band isKindOfClass:NSNumber.class] || [band integerValue] <= 0 ||
            [band integerValue] > 1024 || ![band isEqual:@([band integerValue])]) {
            return @{@"success": @NO, @"message": @"Lista de bandas inválida"};
        }
    }
    for (id mhz in targetFrequencies) {
        if (![mhz isKindOfClass:NSNumber.class] || [mhz integerValue] < 300 ||
            [mhz integerValue] > 100000 || ![mhz isEqual:@([mhz integerValue])]) {
            return @{@"success": @NO, @"message": @"Lista de frecuencias inválida"};
        }
    }
    if (![@[@"2G", @"3G", @"LTE", @"NR"] containsObject:targetRAT]) {
        return @{@"success": @NO, @"message": @"Tecnología de red no válida"};
    }
    if ([targetRAT isEqualToString:@"NR"] && BLDeviceIsKnownLTEOnly()) {
        return @{@"success": @NO, @"message": @"Este iPhone no dispone de módem 5G"};
    }
    NSString *targetMode = BLModeForTargetRAT(targetRAT);
    NSSet *allowedModes = [NSSet setWithArray:
        @[@"automatic", @"2g", @"3g", @"lte", @"5g-auto", @"5g-on", @"5g-only"]];
    if (!targetMode.length || ![allowedModes containsObject:restoreMode]) {
        return @{@"success": @NO,
                 @"message": @"No existe un modo de retorno seguro para iniciar el barrido"};
    }

    @synchronized(self) {
        if (self.running || self.recovering || BLScanJournalExists()) {
            return @{@"success": @NO,
                     @"message": @"Termina el barrido o la recuperación anterior antes de iniciar otro"};
        }
        self.running = YES;
        self.cancelRequested = NO;
    }

    NSDictionary *preflight = [manager queryCoreTelephonyForPassiveObservation];
    NSString *scanID = [[NSUUID UUID] UUIDString];
    NSString *subscription = preflight[@"error"] ? nil : BLScanSubscriptionUUID(preflight);
    NSDictionary *originalBandConfiguration = preflight[@"error"]
        ? nil : [manager bandConfigurationSnapshotFromQuery:preflight];
    NSArray<NSNumber *> *baselineSupported = preflight[@"error"]
        ? @[] : [manager supportedBandsForTargetRAT:targetRAT fromQuery:preflight];
    NSArray<NSNumber *> *baselineActive = preflight[@"error"]
        ? @[] : [manager activeBandsForTargetRAT:targetRAT fromQuery:preflight];
    // Preserve only candidates in BOTH the reference country and modem inventory.
    // Do not infer an available channel from a country allocation.
    NSMutableArray *eligible = [NSMutableArray array];
    BOOL modemInventoryAvailable = baselineSupported.count > 0;
    for (NSNumber *band in targetBands) {
        // 2G/3G firmware can omit the capability inventory entirely.
        // Preserve reference bands for observation in that case, but never
        // enable a band writer without a verified modem baseline below.
        BOOL keepForObservation = !modemInventoryAvailable &&
            ([@[@"2G", @"3G"] containsObject:targetRAT]);
        if (([baselineSupported containsObject:band] || keepForObservation) &&
            ![eligible containsObject:band]) [eligible addObject:band];
    }
    BOOL hasBandBaseline = eligible.count && originalBandConfiguration && baselineSupported.count &&
        baselineActive.count && baselineActive.count <= 128 &&
        [[NSSet setWithArray:baselineActive]
            isSubsetOfSet:[NSSet setWithArray:baselineSupported]];
    NSString *failure = nil;
    if (preflight[@"error"]) failure = @"No se pudo consultar la línea móvil antes del barrido";
    else if (!BLScanSingleActiveLine(preflight))
        failure = @"El barrido requiere una única línea móvil activa";
    else if (subscription.length != 64)
        failure = @"No se pudo identificar de forma estable la línea móvil";
    else if (([targetRAT isEqualToString:@"LTE"] || [targetRAT isEqualToString:@"NR"]) &&
             !eligible.count)
        failure = @"No hay bandas exactas del país compatibles con el inventario del módem";

    if (failure.length) {
        @synchronized(self) {
            self.running = NO;
            self.cancelRequested = NO;
        }
        return @{@"success": @NO, @"message": failure};
    }

    NSMutableDictionary *journal = [@{
        @"version": hasBandBaseline ? @3 : @2,
        @"scan_kind": hasBandBaseline ? @"technology_band_sweep" : @"technology_observation",
        @"original_mode": restoreMode,
        @"target_rat": targetRAT,
        @"country_iso": countryISO,
        @"target_bands": eligible,
        @"requested_target_bands": targetBands,
        @"target_frequencies_mhz": targetFrequencies,
        @"target_mode": targetMode,
        @"scan_id": scanID,
        @"subscription_hash": subscription,
        @"started": @([[NSDate date] timeIntervalSince1970])
    } mutableCopy];
    if (hasBandBaseline) {
        journal[@"original_band_config"] = originalBandConfiguration;
        journal[@"original_bands"] = baselineActive;
        journal[@"initial_supported_bands"] = baselineSupported;
        journal[@"phase"] = @"pre_rat_baseline_saved";
    }
    if (!BLScanWriteJournal(journal)) {
        @synchronized(self) { self.running = NO; }
        return @{@"success": @NO,
                 @"message": @"No se pudo guardar la recuperación antes de cambiar de red"};
    }

    @synchronized(self) {
        self.scanState = [@{
            @"success": @YES,
            @"running": @YES,
            @"read_only": @NO,
            @"band_read_only": @YES,
            @"phase": @"switching_rat",
            @"scan_id": scanID,
            @"target_rat": targetRAT,
            @"country_iso": countryISO,
            @"target_frequencies_mhz": targetFrequencies,
            @"rows": @[],
            @"total": @(BLTechnologyScanSamples),
            @"completed": @0,
            @"message": [NSString stringWithFormat:@"Cambiando temporalmente a %@…",
                BLDisplayTargetRAT(targetRAT)]
        } mutableCopy];
    }

    dispatch_async(self.scanQueue, ^{
        [self runTechnologyScanForTarget:targetRAT
                             restoreMode:restoreMode
                            subscription:subscription
                                 manager:manager];
    });
    return @{
        @"success": @YES,
        @"read_only": @NO,
        @"band_read_only": @YES,
        @"message": [NSString stringWithFormat:@"Barrido %@ iniciado", BLDisplayTargetRAT(targetRAT)]
    };
}

- (void)runTechnologyScanForTarget:(NSString *)targetRAT
                       restoreMode:(NSString *)restoreMode
                      subscription:(NSString *)subscription
                           manager:(BLTelephonyManager *)manager {
    NSMutableDictionary<NSNumber *, NSDictionary *> *byBand = [NSMutableDictionary dictionary];
    NSString *stopReason = nil;
    NSString *targetMode = BLModeForTargetRAT(targetRAT);
    BOOL targetObserved = NO;
    BOOL targetMeasurementSeen = NO;
    NSString *lastServingRAT = nil;
    NSDictionary *scanJournal = BLScanReadJournal();
    NSArray<NSNumber *> *allowedFrequencies =
        BLSortedBands(scanJournal[@"target_frequencies_mhz"]);
    NSTimeInterval deadline = [NSDate date].timeIntervalSince1970 + 360.0;
    @try {
        NSString *setError = nil;
        if (![manager setModeCodeSync:targetMode errorText:&setError]) {
            stopReason = setError ?: @"No se pudo cambiar temporalmente la tecnología";
        }

        // The private RAT getter is unreliable on iOS 18. Do not call a
        // successful setter a verified mode change: wait for an actual serving
        // cell of the requested technology before beginning the scan window.
        NSUInteger registrationWaits = [targetRAT isEqualToString:@"3G"] ? 24 : 12;
        for (NSUInteger wait = 0; !stopReason && wait < registrationWaits; wait++) {
            if ([NSDate date].timeIntervalSince1970 >= deadline) {
                stopReason = @"Tiempo máximo del barrido agotado";
                break;
            }
            if ([self shouldStop]) { stopReason = @"Barrido cancelado"; break; }
            NSDictionary *query = [manager queryCoreTelephonyForPassiveObservation];
            if (query[@"error"]) {
                if (wait + 1 < registrationWaits) { [NSThread sleepForTimeInterval:1.0]; continue; }
                stopReason = @"CoreTelephony no respondió al comprobar el cambio de tecnología";
                break;
            }
            NSString *fingerprint = BLScanSubscriptionUUID(query);
            if (fingerprint.length && ![fingerprint isEqualToString:subscription]) {
                stopReason = @"La línea de datos cambió durante el barrido";
                break;
            }
            NSArray *measurements = BLScanMeasurements(manager, query);
            for (NSDictionary *measurement in measurements) {
                NSString *measurementRAT = [measurement[@"rat"] isKindOfClass:NSString.class]
                    ? measurement[@"rat"] : nil;
                if ([measurementRAT isEqualToString:targetRAT]) targetMeasurementSeen = YES;
                if ([measurement[@"role"] isEqualToString:@"serving"] && measurementRAT.length)
                    lastServingRAT = measurementRAT;
                if ([measurement[@"rat"] isEqualToString:targetRAT] &&
                    [measurement[@"role"] isEqualToString:@"serving"]) {
                    targetObserved = YES;
                }
                BLMergeObservedBand(byBand, measurement, targetRAT, allowedFrequencies);
            }
            @synchronized(self) {
                self.scanState[@"rows"] = BLSortedObservedBands(byBand);
                self.scanState[@"message"] = [NSString stringWithFormat:
                    @"Esperando registro %@ · %lu/%lu s · %lu referencias del país observadas",
                    BLDisplayTargetRAT(targetRAT), (unsigned long)(wait + 1),
                    (unsigned long)registrationWaits, (unsigned long)byBand.count];
            }
            if (targetObserved) break;
            if (wait + 1 < registrationWaits) [NSThread sleepForTimeInterval:1.0];
        }
        if (!stopReason && !targetObserved) {
            if ([targetRAT isEqualToString:@"3G"]) {
                if (targetMeasurementSeen) {
                    stopReason = @"Se detectó información 3G, pero el módem no llegó a registrar una celda 3G servidora. Se restaura el modo anterior.";
                } else if (lastServingRAT.length) {
                    stopReason = [NSString stringWithFormat:
                        @"El cambio a 3G fue aceptado, pero no apareció ninguna celda 3G en %lu s (la última celda servidora seguía en %@). Es probable que no haya 3G disponible o activo en esta zona/operador. Se restaura el modo anterior.",
                        (unsigned long)registrationWaits, BLDisplayTargetRAT(lastServingRAT)];
                } else {
                    stopReason = [NSString stringWithFormat:
                        @"El cambio a 3G fue aceptado, pero no apareció ninguna celda 3G en %lu s. Puede no haber cobertura 3G o la red del operador puede tener 3G retirado. Se restaura el modo anterior.",
                        (unsigned long)registrationWaits];
                }
            } else {
                stopReason = [NSString stringWithFormat:
                    @"No se registró una celda %@ tras solicitar el cambio; se restaura el modo anterior",
                    BLDisplayTargetRAT(targetRAT)];
            }
        }

        // Preserve the first real serving measurements. When a band sweep is
        // available, scan the already-serving band first so the user gets at
        // least one useful reference reading before trying unavailable bands.
        NSDictionary<NSNumber *, NSDictionary *> *initialObservedBands = [byBand copy];

        // If CTBandInfo exposes a writable band inventory for this RAT, sweep
        // every safe modem-reported band one by one. This is the exhaustive
        // path the UI calls "todas las bandas": candidates come from the live
        // modem inventory, never from a hard-coded country list.
        NSDictionary *baselineJournal = BLScanReadJournal();
        NSArray<NSNumber *> *supported = BLSortedBands(baselineJournal[@"initial_supported_bands"]);
        NSArray<NSNumber *> *allowed = BLSortedBands(baselineJournal[@"target_bands"]);
        NSArray<NSNumber *> *originalBands = BLSortedBands(baselineJournal[@"original_bands"]);
        NSDictionary *originalBandConfiguration =
            [baselineJournal[@"original_band_config"] isKindOfClass:NSDictionary.class]
                ? baselineJournal[@"original_band_config"] : nil;
        NSMutableArray<NSNumber *> *candidates = [NSMutableArray array];
        for (NSNumber *band in BLSortedBands(initialObservedBands.allKeys)) {
            NSDictionary *observed = initialObservedBands[band];
            if (![supported containsObject:band] || ![allowed containsObject:band] ||
                ![observed[@"role"] isEqualToString:@"serving"] ||
                !BLScanHasAnyMetric(observed)) continue;
            if ([targetRAT isEqualToString:@"LTE"] &&
                [[BLGDuplexForBand(band) uppercaseString] isEqualToString:@"SDL"]) continue;
            if ([targetRAT isEqualToString:@"NR"] &&
                [[BLGNRDuplexForBand(band) uppercaseString] hasPrefix:@"SDL"]) continue;
            [candidates addObject:band];
        }
        for (NSNumber *band in supported) {
            if (![allowed containsObject:band]) continue;
            if (![band isKindOfClass:NSNumber.class] || band.integerValue <= 0 || band.integerValue > 1024) continue;
            if ([targetRAT isEqualToString:@"LTE"] &&
                [[BLGDuplexForBand(band) uppercaseString] isEqualToString:@"SDL"]) continue;
            if ([targetRAT isEqualToString:@"NR"] &&
                [[BLGNRDuplexForBand(band) uppercaseString] hasPrefix:@"SDL"]) continue;
            if ([candidates containsObject:band]) continue;
            [candidates addObject:band];
        }
        BOOL exhaustive = !stopReason && targetObserved &&
            [baselineJournal[@"version"] isEqual:@3] &&
            [baselineJournal[@"scan_kind"] isEqualToString:@"technology_band_sweep"] &&
            originalBandConfiguration && candidates.count && candidates.count <= 64 &&
            originalBands.count && originalBands.count <= 128 &&
            [[NSSet setWithArray:originalBands] isSubsetOfSet:[NSSet setWithArray:supported]];

        if (exhaustive) {
            NSDictionary *saved = BLScanReadJournal();
            NSMutableDictionary *bandJournal = [saved mutableCopy];
            bandJournal[@"phase"] = @"band_sweep_ready";
            if (!BLScanWriteJournal(bandJournal)) {
                stopReason = @"No se pudo confirmar el journal antes del barrido de bandas";
            } else {
                @synchronized(self) {
                    self.scanState[@"band_read_only"] = @NO;
                    self.scanState[@"total"] = @(candidates.count);
                    self.scanState[@"completed"] = @0;
                    self.scanState[@"message"] = [NSString stringWithFormat:
                        @"%@ · %lu bandas del módem preparadas",
                        BLDisplayTargetRAT(targetRAT), (unsigned long)candidates.count];
                }
            }
        }

        if (exhaustive && !stopReason) {
            // Discard the initial serving/neighbor snapshot: each result below
            // must correspond to a band that was explicitly selected and read
            // back as active before its metrics are accepted.
            [byBand removeAllObjects];
            for (NSUInteger index = 0; index < candidates.count; index++) {
                NSNumber *band = candidates[index];
                if ([NSDate date].timeIntervalSince1970 >= deadline) {
                    stopReason = @"Tiempo máximo del barrido agotado; restaurando";
                    break;
                }
                if ([self shouldStop]) { stopReason = @"Barrido cancelado"; break; }

                NSDictionary *saved = BLScanReadJournal();
                if (!saved) { stopReason = @"Journal de recuperación no disponible"; break; }
                NSMutableDictionary *step = [saved mutableCopy];
                step[@"phase"] = @"band_step_prepared";
                step[@"target_band"] = band;
                step[@"index"] = @(index);
                if (!BLScanWriteJournal(step)) {
                    stopReason = @"No se pudo actualizar el journal antes de cambiar de banda";
                    break;
                }

                NSMutableDictionary *row = [@{
                    @"rat": targetRAT,
                    @"band": band,
                    @"role": @"serving",
                    @"source": @"band_sweep",
                    @"status": @"no_signal"
                } mutableCopy];
                @synchronized(self) {
                    self.scanState[@"message"] = [NSString stringWithFormat:
                        @"%@ %@%@ · %lu/%lu",
                        BLDisplayTargetRAT(targetRAT),
                        [targetRAT isEqualToString:@"NR"] ? @"n" : @"B", band,
                        (unsigned long)(index + 1), (unsigned long)candidates.count];
                }

                NSDictionary *writeQuery = [manager queryCoreTelephonyForPassiveObservation];
                NSString *fingerprint = writeQuery[@"error"] ? nil : BLScanSubscriptionUUID(writeQuery);
                BOOL conflictingServingRAT = !writeQuery[@"error"] &&
                    BLScanHasConflictingServingRAT(manager, writeQuery, targetRAT);
                if (writeQuery[@"error"] || ![fingerprint isEqualToString:subscription] ||
                    !BLScanSingleActiveLine(writeQuery) || conflictingServingRAT) {
                    row[@"status"] = @"query_failed";
                    byBand[band] = row;
                    stopReason = @"La línea cambió o el módem cayó a otra tecnología; restaurando";
                    break;
                }
                NSString *writeError = nil;
                if (![manager writeBands:@[band] forTargetRAT:targetRAT
                              usingQuery:writeQuery errorText:&writeError]) {
                    row[@"status"] = @"write_failed";
                    byBand[band] = row;
                    stopReason = writeError ?: @"La escritura de banda falló; restaurando";
                    break;
                }

                BOOL readbackMatched = NO;
                for (NSUInteger sample = 0; sample < 8; sample++) {
                    if ([NSDate date].timeIntervalSince1970 >= deadline) {
                        stopReason = @"Tiempo máximo del barrido agotado; restaurando";
                        break;
                    }
                    if ([self shouldStop]) { stopReason = @"Barrido cancelado"; break; }
                    [NSThread sleepForTimeInterval:1.0];
                    NSDictionary *readback = [manager queryCoreTelephonyForPassiveObservation];
                    if (readback[@"error"]) continue;
                    NSString *readFingerprint = BLScanSubscriptionUUID(readback);
                    if (readFingerprint.length && ![readFingerprint isEqualToString:subscription]) {
                        stopReason = @"La línea de datos cambió durante el barrido";
                        break;
                    }
                    if (!BLScanMatches([manager activeBandsForTargetRAT:targetRAT fromQuery:readback], @[band])) {
                        continue;
                    }
                    readbackMatched = YES;
                    for (NSDictionary *measurement in BLScanMeasurements(manager, readback)) {
                        if (![measurement[@"rat"] isEqualToString:targetRAT] ||
                            ![measurement[@"role"] isEqualToString:@"serving"]) continue;
                        NSNumber *reportedBand = [measurement[@"band"] isKindOfClass:NSNumber.class]
                            ? measurement[@"band"] : nil;
                        // If CTBandInfo positively read back exactly one active
                        // band, a same-RAT serving metric without a band field can
                        // safely be attributed to that selected band. A reported
                        // but different band is never accepted.
                        if (reportedBand && ![reportedBand isEqual:band]) continue;
                        row[@"role"] = @"serving";
                        row[@"source"] = measurement[@"source"] ?: @"cell_info";
                        if (!reportedBand) row[@"band_inferred_from_active_mask"] = @YES;
                        row[@"status"] = BLScanHasAnyMetric(measurement) ? @"measured" : @"detected";
                        for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
                            id value = measurement[metric];
                            if ([value isKindOfClass:NSNumber.class]) row[metric] = value;
                        }
                        for (NSString *field in @[@"cell_id", @"physical_cell_id", @"psc", @"tac", @"lac", @"channel"]) {
                            if ([measurement[field] isKindOfClass:NSNumber.class]) row[field] = measurement[field];
                        }
                        if ([row[@"status"] isEqualToString:@"measured"]) break;
                    }
                    if ([row[@"status"] isEqualToString:@"measured"]) break;
                }
                if (readbackMatched && ![row[@"status"] isEqualToString:@"measured"]) {
                    NSDictionary *seed = initialObservedBands[band];
                    if ([seed[@"rat"] isEqualToString:targetRAT] &&
                        [seed[@"role"] isEqualToString:@"serving"] &&
                        BLScanHasAnyMetric(seed)) {
                        row[@"source"] = seed[@"source"] ?: @"pre_sweep";
                        row[@"status"] = @"measured_pre_sweep";
                        row[@"pre_sweep"] = @YES;
                        for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
                            id value = seed[metric];
                            if ([value isKindOfClass:NSNumber.class]) row[metric] = value;
                        }
                        for (NSString *field in @[@"cell_id", @"physical_cell_id", @"psc", @"tac", @"lac", @"channel"]) {
                            if ([seed[field] isKindOfClass:NSNumber.class]) row[field] = seed[field];
                        }
                    }
                }
                if (!readbackMatched && !stopReason) {
                    row[@"status"] = @"readback_unverified";
                    stopReason = @"La máscara de banda no pudo verificarse; restaurando";
                }
                byBand[band] = row;
                @synchronized(self) {
                    self.scanState[@"rows"] = BLSortedObservedBands(byBand);
                    self.scanState[@"completed"] = @(index + 1);
                }
                if (stopReason) break;
            }
        } else if (!stopReason && targetObserved) {
            // Some modem/OS combinations expose cell measurements but no
            // writable 2G/3G band dictionary. Keep the directed RAT scan useful
            // by collecting serving + neighbor bands, but label it non-exhaustive.
            @synchronized(self) {
                self.scanState[@"band_read_only"] = @YES;
                self.scanState[@"message"] = [NSString stringWithFormat:
                    @"%@ · el módem no expone bloqueo por banda; buscando celdas observables",
                    BLDisplayTargetRAT(targetRAT)];
            }
        }

        for (NSUInteger sample = 0;
             !stopReason && targetObserved && !exhaustive && sample < BLTechnologyScanSamples;
             sample++) {
            @autoreleasepool {
                if ([NSDate date].timeIntervalSince1970 >= deadline) {
                    stopReason = @"Tiempo máximo del barrido agotado; restaurando";
                    break;
                }
                if ([self shouldStop]) { stopReason = @"Barrido cancelado"; break; }
                NSDictionary *query = [manager queryCoreTelephonyForPassiveObservation];
                if (query[@"error"]) {
                    stopReason = @"CoreTelephony dejó de responder; restaurando la red anterior";
                    break;
                }
                NSString *fingerprint = BLScanSubscriptionUUID(query);
                if (fingerprint.length && ![fingerprint isEqualToString:subscription]) {
                    stopReason = @"La línea de datos cambió; restaurando la red anterior";
                    break;
                }
                BOOL servingTarget = NO;
                for (NSDictionary *measurement in BLScanMeasurements(manager, query)) {
                    if ([measurement[@"rat"] isEqualToString:targetRAT] &&
                        [measurement[@"role"] isEqualToString:@"serving"]) servingTarget = YES;
                    BLMergeObservedBand(byBand, measurement, targetRAT, allowedFrequencies);
                }
                if (!servingTarget && sample >= 2) {
                    stopReason = @"La tecnología solicitada dejó de estar registrada; restaurando";
                }
                NSArray *rows = BLSortedObservedBands(byBand);
                @synchronized(self) {
                    self.scanState[@"rows"] = rows;
                    self.scanState[@"completed"] = @(sample + 1);
                    self.scanState[@"message"] = [NSString stringWithFormat:
                        @"%@ · muestra %lu/%lu · %lu referencias del país observadas",
                        BLDisplayTargetRAT(targetRAT),
                        (unsigned long)(sample + 1),
                        (unsigned long)BLTechnologyScanSamples,
                        (unsigned long)rows.count];
                }
                if (stopReason) break;
                if (sample + 1 < BLTechnologyScanSamples) [NSThread sleepForTimeInterval:1.5];
            }
        }
    } @catch (NSException *exception) {
        stopReason = exception.reason ?: @"Error durante el barrido";
    } @finally {
        NSDictionary *saved = BLScanReadJournal();
        if (saved) {
            NSMutableDictionary *restoring = [saved mutableCopy];
            restoring[@"phase"] = @"restoring";
            (void)BLScanWriteJournal(restoring);
        }
        [self setPhase:@"restoring" message:[NSString stringWithFormat:
            @"Restaurando modo %@…", restoreMode]];
        NSString *recoveryFailure = nil;
        BOOL restored = [self restoreJournalWithManager:manager failure:&recoveryFailure];
        NSArray *rows = BLSortedObservedBands(byBand);
        @synchronized(self) {
            self.running = NO;
            self.cancelRequested = NO;
            self.scanState[@"running"] = @NO;
            self.scanState[@"rows"] = rows;
            self.scanState[@"success"] = @(restored && targetObserved);
            self.scanState[@"phase"] = restored ? @"complete" : @"recovery_required";
            self.scanState[@"recovery_required"] = @(!restored);
            self.scanState[@"message"] = restored
                ? (stopReason ?: [NSString stringWithFormat:
                    @"Barrido %@ completado · %lu bandas observadas · modo anterior solicitado de nuevo",
                    BLDisplayTargetRAT(targetRAT), (unsigned long)rows.count])
                : (recoveryFailure ?: @"No se pudo volver a solicitar el modo anterior. Usa Recuperar antes de otro cambio.");
        }
    }
}

- (NSDictionary *)cancel {
    @synchronized(self) {
        if (self.running) {
            self.cancelRequested = YES;
            self.scanState[@"message"] = [self.scanState[@"read_only"] boolValue]
                ? @"Stopping passive observation; no band restoration needed"
                : @"Cancellation requested; restoring original bands";
            return @{@"success": @YES, @"message": @"Cancel requested", @"running": @YES};
        }
    }
    return @{@"success": @NO, @"message": @"No scan is active; use Recover if recovery is pending"};
}

- (NSDictionary *)requestRecoveryWithManager:(BLTelephonyManager *)manager {
    @synchronized(self) {
        if (self.running) return @{@"success": @NO, @"message": @"Cancel the scan before requesting recovery"};
        if (self.recovering) return @{@"success": @YES, @"message": @"Recovery already in progress"};
        if (!BLScanJournalExists()) return @{@"success": @YES, @"message": @"No recovery is required"};
        self.recovering = YES; // Prevent scan_start while journal may be cleared.
    }
    dispatch_async(self.scanQueue, ^{
        @try { [self recoverIfNeededWithManager:manager]; }
        @finally { @synchronized(self) { self.recovering = NO; } }
    });
    return @{@"success": @YES, @"message": @"Recovery requested"};
}

- (void)setPhase:(NSString *)phase message:(NSString *)message {
    @synchronized(self) {
        self.scanState[@"phase"] = phase ?: @"unknown";
        self.scanState[@"message"] = message ?: @"";
    }
}

- (BOOL)shouldStop {
    @synchronized(self) { return self.cancelRequested; }
}

- (BOOL)restoreJournalWithManager:(BLTelephonyManager *)manager
                           failure:(NSString **)failureReason {
    if (failureReason) *failureReason = nil;
    NSDictionary *saved = BLScanReadJournal();
    if (!saved) {
        if (failureReason) *failureReason = @"No se encontró el journal de recuperación";
        return NO;
    }
    if (([saved[@"version"] isEqual:@2] &&
         [saved[@"scan_kind"] isEqualToString:@"technology_observation"]) ||
        ([saved[@"version"] isEqual:@3] &&
         [saved[@"scan_kind"] isEqualToString:@"technology_band_sweep"])) {
        NSString *subscription = [saved[@"subscription_hash"] isKindOfClass:NSString.class]
            ? saved[@"subscription_hash"] : nil;
        NSString *restoreMode = [saved[@"original_mode"] isKindOfClass:NSString.class]
            ? saved[@"original_mode"] : nil;
        NSString *targetRAT = [saved[@"target_rat"] isKindOfClass:NSString.class]
            ? saved[@"target_rat"] : nil;
        NSSet *allowedModes = [NSSet setWithArray:
            @[@"automatic", @"2g", @"3g", @"lte", @"5g-auto", @"5g-on", @"5g-only"]];
        if (subscription.length != 64 || ![allowedModes containsObject:restoreMode]) {
            if (failureReason) *failureReason = @"El punto de retorno guardado no es válido";
            return NO;
        }

        NSDictionary *identity = nil;
        for (NSUInteger attempt = 0; attempt < 5; attempt++) {
            identity = [manager queryCoreTelephonyForPassiveObservation];
            NSString *fingerprint = identity[@"error"] ? nil : BLScanSubscriptionUUID(identity);
            if (fingerprint.length) break;
            if (attempt < 4) [NSThread sleepForTimeInterval:1.0];
        }
        if (identity[@"error"] || !BLScanRecoveryIdentityCompatible(identity, subscription)) {
            if (failureReason) *failureReason = @"No se pudo confirmar la misma línea móvil durante la recuperación";
            return NO;
        }
        NSDictionary *identityLine = BLRHActiveLineCheck(identity);
        NSDictionary *identityRAT = [identity[@"ratRaw"] isKindOfClass:NSDictionary.class] ? identity[@"ratRaw"] : @{};
        NSLog(@"[BandLock recovery] identity accepted registered_rats=%lu active_contexts=%@ strict=%d",
              (unsigned long)identityRAT.count,
              identityLine[@"active_context_count"] ?: NSNull.null,
              [identityLine[@"verified"] boolValue]);

        BOOL bandsRestored = YES;
        BOOL bandWriteAccepted = YES;
        NSString *bandError = nil;
        NSArray<NSNumber *> *originalBands = @[];
        if ([saved[@"version"] isEqual:@3]) {
            NSDictionary *originalConfiguration =
                [saved[@"original_band_config"] isKindOfClass:NSDictionary.class]
                    ? saved[@"original_band_config"] : nil;
            originalBands = BLSortedBands(saved[@"original_bands"]);
            if (!targetRAT.length || !originalConfiguration || !originalBands.count) {
                if (failureReason) *failureReason = @"La configuración original de bandas no es recuperable";
                return NO;
            }
            bandsRestored = BLScanTargetBandsMatch(manager, identity, targetRAT, originalBands) ||
                BLScanBandConfigurationMatches(manager, identity, originalConfiguration);
            if (!bandsRestored) {
                // Restore only the RAT modified by this scan. A full saved
                // CTBandInfo snapshot can overwrite unrelated live masks.
                NSLog(@"[BandLock recovery] target=%@ restoring original mask=%@", targetRAT, originalBands);
                bandWriteAccepted = [manager writeBands:originalBands
                                           forTargetRAT:targetRAT
                                             usingQuery:identity
                                              errorText:&bandError];
                NSLog(@"[BandLock recovery] band setter accepted=%d error=%@", bandWriteAccepted, bandError);
                // CTBandInfo can take several seconds to converge. Verify
                // the group this scan actually modified, but do not abort
                // before requesting the saved network mode: that old ordering
                // could strand a 3G scan on B1/B2 forever.
                for (NSUInteger check = 0; bandWriteAccepted && !bandsRestored && check < 6; check++) {
                    [NSThread sleepForTimeInterval:1.0];
                    NSDictionary *readback = [manager queryCoreTelephonyForPassiveObservation];
                    if (readback[@"error"]) continue;
                    if (!BLScanRecoveryIdentityCompatible(readback, subscription)) {
                        if (failureReason) *failureReason = @"La línea móvil cambió durante la recuperación";
                        return NO;
                    }
                    bandsRestored = BLScanTargetBandsMatch(manager, readback, targetRAT, originalBands) ||
                        BLScanBandConfigurationMatches(manager, readback, originalConfiguration);
                }
            }
        }

        NSString *restoreError = nil;
        NSLog(@"[BandLock recovery] request original mode=%@ band_match=%d", restoreMode, bandsRestored);
        if (![manager setModeCodeSync:restoreMode errorText:&restoreError]) {
            NSLog(@"[BandLock recovery] restore RAT failed=%@ journal kept", restoreError);
            if (failureReason) *failureReason = [NSString stringWithFormat:
                @"No se pudo solicitar el modo anterior (%@). El journal se conserva para Recuperar.",
                restoreError ?: @"error de CommCenter"];
            return NO;
        }
        NSLog(@"[BandLock recovery] restore RAT accepted; waiting for service and band readback");
        NSString *expectedRAT = BLTargetRATForMode(restoreMode);
        BOOL serviceRestored = NO;
        // A 3G-only scan can leave the modem fully detached on carriers where
        // 3G is unavailable. Allow the saved Auto/LTE request to execute first,
        // then give registration a bounded 60 s convergence window. Physical
        // rhui13 testing showed registration can return after the old 30 s
        // window even though the restored mode/bands are already correct.
        for (NSUInteger check = 0; check < 60; check++) {
            [NSThread sleepForTimeInterval:1.0];
            NSDictionary *readback = [manager queryCoreTelephonyForPassiveObservation];
            if (readback[@"error"]) continue;
            if (!BLScanRecoveryIdentityCompatible(readback, subscription)) {
                if (failureReason) *failureReason = @"La línea móvil cambió durante la recuperación";
                return NO;
            }
            if ([saved[@"version"] isEqual:@3] && !bandsRestored) {
                NSDictionary *originalConfiguration =
                    [saved[@"original_band_config"] isKindOfClass:NSDictionary.class]
                        ? saved[@"original_band_config"] : nil;
                bandsRestored = BLScanTargetBandsMatch(manager, readback, targetRAT, originalBands) ||
                    (originalConfiguration && BLScanBandConfigurationMatches(manager, readback, originalConfiguration));
            }
            NSArray *measurements = BLScanMeasurements(manager, readback);
            if (expectedRAT.length) {
                if (BLScanHasServingRAT(manager, readback, expectedRAT)) {
                    serviceRestored = YES;
                }
            } else {
                for (NSDictionary *measurement in measurements) {
                    if ([measurement[@"role"] isEqualToString:@"serving"] &&
                        [measurement[@"rat"] isKindOfClass:NSString.class]) {
                        serviceRestored = YES;
                        break;
                    }
                }
            }
            if (serviceRestored && bandsRestored) break;
        }
        NSLog(@"[BandLock recovery] convergence service=%d bands=%d band_write=%d", serviceRestored, bandsRestored, bandWriteAccepted);
        if ([saved[@"version"] isEqual:@3] && !bandsRestored) {
            if (failureReason) {
                *failureReason = bandWriteAccepted
                    ? @"El modo anterior volvió, pero la máscara original de bandas aún no pudo verificarse. Usa Recuperar de nuevo."
                    : [NSString stringWithFormat:
                        @"No se pudo restaurar la máscara original de bandas (%@). El modo anterior ya fue solicitado; usa Recuperar de nuevo.",
                        bandError ?: @"error de CoreTelephony"];
            }
            return NO;
        }
        if (!serviceRestored) {
            if (failureReason) *failureReason = @"El modo anterior fue solicitado, pero el servicio móvil no volvió a registrarse dentro de 60 s. Usa Recuperar de nuevo.";
            return NO;
        }
        // The private iOS18 selection getter may still be Unknown. Do not call
        // the selection itself verified, but require cellular registration to
        // converge after restoring the saved BandLock intent before clearing
        // the crash-recovery journal.
        if (!BLScanClearJournal()) {
            NSLog(@"[BandLock recovery] journal clear failed");
            if (failureReason) *failureReason = @"La restauración se verificó, pero no se pudo cerrar el journal de seguridad";
            return NO;
        }
        NSLog(@"[BandLock recovery] journal cleared after positive verification");
        return YES;
    }
    if (![saved[@"version"] isEqual:@1]) {
        if (failureReason) *failureReason = @"Versión de journal de recuperación no compatible";
        return NO;
    }
    NSArray *original = BLSortedBands(saved[@"original_lte"]);
    NSString *subscription = saved[@"subscription_hash"];
    if (!original.count || original.count > 128 || ![subscription isKindOfClass:NSString.class] || subscription.length != 64) return NO;
    for (NSNumber *band in original) {
        if (![band isKindOfClass:NSNumber.class] || band.integerValue <= 0 ||
            band.integerValue > 255) return NO;
    }
    NSArray *initiallySupported = BLSortedBands(saved[@"initial_supported_lte"]);
    if (!initiallySupported.count ||
        ![[NSSet setWithArray:original] isSubsetOfSet:[NSSet setWithArray:initiallySupported]]) return NO;
    // Production BandLock documents slow CommCenter convergence: never
    // rewrite every second. Query/read back for up to 10s per attempt and
    // issue at most one retry.
    for (NSInteger attempt = 0; attempt < 2; attempt++) {
        @autoreleasepool {
            NSDictionary *query = nil;
            // CommCenter often starts after the launch agent. Allow a
            // bounded warm-up instead of abandoning crash recovery at boot.
            for (NSInteger ready = 0; ready < 5; ready++) {
                query = [manager queryCoreTelephony];
                if (!query[@"error"]) break;
                [NSThread sleepForTimeInterval:2.0];
            }
            if (!query || query[@"error"]) return NO;
            if (![BLScanSubscriptionUUID(query) isEqualToString:subscription]) return NO;
            // Do NOT reject restore based on post-scan "supported". Some
            // modems temporarily report only the narrowed active subset,
            // which is exactly when the original band list is most needed.
            if (BLScanMatches([manager activeLTEFromQuery:query], original)) {
                return BLScanClearJournal();
            }
            NSString *errorText = nil;
            if (![manager writeLTEBands:original usingQuery:query errorText:&errorText]) return NO;
            for (NSInteger check = 0; check < 10; check++) {
                [NSThread sleepForTimeInterval:1.0];
                NSDictionary *result = [manager queryCoreTelephony];
                if (result[@"error"]) continue;
                if (![BLScanSubscriptionUUID(result) isEqualToString:subscription]) return NO;
                if (BLScanMatches([manager activeLTEFromQuery:result], original)) {
                    return BLScanClearJournal();
                }
            }
        }
    }
    NSDictionary *last = [manager queryCoreTelephony];
    return !last[@"error"] && [BLScanSubscriptionUUID(last) isEqualToString:subscription] &&
           BLScanMatches([manager activeLTEFromQuery:last], original) && BLScanClearJournal();
}

- (void)recoverIfNeededWithManager:(BLTelephonyManager *)manager {
    if (![self hasPendingRecovery] || [self isRunning]) return;
    NSDictionary *pending = BLScanReadJournal();
    NSString *scanID = [pending[@"scan_id"] isKindOfClass:NSString.class] ? pending[@"scan_id"] : nil;
    if (scanID.length) @synchronized(self) { self.scanState[@"scan_id"] = scanID; }
    [self setPhase:@"restoring" message:@"Recovering bands left by an interrupted scan"];
    NSString *recoveryFailure = nil;
    BOOL restored = [self restoreJournalWithManager:manager failure:&recoveryFailure];
    [self setPhase:(restored ? @"restored" : @"recovery_required")
           message:(restored ? @"Original bands restored" :
                    (recoveryFailure ?: @"Could not verify restoration; retry recovery before changing bands"))];
    @synchronized(self) {
        self.scanState[@"success"] = @(restored);
        self.scanState[@"running"] = @NO;
        self.scanState[@"recovery_required"] = @(!restored);
        if (restored) self.automaticRecoveryRetries = 0;
        else self.automaticRecoveryRetries++;
    }
    if (!restored && self.automaticRecoveryRetries <= 4) {
        NSUInteger attempt = self.automaticRecoveryRetries;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((15 + attempt * 10) * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            if ([self hasPendingRecovery] && ![self isRunning]) {
                (void)[self requestRecoveryWithManager:manager];
            }
        });
    }
}

- (NSDictionary *)startWithManager:(BLTelephonyManager *)manager {
    @try {
        return [self startPreparedWithManager:manager];
    } @catch (NSException *exception) {
        BOOL dirty = BLScanJournalExists();
        @synchronized(self) {
            self.running = NO;
            self.cancelRequested = NO;
        }
        if (dirty) (void)[self requestRecoveryWithManager:manager];
        return @{@"success": @NO, @"message": exception.reason ?: @"CoreTelephony preflight failed"};
    }
}

- (NSDictionary *)startPreparedWithManager:(BLTelephonyManager *)manager {
    @synchronized(self) {
        if (self.running) return @{@"success": @NO, @"message": @"Scan already running"};
        if (self.recovering) return @{@"success": @NO, @"message": @"Original band recovery is still running"};
        if (BLScanJournalExists()) return @{@"success": @NO, @"message": @"Previous scan requires recovery first"};
        self.running = YES; // Lock out all modem writes while preparing.
        self.cancelRequested = NO;
    }
    NSDictionary *query = [manager queryCoreTelephony];
    NSString *subscription = BLScanSubscriptionUUID(query);
    NSDictionary *snapshot = query[@"error"] ? nil : [manager snapshotFromQuery:query];
    NSArray *original = [manager activeLTEFromQuery:query] ?: @[];
    NSArray *supported = snapshot[@"supported"] ?: @[];
    NSString *mode = snapshot[@"mode_code"] ?: @"unknown";
    NSArray *preflight = query[@"error"] ? @[] : BLScanMeasurements(manager, query);
    BOOL servingPower = NO;
    NSNumber *servingRSRP = nil;
    NSNumber *servingBand = nil;
    for (NSDictionary *row in preflight) {
        if ([row[@"role"] isEqual:@"serving"] &&
            [row[@"rat"] isEqual:@"LTE"] &&
            [row[@"source"] isEqual:@"typed"] &&
            [row[@"rsrp"] isKindOfClass:NSNumber.class]) {
            servingPower = YES;
            servingBand = row[@"band"];
            servingRSRP = row[@"rsrp"];
            break;
        }
    }
    NSMutableArray *candidates = [NSMutableArray array];
    if (servingBand && [supported containsObject:servingBand] && ![[BLGDuplexForBand(servingBand) uppercaseString] isEqualToString:@"SDL"]) {
        [candidates addObject:servingBand];
    }
    for (NSNumber *band in supported) {
        if (![band isKindOfClass:NSNumber.class] || band.integerValue <= 0 || band.integerValue > 1024) continue;
        if ([[BLGDuplexForBand(band) uppercaseString] isEqualToString:@"SDL"]) continue;
        if ([candidates containsObject:band]) continue;
        [candidates addObject:band];
        if (candidates.count >= BLScanMaxBands) break;
    }
    NSString *failure = nil;
    if (query[@"error"]) failure = [query[@"error"] description];
    else if (!BLScanSingleActiveLine(query)) failure = @"Experimental scan requires exactly one active cellular service. Disable any second line.";
    else if (!subscription.length) failure = @"The modem does not expose a stable subscription UUID. Active scanning is disabled";
    else if (!original.count || !supported.count) failure = @"LTE band baseline is unavailable";
    else if (original.count > 128 || supported.count > 128)
        failure = @"The LTE band inventory exceeds the safe diagnostic bound";
    else if (![mode isEqualToString:@"lte"]) failure = @"Select LTE / 4G only before the experimental scan (5G and Auto are not scanned)";
    else if (!servingPower) failure = @"No real serving LTE power reading. Run the read-only probe first";
    else if (![servingRSRP isKindOfClass:NSNumber.class] || servingRSRP.doubleValue < -115.0)
        failure = @"Serving RSRP below -115 dBm or missing. Move to stronger coverage before this experimental scan";
    else if (![[NSSet setWithArray:original] isSubsetOfSet:[NSSet setWithArray:supported]])
        failure = @"Original LTE bands are not verified as a subset of modem supported bands";
    if (!failure) {
        for (NSNumber *band in original) {
            if (![band isKindOfClass:NSNumber.class] ||
                band.integerValue < 1 || band.integerValue > 255) {
                failure = @"Original band list is not safely recoverable";
                break;
            }
        }
    }
    if (!failure && (!servingBand || ![candidates.firstObject isEqual:servingBand]))
        failure = @"Serving LTE band is not identified; active scan disabled";
    if (!failure && candidates.count < 2)
        failure = @"Need serving band and one other LTE band for the two-band test";
    // Require two consistent fresh samples before deliberately changing
    // service. This rejects a stale legacy B3 field or a line handover.
    if (!failure) {
        [NSThread sleepForTimeInterval:1.0];
        NSDictionary *fresh = [manager queryCoreTelephony];
        BOOL matched = !fresh[@"error"] &&
                       [BLScanSubscriptionUUID(fresh) isEqualToString:subscription] &&
                       BLScanSingleActiveLine(fresh) &&
                       [[[manager snapshotFromQuery:fresh] objectForKey:@"mode_code"] isEqualToString:@"lte"] &&
                       BLScanMatches([manager activeLTEFromQuery:fresh], original);
        BOOL confirmed = NO;
        for (NSDictionary *row in BLScanMeasurements(manager, fresh)) {
            if ([row[@"role"] isEqual:@"serving"] &&
                [row[@"rat"] isEqual:@"LTE"] &&
                [row[@"source"] isEqual:@"typed"] &&
                [row[@"band"] isEqual:servingBand] &&
                [row[@"rsrp"] isKindOfClass:NSNumber.class] &&
                [row[@"rsrp"] doubleValue] >= -115.0) {
                confirmed = YES;
                break;
            }
        }
        if (!matched || !confirmed) failure = @"Serving LTE band, power, active bands or subscription changed. Scan not started";
    }
    if (failure.length) {
        @synchronized(self) { self.running = NO; }
        return @{@"success": @NO, @"message": failure};
    }
    NSDictionary *journal = @{@"version": @1, @"original_lte": original, @"initial_supported_lte": supported,
                              @"original_nr": snapshot[@"active_nr"] ?: @[],
                              @"subscription_hash": subscription,
                              @"original_mode": mode, @"candidates": candidates, @"started": @([[NSDate date] timeIntervalSince1970])};
    if (!BLScanWriteJournal(journal)) {
        @synchronized(self) { self.running = NO; }
        return @{@"success": @NO, @"message": @"Cannot durably save original bands. No modem changes made"};
    }
    @synchronized(self) {
        self.scanState = [@{@"success": @YES, @"running": @YES,
                            @"phase": @"scanning", @"rows": @[], @"total": @(candidates.count),
                            @"completed": @0, @"message": @"Starting LTE band scan"} mutableCopy];
    }
    NSUInteger generation = 0;
    @synchronized(self) { generation = ++self.generation; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        // Last resort for an undocumented CoreTelephony synchronous call
        // blocking the scanner forever: force launchd to restart this daemon.
        // A write-ahead journal was synced BEFORE the first modem mutation.
        [NSThread sleepForTimeInterval:115.0];
        @synchronized(self) {
            if (self.running && self.generation == generation && BLScanJournalExists()) {
                _exit(75);
            }
        }
    });
    dispatch_async(self.scanQueue, ^{ [self runBands:candidates original:original mode:mode
                                             subscription:subscription manager:manager]; });
    return @{@"success": @YES, @"message": @"Experimental LTE band scan started", @"total": @(candidates.count)};
}

- (void)runBands:(NSArray<NSNumber *> *)bands original:(NSArray<NSNumber *> *)original
           mode:(NSString *)mode subscription:(NSString *)subscription manager:(BLTelephonyManager *)manager {
    NSMutableArray *rows = [NSMutableArray array];
    NSString *stopReason = nil;
    NSTimeInterval totalDeadline = NSDate.date.timeIntervalSince1970 + 70.0;
    @try {
        for (NSNumber *band in bands) {
            @autoreleasepool {
                if ([self shouldStop]) { stopReason = @"Cancelled"; break; }
                if (NSDate.date.timeIntervalSince1970 >= totalDeadline) {
                    stopReason = @"Overall scan timeout";
                    break;
                }
                NSDictionary *saved = BLScanReadJournal();
                if (!saved) { stopReason = @"Recovery journal unreadable"; break; }
                NSMutableDictionary *step = [saved mutableCopy];
                step[@"phase"] = @"step_prepared";
                step[@"target"] = band;
                step[@"index"] = @(rows.count);
                if (!BLScanWriteJournal(step)) {
                    stopReason = @"Could not update recovery journal";
                    break;
                }
                [self setPhase:@"scanning" message:[NSString stringWithFormat:@"Measuring LTE B%@", band]];
                NSMutableDictionary *row = [@{@"band": band, @"rat": @"LTE", @"status": @"no_measurement"} mutableCopy];
                NSDictionary *query = [manager queryCoreTelephony];
                NSString *errorText = nil;
                query = BLRHWritableQuery(manager, query, subscription, mode, &stopReason);
                if (!query) {
                    row[@"status"] = [stopReason containsString:@"explicitly"]
                        ? @"mode_changed" : @"mode_unverified";
                } else if ([self shouldStop]) {
                    stopReason = @"Cancelled";
                    row[@"status"] = @"cancelled";
                } else if (![manager writeLTEBands:@[band] usingQuery:query errorText:&errorText]) {
                    row[@"status"] = @"write_failed";
                    stopReason = errorText ?: @"LTE band write failed; restoring";
                } else {
                    // CommCenter changes can be asynchronous. Never equate
                    // allowed-band readback with cellular registration.
                    NSTimeInterval stepDeadline = NSDate.date.timeIntervalSince1970 + 25.0;
                    for (NSInteger sample = 0; sample < 10 &&
                             NSDate.date.timeIntervalSince1970 < stepDeadline &&
                             NSDate.date.timeIntervalSince1970 < totalDeadline; sample++) {
                        if ([self shouldStop]) { stopReason = @"Cancelled"; break; }
                        [NSThread sleepForTimeInterval:1.0];
                        NSDictionary *readback = [manager queryCoreTelephony];
                        if (readback[@"error"]) continue;
                        if (![BLScanSubscriptionUUID(readback) isEqualToString:subscription] ||
                            !BLScanSingleActiveLine(readback)) {
                            stopReason = @"Cellular subscription changed; restore requires original line";
                            break;
                        }
                        NSString *readbackMode = [manager snapshotFromQuery:readback][@"mode_code"];
                        if (![readbackMode isEqualToString:mode]) {
                            if ([readbackMode isEqualToString:@"unknown"]) {
                                // The old async CoreTelephony getter sometimes
                                // timed out after a band switch. Keep observing,
                                // but do not accept a measurement or write the
                                // next band without explicit LTE-only proof.
                                row[@"status"] = @"mode_unverified";
                                row[@"mode_read_status"] = readback[@"ratReadStatus"] ?: @"unavailable";
                                continue;
                            }
                            stopReason = @"A different network mode was explicitly reported; restoring";
                            break;
                        }
                        if (!BLScanMatches([manager activeLTEFromQuery:readback], @[band])) continue;
                        for (NSDictionary *signal in BLScanMeasurements(manager, readback)) {
                            if (![signal[@"role"] isEqual:@"serving"] ||
                                ![signal[@"rat"] isEqual:@"LTE"] ||
                                ![signal[@"source"] isEqual:@"typed"]) continue;
                            if (![signal[@"band"] isEqual:band] || !BLScanHasPower(signal)) continue;
                            [row addEntriesFromDictionary:signal];
                            row[@"status"] = @"measured";
                            break;
                        }
                        if ([row[@"status"] isEqual:@"measured"]) break;
                    }
                }
                [rows addObject:row];
                @synchronized(self) {
                    self.scanState[@"rows"] = [rows copy];
                    self.scanState[@"completed"] = @(rows.count);
                }
                if (stopReason) break;
            }
        }
    } @catch (NSException *exception) {
        stopReason = exception.reason ?: @"Scan exception";
    } @finally {
        NSDictionary *saved = BLScanReadJournal();
        if (saved) {
            NSMutableDictionary *restoring = [saved mutableCopy];
            restoring[@"phase"] = @"restoring";
            (void)BLScanWriteJournal(restoring);
        }
        [self setPhase:@"restoring" message:@"Restoring original LTE bands"];
        NSString *recoveryFailure = nil;
        BOOL restored = [self restoreJournalWithManager:manager failure:&recoveryFailure];
        @synchronized(self) {
            self.running = NO;
            self.cancelRequested = NO;
            self.scanState[@"running"] = @NO;
            self.scanState[@"success"] = @(restored);
            self.scanState[@"phase"] = restored ? @"complete" : @"recovery_required";
            self.scanState[@"message"] = restored
                ? (stopReason ?: @"Scan completed; original bands restored")
                : (recoveryFailure ?: @"Restoration could not be verified. Do not change bands; use Recover");
            self.scanState[@"recovery_required"] = @(!restored);
        }
    }
}
@end
