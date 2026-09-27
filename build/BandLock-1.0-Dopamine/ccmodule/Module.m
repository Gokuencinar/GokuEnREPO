#import "Module.h"
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <signal.h>
#import <string.h>

#if BL_VARIANT_ROOTHIDE
#import <roothide.h>
#endif

typedef NS_ENUM(NSInteger, BLCCMode) {
    BLCCModeAutomatic = 0,
    BLCCModeLTE,
    BLCCMode5G,
    BLCCMode3G
};

@interface BLCCMenuViewController ()
@property (nonatomic, copy) NSString *currentModeCode;
@property (nonatomic, assign) BOOL supports5G;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        _contentViewController = [BLCCMenuViewController new];
    }
    return self;
}

@end

@implementation BLCCMenuViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        signal(SIGPIPE, SIG_IGN);
        _currentModeCode = @"unknown";
        _supports5G = NO;
        _daemonQueue = dispatch_queue_create("com.gokuencinar.bandlock.ccmodule.menu", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"BandLock Network";
    self.subtitle = @"Modo de red";
    self.hideGlyphInHeader = NO;
    self.useTallLayout = NO;
    self.useTrailingCheckmarkLayout = YES;
    self.useTrailingInset = YES;
    self.visibleMenuItems = 4.0;
    self.minimumMenuItems = 4;

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:24.0 weight:UIImageSymbolWeightSemibold];
    UIImage *glyph =
        [[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"] imageByApplyingSymbolConfiguration:config];
    [self setGlyphImage:glyph];

    [self bl_rebuildMenuItems];
    [self bl_refreshFromDaemon];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self bl_refreshFromDaemon];
}

- (BOOL)shouldBeginTransitionToExpandedContentModule {
    return YES;
}

- (BOOL)_canShowWhileLocked {
    return YES;
}

- (NSString *)bl_socketPath {
#if BL_VARIANT_ROOTHIDE
    NSString *resolved = jbroot(@"/tmp/com.gokuencinar.bandlockd.sock");
    return resolved.length ? resolved : @"/tmp/com.gokuencinar.bandlockd.sock";
#elif BL_VARIANT_ROOTFUL
    return @"/tmp/com.gokuencinar.bandlockd.rootful.sock";
#else
    return @"/tmp/com.gokuencinar.bandlockd.dopamine.sock";
#endif
}

- (NSString *)bl_daemonModeForMode:(BLCCMode)mode {
    switch (mode) {
        case BLCCModeLTE: return @"lte";
        case BLCCMode5G: return @"5g-on";
        case BLCCMode3G: return @"3g";
        case BLCCModeAutomatic:
        default: return @"automatic";
    }
}

- (BOOL)bl_modeSelected:(BLCCMode)mode {
    switch (mode) {
        case BLCCModeAutomatic:
            return [self.currentModeCode isEqualToString:@"automatic"];
        case BLCCModeLTE:
            return [self.currentModeCode isEqualToString:@"lte"];
        case BLCCMode5G:
            return self.supports5G && [self.currentModeCode hasPrefix:@"5g-"];
        case BLCCMode3G:
            return [self.currentModeCode isEqualToString:@"3g"];
    }
    return NO;
}

- (void)bl_rebuildMenuItems {
    __weak typeof(self) weakSelf = self;

    CCUIMenuModuleItem *(^itemForMode)(BLCCMode, NSString *, NSString *) =
    ^CCUIMenuModuleItem *(BLCCMode mode, NSString *title, NSString *identifier) {
        CCUIMenuModuleItem *item =
            [[CCUIMenuModuleItem alloc] initWithTitle:title identifier:identifier handler:^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || self.busy) return;
                [self bl_applyMode:mode];
            }];
        item.selected = [weakSelf bl_modeSelected:mode];
        return item;
    };

    CCUIMenuModuleItem *automatic = itemForMode(BLCCModeAutomatic, @"Automático", @"automatic");
    CCUIMenuModuleItem *lte = itemForMode(BLCCModeLTE, @"4G / LTE", @"lte");
    NSString *fiveGTitle = self.supports5G ? @"5G" : @"5G (no disponible)";
    CCUIMenuModuleItem *fiveG = itemForMode(BLCCMode5G, fiveGTitle, @"5g-on");
    CCUIMenuModuleItem *threeG = itemForMode(BLCCMode3G, @"3G / UMTS", @"3g");

    if (!self.supports5G) {
        fiveG.subtitle = @"Este iPhone o línea no reporta soporte 5G";
    }

    [self setMenuItems:@[automatic, lte, fiveG, threeG]];
}

- (void)bl_applyMode:(BLCCMode)mode {
    if (self.busy) return;
    if (mode == BLCCMode5G && !self.supports5G) return;

    self.busy = YES;
    NSString *requested = [self bl_daemonModeForMode:mode];

    dispatch_async(self.daemonQueue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"rat", @"mode": requested}];
        BOOL success = [result[@"success"] boolValue];
        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        BOOL supports5G = [result[@"supports_5g"] boolValue];

        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"automatic";

        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            if (success && modeCode.length) {
                self.currentModeCode = modeCode;
                self.supports5G = supports5G;
                [self bl_rebuildMenuItems];
            } else {
                [self bl_refreshFromDaemon];
            }
        });
    });
}

- (void)bl_refreshFromDaemon {
    dispatch_queue_t queue = self.daemonQueue;
    if (!queue) return;

    dispatch_async(queue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"status"}];
        if (![result[@"success"] boolValue]) return;

        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        BOOL supports5G = [result[@"supports_5g"] boolValue];
        if (!modeCode.length) return;
        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"automatic";

        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentModeCode = modeCode;
            self.supports5G = supports5G;
            [self bl_rebuildMenuItems];
        });
    });
}

- (NSDictionary *)bl_sendRequestSynchronously:(NSDictionary *)request {
    NSData *body = [NSJSONSerialization dataWithJSONObject:request ?: @{} options:0 error:nil];
    if (!body) return @{@"success": @NO};

    NSMutableData *wire = [body mutableCopy];
    [wire appendBytes:"\n" length:1];

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return @{@"success": @NO};

    int one = 1;
    (void)setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));

    struct timeval timeout = {.tv_sec = 4, .tv_usec = 0};
    (void)setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    (void)setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    const char *path = self.bl_socketPath.fileSystemRepresentation;
    if (!path || strlen(path) >= sizeof(((struct sockaddr_un *)0)->sun_path)) {
        close(fd);
        return @{@"success": @NO};
    }

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strlcpy(address.sun_path, path, sizeof(address.sun_path));

    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        close(fd);
        return @{@"success": @NO};
    }

    const uint8_t *bytes = wire.bytes;
    NSUInteger remaining = wire.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written <= 0) {
            close(fd);
            return @{@"success": @NO};
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }

    NSMutableData *responseData = [NSMutableData data];
    uint8_t buffer[4096];
    while (responseData.length < 65536) {
        ssize_t count = read(fd, buffer, sizeof(buffer));
        if (count <= 0) break;
        [responseData appendBytes:buffer length:(NSUInteger)count];
        if (memchr(buffer, '\n', (size_t)count)) break;
    }
    close(fd);

    if (!responseData.length) return @{@"success": @NO};

    NSRange newline =
        [responseData rangeOfData:[NSData dataWithBytes:"\n" length:1]
                          options:0
                            range:NSMakeRange(0, responseData.length)];
    if (newline.location != NSNotFound) responseData.length = newline.location;

    id result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    return [result isKindOfClass:NSDictionary.class] ? result : @{@"success": @NO};
}

@end
