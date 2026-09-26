#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <roothide.h>
#import <fcntl.h>
#import <unistd.h>

static CFStringRef const BLFieldTestNotification = CFSTR("com.gokuencinar.bandlock.fieldtest");
static BOOL BLFieldTestRunning = NO;

static void BLBridgeLog(NSString *message) {
    NSString *path = jbroot(@"/tmp/BandLock-fieldbridge.log");
    const char *filePath = path.fileSystemRepresentation;
    if (!filePath) return;
    int fd = open(filePath, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    NSString *line = [NSString stringWithFormat:@"%.3f pid=%d %@\n",
                      [NSDate date].timeIntervalSince1970,
                      getpid(),
                      message ?: @"(null)"];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length) (void)write(fd, data.bytes, data.length);
    close(fd);
}

static UITabBarController *BLFindTabController(UIViewController *controller) {
    if (!controller) return nil;
    if ([controller isKindOfClass:[UITabBarController class]]) return (UITabBarController *)controller;
    UITabBarController *found = BLFindTabController(controller.presentedViewController);
    if (found) return found;
    for (UIViewController *child in controller.childViewControllers) {
        found = BLFindTabController(child);
        if (found) return found;
    }
    return nil;
}

static UIWindow *BLMainWindow(void) {
    UIWindow *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (!fallback) fallback = window;
            if (window.isKeyWindow) return window;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.hidden && window.alpha > 0.01) return window;
        }
    }
    return fallback;
}

static void BLCollectControls(UIView *view, NSMutableArray<UIControl *> *controls) {
    if (!view || view.hidden || view.alpha < 0.01) return;
    if ([view isKindOfClass:[UIControl class]]) [controls addObject:(UIControl *)view];
    for (UIView *child in view.subviews) BLCollectControls(child, controls);
}

static NSString *BLControlText(UIControl *control) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *label = control.accessibilityLabel;
    if (label.length) [parts addObject:label];
    NSString *value = [control.accessibilityValue isKindOfClass:[NSString class]] ? (NSString *)control.accessibilityValue : nil;
    if (value.length) [parts addObject:value];
    if ([control isKindOfClass:[UIButton class]]) {
        NSString *title = ((UIButton *)control).currentTitle;
        if (title.length) [parts addObject:title];
    }
    return [parts componentsJoinedByString:@" | "];
}

static BOOL BLTextMatchesToken(NSString *text, NSString *token) {
    if (!text.length || !token.length) return NO;
    NSString *lower = text.lowercaseString;
    if (token.length == 1 && [@"0123456789" containsString:token]) {
        if ([lower isEqualToString:token]) return YES;
        if ([lower hasPrefix:[token stringByAppendingString:@","]] ||
            [lower hasPrefix:[token stringByAppendingString:@" "]] ||
            [lower hasPrefix:[token stringByAppendingString:@"\n"]]) return YES;
    }
    if ([token isEqualToString:@"*"]) {
        return [lower isEqualToString:@"*"] || [lower containsString:@"asterisk"] ||
               [lower containsString:@"asterisco"] || [lower containsString:@"star"];
    }
    if ([token isEqualToString:@"#"]) {
        return [lower isEqualToString:@"#"] || [lower containsString:@"number sign"] ||
               [lower containsString:@"pound"] || [lower containsString:@"hash"] ||
               [lower containsString:@"almohadilla"] || [lower containsString:@"numeral"];
    }
    if ([token isEqualToString:@"CALL"]) {
        return [lower isEqualToString:@"call"] || [lower containsString:@"call button"] ||
               [lower isEqualToString:@"llamar"] || [lower containsString:@"llamada"];
    }
    return NO;
}

static UIControl *BLFindControl(NSArray<UIControl *> *controls, NSString *token) {
    for (UIControl *control in controls) {
        if (!control.enabled || control.hidden || control.alpha < 0.01) continue;
        NSString *text = BLControlText(control);
        if (BLTextMatchesToken(text, token)) return control;
    }
    return nil;
}

static void BLLogControls(NSArray<UIControl *> *controls) {
    BLBridgeLog([NSString stringWithFormat:@"controls count=%lu", (unsigned long)controls.count]);
    NSUInteger index = 0;
    for (UIControl *control in controls) {
        if (index++ > 80) break;
        CGRect frame = [control convertRect:control.bounds toView:nil];
        BLBridgeLog([NSString stringWithFormat:@"control class=%@ text=%@ frame=%.0f,%.0f %.0fx%.0f",
                     NSStringFromClass(control.class), BLControlText(control),
                     frame.origin.x, frame.origin.y, frame.size.width, frame.size.height]);
    }
}

static void BLTapSequence(NSArray<NSString *> *tokens, NSUInteger index);

static void BLTapSequence(NSArray<NSString *> *tokens, NSUInteger index) {
    if (index >= tokens.count) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = BLMainWindow();
            NSMutableArray<UIControl *> *controls = [NSMutableArray array];
            BLCollectControls(window, controls);
            UIControl *call = BLFindControl(controls, @"CALL");
            if (!call) {
                BLBridgeLog(@"call control not found; leaving code entered for inspection");
                BLFieldTestRunning = NO;
                return;
            }
            BLBridgeLog([NSString stringWithFormat:@"tapping call class=%@ text=%@", NSStringFromClass(call.class), BLControlText(call)]);
            [call sendActionsForControlEvents:UIControlEventTouchUpInside];
            BLFieldTestRunning = NO;
            BLBridgeLog(@"sequence complete");
        });
        return;
    }

    UIWindow *window = BLMainWindow();
    NSMutableArray<UIControl *> *controls = [NSMutableArray array];
    BLCollectControls(window, controls);
    NSString *token = tokens[index];
    UIControl *control = BLFindControl(controls, token);
    if (!control) {
        BLBridgeLog([NSString stringWithFormat:@"token not found token=%@ index=%lu", token, (unsigned long)index]);
        BLLogControls(controls);
        BLFieldTestRunning = NO;
        return;
    }
    BLBridgeLog([NSString stringWithFormat:@"tap token=%@ class=%@ text=%@", token, NSStringFromClass(control.class), BLControlText(control)]);
    [control sendActionsForControlEvents:UIControlEventTouchUpInside];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.09 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BLTapSequence(tokens, index + 1);
    });
}

static void BLRunFieldTest(void) {
    if (BLFieldTestRunning) {
        BLBridgeLog(@"request ignored; already running");
        return;
    }
    BLFieldTestRunning = YES;
    BLBridgeLog(@"request begin");

    UIWindow *window = BLMainWindow();
    UITabBarController *tabs = BLFindTabController(window.rootViewController);
    if (tabs) {
        NSArray<UITabBarItem *> *items = tabs.tabBar.items ?: @[];
        NSInteger keypadIndex = -1;
        for (NSUInteger i = 0; i < items.count; i++) {
            NSString *title = items[i].title.lowercaseString ?: @"";
            BLBridgeLog([NSString stringWithFormat:@"tab index=%lu title=%@", (unsigned long)i, items[i].title ?: @"(null)"]);
            if ([title containsString:@"keypad"] || [title containsString:@"teclado"]) keypadIndex = (NSInteger)i;
        }
        if (keypadIndex < 0 && items.count > 3) keypadIndex = 3;
        if (keypadIndex >= 0 && keypadIndex < (NSInteger)tabs.viewControllers.count) {
            tabs.selectedIndex = (NSUInteger)keypadIndex;
            BLBridgeLog([NSString stringWithFormat:@"selected keypad index=%ld", (long)keypadIndex]);
        }
    } else {
        BLBridgeLog(@"tab controller not found");
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *currentWindow = BLMainWindow();
        NSMutableArray<UIControl *> *controls = [NSMutableArray array];
        BLCollectControls(currentWindow, controls);
        BLLogControls(controls);
        NSArray<NSString *> *tokens = @[@"*", @"3", @"0", @"0", @"1", @"#", @"1", @"2", @"3", @"4", @"5", @"#", @"*"];
        BLTapSequence(tokens, 0);
    });
}

static void BLFieldTestNotificationCallback(CFNotificationCenterRef center,
                                             void *observer,
                                             CFStringRef name,
                                             const void *object,
                                             CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        BLBridgeLog(@"Darwin notification received");
        BLRunFieldTest();
    });
}

__attribute__((constructor)) static void BLFieldBridgeInit(void) {
    @autoreleasepool {
        BLBridgeLog([NSString stringWithFormat:@"bridge loaded bundle=%@", NSBundle.mainBundle.bundleIdentifier ?: @"(null)"]);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        BLFieldTestNotificationCallback,
                                        BLFieldTestNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
