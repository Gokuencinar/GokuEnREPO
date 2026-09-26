#import <UIKit/UIKit.h>
#import "BLAppDelegate.h"
#import "BLDiagnostics.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        BLInstallCrashDiagnostics();
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(BLAppDelegate.class));
    }
}
