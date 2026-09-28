#import "Module.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <string.h>
#import <dlfcn.h>
#import "BLCCPreferences.h"

typedef void *BLCTServerConnectionRef;
typedef BLCTServerConnectionRef (*BLCTServerConnectionCreateFn)(CFAllocatorRef allocator, void (*callback)(void), void *context);
typedef void *(*BLCTServerConnectionSetRATSelectionFn)(BLCTServerConnectionRef connection, CFStringRef selection, void *unknown);

static void BLCTServerConnectionCallback(void) {}

static void *BLCoreTelephonyHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

static CFStringRef BLRATSelectionConstant(const char *symbolName) {
    void *handle = BLCoreTelephonyHandle();
    if (!handle || !symbolName) return NULL;
    CFStringRef *symbol = (CFStringRef *)dlsym(handle, symbolName);
    return symbol ? *symbol : NULL;
}

#if BL_VARIANT_ROOTHIDE
#import <roothide.h>
#endif

@interface CCUIToggleModule (BLReconfigure)
- (void)reconfigureView;
@end

@interface BLCCModule ()
@property (nonatomic, copy) NSString *currentModeCode;
@property (nonatomic, copy) NSString *confirmedModeCode;
@property (nonatomic, assign) BOOL supports5G;
@property (nonatomic, assign) NSUInteger stateEpoch;
@property (nonatomic, assign) NSTimeInterval statusRefreshNotBefore;
@property (nonatomic, assign) BOOL statusRefreshInFlight;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@property (nonatomic, strong) UIAlertController *modePicker;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentModeCode = @"automatic";
        _confirmedModeCode = @"automatic";
        _supports5G = NO;
        _stateEpoch = 0;
        _statusRefreshNotBefore = 0;
        _statusRefreshInFlight = NO;
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
    if ([self.currentModeCode isEqualToString:@"2g"]) text = @"2G";
    else if ([self.currentModeCode isEqualToString:@"lte"]) text = @"4G";
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
    if ([self.currentModeCode isEqualToString:@"2g"]) return YES;
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
    if (!self.daemonQueue || self.statusRefreshInFlight) return;
    if (CFAbsoluteTimeGetCurrent() < self.statusRefreshNotBefore) return;
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
    if ([mode isEqualToString:@"2g"]) return @"2G / GSM";
    if ([mode isEqualToString:@"3g"]) return @"3G / UMTS";
    if ([mode isEqualToString:@"lte"]) return @"4G / LTE";
    if ([mode isEqualToString:@"5g-auto"]) return BLCCAdvanced5GModes() ? @"5G Auto" : @"5G";
    if ([mode isEqualToString:@"5g-on"]) return @"5G NSA";
    if ([mode isEqualToString:@"5g-only"]) return @"5G SA";
    return mode ?: @"";
}

- (BOOL)bl_modeIsCurrent:(NSString *)mode {
    if ([mode isEqualToString:@"5g-auto"] && !BLCCAdvanced5GModes()) {
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

    // On iOS 15+ Control Center can briefly expose its window through a scene
    // that is not yet foreground-active. Make a second scene-only pass instead
    // of using UIApplication.windows (deprecated starting in iOS 15).
    if (!window) {
        for (UIScene *scene in scenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }
            }
            if (!window) window = windowScene.windows.firstObject;
            if (window) break;
        }
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

        BLCCSynchronizePreferences();
        NSMutableArray<NSString *> *modes = [NSMutableArray arrayWithObject:@"automatic"];
        if (BLCCShow2G()) [modes addObject:@"2g"];
        if (BLCCShow3G()) [modes addObject:@"3g"];
        if (BLCCShowLTE()) [modes addObject:@"lte"];
        if (BLCCShow5G() && self.supports5G) {
            if (BLCCAdvanced5GModes()) {
                [modes addObjectsFromArray:@[@"5g-auto", @"5g-on", @"5g-only"]];
            } else {
                [modes addObject:@"5g-auto"];
            }
        }
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
    if ([requestedMode hasPrefix:@"5g-"] && !self.supports5G) return;

    self.stateEpoch += 1;
    NSUInteger epoch = self.stateEpoch;

    // Keep the UI responsive immediately, but perform the actual modem change
    // through BandLockDaemon. The app uses the same CoreTelephonyClient path
    // successfully on newer Qualcomm devices, while the direct
    // _CTServerConnectionSetRATSelection path can return without applying the
    // requested RAT and the next status refresh then falls back to Auto/5G.
    self.currentModeCode = requestedMode;
    [self bl_syncVisualSelection];
    [self bl_applyModeThroughDaemon:requestedMode epoch:epoch];
}

- (BOOL)bl_setRATDirect:(NSString *)mode {
    void *handle = BLCoreTelephonyHandle();
    if (!handle) return NO;

    BLCTServerConnectionCreateFn createConnection =
        (BLCTServerConnectionCreateFn)dlsym(handle, "_CTServerConnectionCreate");
    BLCTServerConnectionSetRATSelectionFn setSelection =
        (BLCTServerConnectionSetRATSelectionFn)dlsym(handle, "_CTServerConnectionSetRATSelection");
    if (!createConnection || !setSelection) return NO;

    CFStringRef selection = NULL;
    if ([mode isEqualToString:@"automatic"]) selection = BLRATSelectionConstant("kCTRegistrationRATSelection7");
    else if ([mode isEqualToString:@"2g"]) selection = BLRATSelectionConstant("kCTRegistrationRATSelection0");
    else if ([mode isEqualToString:@"3g"]) selection = BLRATSelectionConstant("kCTRegistrationRATSelection1");
    else if ([mode isEqualToString:@"lte"]) selection = BLRATSelectionConstant("kCTRegistrationRATSelection6");
    else if ([mode isEqualToString:@"5g-on"]) selection = BLRATSelectionConstant("kCTRegistrationRATSelection11");
    if (!selection) return NO;

    BLCTServerConnectionRef connection =
        createConnection(kCFAllocatorDefault, BLCTServerConnectionCallback, NULL);
    if (!connection) return NO;

    setSelection(connection, selection, NULL);
    return YES;
}

- (void)bl_applyModeThroughDaemon:(NSString *)requestedMode epoch:(NSUInteger)epoch {
    dispatch_queue_t queue = self.daemonQueue;
    if (!queue || !requestedMode.length) return;

    dispatch_async(queue, ^{
        NSDictionary *result =
            [self bl_sendRequestSynchronously:@{@"cmd": @"rat", @"mode": requestedMode}];
        BOOL success = [result[@"success"] boolValue];
        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        id supports5GValue = result[@"supports_5g"];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (epoch != self.stateEpoch) return;

            if (!success) {
                self.currentModeCode = self.confirmedModeCode ?: @"automatic";
                [self bl_syncVisualSelection];
                return;
            }

            if ([supports5GValue respondsToSelector:@selector(boolValue)]) {
                self.supports5G = [supports5GValue boolValue];
            }
            NSString *confirmed = modeCode.length ? modeCode : requestedMode;
            if (!self.supports5G && [confirmed hasPrefix:@"5g-"]) confirmed = @"automatic";
            self.currentModeCode = confirmed;
            self.confirmedModeCode = confirmed;
            [self bl_syncVisualSelection];
        });
    });
}

- (void)bl_refreshFromDaemon {
    dispatch_queue_t queue = self.daemonQueue;
    if (!queue || self.statusRefreshInFlight) return;
    if (CFAbsoluteTimeGetCurrent() < self.statusRefreshNotBefore) return;
    NSUInteger epoch = self.stateEpoch;
    self.statusRefreshInFlight = YES;

    dispatch_async(queue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"status"}];
        if (![result[@"success"] boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{ self.statusRefreshInFlight = NO; });
            return;
        }

        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        BOOL supports5G = [result[@"supports_5g"] boolValue];
        if (!modeCode.length) {
            dispatch_async(dispatch_get_main_queue(), ^{ self.statusRefreshInFlight = NO; });
            return;
        }
        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"automatic";

        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusRefreshInFlight = NO;
            if (epoch != self.stateEpoch) return;
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
    // RAT changes are handled asynchronously from the Control Center UI, so
    // match the app client's generous IPC window. CoreTelephonyClient may need
    // several seconds to resolve the subscription context and complete a RAT
    // transition on newer devices.
    struct timeval timeout = {.tv_sec = 30, .tv_usec = 0};
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
