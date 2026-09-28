#import <UIKit/UIKit.h>
#import "CFAppDelegate.h"
#import "CFCarrierManager.h"
#include <string.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--diagnose") == 0) {
            NSString *diagnostic = [[CFCarrierManager new] diagnosticText];
            fprintf(stdout, "%s\n", diagnostic.UTF8String ?: "CarrierFix diagnostic unavailable");
            return 0;
        }
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(CFAppDelegate.class));
    }
}
