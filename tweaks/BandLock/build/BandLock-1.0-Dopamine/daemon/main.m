#import <Foundation/Foundation.h>
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import "BLRHSignalScan.h"
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/stat.h>
#import <unistd.h>
#import <signal.h>
#import <errno.h>
#import <fcntl.h>
#import <stdio.h>
#import <sys/time.h>
#import <string.h>
#import <stdint.h>
#import <dlfcn.h>
#import <stdlib.h>

extern int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);
enum { BLJetsamSetTaskLimit = 6, BLJetsamLimitMB = 64 };

static void BLDaemonLog(const char *message) {
    const char *path = "/tmp/BandLock-daemon.log";
    if (!path || !*path) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    struct timeval tv;
    gettimeofday(&tv, NULL);
    char line[1200];
    int length = snprintf(line,
                          sizeof(line),
                          "%lld.%03d pid=%d %s\n",
                          (long long)tv.tv_sec,
                          (int)(tv.tv_usec / 1000),
                          (int)getpid(),
                          message ? message : "(null)");
    if (length > 0) {
        size_t count = (size_t)length;
        if (count >= sizeof(line)) count = sizeof(line) - 1;
        (void)write(fd, line, count);
    }
    close(fd);
}

@interface BLTelephonyManager (BandLockDaemonPrivate)
- (NSDictionary *)queryCoreTelephony;
- (NSDictionary *)queryCoreTelephonyForPassiveObservation;
- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query;
- (BOOL)setRatSelectionSync:(NSString *)selection preferred:(NSString *)preferred errorText:(NSString **)errorText;
- (BOOL)setModeCodeSync:(NSString *)mode errorText:(NSString **)errorText;
- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
- (NSArray<NSNumber *> *)activeLTEFromQuery:(NSDictionary *)query;
- (BOOL)writeNRBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
- (NSArray<NSNumber *> *)activeNRFromQuery:(NSDictionary *)query;
- (BOOL)openFieldTestWithError:(NSString **)errorText;
@end

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLNRRAT = @"kCTRegistrationRadioAccessTechnologyNR";
static NSString * const BLUTRANRAT = @"kCTRegistrationRadioAccessTechnologyUTRAN";
static NSString * const BLGSMRAT = @"kCTRegistrationRadioAccessTechnologyGSM";
static NSString * const BLRATAutomatic = @"kCTRegistrationRATSelectionAutomatic";
static NSString * const BLRATGSM = @"kCTRegistrationRATSelectionGSM";
static NSString * const BLRATLTE = @"kCTRegistrationRATSelectionLTE";
static NSString * const BLRATUMTS = @"kCTRegistrationRATSelectionUMTS";
static NSString * const BLRATNR = @"kCTRegistrationRATSelectionNR";
static NSString * const BLRATNRSA = @"kCTRegistrationRATSelectionNRStandAlone";
static NSString * const BLLastAcceptedModeDefaultsKey = @"BandLockLastAcceptedModeCode";
static NSString * const BLLastAcceptedModeTimeDefaultsKey = @"BandLockLastAcceptedModeTime";

static NSSet<NSString *> *BLAllowedModeCodes(void) {
    static NSSet<NSString *> *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        allowed = [NSSet setWithArray:
            @[@"automatic", @"2g", @"3g", @"lte", @"5g-auto", @"5g-on", @"5g-only"]];
    });
    return allowed;
}

static NSString *BLStoredAcceptedModeCode(void) {
    NSString *mode = [NSUserDefaults.standardUserDefaults stringForKey:BLLastAcceptedModeDefaultsKey];
    return [BLAllowedModeCodes() containsObject:mode] ? mode : nil;
}

static void BLRememberAcceptedModeCode(NSString *mode) {
    if (![BLAllowedModeCodes() containsObject:mode]) return;
    [NSUserDefaults.standardUserDefaults setObject:mode forKey:BLLastAcceptedModeDefaultsKey];
    [NSUserDefaults.standardUserDefaults setDouble:[NSDate date].timeIntervalSince1970
                                           forKey:BLLastAcceptedModeTimeDefaultsKey];
}

static NSString *BLRecentAcceptedModeCode(void) {
    NSString *mode = BLStoredAcceptedModeCode();
    if (!mode.length) return nil;
    NSTimeInterval timestamp =
        [NSUserDefaults.standardUserDefaults doubleForKey:BLLastAcceptedModeTimeDefaultsKey];
    NSTimeInterval age = [NSDate date].timeIntervalSince1970 - timestamp;
    return timestamp > 0 && age >= 0 && age <= 300.0 ? mode : nil;
}

static NSString *BLSocketPath(void) {
    return @"/tmp/com.gokuencinar.bandlockd.dopamine.sock";
}

static BOOL BLPathIsSocket(const char *path) {
    struct stat st;
    return path && lstat(path, &st) == 0 && S_ISSOCK(st.st_mode);
}

static int BLLaunchdActivatedSocket(const char *path) {
    typedef int (*BLLaunchActivateSocketFn)(const char *, int **, size_t *);
    BLLaunchActivateSocketFn activate = (BLLaunchActivateSocketFn)dlsym(RTLD_DEFAULT, "launch_activate_socket");
    void *xpcHandle = NULL;
    if (!activate) {
        xpcHandle = dlopen("/usr/lib/system/libxpc.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (xpcHandle) activate = (BLLaunchActivateSocketFn)dlsym(xpcHandle, "launch_activate_socket");
    }
    if (!activate) {
        BOOL socketExists = BLPathIsSocket(path);
        BLDaemonLog(socketExists
            ? "launch_activate_socket unavailable while managed socket exists; refusing unlink"
            : "launch_activate_socket unavailable; using legacy bind");
        if (xpcHandle) dlclose(xpcHandle);
        return socketExists ? -2 : -1;
    }
    int *fds = NULL;
    size_t count = 0;
    int rc = activate("BandLockListener", &fds, &count);
    if (xpcHandle) dlclose(xpcHandle);
    if (rc != 0 || !fds || count == 0) {
        BOOL fallbackAllowed = (rc == ENOENT || rc == ESRCH) && !BLPathIsSocket(path);
        BLDaemonLog([[NSString stringWithFormat:@"launch socket activation rc=%d count=%lu fallback=%d",
                      rc, (unsigned long)count, fallbackAllowed ? 1 : 0] UTF8String]);
        if (fds) free(fds);
        return fallbackAllowed ? -1 : -2;
    }
    if (count != 1) {
        for (size_t i = 0; i < count; i++) close(fds[i]);
        free(fds);
        BLDaemonLog("launch socket activation returned unexpected descriptor count");
        return -2;
    }
    int serverFD = fds[0];
    free(fds);
    int socketType = 0;
    socklen_t optionLength = sizeof(int);
    struct sockaddr_un boundAddress;
    socklen_t addressLength = sizeof(boundAddress);
    memset(&boundAddress, 0, sizeof(boundAddress));
    if (getsockopt(serverFD, SOL_SOCKET, SO_TYPE, &socketType, &optionLength) != 0 ||
        socketType != SOCK_STREAM ||
        getsockname(serverFD, (struct sockaddr *)&boundAddress, &addressLength) != 0 ||
        boundAddress.sun_family != AF_UNIX) {
        BLDaemonLog([[NSString stringWithFormat:@"launch socket activation invalid type/family type=%d family=%d errno=%d",
                      socketType, (int)boundAddress.sun_family, errno] UTF8String]);
        close(serverFD);
        return -2;
    }
    // SO_ACCEPTCONN returns ENOPROTOOPT on some iOS 16 Dopamine builds.
    // Calling listen again is valid for an already-listening stream socket,
    // and also covers launchd handing us a bound-but-not-yet-listening FD.
    if (listen(serverFD, 8) != 0) {
        BLDaemonLog([[NSString stringWithFormat:@"launch socket listen failed errno=%d", errno] UTF8String]);
        close(serverFD);
        return -2;
    }
    BLDaemonLog("launch socket listen ready");
    BLDaemonLog("launch socket activation acquired BandLockListener");
    return serverFD;
}

static int BLLegacyServerSocket(const char *path) {
    int serverFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (serverFD < 0) return -1;
    unlink(path);

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strlcpy(address.sun_path, path, sizeof(address.sun_path));
    if (bind(serverFD, (struct sockaddr *)&address, sizeof(address)) != 0) {
        BLDaemonLog([[NSString stringWithFormat:@"legacy bind failed errno=%d", errno] UTF8String]);
        close(serverFD);
        return -1;
    }
    chmod(path, 0600);
    if (listen(serverFD, 8) != 0) {
        BLDaemonLog([[NSString stringWithFormat:@"legacy listen failed errno=%d", errno] UTF8String]);
        close(serverFD);
        unlink(path);
        return -1;
    }
    BLDaemonLog("legacy socket listening");
    return serverFD;
}

static NSDictionary *BLStatusPayload(BLTelephonyManager *manager, NSDictionary *query) {
    if (query[@"error"]) return @{@"success": @NO, @"message": [query[@"error"] description] ?: @"CoreTelephony error"};
    NSDictionary *snapshot = [manager snapshotFromQuery:query];
    NSMutableDictionary *payload = [@{
        @"success": @YES,
        @"supported": snapshot[@"supported"] ?: @[],
        @"active": snapshot[@"active"] ?: @[],
        @"supported_nr": snapshot[@"supported_nr"] ?: @[],
        @"active_nr": snapshot[@"active_nr"] ?: @[],
        @"supports_5g": snapshot[@"supports_5g"] ?: @NO,
        @"rat": snapshot[@"rat"] ?: @"—",
        @"serving": snapshot[@"serving"] ?: @"—",
        @"mode": snapshot[@"mode"] ?: @"—",
        @"mode_code": snapshot[@"mode_code"] ?: @"unknown"
    } mutableCopy];
    NSString *acceptedMode = BLStoredAcceptedModeCode();
    if (acceptedMode.length) payload[@"accepted_mode"] = acceptedMode;
    return payload;
}

static NSDictionary *BLApplyNRBandsPayload(BLTelephonyManager *manager, NSArray<NSNumber *> *requested) {
    NSArray<NSNumber *> *bands = BLSortedBands(requested);
    if (!bands.count) return @{@"success": @NO, @"message": @"Empty 5G NR band list"};
    BOOL allSDL = YES;
    for (NSNumber *band in bands) if (![[BLGNRDuplexForBand(band) uppercaseString] hasPrefix:@"SDL"]) { allSDL = NO; break; }
    if (allSDL) return @{@"success": @NO, @"message": @"SDL-only 5G NR selections are not allowed"};

    NSDictionary *query = [manager queryCoreTelephony];
    if (query[@"error"]) return @{@"success": @NO, @"message": [query[@"error"] description] ?: @"CoreTelephony error"};
    NSDictionary *before = [manager snapshotFromQuery:query];
    NSArray<NSNumber *> *supported = before[@"supported_nr"] ?: @[];
    if (!supported.count) return @{@"success": @NO, @"message": @"This modem does not report configurable 5G NR bands"};

    NSSet *supportedSet = [NSSet setWithArray:supported];
    for (NSNumber *band in bands) {
        if (![supportedSet containsObject:band]) return @{@"success": @NO, @"message": [NSString stringWithFormat:@"n%@ is not supported by this modem", band]};
    }

    NSArray<NSNumber *> *previous = [manager activeNRFromQuery:query] ?: @[];
    NSString *writeError = nil;
    if (![manager writeNRBands:bands usingQuery:query errorText:&writeError]) return @{@"success": @NO, @"message": writeError ?: @"5G NR write failed"};

    NSDictionary *verify = nil;
    NSArray<NSNumber *> *readback = @[];
    BOOL matches = NO;
    NSString *lastVerifyError = nil;
    NSSet *requestedSet = [NSSet setWithArray:bands];
    for (NSInteger attempt = 1; attempt <= 40; attempt++) {
        [NSThread sleepForTimeInterval:0.5];
        NSDictionary *candidate = [manager queryCoreTelephony];
        if (candidate[@"error"]) {
            lastVerifyError = [candidate[@"error"] description];
            BLDaemonLog([[NSString stringWithFormat:@"apply-nr verify attempt=%ld error=%@", (long)attempt, lastVerifyError ?: @"unknown"] UTF8String]);
            continue;
        }
        verify = candidate;
        readback = [manager activeNRFromQuery:verify] ?: @[];
        matches = [requestedSet isEqualToSet:[NSSet setWithArray:readback]];
        BLDaemonLog([[NSString stringWithFormat:@"apply-nr verify attempt=%ld matches=%d readback=%@", (long)attempt, matches ? 1 : 0, BLNRBandList(readback)] UTF8String]);
        if (matches) break;
        if (attempt == 20) {
            NSString *retryError = nil;
            if (![manager writeNRBands:bands usingQuery:verify errorText:&retryError]) return @{@"success": @NO, @"message": retryError ?: @"5G NR retry failed"};
            BLDaemonLog("apply-nr retry write accepted");
        }
    }
    if (!verify && lastVerifyError.length) return @{@"success": @NO, @"message": lastVerifyError};
    if (!verify) verify = [manager queryCoreTelephony];

    NSMutableDictionary *payload = [BLStatusPayload(manager, verify) mutableCopy];
    if (!payload) payload = [NSMutableDictionary dictionary];
    payload[@"success"] = @(matches);
    payload[@"previous_nr"] = previous;
    payload[@"message"] = matches
        ? [NSString stringWithFormat:@"Active 5G NR bands: %@", BLNRBandList(readback)]
        : [NSString stringWithFormat:@"Requested %@; read back %@", BLNRBandList(bands), BLNRBandList(readback)];
    return payload;
}

static NSDictionary *BLHandleRequest(NSDictionary *request) {
    @try {
        NSString *command = [request[@"cmd"] isKindOfClass:[NSString class]] ? request[@"cmd"] : @"";
        BLDaemonLog([[NSString stringWithFormat:@"handle command=%@", command] UTF8String]);
        BLTelephonyManager *manager = BLTelephonyManager.sharedManager;

        // This is a modem capability / safety gate, NOT a filesystem
        // permissions error. NR writes and the old two-band experiment remain
        // disabled on iOS 18. LTE apply is intentionally allowed again: the
        // same LTE band writer is now exercised by the guarded technology scan
        // and apply has its own subset validation + positive readback loop.
        // Leave emergency journal recovery available: preventing restoration
        // after a previous build wrote bands would be unsafe.
        if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18 &&
            [@[@"apply_nr", @"scan_start"] containsObject:command]) {
            return @{@"success": @NO, @"unsupported_modem_write": @YES,
                     @"message": @"El cambio de red no está verificado en este iOS"};
        }

        if ([command isEqualToString:@"signal_probe"]) {
            if ([BLRHSignalScan.sharedScan isRunning]) {
                return @{@"success": @NO, @"message": @"A scan is already running; query scan_status"};
            }
            // Signal-only requests must not block on the unreliable RAT getter.
            // Do not reuse this route to authorize any active band operation.
            return [manager signalProbeFromQuery:[manager queryCoreTelephonyForPassiveObservation]];
        }
        if ([command isEqualToString:@"scan_status"]) return [BLRHSignalScan.sharedScan status];
        if ([command isEqualToString:@"scan_line_diagnostic"]) {
            return [BLRHSignalScan.sharedScan lineDiagnosticsWithManager:manager];
        }
        if ([command isEqualToString:@"band_inventory_diagnostic"]) {
            return [BLRHSignalScan.sharedScan bandInventoryWithManager:manager];
        }
        if ([command isEqualToString:@"scan_cancel"]) return [BLRHSignalScan.sharedScan cancel];
        if ([command isEqualToString:@"scan_recover"]) {
            return [BLRHSignalScan.sharedScan requestRecoveryWithManager:manager];
        }
        if ([command isEqualToString:@"scan_start"]) {
            return [BLRHSignalScan.sharedScan startWithManager:manager];
        }
        if ([command isEqualToString:@"scan_observe_start"]) {
            NSString *targetRAT = [request[@"rat"] isKindOfClass:NSString.class] ? request[@"rat"] : @"";
            if (![@[@"AUTO", @"2G", @"3G", @"LTE", @"NR"] containsObject:targetRAT])
                return @{@"success": @NO, @"message": @"Selecciona Auto, 2G, 3G, 4G o 5G"};
            return [BLRHSignalScan.sharedScan startPassiveObservationWithManager:manager target:targetRAT];
        }
        if ([command isEqualToString:@"scan_technology_start"]) {
            NSString *targetRAT = [request[@"rat"] isKindOfClass:NSString.class] ? request[@"rat"] : @"";
            if (![@[@"2G", @"3G", @"LTE", @"NR"] containsObject:targetRAT])
                return @{@"success": @NO, @"message": @"Selecciona una tecnología 2G, 3G, 4G o 5G"};
            NSString *restoreMode = BLRecentAcceptedModeCode();
            if (!restoreMode.length) {
                return @{@"success": @NO,
                         @"message": @"Selecciona un modo de red en BandLock (por ejemplo Auto) justo antes del barrido para establecer un punto de retorno seguro."};
            }
            return [BLRHSignalScan.sharedScan startTechnologyScanWithManager:manager
                                                                      target:targetRAT
                                                                 restoreMode:restoreMode
                                                                  countryISO:request[@"country_iso"]
                                                                 targetBands:request[@"target_bands"]
                                                           targetFrequencies:request[@"target_frequencies_mhz"]];
        }
        if (([command isEqualToString:@"rat"] ||
             [command isEqualToString:@"apply"] ||
             [command isEqualToString:@"apply_nr"]) &&
            ([BLRHSignalScan.sharedScan isRunning] ||
             [BLRHSignalScan.sharedScan isRecovering] ||
             [BLRHSignalScan.sharedScan hasPendingRecovery])) {
            return @{@"success": @NO,
                     @"message": @"LTE scan or recovery in progress. Complete the original-band restore first."};
        }

        if ([command isEqualToString:@"status"]) {
            BLDaemonLog("status query begin");
            // On iOS 18 neither the sync nor the async private RAT getter has
            // produced trustworthy results on the test device. More importantly,
            // SpringBoard requests must never enqueue that slow getter in the
            // daemon. Report a conservative unknown selection instead.
            BOOL passiveStatus = [NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18;
            NSDictionary *query = passiveStatus ? [manager queryCoreTelephonyForPassiveObservation]
                                                : [manager queryCoreTelephony];
            NSDictionary *payload = BLStatusPayload(manager, query);
            BLDaemonLog("status query end");
            return payload;
        }

        if ([command isEqualToString:@"rat"]) {
            NSString *mode = [request[@"mode"] isKindOfClass:[NSString class]] ? request[@"mode"] : @"";
            if (![BLAllowedModeCodes() containsObject:mode])
                return @{@"success": @NO, @"message": @"Modo de red no válido"};
            // 1.5 did not require an authoritative RAT readback before the
            // setter. The private getter is unreliable on iOS 18 and caused
            // the 1.6 path to fail before attempting a user-requested mode.
            // Keep the scan/recovery exclusion above; never apply band writes
            // here. This command is only reached after explicit user action.
            BOOL requests5G = [mode hasPrefix:@"5g-"];
            if (requests5G) {
                NSDictionary *capabilityQuery = [manager queryCoreTelephony];
                if (capabilityQuery[@"error"]) return @{@"success": @NO, @"message": [capabilityQuery[@"error"] description] ?: @"CoreTelephony error"};
                NSDictionary *capabilitySnapshot = [manager snapshotFromQuery:capabilityQuery];
                if (![capabilitySnapshot[@"supports_5g"] boolValue]) {
                    return @{@"success": @NO, @"message": @"This iPhone or active line does not report 5G support"};
                }
            }
            NSString *errorText = nil;
            if (![manager setModeCodeSync:mode errorText:&errorText]) {
                BLDaemonLog("RAT setter failed; no automatic retry");
                return @{@"success": @NO, @"message": errorText ?: @"RAT write failed"};
            }
            BLRememberAcceptedModeCode(mode);
            BOOL isIOS18 = [NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18;
            // iOS18 RAT getters may produce EAGAIN even after a successful
            // setter callback. Do not mistake this for a failed write and do
            // not issue additional private getters/repeated writes.
            if (isIOS18) {
                BLDaemonLog("RAT callback accepted; modem selection remains unverified");
                return @{@"success": @YES, @"verification_pending": @YES,
                         @"mode_code": @"unknown",
                         @"accepted_mode": mode,
                         @"message": @"Solicitud aceptada; modo aún sin confirmar"};
            }
            [NSThread sleepForTimeInterval:0.35];
            NSMutableDictionary *payload =
                [BLStatusPayload(manager, [manager queryCoreTelephony]) mutableCopy];
            if ([payload[@"success"] boolValue]) {
                payload[@"message"] = payload[@"mode"] ?: @"Modo actualizado";
            }
            return payload;
        }

        if ([command isEqualToString:@"apply"]) {
            NSArray<NSNumber *> *bands = BLSortedBands(request[@"bands"]);
            if (!bands.count) return @{@"success": @NO, @"message": @"Empty LTE band list"};

            BOOL allSDL = YES;
            for (NSNumber *band in bands) {
                if (![[BLGDuplexForBand(band) uppercaseString] isEqualToString:@"SDL"]) { allSDL = NO; break; }
            }
            if (allSDL) return @{@"success": @NO, @"message": @"SDL-only LTE selections are not allowed"};

            BOOL passiveApplyQuery = [NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18;
            NSDictionary *query = passiveApplyQuery
                ? [manager queryCoreTelephonyForPassiveObservation]
                : [manager queryCoreTelephony];
            if (query[@"error"]) return @{@"success": @NO, @"message": [query[@"error"] description] ?: @"CoreTelephony error"};
            NSDictionary *before = [manager snapshotFromQuery:query];
            NSArray<NSNumber *> *supported = before[@"supported"] ?: @[];
            NSSet *supportedSet = [NSSet setWithArray:supported];
            for (NSNumber *band in bands) {
                if (![supportedSet containsObject:band]) return @{@"success": @NO, @"message": [NSString stringWithFormat:@"B%@ is not supported by this modem", band]};
            }

            NSArray<NSNumber *> *previous = [manager activeLTEFromQuery:query] ?: @[];
            NSString *writeError = nil;
            if (![manager writeLTEBands:bands usingQuery:query errorText:&writeError]) {
                return @{@"success": @NO, @"message": writeError ?: @"LTE write failed"};
            }

            NSDictionary *verify = nil;
            NSArray<NSNumber *> *readback = @[];
            BOOL matches = NO;
            NSString *lastVerifyError = nil;
            NSSet *requestedSet = [NSSet setWithArray:bands];

            // CommCenter applies band changes asynchronously. On the test
            // iPhone, narrowing 25 -> 7 bands sometimes becomes visible in
            // under a second and sometimes only after several seconds. Poll
            // a bounded window and perform only one fresh-query retry write.
            for (NSInteger attempt = 1; attempt <= 40; attempt++) {
                [NSThread sleepForTimeInterval:0.5];
                NSDictionary *candidate = passiveApplyQuery
                    ? [manager queryCoreTelephonyForPassiveObservation]
                    : [manager queryCoreTelephony];
                if (candidate[@"error"]) {
                    lastVerifyError = [candidate[@"error"] description];
                    BLDaemonLog([[NSString stringWithFormat:@"apply verify attempt=%ld error=%@", (long)attempt, lastVerifyError ?: @"unknown"] UTF8String]);
                    continue;
                }

                verify = candidate;
                readback = [manager activeLTEFromQuery:verify] ?: @[];
                matches = [requestedSet isEqualToSet:[NSSet setWithArray:readback]];
                BLDaemonLog([[NSString stringWithFormat:@"apply verify attempt=%ld matches=%d readback=%@",
                              (long)attempt,
                              matches ? 1 : 0,
                              BLBandList(readback)] UTF8String]);
                if (matches) break;

                // Give CommCenter a full 10 seconds to converge before a
                // single retry. A premature rewrite can restart the modem's
                // asynchronous narrowing transition on some iOS 16 devices.
                if (attempt == 20) {
                    NSString *retryError = nil;
                    if (![manager writeLTEBands:bands usingQuery:verify errorText:&retryError]) {
                        return @{@"success": @NO, @"message": retryError ?: @"LTE retry failed"};
                    }
                    BLDaemonLog("apply retry write accepted");
                }
            }

            if (!verify && lastVerifyError.length) {
                return @{@"success": @NO, @"message": lastVerifyError};
            }

            NSMutableDictionary *payload = [BLStatusPayload(manager, verify) mutableCopy];
            if (!payload) payload = [NSMutableDictionary dictionary];
            payload[@"success"] = @(matches);
            payload[@"previous"] = previous;
            payload[@"message"] = matches
                ? [NSString stringWithFormat:@"Active LTE bands: %@", BLBandList(readback)]
                : [NSString stringWithFormat:@"Requested %@; read back %@", BLBandList(bands), BLBandList(readback)];
            return payload;
        }

        if ([command isEqualToString:@"apply_nr"]) {
            return BLApplyNRBandsPayload(manager, request[@"bands"]);
        }

        if ([command isEqualToString:@"fieldtest"]) {
            NSString *errorText = nil;
            BOOL ok = [manager openFieldTestWithError:&errorText];
            return @{@"success": @(ok), @"message": ok ? @"Field Test requested" : (errorText ?: @"Could not open Field Test")};
        }

        return @{@"success": @NO, @"message": @"Unknown command"};
    }
    @catch (NSException *exception) {
        return @{@"success": @NO,
                 @"message": exception.reason ?: exception.name ?: @"NSException",
                 @"exception": exception.name ?: @"NSException"};
    }
}

static void BLWriteResponse(int clientFD, NSDictionary *response) {
    BLDaemonLog("response serialize begin");
    NSData *data = [NSJSONSerialization dataWithJSONObject:response ?: @{} options:0 error:nil];
    if (!data) data = [@"{\"success\":false,\"message\":\"JSON encoding failed\"}" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *wire = [data mutableCopy];
    [wire appendBytes:"\n" length:1];
    BLDaemonLog([[NSString stringWithFormat:@"response write begin bytes=%lu", (unsigned long)wire.length] UTF8String]);
    const uint8_t *bytes = wire.bytes;
    NSUInteger remaining = wire.length;
    while (remaining > 0) {
        ssize_t written = write(clientFD, bytes, remaining);
        if (written <= 0) {
            BLDaemonLog([[NSString stringWithFormat:@"response write failed errno=%d", errno] UTF8String]);
            break;
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    BLDaemonLog("response write end");
}

static void BLServeClient(int clientFD) {
    BLDaemonLog("serve client begin");
    NSMutableData *requestData = [NSMutableData data];
    uint8_t buffer[4096];
    while (requestData.length < 65536) {
        ssize_t count = read(clientFD, buffer, sizeof(buffer));
        if (count <= 0) {
            BLDaemonLog([[NSString stringWithFormat:@"request read stop rc=%ld errno=%d", (long)count, count < 0 ? errno : 0] UTF8String]);
            break;
        }
        BLDaemonLog([[NSString stringWithFormat:@"request read chunk bytes=%ld", (long)count] UTF8String]);
        [requestData appendBytes:buffer length:(NSUInteger)count];
        if (memchr(buffer, '\n', (size_t)count)) break;
    }

    NSRange newline = [requestData rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, requestData.length)];
    if (newline.location != NSNotFound) requestData.length = newline.location;
    NSDictionary *request = requestData.length ? [NSJSONSerialization JSONObjectWithData:requestData options:0 error:nil] : nil;
    if (![request isKindOfClass:[NSDictionary class]]) {
        BLDaemonLog("request invalid");
        BLWriteResponse(clientFD, @{@"success": @NO, @"message": @"Invalid request"});
        return;
    }
    BLDaemonLog("request parsed");
    BLWriteResponse(clientFD, BLHandleRequest(request));
    BLDaemonLog("serve client end");
}

int main(int argc, char *argv[]) {
    (void)memorystatus_control(BLJetsamSetTaskLimit, (int32_t)getpid(), BLJetsamLimitMB, NULL, 0);
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        BLDaemonLog("daemon start");
        NSString *socketPath = BLSocketPath();
        const char *path = socketPath.fileSystemRepresentation;
        if (!path || strlen(path) >= sizeof(((struct sockaddr_un *)0)->sun_path)) return 70;

        int serverFD = BLLaunchdActivatedSocket(path);
        if (serverFD == -1) serverFD = BLLegacyServerSocket(path);
        if (serverFD < 0) return 72;
        BLDaemonLog("daemon listening");
        if ([BLRHSignalScan.sharedScan hasPendingRecovery]) {
            // The recovery queue is single-flight. Set 'recovering'
            // synchronously before accepting any other modem commands.
            (void)[BLRHSignalScan.sharedScan requestRecoveryWithManager:BLTelephonyManager.sharedManager];
        }

        while (1) {
            int clientFD = accept(serverFD, NULL, NULL);
            if (clientFD < 0) {
                if (errno == EINTR) continue;
                [NSThread sleepForTimeInterval:0.1];
                continue;
            }
            BLDaemonLog("accept client");
            @autoreleasepool { BLServeClient(clientFD); }
            close(clientFD);
            BLDaemonLog("client closed");
        }
    }
}
