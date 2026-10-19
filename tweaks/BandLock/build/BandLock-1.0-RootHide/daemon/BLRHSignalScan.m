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

@interface BLTelephonyManager (BLRHSignalScanPrivate)
- (NSDictionary *)queryCoreTelephony;
- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query;
- (NSArray<NSNumber *> *)activeLTEFromQuery:(NSDictionary *)query;
- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
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
    if (!directoryPath.length || !journalPath.length || ![directoryPath containsString:@"/.jbroot-"]) return NO;
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
           [row[@"rssi"] isKindOfClass:NSNumber.class];
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
             @"active_context_matches_data_slot": @(slotMatched),
             @"data_service_matches_registered_rat": @(serviceInRAT),
             @"active_context_check_status": status};
}

static BOOL BLScanSingleActiveLine(NSDictionary *query) {
    return [BLRHActiveLineCheck(query)[@"verified"] boolValue];
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

- (NSDictionary *)cancel {
    @synchronized(self) {
        if (self.running) {
            self.cancelRequested = YES;
            self.scanState[@"message"] = @"Cancellation requested; restoring original bands";
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

- (BOOL)restoreJournalWithManager:(BLTelephonyManager *)manager {
    NSDictionary *saved = BLScanReadJournal();
    if (!saved || ![saved[@"version"] isEqual:@1]) return NO;
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
    [self setPhase:@"restoring" message:@"Recovering bands left by an interrupted scan"];
    BOOL restored = [self restoreJournalWithManager:manager];
    [self setPhase:(restored ? @"restored" : @"recovery_required")
           message:(restored ? @"Original bands restored" : @"Could not verify restoration; retry recovery before changing bands")];
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
        BOOL restored = [self restoreJournalWithManager:manager];
        @synchronized(self) {
            self.running = NO;
            self.cancelRequested = NO;
            self.scanState[@"running"] = @NO;
            self.scanState[@"success"] = @(restored);
            self.scanState[@"phase"] = restored ? @"complete" : @"recovery_required";
            self.scanState[@"message"] = restored
                ? (stopReason ?: @"Scan completed; original bands restored")
                : @"Restoration could not be verified. Do not change bands; use Recover";
            self.scanState[@"recovery_required"] = @(!restored);
        }
    }
}
@end
