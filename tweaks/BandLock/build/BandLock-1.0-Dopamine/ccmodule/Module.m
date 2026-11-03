#import "Module.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <string.h>
#import "BLCCPreferences.h"
#import "../../BLHardwareCapabilities.h"

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
@property (nonatomic, assign) NSUInteger stateEpoch;
@property (nonatomic, assign) NSTimeInterval statusRefreshNotBefore;
@property (nonatomic, assign) NSTimeInterval modeIntentPinnedUntil;
@property (nonatomic, assign) BOOL statusRefreshInFlight;
@property (nonatomic, assign) BOOL modeWriteInFlight;
@property (nonatomic, copy) NSString *queuedModeCode;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@property (nonatomic, strong) UIAlertController *modePicker;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        // Saved preference is merely an intent from a previous session.
        // Never represent it as a freshly verified modem selection.
        _currentModeCode = @"automatic";
        _confirmedModeCode = nil;
        _pendingModeCode = nil;
        _supports5G = NO;
        _stateEpoch = 0;
        _statusRefreshNotBefore = 0;
        _modeIntentPinnedUntil = 0;
        _statusRefreshInFlight = NO;
        _modeWriteInFlight = NO;
        _queuedModeCode = nil;
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
    // Unknown state falls back to Auto visually; never show "Red" or "?".

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

- (NSString *)bl_normalizedReportedMode:(NSString *)reportedMode {
    if (!reportedMode.length) return reportedMode;

    if (BLDeviceIsKnownLTEOnly() && [reportedMode hasPrefix:@"5g-"]) reportedMode = @"unknown";

    // Only a trustworthy modem readback may update the confirmed mode.
    // A saved preference is not a modem readback.
    if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18) {
        if ([reportedMode isEqualToString:@"2g"] && !BLCCShow2G()) return @"automatic";
        if ([reportedMode isEqualToString:@"3g"] && !BLCCShow3G()) return @"automatic";
        if ([reportedMode isEqualToString:@"lte"] && !BLCCShowLTE()) return @"automatic";
        if ([reportedMode hasPrefix:@"5g-"] && (!self.supports5G || !BLCCShow5G())) return @"unknown";
        return reportedMode;
    }

    BLCCSynchronizePreferences();
    NSString *intent = BLCCLastModeCode();

    // On some iOS 16 / Qualcomm combinations CoreTelephony reports Automatic
    // again shortly after a successful forced 3G/LTE change even though the
    // modem remains on the requested RAT. The CC tile therefore represents the
    // last mode BandLock successfully requested, not that ambiguous readback.
    if (intent.length) {
        if ([intent isEqualToString:@"2g"]) return BLCCShow2G() ? @"2g" : @"automatic";
        if ([intent isEqualToString:@"3g"]) return BLCCShow3G() ? @"3g" : @"automatic";
        if ([intent isEqualToString:@"lte"]) return BLCCShowLTE() ? @"lte" : @"automatic";
        if ([intent hasPrefix:@"5g-"]) return (self.supports5G && BLCCShow5G() && !BLDeviceIsKnownLTEOnly()) ? intent : @"automatic";
        if ([intent isEqualToString:@"automatic"]) return @"automatic";
    }

    // With no persisted BandLock intent yet, use the modem readback, but never
    // surface a mode the user explicitly hid from the Control Center selector.
    if ([reportedMode isEqualToString:@"2g"] && !BLCCShow2G()) return @"automatic";
    if ([reportedMode isEqualToString:@"3g"] && !BLCCShow3G()) return @"automatic";
    if ([reportedMode isEqualToString:@"lte"] && !BLCCShowLTE()) return @"automatic";
    if ([reportedMode hasPrefix:@"5g-"] && !BLCCShow5G()) {
        return @"automatic";
    }

    return reportedMode;
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

        BOOL readOnly18 = [NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18;
        UIAlertController *picker =
            [UIAlertController alertControllerWithTitle:@"BandLock Network"
                                                message:readOnly18
                                                    ? @"Se comprobará la compatibilidad antes de cambiar el modo."
                                                    : @"Selecciona el modo de red"
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
    self.modeIntentPinnedUntil = CFAbsoluteTimeGetCurrent() + 8.0;
    self.pendingModeCode = requestedMode;

    // Keep the UI responsive immediately, but perform the actual modem change
    // through BandLockDaemon. The app uses the same CoreTelephonyClient path
    // successfully on newer Qualcomm devices, while the direct
    // legacy direct setter can return without applying the
    // requested RAT and the next status refresh then falls back to Auto/5G.
    self.currentModeCode = requestedMode;
    [self bl_syncVisualSelection];
    // A serial dispatch queue alone still executes every rapid tap. Keep only
    // the newest explicit intent while one modem write is in flight so a
    // 2G→3G→4G gesture cannot hammer CommCenter with obsolete intermediate
    // setters. The latest intent is submitted only after the accepted write;
    // a failed/EAGAIN write is never retried automatically.
    if (self.modeWriteInFlight) {
        self.queuedModeCode = requestedMode;
        return;
    }
    self.modeWriteInFlight = YES;
    [self bl_applyModeThroughDaemon:requestedMode epoch:epoch];
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
            @try {
              if (epoch != self.stateEpoch) return;

              if (!success) {
                  BOOL uncertain = [result[@"verification_pending"] boolValue];
                  if (!uncertain) self.pendingModeCode = nil;
                  self.currentModeCode = uncertain && self.pendingModeCode.length
                      ? self.pendingModeCode : (self.confirmedModeCode ?: @"automatic");
                  [self bl_syncVisualSelection];
                  if (uncertain) {
                      // The setter may have taken effect but the private
                      // getter cannot confirm it. Never show a false failure
                      // dialog or claim that the previous mode is still set.
                      self.statusRefreshNotBefore = CFAbsoluteTimeGetCurrent() + 3.0;
                      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)),
                          dispatch_get_main_queue(), ^{
                              if (epoch == self.stateEpoch) [self bl_refreshFromDaemon];
                          });
                      return;
                  }
                  NSString *message = [result[@"message"] isKindOfClass:NSString.class]
                      ? result[@"message"] : @"No se ha podido cambiar el modo";
                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)),
                                 dispatch_get_main_queue(), ^{
                      UIViewController *presenter = [self bl_topViewController];
                      if (!presenter || presenter.presentedViewController) return;
                      UIAlertController *notice = [UIAlertController
                          alertControllerWithTitle:@"BandLock" message:message
                          preferredStyle:UIAlertControllerStyleAlert];
                      [notice addAction:[UIAlertAction actionWithTitle:@"Aceptar"
                                                                 style:UIAlertActionStyleCancel handler:nil]];
                      [presenter presentViewController:notice animated:YES completion:nil];
                  });
                  return;
              }

            if ([supports5GValue respondsToSelector:@selector(boolValue)]) {
                self.supports5G = [supports5GValue boolValue];
              }
              NSString *confirmed = modeCode.length ? modeCode : @"unknown";
            if (!self.supports5G && [confirmed hasPrefix:@"5g-"]) confirmed = @"automatic";
            confirmed = [self bl_normalizedReportedMode:confirmed];
            BOOL verified = ![result[@"verification_pending"] boolValue] &&
                ![confirmed isEqualToString:@"unknown"];
            self.currentModeCode = verified ? confirmed : requestedMode;
            BLCCSetLastModeCode(requestedMode);
            if (verified) {
                self.confirmedModeCode = confirmed;
                self.pendingModeCode = nil;
            } else {
                self.pendingModeCode = requestedMode;
            }
            self.modeIntentPinnedUntil = CFAbsoluteTimeGetCurrent() + 8.0;
            self.statusRefreshNotBefore = self.modeIntentPinnedUntil;
            [self bl_syncVisualSelection];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (epoch == self.stateEpoch) [self bl_refreshFromDaemon];
            });
            } @finally {
                NSString *queued = self.queuedModeCode;
                self.queuedModeCode = nil;
                self.modeWriteInFlight = NO;
                if (success && queued.length && ![queued isEqualToString:requestedMode]) {
                    self.modeWriteInFlight = YES;
                    [self bl_applyModeThroughDaemon:queued epoch:self.stateEpoch];
                } else if (success && queued.length && [queued isEqualToString:requestedMode]) {
                    // The latest tap returned to the in-flight selection.
                    // Its epoch superseded the original callback, so keep
                    // that accepted intent instead of leaving stale UI.
                    self.currentModeCode = requestedMode;
                    self.pendingModeCode = requestedMode;
                    BLCCSetLastModeCode(requestedMode);
                    self.statusRefreshNotBefore = CFAbsoluteTimeGetCurrent() + 8.0;
                    [self bl_syncVisualSelection];
                } else if (!success && epoch != self.stateEpoch) {
                    // A newer visual intent was never submitted because the
                    // preceding modem write failed. Do not leave that unsent
                    // intent painted as if CommCenter had accepted it.
                    self.pendingModeCode = nil;
                    self.currentModeCode = self.confirmedModeCode ?: @"automatic";
                    [self bl_syncVisualSelection];
                }
            }
        });
    });
}

- (void)bl_refreshFromDaemon {
    dispatch_queue_t queue = self.daemonQueue;
    if (!queue || self.statusRefreshInFlight) return;
    if (CFAbsoluteTimeGetCurrent() < self.statusRefreshNotBefore) return;
    NSUInteger epoch = self.stateEpoch;
    self.statusRefreshInFlight = YES;
    // CoreTelephony status may be expensive or temporarily unresponsive.
    // Repainting the Control Center must not cause an unbounded query loop.
    self.statusRefreshNotBefore = CFAbsoluteTimeGetCurrent() + 20.0;

    dispatch_async(queue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"status"}];
        if (![result[@"success"] boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{ self.statusRefreshInFlight = NO; });
            return;
        }

        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        NSString *acceptedMode = [result[@"accepted_mode"] isKindOfClass:NSString.class]
            ? result[@"accepted_mode"] : nil;
        BOOL supports5G = !BLDeviceIsKnownLTEOnly() && [result[@"supports_5g"] boolValue];
        if (!modeCode.length) {
            dispatch_async(dispatch_get_main_queue(), ^{ self.statusRefreshInFlight = NO; });
            return;
        }
        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"unknown";

        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusRefreshInFlight = NO;
            if (epoch != self.stateEpoch) return;
            self.supports5G = supports5G;
            NSString *normalizedModeCode = [self bl_normalizedReportedMode:modeCode];
            NSString *normalizedAccepted = acceptedMode.length
                ? [self bl_normalizedReportedMode:acceptedMode] : nil;
            BOOL hasAcceptedIntent = normalizedAccepted.length &&
                ![normalizedAccepted isEqualToString:@"unknown"];
            BOOL verified = ![normalizedModeCode isEqualToString:@"unknown"] &&
                (!hasAcceptedIntent || [normalizedModeCode isEqualToString:normalizedAccepted]);
            if (!verified && hasAcceptedIntent &&
                ![normalizedAccepted isEqualToString:@"unknown"]) {
                self.pendingModeCode = [normalizedAccepted isEqualToString:@"automatic"]
                    ? nil : normalizedAccepted;
                normalizedModeCode = normalizedAccepted;
            } else if (!verified && self.pendingModeCode.length) {
                normalizedModeCode = self.pendingModeCode;
            } else if (!verified) {
                normalizedModeCode = @"automatic";
            }
            BOOL changed = ![self.currentModeCode isEqualToString:normalizedModeCode];
            self.currentModeCode = normalizedModeCode;
            if (verified) {
                self.confirmedModeCode = normalizedModeCode;
                self.pendingModeCode = nil;
            }
            if (changed) [self bl_syncVisualSelection];
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
    // The 3-second limit is for background status refresh only. An explicit
    // RAT action performs a bounded readback before the setter and needs a
    // longer async IPC window, without blocking SpringBoard's main thread.
    BOOL ios18 = [NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18;
    BOOL backgroundStatus = [request[@"cmd"] isEqualToString:@"status"];
    struct timeval timeout = {.tv_sec = ios18 ? (backgroundStatus ? 3 : 12) : 30, .tv_usec = 0};
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
