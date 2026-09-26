#import "BLTelephonyManager.h"
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
static NSString * const BLDaemonSocketRelativePath = @"/tmp/com.gokuencinar.bandlockd.sock";

static NSString *BLRootHidePhysicalRootFromEnvironment(void) {
    const char *keys[] = {"CFFIXED_USER_HOME", "HOME"};
    NSString *suffix = @"/var/mobile";
    for (NSUInteger i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
        const char *rawValue = getenv(keys[i]);
        if (!rawValue || !*rawValue) continue;
        NSString *home = [NSString stringWithUTF8String:rawValue];
        if (!home.length || ![home hasSuffix:suffix]) continue;
        NSString *root = [home substringToIndex:home.length - suffix.length];
        if ([root containsString:@"/.jbroot-"]) return root;
    }
    return nil;
}

static NSString *BLDaemonSocketPath(void) {
    NSString *physicalRoot = BLRootHidePhysicalRootFromEnvironment();
    if (physicalRoot.length) return [physicalRoot stringByAppendingString:BLDaemonSocketRelativePath];
    return BLDaemonSocketRelativePath;
}

@interface BLTelephonyManager ()
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousBands;
@property (nonatomic, copy, readwrite) NSString *radioAccessTechnology;
@property (nonatomic, copy, readwrite) NSString *servingBand;
@property (nonatomic, copy, readwrite) NSString *networkMode;
@property (nonatomic, copy) NSString *networkModeCode;
@property (nonatomic, copy, readwrite) NSString *statusText;
@property (nonatomic, copy, readwrite) NSString *detailText;
@property (nonatomic, assign, readwrite) BOOL hasReadState;
@property (nonatomic, assign, readwrite) BOOL busy;
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
        _pendingBands = @[];
        _previousBands = BLSortedBands([NSUserDefaults.standardUserDefaults arrayForKey:BLPreviousBandsDefaultsKey]);
        _radioAccessTechnology = @"—";
        _servingBand = @"—";
        _networkMode = BLT(@"Sin consultar", @"Not queried");
        _networkModeCode = @"unknown";
        _statusText = BLT(@"Pulsa Actualizar", @"Tap Refresh");
        _detailText = BLT(@"BandLock usa un daemon separado para CoreTelephony. La app principal no ejecuta procesos ni APIs privadas del módem.", @"BandLock uses a separate daemon for CoreTelephony. The main app does not spawn processes or execute modem private APIs.");
        _hasReadState = NO;
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
        self.detailText = BLT(@"BandLock usa un daemon separado para CoreTelephony. La app principal no ejecuta procesos ni APIs privadas del módem.", @"BandLock uses a separate daemon for CoreTelephony. The main app does not spawn processes or execute modem private APIs.");
    } else if ([self.networkModeCode isEqualToString:@"automatic"]) {
        self.networkMode = BLT(@"Automático", @"Automatic");
    } else if ([self.networkModeCode isEqualToString:@"lte"]) {
        self.networkMode = BLT(@"Solo LTE / 4G", @"LTE / 4G only");
    } else if ([self.networkModeCode isEqualToString:@"unknown"]) {
        self.networkMode = BLT(@"No disponible", @"Unavailable");
    }
}

- (NSString *)socketPath {
    return self.daemonSocketPath ?: BLDaemonSocketRelativePath;
}

- (NSDictionary *)daemonUnavailableResult:(NSString *)detail {
    return @{@"success": @NO,
             @"message": detail.length ? detail : BLT(@"BandLockDaemon no está disponible. Reinstala BandLock o reinicia el jailbreak.", @"BandLockDaemon is unavailable. Reinstall BandLock or restart the jailbreak.")};
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
        return [self daemonUnavailableResult:BLT(@"La ruta del socket del daemon no es válida.", @"The daemon socket path is invalid.")];
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
    for (NSInteger attempt = 0; attempt < 5; attempt++) {
        BLBreadcrumbf("connect begin attempt=%ld", (long)attempt + 1);
        connected = connect(fd, (struct sockaddr *)&address, sizeof(address));
        BLBreadcrumbf("connect end attempt=%ld rc=%d errno=%d",
                      (long)attempt + 1,
                      connected,
                      connected == 0 ? 0 : errno);
        if (connected == 0) break;
        if (errno != ENOENT && errno != ECONNREFUSED) break;
        usleep(150000);
    }
    if (connected != 0) {
        int savedErrno = errno;
        BLBreadcrumbf("connect failed final errno=%d", savedErrno);
        close(fd);
        return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"No se pudo conectar con BandLockDaemon (errno %d).", @"Could not connect to BandLockDaemon (errno %d)."), savedErrno]];
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
            return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"La comunicación con el daemon falló al enviar (errno %d).", @"Daemon communication failed while sending (errno %d)."), savedErrno]];
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
            return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"La respuesta del daemon falló (errno %d).", @"Daemon response failed (errno %d)."), savedErrno]];
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
        return [self daemonUnavailableResult:BLT(@"BandLockDaemon cerró la conexión sin responder. Si CoreTelephony hizo fallar el daemon, la app principal permanece abierta.", @"BandLockDaemon closed the connection without replying. If CoreTelephony crashed the daemon, the main app remains open.")];
    }

    BLBreadcrumb("json parse begin");
    NSRange newline = [responseData rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, responseData.length)];
    if (newline.location != NSNotFound) responseData.length = newline.location;
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
    if (![result isKindOfClass:[NSDictionary class]]) {
        BLBreadcrumb("json parse invalid dictionary");
        NSString *raw = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] ?: @"—";
        return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"Respuesta inválida del daemon: %@", @"Invalid daemon response: %@"), raw]];
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
                    completion(result ?: @{@"success": @NO, @"message": @"No result"});
                    BLBreadcrumb("client completion end");
                } @catch (NSException *exception) {
                    BLBreadcrumbf("client completion exception name=%s reason=%s",
                                  exception.name.UTF8String ?: "(null)",
                                  exception.reason.UTF8String ?: "(null)");
                    self.statusText = BLT(@"Error de cliente", @"Client error");
                    self.detailText = [NSString stringWithFormat:@"Client exception: %@", exception.reason ?: exception.name];
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
    self.radioAccessTechnology = [result[@"rat"] isKindOfClass:[NSString class]] ? result[@"rat"] : @"—";
    BLBreadcrumb("consume rat assigned");
    self.servingBand = [result[@"serving"] isKindOfClass:[NSString class]] ? result[@"serving"] : @"—";
    BLBreadcrumb("consume serving assigned");
    NSString *modeCode = [result[@"mode_code"] isKindOfClass:[NSString class]] ? result[@"mode_code"] : nil;
    self.networkModeCode = modeCode ?: @"other";
    if ([modeCode isEqualToString:@"automatic"]) self.networkMode = BLT(@"Automático", @"Automatic");
    else if ([modeCode isEqualToString:@"lte"]) self.networkMode = BLT(@"Solo LTE / 4G", @"LTE / 4G only");
    else if ([modeCode isEqualToString:@"unknown"]) self.networkMode = BLT(@"No disponible", @"Unavailable");
    else self.networkMode = [result[@"mode"] isKindOfClass:[NSString class]] ? result[@"mode"] : BLT(@"No disponible", @"Unavailable");
    BLBreadcrumb("consume mode assigned");
    self.hasReadState = YES;
    BLBreadcrumb("consume hasReadState assigned");
    if (resetPending || !_pendingBands.count) _pendingBands = [self.activeBands copy];
    BLBreadcrumb("consume pending assigned");
    BLBreadcrumb("consume status end");
}

- (void)finishResult:(NSDictionary *)result successMessage:(NSString *)successMessage completion:(BLActionCompletion)completion {
    BLBreadcrumb("finish result begin");
    BOOL success = [result[@"success"] boolValue];
    NSString *daemonMessage = [result[@"message"] isKindOfClass:[NSString class]] ? result[@"message"] : nil;
    NSString *message = success ? (successMessage ?: daemonMessage ?: BLT(@"Operación completada.", @"Operation completed."))
                                : (daemonMessage ?: BLT(@"Operación fallida.", @"Operation failed."));
    self.statusText = success ? BLT(@"Listo", @"Ready") : BLT(@"Error del daemon", @"Daemon error");
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
    self.statusText = BLT(@"Consultando daemon…", @"Querying daemon…");
    [self sendRequest:@{@"cmd": @"status"} completion:^(NSDictionary *result) {
        BLBreadcrumb("refresh result block enter");
        if ([result[@"success"] boolValue]) [self consumeStatusResult:result resetPending:YES];
        [self finishResult:result successMessage:BLT(@"Estado del módem actualizado.", @"Modem state updated.") completion:completion];
        BLBreadcrumb("refresh result block end");
    }];
    BLBreadcrumb("refreshWithCompletion return");
}

- (void)setPendingBands:(NSArray<NSNumber *> *)bands {
    _pendingBands = [BLSortedBands(bands) copy];
    self.statusText = BLT(@"Selección preparada", @"Selection prepared");
    self.detailText = BLBandList(_pendingBands);
}

- (void)setNetworkMode:(NSString *)mode completion:(BLActionCompletion)completion {
    [self sendRequest:@{@"cmd": @"rat", @"mode": mode ?: @"automatic"} completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) [self consumeStatusResult:result resetPending:NO];
        [self finishResult:result successMessage:BLT(@"Modo de red actualizado.", @"Network mode updated.") completion:completion];
    }];
}

- (void)setNetworkModeAutomatic:(BLActionCompletion)completion { [self setNetworkMode:@"automatic" completion:completion]; }
- (void)setNetworkModeLTEOnly:(BLActionCompletion)completion { [self setNetworkMode:@"lte" completion:completion]; }

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
            [self consumeStatusResult:result resetPending:YES];
        }
        [self finishResult:result successMessage:BLT(@"Selección LTE aplicada.", @"LTE selection applied.") completion:completion];
    }];
}

- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion { [self applyBands:self.pendingBands savePrevious:YES completion:completion]; }

- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.previousBands.count) {
        if (completion) completion(NO, BLT(@"No hay una selección anterior guardada.", @"No previous selection is saved."));
        return;
    }
    [self applyBands:self.previousBands savePrevious:NO completion:completion];
}

- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.supportedBands.count) {
        if (completion) completion(NO, BLT(@"Pulsa Actualizar estado primero.", @"Tap Refresh status first."));
        return;
    }
    [self applyBands:self.supportedBands savePrevious:YES completion:completion];
}

- (void)openFieldTestWithCompletion:(BLActionCompletion)completion {
    [self sendRequest:@{@"cmd": @"fieldtest"} completion:^(NSDictionary *result) {
        [self finishResult:result
            successMessage:BLT(@"Field Test solicitado.", @"Field Test requested.")
               completion:completion];
    }];
}

@end
