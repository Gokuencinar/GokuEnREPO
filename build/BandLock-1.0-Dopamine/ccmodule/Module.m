#import "Module.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <string.h>

#if BL_VARIANT_ROOTHIDE
#import <roothide.h>
#endif

@interface CCUIToggleModule (BLReconfigure)
- (void)reconfigureView;
@end

@interface BLCCModule ()
@property (nonatomic, copy) NSString *currentModeCode;
@property (nonatomic, copy) NSString *confirmedModeCode;
@property (nonatomic, copy) NSString *pendingModeCode;
@property (nonatomic, assign) BOOL supports5G;
@property (nonatomic, assign) BOOL requestInFlight;
@property (nonatomic, assign) NSUInteger stateEpoch;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@property (nonatomic, strong) UIAlertController *modePicker;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentModeCode = @"automatic";
        _confirmedModeCode = @"automatic";
        _pendingModeCode = nil;
        _supports5G = NO;
        _requestInFlight = NO;
        _stateEpoch = 0;
        _daemonQueue = dispatch_queue_create("com.gokuencinar.bandlock.ccmodule", DISPATCH_QUEUE_SERIAL);
        [self bl_refreshFromDaemon];
    }
    return self;
}

- (UIImage *)iconGlyph {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
    label.textColor = UIColor.blackColor;
    label.backgroundColor = UIColor.clearColor;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.7;
    label.clipsToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;

    NSString *text = @"Auto";
    if ([self.currentModeCode isEqualToString:@"lte"]) text = @"4G";
    else if ([self.currentModeCode isEqualToString:@"3g"]) text = @"3G";
    else if (self.supports5G && [self.currentModeCode hasPrefix:@"5g-"]) text = @"5G";
    else if (![self.currentModeCode isEqualToString:@"automatic"]) text = @"?";

    label.font = [UIFont systemFontOfSize:[text isEqualToString:@"Auto"] ? 13.0 : 16.0
                                  weight:UIFontWeightSemibold];
    label.text = text;

    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 0.0);
    [label.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
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

- (void)bl_syncVisualSelection {
    // Ask CCUIToggleModule to re-read our overridden -isSelected. Calling the
    // base setter is not sufficient on iOS 16 while the module is already
    // visible: the host can keep the old highlighted appearance cached.
    [super refreshState];
    [super reconfigureView];

    // UIAlertController dismisses after its action handler returns. A repaint
    // issued during that transition can be dropped by the Control Center host,
    // so repeat it once the sheet has finished leaving the hierarchy.
    NSUInteger epoch = self.stateEpoch;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.40 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (epoch != self.stateEpoch) return;
        [super refreshState];
        [super reconfigureView];
    });
}

- (void)setSelected:(BOOL)selected {
    (void)selected;
    [self bl_presentModePicker];
}

- (void)refreshState {
    [super refreshState];
    if (!self.daemonQueue || self.requestInFlight || self.pendingModeCode.length) return;
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

- (NSString *)bl_titleForMode:(NSString *)mode {
    if ([mode isEqualToString:@"automatic"]) return @"Auto";
    if ([mode isEqualToString:@"3g"]) return @"3G / UMTS";
    if ([mode isEqualToString:@"lte"]) return @"4G / LTE";
    if ([mode isEqualToString:@"5g-on"]) return @"5G";
    return mode ?: @"";
}

- (BOOL)bl_modeIsCurrent:(NSString *)mode {
    if ([mode isEqualToString:@"5g-on"]) {
        return self.supports5G && [self.currentModeCode hasPrefix:@"5g-"];
    }
    return [self.currentModeCode isEqualToString:mode];
}

- (UIViewController *)bl_topViewController {
    UIWindow *window = nil;
    NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes;

    for (UIScene *scene in scenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *candidate in windowScene.windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }

        if (!window) {
            window = windowScene.windows.firstObject;
        }
        if (window) break;
    }

    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
        controller = controller.presentedViewController;
    }
    return controller;
}

- (void)bl_presentModePicker {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.modePicker.presentingViewController) return;

        UIViewController *presenter = [self bl_topViewController];
        if (!presenter) return;

        UIAlertController *picker =
            [UIAlertController alertControllerWithTitle:@"BandLock Network"
                                                message:@"Selecciona el modo de red"
                                         preferredStyle:UIAlertControllerStyleActionSheet];

        NSArray<NSString *> *modes = @[@"automatic", @"3g", @"lte", @"5g-on"];
        for (NSString *mode in modes) {
            NSString *title = [self bl_titleForMode:mode];
            if ([self bl_modeIsCurrent:mode]) {
                title = [@"✓ " stringByAppendingString:title];
            }

            UIAlertAction *action =
                [UIAlertAction actionWithTitle:title
                                         style:UIAlertActionStyleDefault
                                       handler:^(__unused UIAlertAction *selectedAction) {
                    self.modePicker = nil;
                    [self bl_applyMode:mode];
                }];

            if ([mode isEqualToString:@"5g-on"] && !self.supports5G) {
                action.enabled = NO;
            }
            [picker addAction:action];
        }

        [picker addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(__unused UIAlertAction *action) {
            self.modePicker = nil;
        }]];

        UIPopoverPresentationController *popover = picker.popoverPresentationController;
        if (popover) {
            popover.sourceView = presenter.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                            CGRectGetMidY(presenter.view.bounds),
                                            1.0, 1.0);
            popover.permittedArrowDirections = 0;
        }

        self.modePicker = picker;
        [presenter presentViewController:picker animated:YES completion:nil];
    });
}

- (void)bl_applyMode:(NSString *)requestedMode {
    if (!requestedMode.length) return;
    if ([requestedMode isEqualToString:@"5g-on"] && !self.supports5G) return;

    dispatch_queue_t queue = self.daemonQueue;
    if (!queue) return;

    self.stateEpoch += 1;

    // Always reflect the latest user choice immediately, even if the daemon is
    // still finishing a previous RAT switch.
    self.currentModeCode = requestedMode;
    [self bl_syncVisualSelection];

    if (self.requestInFlight) {
        // Coalesce rapid taps: keep only the newest requested RAT. The current
        // daemon transaction is allowed to finish, then this value is applied.
        self.pendingModeCode = requestedMode;
        return;
    }

    [self bl_startModeRequest:requestedMode];
}

- (void)bl_startModeRequest:(NSString *)requestedMode {
    if (!requestedMode.length || self.requestInFlight) return;

    dispatch_queue_t queue = self.daemonQueue;
    if (!queue) return;

    self.requestInFlight = YES;

    dispatch_async(queue, ^{
        NSDictionary *result =
            [self bl_sendRequestSynchronously:@{@"cmd": @"rat", @"mode": requestedMode, @"fast": @YES}];
        BOOL success = [result[@"success"] boolValue];
        id supports5GValue = result[@"supports_5g"];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.requestInFlight = NO;

            BOOL hasSupports5G = [supports5GValue respondsToSelector:@selector(boolValue)];
            BOOL supports5G = hasSupports5G ? [supports5GValue boolValue] : self.supports5G;

            NSString *normalizedMode = requestedMode;
            if (!supports5G && [normalizedMode hasPrefix:@"5g-"]) {
                normalizedMode = @"automatic";
            }

            if (success) {
                if (hasSupports5G) self.supports5G = supports5G;
                self.confirmedModeCode = normalizedMode;
            }

            NSString *nextMode = self.pendingModeCode;
            self.pendingModeCode = nil;

            if (nextMode.length) {
                // If the final tap already matches what just succeeded, no
                // second modem transaction is necessary.
                if (success && [nextMode isEqualToString:normalizedMode]) {
                    self.currentModeCode = normalizedMode;
                    [self bl_syncVisualSelection];
                } else {
                    [self bl_startModeRequest:nextMode];
                }
                return;
            }

            if (success) {
                self.currentModeCode = normalizedMode;
                [self bl_syncVisualSelection];

                NSUInteger epoch = self.stateEpoch;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    if (epoch == self.stateEpoch && !self.requestInFlight && !self.pendingModeCode.length) {
                        [self bl_refreshFromDaemon];
                    }
                });
            } else {
                self.currentModeCode = self.confirmedModeCode ?: @"automatic";
                [self bl_syncVisualSelection];
                [self bl_refreshFromDaemon];
            }
        });
    });
}

- (void)bl_refreshFromDaemon {
    dispatch_queue_t queue = self.daemonQueue;
    if (!queue || self.requestInFlight || self.pendingModeCode.length) return;
    NSUInteger epoch = self.stateEpoch;

    dispatch_async(queue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"status"}];
        if (![result[@"success"] boolValue]) return;

        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        BOOL supports5G = [result[@"supports_5g"] boolValue];
        if (!modeCode.length) return;
        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"automatic";

        dispatch_async(dispatch_get_main_queue(), ^{
            if (epoch != self.stateEpoch || self.requestInFlight || self.pendingModeCode.length) return;
            self.currentModeCode = modeCode;
            self.confirmedModeCode = modeCode;
            self.supports5G = supports5G;
            [self bl_syncVisualSelection];
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
    struct timeval timeout = {.tv_sec = 1, .tv_usec = 500000};
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
