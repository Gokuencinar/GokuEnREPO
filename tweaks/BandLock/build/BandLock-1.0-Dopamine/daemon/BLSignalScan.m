#import "BLSignalScan.h"
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <errno.h>
#import <stdio.h>
#import <objc/message.h>

@interface BLTelephonyManager (BLSignalScanPrivate)
- (NSDictionary *)queryCoreTelephony;
- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query;
- (NSArray<NSNumber *> *)activeLTEFromQuery:(NSDictionary *)query;
- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
@end

static NSString * const BLScanDirectory = @"/var/mobile/Library/Application Support/BandLockGlobal";
static NSString * const BLScanJournal = @"/var/mobile/Library/Application Support/BandLockGlobal/signal-scan-recovery.plist";
static const NSUInteger BLScanMaxBands = 2;

// A crash-safe, private journal must exist before ANY modem write. A plain
// NSUserDefaults synchronize is not an adequate rollback guarantee.
static BOOL BLScanWriteJournal(NSDictionary *state) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    if (![fm createDirectoryAtPath:BLScanDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:&error]) return NO;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!data.length) return NO;
    NSString *temp = [BLScanJournal stringByAppendingFormat:@".%@.tmp", NSUUID.UUID.UUIDString];
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
    if (written && rename(temp.fileSystemRepresentation, BLScanJournal.fileSystemRepresentation) != 0) written = NO;
    if (!written) { unlink(temp.fileSystemRepresentation); return NO; }
    int directory = open(BLScanDirectory.fileSystemRepresentation, O_RDONLY);
    if (directory < 0) return NO;
    BOOL durable = fsync(directory) == 0;
    close(directory);
    return durable;
}

static BOOL BLScanClearJournal(void) {
    if (unlink(BLScanJournal.fileSystemRepresentation) != 0 && errno != ENOENT) return NO;
    int directory = open(BLScanDirectory.fileSystemRepresentation, O_RDONLY);
    if (directory < 0) return NO;
    BOOL durable = fsync(directory) == 0;
    close(directory);
    return durable;
}

static NSDictionary *BLScanReadJournal(void) {
    id value = [NSDictionary dictionaryWithContentsOfFile:BLScanJournal];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static BOOL BLScanJournalExists(void) {
    return access(BLScanJournal.fileSystemRepresentation, F_OK) == 0;
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
    return identifier.length && identifier.length <= 128 ? identifier : nil;
}

static BOOL BLScanHasPower(NSDictionary *row) {
    return [row[@"rsrp"] isKindOfClass:NSNumber.class] ||
           [row[@"rssi"] isKindOfClass:NSNumber.class];
}

static NSArray *BLScanMeasurements(BLTelephonyManager *manager, NSDictionary *query) {
    id info = query[@"cellInfo"];
    return info && info != NSNull.null ? ([manager signalMeasurementsFromCellInfo:info] ?: @[]) : @[];
}

@interface BLSignalScan ()
@property (nonatomic, strong) NSMutableDictionary *scanState;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL cancelRequested;
@property (nonatomic, assign) BOOL recovering;
@property (nonatomic, strong) dispatch_queue_t scanQueue;
@end

@implementation BLSignalScan

+ (instancetype)sharedScan {
    static BLSignalScan *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[BLSignalScan alloc] init]; });
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
    if (query[@"error"]) return @{@"success": @NO, @"message": [query[@"error"] description] ?: @"Cell query failed"};
    NSArray *measurements = BLScanMeasurements(manager, query);
    return @{@"success": @YES, @"measurements": measurements,
             @"message": measurements.count ? @"Measurements available" : @"iOS did not expose usable signal measurements"};
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
    NSString *subscription = saved[@"subscription_uuid"];
    if (!original.count || original.count > 128 || ![subscription isKindOfClass:NSString.class] || !subscription.length) return NO;
    for (NSNumber *band in original) {
        if (![band isKindOfClass:NSNumber.class] || band.integerValue <= 0 ||
            band.integerValue > 255) return NO;
    }
    // Production BandLock documents slow CommCenter convergence: never
    // rewrite every second. Query/read back for up to 10s per attempt and
    // issue at most one retry.
    for (NSInteger attempt = 0; attempt < 2; attempt++) {
        @autoreleasepool {
            NSDictionary *query = [manager queryCoreTelephony];
            if (query[@"error"]) return NO;
            if (![BLScanSubscriptionUUID(query) isEqualToString:subscription]) return NO;
            NSArray *supported = [manager snapshotFromQuery:query][@"supported"];
            if (![supported isKindOfClass:NSArray.class] ||
                ![[NSSet setWithArray:original] isSubsetOfSet:[NSSet setWithArray:supported]]) return NO;
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
    }
}

- (NSDictionary *)startWithManager:(BLTelephonyManager *)manager {
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
    for (NSDictionary *row in preflight) {
        if ([row[@"role"] isEqual:@"serving"] && [row[@"rat"] isEqual:@"LTE"] && BLScanHasPower(row)) { servingPower = YES; break; }
    }
    NSNumber *servingBand = nil;
    for (NSDictionary *row in preflight) {
        if ([row[@"role"] isEqual:@"serving"] && [row[@"rat"] isEqual:@"LTE"] && BLScanHasPower(row)) {
            servingPower = YES;
            servingBand = row[@"band"];
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
    else if (!subscription.length) failure = @"The modem does not expose a stable subscription UUID. Active scanning is disabled";
    else if (!original.count || !supported.count) failure = @"LTE band baseline is unavailable";
    else if (![mode isEqualToString:@"lte"]) failure = @"Select LTE / 4G only before the experimental scan (5G and Auto are not scanned)";
    else if (!servingPower) failure = @"No real serving LTE power reading. Run the read-only probe first";
    else if (!servingBand || ![candidates.firstObject isEqual:servingBand])
        failure = @"Serving LTE band is not identified; active scan disabled";
    else if (candidates.count < 2) failure = @"Need serving band and one other LTE band for the two-band test";
    if (failure.length) {
        @synchronized(self) { self.running = NO; }
        return @{@"success": @NO, @"message": failure};
    }
    NSDictionary *journal = @{@"version": @1, @"original_lte": original, @"original_nr": snapshot[@"active_nr"] ?: @[],
                              @"subscription_uuid": subscription,
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
                if (query[@"error"]) {
                    row[@"status"] = @"query_failed";
                } else if (![BLScanSubscriptionUUID(query) isEqualToString:subscription]) {
                    stopReason = @"Cellular subscription changed; restore requires original line";
                    row[@"status"] = @"subscription_changed";
                } else if (![[manager snapshotFromQuery:query][@"mode_code"] description] isEqual:mode]) {
                    stopReason = @"Network mode changed externally; restoring";
                    row[@"status"] = @"mode_changed";
                } else if (![manager writeLTEBands:@[band] usingQuery:query errorText:&errorText]) {
                    row[@"status"] = @"write_failed";
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
                        if (![BLScanSubscriptionUUID(readback) isEqualToString:subscription]) {
                            stopReason = @"Cellular subscription changed; restore requires original line";
                            break;
                        }
                        if (![[manager snapshotFromQuery:readback][@"mode_code"] description] isEqual:mode]) {
                            stopReason = @"Network mode changed externally; restoring";
                            break;
                        }
                        if (!BLScanMatches([manager activeLTEFromQuery:readback], @[band])) continue;
                        for (NSDictionary *signal in BLScanMeasurements(manager, readback)) {
                            if (![signal[@"role"] isEqual:@"serving"] || ![signal[@"rat"] isEqual:@"LTE"]) continue;
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
