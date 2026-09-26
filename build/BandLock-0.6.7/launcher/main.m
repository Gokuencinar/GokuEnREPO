#import <Foundation/Foundation.h>
#include <dlfcn.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        const char *bundle = argc > 1 ? argv[1] : "com.gokuencinar.bandlock.app";
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_GLOBAL);
        if (!handle) {
            fprintf(stderr, "dlopen failed: %s\n", dlerror());
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
                    fprintf(stderr, "launch error=%d (%s)\n", result, buffer);
                }
            }
        }
        CFRelease(identifier);
        dlclose(handle);
        printf("launch result=%d\n", result);
        return result;
    }
}
