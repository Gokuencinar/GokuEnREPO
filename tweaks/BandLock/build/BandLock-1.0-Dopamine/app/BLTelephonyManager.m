#import "BLTelephonyManager.h"
#import "../../BLHardwareCapabilities.h"
#import "BLCommon.h"
#import "BLBreadcrumb.h"
#import <sys/socket.h>
#import <sys/stat.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <errno.h>
#import <stdlib.h>
#import <string.h>
#import <signal.h>
#import <objc/runtime.h>

static NSString * const BLPreviousBandsDefaultsKey = @"BandLockPreviousBands";
static NSString * const BLPreviousNRBandsDefaultsKey = @"BandLockPreviousNRBands";
static NSString * const BLPendingBandsDefaultsKey = @"BandLockPendingBands";
static NSString * const BLPendingNRBandsDefaultsKey = @"BandLockPendingNRBands";
#if BL_VARIANT_ROOTFUL
static NSString * const BLDaemonSocketRelativePath = @"/tmp/com.gokuencinar.bandlockd.rootful.sock";
#else
static NSString * const BLDaemonSocketRelativePath = @"/tmp/com.gokuencinar.bandlockd.dopamine.sock";
#endif

static NSString *BLDaemonSocketPath(void) {
    return BLDaemonSocketRelativePath;
}

static NSString *BLFriendlyResultMessage(NSDictionary *result, NSString *command) {
    BOOL success = [result[@"success"] boolValue];
    NSString *phase = [result[@"phase"] isKindOfClass:NSString.class] ? result[@"phase"] : @"";
    NSString *raw = [result[@"message"] isKindOfClass:NSString.class] ? result[@"message"] : @"";
    NSString *lower = raw.lowercaseString;

    if (!success) {
        BOOL recoveryNeeded = [result[@"recovery_required"] boolValue] ||
            [phase isEqualToString:@"recovery_required"] ||
            ([command hasPrefix:@"scan_"] &&
             ([lower containsString:@"recover"] || [lower containsString:@"restore"]));
        if (recoveryNeeded) {
            return BLT(@"Es necesario recuperar la configuración anterior antes de continuar.",
                       @"The previous configuration must be recovered before continuing.");
        }
        if ([command isEqualToString:@"status"])
            return BLT(@"No se pudo actualizar el estado.", @"Could not refresh status.");
        if ([command isEqualToString:@"rat"])
            return BLT(@"No se pudo cambiar el modo de red.", @"Could not change network mode.");
        if ([command isEqualToString:@"apply"] || [command isEqualToString:@"apply_nr"])
            return BLT(@"No se pudo aplicar la selección.", @"Could not apply the selection.");
        if ([command isEqualToString:@"fieldtest"])
            return BLT(@"No se pudo abrir Field Test.", @"Could not open Field Test.");
        if ([command isEqualToString:@"signal_probe"])
            return BLT(@"No se pudo leer la señal.", @"Could not read signal.");
        if ([command isEqualToString:@"scan_observe_start"])
            return BLT(@"No se pudo iniciar la observación.", @"Could not start observation.");
        if ([command isEqualToString:@"scan_start"] || [command isEqualToString:@"scan_technology_start"])
            return BLT(@"No se pudo iniciar el barrido.", @"Could not start the scan.");
        if ([command isEqualToString:@"scan_status"])
            return BLT(@"No se pudo actualizar el barrido.", @"Could not update the scan.");
        if ([command isEqualToString:@"scan_cancel"])
            return BLT(@"No se pudo cancelar el barrido.", @"Could not cancel the scan.");
        if ([command isEqualToString:@"scan_recover"])
            return BLT(@"No se pudo iniciar la recuperación.", @"Could not start recovery.");
        return BLT(@"No se pudo completar la operación.", @"The operation could not be completed.");
    }

    if ([command isEqualToString:@"scan_status"]) {
        NSArray *rows = [result[@"rows"] isKindOfClass:NSArray.class] ? result[@"rows"] : @[];
        if ([phase isEqualToString:@"observing"])
            return BLT(@"Observando la red actual…", @"Observing the current network…");
        if ([phase isEqualToString:@"observation_complete"])
            return rows.count ? BLT(@"Observación completada.", @"Observation completed.")
                              : BLT(@"Observación completada sin señal medible.", @"Observation completed with no measurable signal.");
        if ([phase isEqualToString:@"observation_cancelled"])
            return BLT(@"Observación detenida.", @"Observation stopped.");
        if ([phase isEqualToString:@"observation_stopped"])
            return BLT(@"La observación se detuvo.", @"Observation stopped.");
        if ([phase isEqualToString:@"switching_rat"])
            return BLT(@"Preparando el barrido…", @"Preparing the scan…");
        if ([phase isEqualToString:@"scanning"])
            return BLT(@"Midiendo cobertura…", @"Measuring coverage…");
        if ([phase isEqualToString:@"restoring"])
            return BLT(@"Restaurando la configuración anterior…", @"Restoring the previous configuration…");
        if ([phase isEqualToString:@"restored"])
            return BLT(@"Configuración restaurada.", @"Configuration restored.");
        if ([phase isEqualToString:@"complete"])
            return rows.count ? BLT(@"Barrido completado.", @"Scan completed.")
                              : BLT(@"Barrido completado sin señal medible.", @"Scan completed with no measurable signal.");
        if ([phase isEqualToString:@"recovery_required"])
            return BLT(@"No se pudo restaurar la configuración anterior. Usa Recuperar antes de hacer otro cambio.",
                       @"The previous configuration could not be restored. Use Recover before making another change.");
        return @"";
    }
    if ([command isEqualToString:@"scan_observe_start"])
        return BLT(@"Observación iniciada.", @"Observation started.");
    if ([command isEqualToString:@"scan_start"] || [command isEqualToString:@"scan_technology_start"])
        return BLT(@"Barrido iniciado.", @"Scan started.");
    if ([command isEqualToString:@"scan_cancel"])
        return BLT(@"Cancelación solicitada.", @"Cancellation requested.");
    if ([command isEqualToString:@"scan_recover"])
        return BLT(@"Recuperación solicitada.", @"Recovery requested.");
    return raw;
}

static NSDictionary *BLResultForUserInterface(NSDictionary *result, NSString *command) {
    if (![result isKindOfClass:NSDictionary.class]) return @{
        @"success": @NO,
        @"message": BLT(@"No se pudo completar la operación.", @"The operation could not be completed.")
    };
    NSMutableDictionary *safe = [result mutableCopy];
    NSString *message = BLFriendlyResultMessage(result, command ?: @"");
    if (message.length) safe[@"message"] = message;
    else [safe removeObjectForKey:@"message"];
    return safe;
}

@interface BLTelephonyManager ()
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedNRBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeNRBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingNRBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousNRBands;
@property (nonatomic, assign, readwrite) BOOL supports5G;
@property (nonatomic, copy, readwrite) NSString *radioAccessTechnology;
@property (nonatomic, copy, readwrite) NSString *servingBand;
@property (nonatomic, copy, readwrite) NSString *networkMode;
@property (nonatomic, copy) NSString *networkModeCode;
@property (nonatomic, copy, readwrite) NSString *statusText;
@property (nonatomic, copy, readwrite) NSString *detailText;
@property (nonatomic, assign, readwrite) BOOL hasReadState;
@property (nonatomic, assign, readwrite) BOOL hasRefreshedStatus;
@property (nonatomic, assign, readwrite) BOOL busy;
@property (nonatomic, assign) BOOL hasExplicitPendingBands;
@property (nonatomic, assign) BOOL hasExplicitPendingNRBands;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@property (nonatomic, copy) NSString *daemonSocketPath;
@end

@implementation BLTelephonyManager

+ (instancetype)sharedManager {
    static BLTelephonyManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] initPrivate]; });
    return manager;
}

- (instancetype)init { return BLTelephonyManager.sharedManager; }

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        BLBreadcrumb("manager init begin");
        signal(SIGPIPE, SIG_IGN);
        BLBreadcrumb("SIGPIPE ignored process-wide");
        _daemonQueue = dispatch_queue_create("com.gokuencinar.bandlock.daemon-client", DISPATCH_QUEUE_SERIAL);
        _daemonSocketPath = [BLDaemonSocketPath() copy];
        BLBreadcrumbf("manager socket path cached path=%s",
                      _daemonSocketPath.fileSystemRepresentation ?: "(null)");
        _supportedBands = @[];
        _activeBands = @[];
        id savedPendingBands = [NSUserDefaults.standardUserDefaults objectForKey:BLPendingBandsDefaultsKey];
        _pendingBands = [savedPendingBands isKindOfClass:[NSArray class]] ? BLSortedBands(savedPendingBands) : @[];
        _hasExplicitPendingBands = [savedPendingBands isKindOfClass:[NSArray class]];
        _previousBands = BLSortedBands([NSUserDefaults.standardUserDefaults arrayForKey:BLPreviousBandsDefaultsKey]);
        _supportedNRBands = @[];
        _activeNRBands = @[];
        id savedPendingNRBands = [NSUserDefaults.standardUserDefaults objectForKey:BLPendingNRBandsDefaultsKey];
        _pendingNRBands = [savedPendingNRBands isKindOfClass:[NSArray class]] ? BLSortedBands(savedPendingNRBands) : @[];
        _hasExplicitPendingNRBands = [savedPendingNRBands isKindOfClass:[NSArray class]];
        _previousNRBands = BLSortedBands([NSUserDefaults.standardUserDefaults arrayForKey:BLPreviousNRBandsDefaultsKey]);
        _supports5G = NO;
        _radioAccessTechnology = @"—";
        _servingBand = @"—";
        _networkMode = BLT(@"Sin consultar", @"Not queried");
        _networkModeCode = @"unknown";
        _statusText = BLT(@"Pulsa Actualizar", @"Tap Refresh");
        _detailText = BLT(@"Listo para actualizar.", @"Ready to refresh.");
        _hasReadState = NO;
        _hasRefreshedStatus = NO;
        _busy = NO;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(languageDidChange:) name:BLLanguageDidChangeNotification object:nil];
        BLBreadcrumb("manager init end");
    }
    return self;
}

- (void)languageDidChange:(NSNotification *)notification {
    if (!self.hasReadState) {
        self.networkMode = BLT(@"Sin consultar", @"Not queried");
        self.statusText = BLT(@"Pulsa Actualizar", @"Tap Refresh");
        self.detailText = BLT(@"Listo para actualizar.", @"Ready to refresh.");
    } else if ([self.networkModeCode isEqualToString:@"automatic"]) {
        self.networkMode = BLT(@"Automático", @"Automatic");
    } else if ([self.networkModeCode isEqualToString:@"2g"]) {
        self.networkMode = BLT(@"Solo 2G", @"2G only");
    } else if ([self.networkModeCode isEqualToString:@"lte"]) {
        self.networkMode = BLT(@"Solo LTE / 4G", @"LTE / 4G only");
    } else if ([self.networkModeCode isEqualToString:@"5g-auto"]) {
        self.networkMode = @"5G Auto";
    } else if ([self.networkModeCode isEqualToString:@"5g-on"]) {
        self.networkMode = @"5G On";
    } else if ([self.networkModeCode isEqualToString:@"5g-only"]) {
        self.networkMode = @"5G Only (SA)";
    } else if ([self.networkModeCode isEqualToString:@"unknown"]) {
        self.networkMode = BLT(@"No disponible", @"Unavailable");
    }
}

- (NSString *)socketPath {
    return self.daemonSocketPath ?: BLDaemonSocketRelativePath;
}

- (NSDictionary *)daemonUnavailableResult:(NSString *)detail {
    return @{@"success": @NO,
             @"message": BLT(@"No se pudo conectar con el servicio de BandLock. Inténtalo de nuevo.",
                              @"Could not connect to BandLock. Try again.")};
}

- (NSDictionary *)sendRequestSynchronously:(NSDictionary *)request {
    BLBreadcrumb("sync request enter");
    const char *fixedHome = getenv("CFFIXED_USER_HOME");
    const char *home = getenv("HOME");
    BLBreadcrumbf("env CFFIXED_USER_HOME=%s HOME=%s",
                  fixedHome && *fixedHome ? fixedHome : "(unset)",
                  home && *home ? home : "(unset)");
    NSError *jsonError = nil;
    BLBreadcrumb("json serialize begin");
    NSData *body = [NSJSONSerialization dataWithJSONObject:request ?: @{} options:0 error:&jsonError];
    if (!body) {
        BLBreadcrumb("json serialize failed");
        return [self daemonUnavailableResult:jsonError.localizedDescription];
    }
    BLBreadcrumbf("json serialize end bytes=%lu", (unsigned long)body.length);
    NSMutableData *wire = [body mutableCopy];
    [wire appendBytes:"\n" length:1];

    BLBreadcrumb("socket begin");
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        BLBreadcrumbf("socket failed errno=%d", errno);
        return [self daemonUnavailableResult:[NSString stringWithFormat:@"socket errno=%d", errno]];
    }
    BLBreadcrumbf("socket end fd=%d", fd);

    int one = 1;
    int noSigPipeRC = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
    BLBreadcrumbf("setsockopt SO_NOSIGPIPE rc=%d errno=%d", noSigPipeRC, noSigPipeRC == 0 ? 0 : errno);
    // Band changes can take several seconds to settle in CommCenter even
    // after the private API call itself returns. Keep the IPC timeout above
    // the daemon's bounded verification window so a valid late readback does
    // not look like a client-side transport failure.
    struct timeval timeout = {.tv_sec = 30, .tv_usec = 0};
    int recvTimeoutRC = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    BLBreadcrumbf("setsockopt SO_RCVTIMEO rc=%d errno=%d", recvTimeoutRC, recvTimeoutRC == 0 ? 0 : errno);
    int sendTimeoutRC = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
    BLBreadcrumbf("setsockopt SO_SNDTIMEO rc=%d errno=%d", sendTimeoutRC, sendTimeoutRC == 0 ? 0 : errno);

    NSString *pathString = [self socketPath];
    const char *path = pathString.fileSystemRepresentation;
    BLBreadcrumbf("socket path path=%s len=%lu uid=%d euid=%d",
                  path ?: "(null)",
                  path ? (unsigned long)strlen(path) : 0UL,
                  (int)getuid(),
                  (int)geteuid());
    if (!path || strlen(path) >= sizeof(((struct sockaddr_un *)0)->sun_path)) {
        BLBreadcrumb("socket path invalid");
        close(fd);
        return [self daemonUnavailableResult:@"socket-path-invalid"];
    }

    struct stat socketStat;
    memset(&socketStat, 0, sizeof(socketStat));
    int statRC = stat(path, &socketStat);
    BLBreadcrumbf("socket stat rc=%d errno=%d mode=%o uid=%d gid=%d",
                  statRC,
                  statRC == 0 ? 0 : errno,
                  statRC == 0 ? (unsigned int)(socketStat.st_mode & 07777) : 0U,
                  statRC == 0 ? (int)socketStat.st_uid : -1,
                  statRC == 0 ? (int)socketStat.st_gid : -1);

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strlcpy(address.sun_path, path, sizeof(address.sun_path));

    int connected = -1;
    for (NSInteger attempt = 0; attempt < 30; attempt++) {
        BLBreadcrumbf("connect begin attempt=%ld", (long)attempt + 1);
        connected = connect(fd, (struct sockaddr *)&address, sizeof(address));
        BLBreadcrumbf("connect end attempt=%ld rc=%d errno=%d",
                      (long)attempt + 1,
                      connected,
                      connected == 0 ? 0 : errno);
        if (connected == 0) break;
        if (errno != ENOENT && errno != ECONNREFUSED) break;
        usleep(200000);
    }
    if (connected != 0) {
        int savedErrno = errno;
        BLBreadcrumbf("connect failed final errno=%d", savedErrno);
        close(fd);
        return [self daemonUnavailableResult:[NSString stringWithFormat:@"connect-failed:%d", savedErrno]];
    }

    const uint8_t *bytes = wire.bytes;
    NSUInteger remaining = wire.length;
    BLBreadcrumbf("write begin bytes=%lu", (unsigned long)remaining);
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        BLBreadcrumbf("write chunk rc=%ld errno=%d remaining-before=%lu",
                      (long)written,
                      written > 0 ? 0 : errno,
                      (unsigned long)remaining);
        if (written <= 0) {
            int savedErrno = errno;
            close(fd);
            return [self daemonUnavailableResult:[NSString stringWithFormat:@"send-failed:%d", savedErrno]];
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    BLBreadcrumb("write end");

    NSMutableData *responseData = [NSMutableData data];
    uint8_t buffer[4096];
    BLBreadcrumb("read begin");
    while (responseData.length < 131072) {
        ssize_t count = read(fd, buffer, sizeof(buffer));
        BLBreadcrumbf("read chunk rc=%ld errno=%d total-before=%lu",
                      (long)count,
                      count >= 0 ? 0 : errno,
                      (unsigned long)responseData.length);
        if (count < 0) {
            int savedErrno = errno;
            close(fd);
            return [self daemonUnavailableResult:[NSString stringWithFormat:@"receive-failed:%d", savedErrno]];
        }
        if (count == 0) break;
        [responseData appendBytes:buffer length:(NSUInteger)count];
        if (memchr(buffer, '\n', (size_t)count)) break;
    }
    BLBreadcrumbf("read end bytes=%lu", (unsigned long)responseData.length);
    close(fd);
    BLBreadcrumb("socket closed");

    if (!responseData.length) {
        BLBreadcrumb("empty response");
        return [self daemonUnavailableResult:@"empty-response"];
    }

    BLBreadcrumb("json parse begin");
    NSRange newline = [responseData rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, responseData.length)];
    if (newline.location != NSNotFound) responseData.length = newline.location;
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
    if (![result isKindOfClass:[NSDictionary class]]) {
        BLBreadcrumb("json parse invalid dictionary");
        return [self daemonUnavailableResult:@"invalid-response"];
    }
    BLBreadcrumb("json parse end dictionary");
    BLBreadcrumb("sync request return");
    return result;
}

- (void)sendRequest:(NSDictionary *)request completion:(void (^)(NSDictionary *result))completion {
    BLBreadcrumb("sendRequest enter");
    if (self.busy) {
        BLBreadcrumb("sendRequest rejected busy");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                BLBreadcrumb("busy completion on main");
                completion(@{@"success": @NO, @"message": BLT(@"Hay una operación en curso.", @"An operation is already running.")});
            });
        }
        return;
    }
    self.busy = YES;
    BLBreadcrumb("sendRequest busy set");
    dispatch_async(self.daemonQueue, ^{
        BLBreadcrumb("daemon queue enter");
        NSDictionary *result = nil;
        @try {
            result = [self sendRequestSynchronously:request];
        } @catch (NSException *exception) {
            BLBreadcrumbf("sync request exception name=%s reason=%s",
                          exception.name.UTF8String ?: "(null)",
                          exception.reason.UTF8String ?: "(null)");
            result = [self daemonUnavailableResult:[NSString stringWithFormat:@"Client exception: %@", exception.reason ?: exception.name]];
        }
        BLBreadcrumb("daemon queue sync request returned");
        dispatch_async(dispatch_get_main_queue(), ^{
            BLBreadcrumb("main queue completion enter");
            self.busy = NO;
            BLBreadcrumb("main queue busy cleared");
            if (completion) {
                @try {
                    BLBreadcrumb("client completion begin");
                    NSString *command = [request[@"cmd"] isKindOfClass:NSString.class] ? request[@"cmd"] : @"";
                    completion(BLResultForUserInterface(result, command));
                    BLBreadcrumb("client completion end");
                } @catch (NSException *exception) {
                    BLBreadcrumbf("client completion exception name=%s reason=%s",
                                  exception.name.UTF8String ?: "(null)",
                                  exception.reason.UTF8String ?: "(null)");
                    self.statusText = BLT(@"No disponible", @"Unavailable");
                    self.detailText = BLT(@"No se pudo completar la operación.", @"The operation could not be completed.");
                }
            }
            BLBreadcrumb("main queue completion end");
        });
        BLBreadcrumb("main queue completion scheduled");
    });
    BLBreadcrumb("sendRequest queued");
}

- (void)consumeStatusResult:(NSDictionary *)result resetPending:(BOOL)resetPending {
    BLBreadcrumb("consume status begin");
    id supportedValue = result[@"supported"];
    BLBreadcrumbf("consume supported class=%s", object_getClassName(supportedValue));
    NSArray<NSNumber *> *supported = [supportedValue isKindOfClass:[NSArray class]] ? [(NSArray *)supportedValue copy] : @[];
    BLBreadcrumbf("consume supported validated count=%lu", (unsigned long)supported.count);
    self.supportedBands = supported;
    BLBreadcrumb("consume supported assigned");

    id activeValue = result[@"active"];
    BLBreadcrumbf("consume active class=%s", object_getClassName(activeValue));
    NSArray<NSNumber *> *active = [activeValue isKindOfClass:[NSArray class]] ? [(NSArray *)activeValue copy] : @[];
    BLBreadcrumbf("consume active validated count=%lu", (unsigned long)active.count);
    self.activeBands = active;
    BLBreadcrumb("consume active assigned");
    id supportedNRValue = result[@"supported_nr"];
    self.supportedNRBands = [supportedNRValue isKindOfClass:[NSArray class]] ? BLSortedBands(supportedNRValue) : @[];
    id activeNRValue = result[@"active_nr"];
    self.activeNRBands = [activeNRValue isKindOfClass:[NSArray class]] ? BLSortedBands(activeNRValue) : @[];
    self.supports5G = !BLDeviceIsKnownLTEOnly() &&
        ([result[@"supports_5g"] boolValue] || self.supportedNRBands.count > 0);
    if (!self.supports5G) { self.supportedNRBands = @[]; self.activeNRBands = @[]; }
    self.radioAccessTechnology = [result[@"rat"] isKindOfClass:[NSString class]] ? result[@"rat"] : @"—";
    BLBreadcrumb("consume rat assigned");
    self.servingBand = [result[@"serving"] isKindOfClass:[NSString class]] ? result[@"serving"] : @"—";
    BLBreadcrumb("consume serving assigned");
    NSString *modeCode = [result[@"mode_code"] isKindOfClass:[NSString class]] ? result[@"mode_code"] : nil;
    if (!self.supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"unknown";
    self.networkModeCode = modeCode ?: @"other";
    if ([modeCode isEqualToString:@"automatic"]) self.networkMode = BLT(@"Automático", @"Automatic");
    else if ([modeCode isEqualToString:@"2g"]) self.networkMode = BLT(@"Solo 2G", @"2G only");
    else if ([modeCode isEqualToString:@"lte"]) self.networkMode = BLT(@"Solo LTE / 4G", @"LTE / 4G only");
    else if ([modeCode isEqualToString:@"3g"]) self.networkMode = BLT(@"Solo 3G", @"3G only");
    else if ([modeCode isEqualToString:@"5g-auto"]) self.networkMode = @"5G Auto";
    else if ([modeCode isEqualToString:@"5g-on"]) self.networkMode = @"5G On";
    else if ([modeCode isEqualToString:@"5g-only"]) self.networkMode = @"5G Only (SA)";
    else if ([modeCode isEqualToString:@"unknown"]) self.networkMode = BLT(@"No disponible", @"Unavailable");
    else self.networkMode = [result[@"mode"] isKindOfClass:[NSString class]] ? result[@"mode"] : BLT(@"No disponible", @"Unavailable");
    BLBreadcrumb("consume mode assigned");
    self.hasReadState = YES;
    BLBreadcrumb("consume hasReadState assigned");
    if (resetPending) {
        _pendingBands = [self.activeBands copy];
        _pendingNRBands = [self.activeNRBands copy];
        self.hasExplicitPendingBands = NO;
        self.hasExplicitPendingNRBands = NO;
        [NSUserDefaults.standardUserDefaults removeObjectForKey:BLPendingBandsDefaultsKey];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:BLPendingNRBandsDefaultsKey];
    } else {
        if (!self.hasExplicitPendingBands) _pendingBands = [self.activeBands copy];
        if (!self.hasExplicitPendingNRBands) _pendingNRBands = [self.activeNRBands copy];
    }
    BLBreadcrumb("consume pending assigned");
    BLBreadcrumb("consume status end");
}

- (void)finishResult:(NSDictionary *)result successMessage:(NSString *)successMessage completion:(BLActionCompletion)completion {
    BLBreadcrumb("finish result begin");
    BOOL success = [result[@"success"] boolValue];
    NSString *daemonMessage = [result[@"message"] isKindOfClass:[NSString class]] ? result[@"message"] : nil;
    NSString *message = success ? (successMessage ?: daemonMessage ?: BLT(@"Operación completada.", @"Operation completed."))
                                : (daemonMessage ?: BLT(@"Operación fallida.", @"Operation failed."));
    self.statusText = success ? BLT(@"Listo", @"Ready") : BLT(@"No disponible", @"Unavailable");
    self.detailText = message ?: @"";
    if (completion) {
        BLBreadcrumb("action completion begin");
        completion(success, self.detailText);
        BLBreadcrumb("action completion end");
    }
    BLBreadcrumb("finish result end");
}

- (void)refreshWithCompletion:(BLActionCompletion)completion {
    BLBreadcrumb("refreshWithCompletion enter");
    self.statusText = BLT(@"Actualizando…", @"Refreshing…");
    [self sendRequest:@{@"cmd": @"status"} completion:^(NSDictionary *result) {
        BLBreadcrumb("refresh result block enter");
        if ([result[@"success"] boolValue]) [self consumeStatusResult:result resetPending:NO];
        self.hasRefreshedStatus = YES;
        [self finishResult:result successMessage:BLT(@"Estado actualizado.", @"Status updated.") completion:completion];
        BLBreadcrumb("refresh result block end");
    }];
    BLBreadcrumb("refreshWithCompletion return");
}

- (void)setPendingBands:(NSArray<NSNumber *> *)bands {
    _pendingBands = [BLSortedBands(bands) copy];
    self.hasExplicitPendingBands = YES;
    [NSUserDefaults.standardUserDefaults setObject:_pendingBands forKey:BLPendingBandsDefaultsKey];
    self.statusText = BLT(@"Selección preparada", @"Selection prepared");
    self.detailText = BLBandList(_pendingBands);
}

- (void)setPendingNRBands:(NSArray<NSNumber *> *)bands {
    _pendingNRBands = [BLSortedBands(bands) copy];
    self.hasExplicitPendingNRBands = YES;
    [NSUserDefaults.standardUserDefaults setObject:_pendingNRBands forKey:BLPendingNRBandsDefaultsKey];
    self.statusText = BLT(@"Selección 5G preparada", @"5G selection prepared");
    self.detailText = BLNRBandList(_pendingNRBands);
}

- (void)setNetworkMode:(NSString *)mode completion:(BLActionCompletion)completion {
    [self sendRequest:@{@"cmd": @"rat", @"mode": mode ?: @"automatic"} completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) [self consumeStatusResult:result resetPending:NO];
        [self finishResult:result successMessage:BLT(@"Modo de red actualizado.", @"Network mode updated.") completion:completion];
    }];
}

- (void)setNetworkModeAutomatic:(BLActionCompletion)completion { [self setNetworkMode:@"automatic" completion:completion]; }
- (void)setNetworkModeLTEOnly:(BLActionCompletion)completion { [self setNetworkMode:@"lte" completion:completion]; }
- (void)setNetworkMode5GAuto:(BLActionCompletion)completion { [self setNetworkMode:@"5g-auto" completion:completion]; }
- (void)setNetworkMode5GOn:(BLActionCompletion)completion { [self setNetworkMode:@"5g-on" completion:completion]; }
- (void)setNetworkMode5GOnly:(BLActionCompletion)completion { [self setNetworkMode:@"5g-only" completion:completion]; }

- (void)applyBands:(NSArray<NSNumber *> *)bands savePrevious:(BOOL)savePrevious completion:(BLActionCompletion)completion {
    NSArray<NSNumber *> *clean = BLSortedBands(bands);
    if (!clean.count) {
        if (completion) completion(NO, BLT(@"Selecciona al menos una banda LTE.", @"Select at least one LTE band."));
        return;
    }
    if (savePrevious && self.activeBands.count) {
        self.previousBands = self.activeBands;
        [NSUserDefaults.standardUserDefaults setObject:self.previousBands forKey:BLPreviousBandsDefaultsKey];
    }
    [self sendRequest:@{@"cmd": @"apply", @"bands": clean} completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) {
            NSArray *previous = BLSortedBands(result[@"previous"]);
            if (savePrevious && previous.count) {
                self.previousBands = previous;
                [NSUserDefaults.standardUserDefaults setObject:previous forKey:BLPreviousBandsDefaultsKey];
            }
            [self consumeStatusResult:result resetPending:NO];
            _pendingBands = [self.activeBands copy];
            self.hasExplicitPendingBands = NO;
            [NSUserDefaults.standardUserDefaults removeObjectForKey:BLPendingBandsDefaultsKey];
        }
        [self finishResult:result successMessage:BLT(@"Selección LTE aplicada.", @"LTE selection applied.") completion:completion];
    }];
}

- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion { [self applyBands:self.pendingBands savePrevious:YES completion:completion]; }

- (void)applyNRBands:(NSArray<NSNumber *> *)bands savePrevious:(BOOL)savePrevious completion:(BLActionCompletion)completion {
    NSArray<NSNumber *> *clean = BLSortedBands(bands);
    if (!clean.count) {
        if (completion) completion(NO, BLT(@"Selecciona al menos una banda 5G NR.", @"Select at least one 5G NR band."));
        return;
    }
    if (savePrevious && self.activeNRBands.count) {
        self.previousNRBands = self.activeNRBands;
        [NSUserDefaults.standardUserDefaults setObject:self.previousNRBands forKey:BLPreviousNRBandsDefaultsKey];
    }
    [self sendRequest:@{@"cmd": @"apply_nr", @"bands": clean} completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) {
            NSArray *previous = BLSortedBands(result[@"previous_nr"]);
            if (savePrevious && previous.count) {
                self.previousNRBands = previous;
                [NSUserDefaults.standardUserDefaults setObject:previous forKey:BLPreviousNRBandsDefaultsKey];
            }
            [self consumeStatusResult:result resetPending:NO];
            _pendingNRBands = [self.activeNRBands copy];
            self.hasExplicitPendingNRBands = NO;
            [NSUserDefaults.standardUserDefaults removeObjectForKey:BLPendingNRBandsDefaultsKey];
        }
        [self finishResult:result successMessage:BLT(@"Selección 5G NR aplicada.", @"5G NR selection applied.") completion:completion];
    }];
}

- (void)applyPendingNRBandsWithCompletion:(BLActionCompletion)completion { [self applyNRBands:self.pendingNRBands savePrevious:YES completion:completion]; }

- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.previousBands.count) {
        if (completion) completion(NO, BLT(@"No hay una selección anterior guardada.", @"No previous selection is saved."));
        return;
    }
    [self applyBands:self.previousBands savePrevious:NO completion:completion];
}

- (void)restorePreviousNRBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.previousNRBands.count) {
        if (completion) completion(NO, BLT(@"No hay una selección 5G anterior guardada.", @"No previous 5G selection is saved."));
        return;
    }
    [self applyNRBands:self.previousNRBands savePrevious:NO completion:completion];
}

- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.supportedBands.count) {
        if (completion) completion(NO, BLT(@"Pulsa Actualizar estado primero.", @"Tap Refresh status first."));
        return;
    }
    [self applyBands:self.supportedBands savePrevious:YES completion:completion];
}

- (void)restoreAllSupportedNRBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.supportedNRBands.count) {
        if (completion) completion(NO, BLT(@"Este iPhone no reporta bandas 5G NR configurables.", @"This iPhone does not report configurable 5G NR bands."));
        return;
    }
    [self applyNRBands:self.supportedNRBands savePrevious:YES completion:completion];
}

- (void)openFieldTestWithCompletion:(BLActionCompletion)completion {
    [self sendRequest:@{@"cmd": @"fieldtest"} completion:^(NSDictionary *result) {
        [self finishResult:result
            successMessage:BLT(@"Field Test solicitado.", @"Field Test requested.")
               completion:completion];
    }];
}

- (void)signalProbeWithCompletion:(void (^)(NSDictionary *result))completion {
    [self sendRequest:@{@"cmd": @"signal_probe"} completion:completion];
}

- (void)startSignalScanWithCompletion:(void (^)(NSDictionary *result))completion {
    [self sendRequest:@{@"cmd": @"scan_start"} completion:completion];
}

- (void)startPassiveSignalObservationForRAT:(NSString *)rat
                               completion:(void (^)(NSDictionary *result))completion {
    if (![@[@"AUTO", @"2G", @"3G", @"LTE", @"NR"] containsObject:rat]) {
        if (completion) completion(@{@"success": @NO, @"message": @"Tecnología no válida"});
        return;
    }
    [self sendRequest:@{@"cmd": @"scan_observe_start", @"rat": rat} completion:completion];
}

- (void)startTechnologySignalScanForRAT:(NSString *)rat
                              completion:(void (^)(NSDictionary *result))completion {
    if (![@[@"2G", @"3G", @"LTE", @"NR"] containsObject:rat]) {
        if (completion) completion(@{@"success": @NO, @"message": @"Tecnología no válida"});
        return;
    }
    [self sendRequest:@{@"cmd": @"scan_technology_start", @"rat": rat} completion:completion];
}

- (void)signalScanStatusWithCompletion:(void (^)(NSDictionary *result))completion {
    [self sendRequest:@{@"cmd": @"scan_status"} completion:completion];
}

- (void)startTechnologySignalScanForRAT:(NSString *)rat country:(NSString *)iso
                            targetBands:(NSArray<NSNumber *> *)bands
                      targetFrequencies:(NSArray<NSNumber *> *)frequencies
                             completion:(void (^)(NSDictionary *result))completion {
    if (![@[@"2G", @"3G", @"LTE", @"NR"] containsObject:rat] ||
        ![iso isKindOfClass:NSString.class] || iso.length != 2 ||
        ![bands isKindOfClass:NSArray.class] || bands.count > 64 ||
        ![frequencies isKindOfClass:NSArray.class] || frequencies.count > 64 ||
        (!bands.count && !frequencies.count)) {
        if (completion) completion(@{@"success": @NO, @"message": @"País, tecnología o frecuencias no válidos"});
        return;
    }
    [self sendRequest:@{@"cmd": @"scan_technology_start", @"rat": rat,
                        @"country_iso": iso, @"target_bands": bands,
                        @"target_frequencies_mhz": frequencies} completion:completion];
}

- (void)cancelSignalScanWithCompletion:(void (^)(NSDictionary *result))completion {
    [self sendRequest:@{@"cmd": @"scan_cancel"} completion:completion];
}

- (void)recoverSignalScanWithCompletion:(void (^)(NSDictionary *result))completion {
    [self sendRequest:@{@"cmd": @"scan_recover"} completion:completion];
}

@end
