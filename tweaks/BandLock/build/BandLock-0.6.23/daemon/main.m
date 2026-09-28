#import <Foundation/Foundation.h>
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import <roothide.h>
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

static void BLDaemonLog(const char *message) {
    NSString *resolvedLogPath = jbroot(@"/tmp/BandLock-daemon.log");
    const char *path = resolvedLogPath.fileSystemRepresentation;
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
- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query;
- (BOOL)setRatSelectionSync:(NSString *)selection preferred:(NSString *)preferred errorText:(NSString **)errorText;
- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
- (NSArray<NSNumber *> *)activeLTEFromQuery:(NSDictionary *)query;
- (BOOL)openFieldTestWithError:(NSString **)errorText;
@end

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLRATAutomatic = @"kCTRegistrationRATSelectionAutomatic";
static NSString * const BLRATLTE = @"kCTRegistrationRATSelectionLTE";

static NSString *BLSocketPath(void) {
    NSString *resolved = jbroot(@"/tmp/com.gokuencinar.bandlockd.sock");
    return resolved.length ? resolved : @"/tmp/com.gokuencinar.bandlockd.sock";
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

static NSDictionary *BLHandleRequest(NSDictionary *request) {
    @try {
        NSString *command = [request[@"cmd"] isKindOfClass:[NSString class]] ? request[@"cmd"] : @"";
        BLDaemonLog([[NSString stringWithFormat:@"handle command=%@", command] UTF8String]);
        BLTelephonyManager *manager = BLTelephonyManager.sharedManager;

        if ([command isEqualToString:@"status"]) {
            BLDaemonLog("status query begin");
            NSDictionary *payload = BLStatusPayload(manager, [manager queryCoreTelephony]);
            BLDaemonLog("status query end");
            return payload;
        }

        if ([command isEqualToString:@"rat"]) {
            NSString *mode = [request[@"mode"] isKindOfClass:[NSString class]] ? request[@"mode"] : @"";
            NSString *selection = [mode isEqualToString:@"lte"] ? BLRATLTE : BLRATAutomatic;
            NSString *preferred = [mode isEqualToString:@"lte"] ? BLLTERAT : nil;
            NSString *errorText = nil;
            if (![manager setRatSelectionSync:selection preferred:preferred errorText:&errorText]) {
                return @{@"success": @NO, @"message": errorText ?: @"RAT write failed"};
            }
            [NSThread sleepForTimeInterval:0.35];
            NSMutableDictionary *payload = [BLStatusPayload(manager, [manager queryCoreTelephony]) mutableCopy];
            if ([payload[@"success"] boolValue]) payload[@"message"] = payload[@"mode"] ?: @"RAT updated";
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

            NSDictionary *query = [manager queryCoreTelephony];
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

            [NSThread sleepForTimeInterval:0.8];
            NSDictionary *verify = [manager queryCoreTelephony];
            if (verify[@"error"]) return @{@"success": @NO, @"message": [verify[@"error"] description] ?: @"Verification failed"};
            NSArray<NSNumber *> *readback = [manager activeLTEFromQuery:verify] ?: @[];
            BOOL matches = [[NSSet setWithArray:bands] isEqualToSet:[NSSet setWithArray:readback]];

            if (!matches) {
                NSString *retryError = nil;
                if (![manager writeLTEBands:bands usingQuery:verify errorText:&retryError]) return @{@"success": @NO, @"message": retryError ?: @"LTE retry failed"};
                [NSThread sleepForTimeInterval:1.0];
                verify = [manager queryCoreTelephony];
                if (verify[@"error"]) return @{@"success": @NO, @"message": [verify[@"error"] description] ?: @"Verification failed"};
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
            return payload;
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
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        BLDaemonLog("daemon start");
        NSString *socketPath = BLSocketPath();
        const char *path = socketPath.fileSystemRepresentation;
        if (!path || strlen(path) >= sizeof(((struct sockaddr_un *)0)->sun_path)) return 70;

        int serverFD = socket(AF_UNIX, SOCK_STREAM, 0);
        if (serverFD < 0) return 71;
        unlink(path);

        struct sockaddr_un address;
        memset(&address, 0, sizeof(address));
        address.sun_family = AF_UNIX;
        strlcpy(address.sun_path, path, sizeof(address.sun_path));

        if (bind(serverFD, (struct sockaddr *)&address, sizeof(address)) != 0) { close(serverFD); return 72; }
        chmod(path, 0600);
        if (listen(serverFD, 8) != 0) { close(serverFD); unlink(path); return 73; }
        BLDaemonLog("daemon listening");

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
