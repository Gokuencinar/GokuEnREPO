#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <roothide.h>
#import <fcntl.h>
#import <unistd.h>
#import <dlfcn.h>
#import <objc/message.h>

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

static BOOL BLCallFieldTestSelector(Class targetClass, NSString *source, NSString *code) {
    if (!targetClass) {
        BLBridgeLog([NSString stringWithFormat:@"%@ class unavailable", source]);
        return NO;
    }

    SEL selector = NSSelectorFromString(@"launchFieldTestIfNeeded:");
    if (![targetClass respondsToSelector:selector]) {
        BLBridgeLog([NSString stringWithFormat:@"%@ launchFieldTestIfNeeded: unavailable", source]);
        return NO;
    }

    @try {
        BOOL handled = ((BOOL (*)(id, SEL, id))objc_msgSend)((id)targetClass, selector, code);
        BLBridgeLog([NSString stringWithFormat:@"%@ launchFieldTestIfNeeded handled=%d", source, handled ? 1 : 0]);
        return handled;
    } @catch (NSException *exception) {
        BLBridgeLog([NSString stringWithFormat:@"%@ exception=%@ reason=%@",
                     source,
                     exception.name ?: @"(null)",
                     exception.reason ?: @"(null)"]);
        return NO;
    }
}

static void BLRunFieldTest(void) {
    if (BLFieldTestRunning) {
        BLBridgeLog(@"request ignored; already running");
        return;
    }
    BLFieldTestRunning = YES;
    BLBridgeLog(@"request begin");

    NSString *code = @"*3001#12345#*";
    BOOL handled = NO;

    // MobilePhone's own call path asks launchFieldTestIfNeeded: before it
    // constructs a dial request. Invoke that special-code branch directly
    // inside MobilePhone instead of sending the string to CT/TU dialing APIs.
    Class dialerController = NSClassFromString(@"DialerController");
    handled = BLCallFieldTestSelector(dialerController, @"DialerController", code);

    if (!handled) {
        void *telephonyUI = dlopen("/System/Library/PrivateFrameworks/TelephonyUI.framework/TelephonyUI", RTLD_NOW | RTLD_GLOBAL);
        BLBridgeLog([NSString stringWithFormat:@"TelephonyUI dlopen=%p", telephonyUI]);
        Class phonePad = NSClassFromString(@"TPPhonePad");
        handled = BLCallFieldTestSelector(phonePad, @"TPPhonePad", code);
    }

    BLBridgeLog([NSString stringWithFormat:@"request end handled=%d", handled ? 1 : 0]);

    // The daemon posts up to three notifications while Phone is starting.
    // Keep the bridge busy long enough to collapse those retries into a
    // single handler invocation once this process has received one of them.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BLFieldTestRunning = NO;
        BLBridgeLog(@"request debounce released");
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
