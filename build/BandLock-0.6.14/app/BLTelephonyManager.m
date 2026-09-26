#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

static NSString * const BLPreviousBandsDefaultsKey = @"BandLockPreviousBands";
static NSString * const BLDaemonSocketPath = @"/tmp/bandlockd.sock";

@interface BLTelephonyManager ()
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousBands;
@property (nonatomic, copy, readwrite) NSString *radioAccessTechnology;
@property (nonatomic, copy, readwrite) NSString *servingBand;
@property (nonatomic, copy, readwrite) NSString *networkMode;
@property (nonatomic, copy, readwrite) NSString *statusText;
@property (nonatomic, copy, readwrite) NSString *detailText;
@property (nonatomic, assign, readwrite) BOOL hasReadState;
@property (nonatomic, assign, readwrite) BOOL busy;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
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
        _daemonQueue = dispatch_queue_create("com.gokuencinar.bandlock.daemon-client", DISPATCH_QUEUE_SERIAL);
        _supportedBands = @[];
        _activeBands = @[];
        _pendingBands = @[];
        _previousBands = BLSortedBands([NSUserDefaults.standardUserDefaults arrayForKey:BLPreviousBandsDefaultsKey]);
        _radioAccessTechnology = @"—";
        _servingBand = @"—";
        _networkMode = BLT(@"Sin consultar", @"Not queried");
        _statusText = BLT(@"Pulsa Actualizar", @"Tap Refresh");
        _detailText = BLT(@"BandLock usa un daemon separado para CoreTelephony. La app principal no ejecuta procesos ni APIs privadas del módem.", @"BandLock uses a separate daemon for CoreTelephony. The main app does not spawn processes or execute modem private APIs.");
        _hasReadState = NO;
        _busy = NO;
    }
    return self;
}

- (NSString *)socketPath {
    return BLDaemonSocketPath;
}

- (NSDictionary *)daemonUnavailableResult:(NSString *)detail {
    return @{@"success": @NO,
             @"message": detail.length ? detail : BLT(@"BandLockDaemon no está disponible. Reinstala BandLock 0.6.3 o reinicia el jailbreak.", @"BandLockDaemon is unavailable. Reinstall BandLock 0.6.3 or restart the jailbreak.")};
}

- (NSDictionary *)sendRequestSynchronously:(NSDictionary *)request {
    NSError *jsonError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:request ?: @{} options:0 error:&jsonError];
    if (!body) return [self daemonUnavailableResult:jsonError.localizedDescription];
    NSMutableData *wire = [body mutableCopy];
    [wire appendBytes:"\n" length:1];

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return [self daemonUnavailableResult:[NSString stringWithFormat:@"socket errno=%d", errno]];

    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
    struct timeval timeout = {.tv_sec = 5, .tv_usec = 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    NSString *pathString = [self socketPath];
    const char *path = pathString.fileSystemRepresentation;
    if (!path || strlen(path) >= sizeof(((struct sockaddr_un *)0)->sun_path)) {
        close(fd);
        return [self daemonUnavailableResult:BLT(@"La ruta del socket del daemon no es válida.", @"The daemon socket path is invalid.")];
    }

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strlcpy(address.sun_path, path, sizeof(address.sun_path));

    int connected = -1;
    for (NSInteger attempt = 0; attempt < 5; attempt++) {
        connected = connect(fd, (struct sockaddr *)&address, sizeof(address));
        if (connected == 0) break;
        if (errno != ENOENT && errno != ECONNREFUSED) break;
        usleep(150000);
    }
    if (connected != 0) {
        int savedErrno = errno;
        close(fd);
        return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"No se pudo conectar con BandLockDaemon (errno %d).", @"Could not connect to BandLockDaemon (errno %d)."), savedErrno]];
    }

    const uint8_t *bytes = wire.bytes;
    NSUInteger remaining = wire.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written <= 0) {
            int savedErrno = errno;
            close(fd);
            return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"La comunicación con el daemon falló al enviar (errno %d).", @"Daemon communication failed while sending (errno %d)."), savedErrno]];
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }

    NSMutableData *responseData = [NSMutableData data];
    uint8_t buffer[4096];
    while (responseData.length < 131072) {
        ssize_t count = read(fd, buffer, sizeof(buffer));
        if (count < 0) {
            int savedErrno = errno;
            close(fd);
            return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"La respuesta del daemon falló (errno %d).", @"Daemon response failed (errno %d)."), savedErrno]];
        }
        if (count == 0) break;
        [responseData appendBytes:buffer length:(NSUInteger)count];
        if (memchr(buffer, '\n', (size_t)count)) break;
    }
    close(fd);

    if (!responseData.length) {
        return [self daemonUnavailableResult:BLT(@"BandLockDaemon cerró la conexión sin responder. Si CoreTelephony hizo fallar el daemon, la app principal permanece abierta.", @"BandLockDaemon closed the connection without replying. If CoreTelephony crashed the daemon, the main app remains open.")];
    }

    NSRange newline = [responseData rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, responseData.length)];
    if (newline.location != NSNotFound) responseData.length = newline.location;
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
    if (![result isKindOfClass:[NSDictionary class]]) {
        NSString *raw = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] ?: @"—";
        return [self daemonUnavailableResult:[NSString stringWithFormat:BLT(@"Respuesta inválida del daemon: %@", @"Invalid daemon response: %@"), raw]];
    }
    return result;
}

- (void)sendRequest:(NSDictionary *)request completion:(void (^)(NSDictionary *result))completion {
    if (self.busy) {
        if (completion) completion(@{@"success": @NO, @"message": BLT(@"Hay una operación en curso.", @"An operation is already running.")});
        return;
    }
    self.busy = YES;
    dispatch_async(self.daemonQueue, ^{
        NSDictionary *result = [self sendRequestSynchronously:request];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            if (completion) completion(result ?: @{@"success": @NO, @"message": @"No result"});
        });
    });
}

- (void)consumeStatusResult:(NSDictionary *)result resetPending:(BOOL)resetPending {
    self.supportedBands = BLSortedBands(result[@"supported"]);
    self.activeBands = BLSortedBands(result[@"active"]);
    self.radioAccessTechnology = [result[@"rat"] isKindOfClass:[NSString class]] ? result[@"rat"] : @"—";
    self.servingBand = [result[@"serving"] isKindOfClass:[NSString class]] ? result[@"serving"] : @"—";
    self.networkMode = [result[@"mode"] isKindOfClass:[NSString class]] ? result[@"mode"] : BLT(@"No disponible", @"Unavailable");
    self.hasReadState = YES;
    if (resetPending || !self.pendingBands.count) self.pendingBands = self.activeBands;
}

- (void)finishResult:(NSDictionary *)result successMessage:(NSString *)successMessage completion:(BLActionCompletion)completion {
    BOOL success = [result[@"success"] boolValue];
    NSString *message = [result[@"message"] isKindOfClass:[NSString class]] ? result[@"message"] : (success ? successMessage : BLT(@"Operación fallida.", @"Operation failed."));
    self.statusText = success ? BLT(@"Listo", @"Ready") : BLT(@"Error del daemon", @"Daemon error");
    self.detailText = message ?: @"";
    if (completion) completion(success, self.detailText);
}

- (void)refreshWithCompletion:(BLActionCompletion)completion {
    self.statusText = BLT(@"Consultando daemon…", @"Querying daemon…");
    [self sendRequest:@{@"cmd": @"status"} completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) [self consumeStatusResult:result resetPending:YES];
        [self finishResult:result successMessage:BLT(@"Estado del módem actualizado.", @"Modem state updated.") completion:completion];
    }];
}

- (void)setPendingBands:(NSArray<NSNumber *> *)bands {
    self.pendingBands = BLSortedBands(bands);
    self.statusText = BLT(@"Selección preparada", @"Selection prepared");
    self.detailText = BLBandList(self.pendingBands);
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
        [self finishResult:result successMessage:BLT(@"Field Test solicitado.", @"Field Test requested.") completion:completion];
    }];
}

@end
