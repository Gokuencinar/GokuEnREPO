#import <Foundation/Foundation.h>
#include <dlfcn.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

static BOOL BLLaunchWithLaunchServices(NSString *bundleID) {
    void *core = dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_GLOBAL);
    if (!core) {
        core = dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_GLOBAL);
    }

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass || ![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        if (core) dlclose(core);
        return NO;
    }

    LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
    BOOL opened = [workspace openApplicationWithBundleID:bundleID];
    if (core) dlclose(core);
    return opened;
}

static int BLLaunchWithSpringBoardServices(const char *bundle) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_GLOBAL);
    if (!handle) {
        fprintf(stderr, "SpringBoardServices dlopen failed: %s\n", dlerror());
        return 1;
    }

    int (*launch)(CFStringRef, bool) = dlsym(handle, "SBSLaunchApplicationWithIdentifier");
    if (!launch) {
        fprintf(stderr, "SBSLaunchApplicationWithIdentifier unavailable\n");
        dlclose(handle);
        return 2;
    }

    CFStringRef (*errorString)(unsigned int) = dlsym(handle, "SBSApplicationLaunchingErrorString");
    CFStringRef identifier = CFStringCreateWithCString(kCFAllocatorDefault, bundle, kCFStringEncodingUTF8);
    if (!identifier) {
        dlclose(handle);
        return 3;
    }

    int result = launch(identifier, false);
    if (result != 0 && errorString) {
        CFStringRef message = errorString((unsigned int)result);
        if (message) {
            char buffer[512] = {0};
            if (CFStringGetCString(message, buffer, sizeof(buffer), kCFStringEncodingUTF8)) {
                fprintf(stderr, "SpringBoardServices error=%d (%s)\n", result, buffer);
            }
        }
    }

    CFRelease(identifier);
    dlclose(handle);
    return result;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        const char *bundle = argc > 1 ? argv[1] : "com.gokuencinar.bandlock.app";
        NSString *bundleID = [NSString stringWithUTF8String:bundle];
        if (!bundleID.length) {
            fprintf(stderr, "Invalid bundle identifier\n");
            return 3;
        }

        if (BLLaunchWithLaunchServices(bundleID)) {
            printf("launch method=LaunchServices result=success\n");
            return 0;
        }

        fprintf(stderr, "LaunchServices did not open %s; trying SpringBoardServices\n", bundle);
        int result = BLLaunchWithSpringBoardServices(bundle);
        printf("launch method=SpringBoardServices result=%d\n", result);
        return result;
    }
}
