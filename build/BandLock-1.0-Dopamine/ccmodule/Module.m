#import "Module.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
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

@interface BLCCModule ()
@property (nonatomic, copy) NSString *currentModeCode;
@property (nonatomic, assign) BOOL supports5G;
@property (nonatomic, assign) BOOL requestInFlight;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        signal(SIGPIPE, SIG_IGN);
        _currentModeCode = @"unknown";
        _supports5G = NO;
        _requestInFlight = NO;
        _daemonQueue = dispatch_queue_create("com.gokuencinar.bandlock.ccmodule", DISPATCH_QUEUE_SERIAL);
        [self bl_refreshFromDaemon];
    }
    return self;
}

- (UIImage *)iconGlyph {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24.0 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"] imageByApplyingSymbolConfiguration:config];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)selectedIconGlyph {
    return [self iconGlyph];
}

- (UIColor *)selectedColor {
    return UIColor.systemBlueColor;
}

- (BOOL)isSelected {
    if ([self.currentModeCode isEqualToString:@"lte"]) return YES;
    if ([self.currentModeCode isEqualToString:@"3g"]) return YES;
    if (self.supports5G && [self.currentModeCode hasPrefix:@"5g-"]) return YES;
    return NO;
}

- (void)setSelected:(BOOL)selected {
    (void)selected;
    if (self.requestInFlight) return;
    [self bl_presentModeMenu];
}

- (void)refreshState {
    [super refreshState];
    if (!self.daemonQueue) return;
    [self bl_refreshFromDaemon];
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

- (NSString *)bl_currentModeName {
    if ([self.currentModeCode isEqualToString:@"lte"]) return @"4G / LTE";
    if ([self.currentModeCode isEqualToString:@"3g"]) return @"3G / UMTS";
    if (self.supports5G && [self.currentModeCode hasPrefix:@"5g-"]) return @"5G";
    if ([self.currentModeCode isEqualToString:@"automatic"]) return @"Auto";
    return @"Desconocido";
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

- (NSString *)bl_titleForMode:(BLCCMode)mode {
    NSString *title = @"Auto";
    switch (mode) {
        case BLCCModeLTE: title = @"4G / LTE"; break;
        case BLCCMode5G: title = self.supports5G ? @"5G" : @"5G (no disponible)"; break;
        case BLCCMode3G: title = @"3G / UMTS"; break;
        case BLCCModeAutomatic: default: break;
    }
    return [self bl_modeSelected:mode] ? [@"✓ " stringByAppendingString:title] : title;
}

- (NSString *)bl_daemonModeForMode:(BLCCMode)mode {
    switch (mode) {
        case BLCCModeLTE: return @"lte";
        case BLCCMode5G: return @"5g-on";
        case BLCCMode3G: return @"3g";
        case BLCCModeAutomatic: default: return @"automatic";
    }
}

- (void)bl_presentModeMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *controller = (UIViewController *)self.contentViewController;
        if (!controller || controller.presentedViewController) return;

        UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"BandLock Network"
                                                                      message:[NSString stringWithFormat:@"Modo actual: %@", [self bl_currentModeName]]
                                                               preferredStyle:UIAlertControllerStyleActionSheet];

        NSArray<NSNumber *> *modes = @[@(BLCCModeAutomatic), @(BLCCModeLTE), @(BLCCMode5G), @(BLCCMode3G)];
        for (NSNumber *value in modes) {
            BLCCMode mode = (BLCCMode)value.integerValue;
            UIAlertAction *action = [UIAlertAction actionWithTitle:[self bl_titleForMode:mode]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(__unused UIAlertAction *action) {
                [self bl_applyMode:mode];
            }];
            if (mode == BLCCMode5G && !self.supports5G) action.enabled = NO;
            [menu addAction:action];
        }

        [menu addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
        [controller presentViewController:menu animated:YES completion:nil];
    });
}

- (void)bl_applyMode:(BLCCMode)mode {
    if (self.requestInFlight) return;
    self.requestInFlight = YES;

    NSString *requested = [self bl_daemonModeForMode:mode];
    dispatch_async(self.daemonQueue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"rat", @"mode": requested}];
        BOOL success = [result[@"success"] boolValue];
        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        BOOL supports5G = [result[@"supports_5g"] boolValue];
        NSString *message = [result[@"message"] isKindOfClass:NSString.class] ? result[@"message"] : @"No se pudo cambiar el modo de red.";
        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"automatic";

        dispatch_async(dispatch_get_main_queue(), ^{
            self.requestInFlight = NO;

            if (success && modeCode.length) {
                self.currentModeCode = modeCode;
                self.supports5G = supports5G;
                [super refreshState];
                return;
            }

            [self bl_showError:message];
            [self bl_refreshFromDaemon];
        });
    });
}

- (void)bl_showError:(NSString *)message {
    UIViewController *controller = (UIViewController *)self.contentViewController;
    if (!controller || controller.presentedViewController) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock"
                                                                   message:message ?: @"Error"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
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
            [super refreshState];
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

    NSRange newline = [responseData rangeOfData:[NSData dataWithBytes:"\n" length:1]
                                       options:0
                                         range:NSMakeRange(0, responseData.length)];
    if (newline.location != NSNotFound) responseData.length = newline.location;

    id result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    return [result isKindOfClass:NSDictionary.class] ? result : @{@"success": @NO};
}

@end
