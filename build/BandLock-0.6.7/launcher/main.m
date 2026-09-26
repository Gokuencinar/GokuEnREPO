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
        CFStringRef identifier = CFStringCreateWithCString(kCFAllocatorDefault, bundle, kCFStringEncodingUTF8);
        if (!identifier) {
            dlclose(handle);
            return 3;
        }
        int result = launch(identifier, false);
        CFRelease(identifier);
        dlclose(handle);
        printf("launch result=%d\n", result);
        return result;
    }
}
