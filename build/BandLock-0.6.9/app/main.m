#import <UIKit/UIKit.h>
#import "BLAppDelegate.h"
#import <fcntl.h>
#import <unistd.h>
#import <string.h>

static void BLStartupLog(const char *message) {
    int fd = open("/var/tmp/BandLock-startup.log", O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) return;
    if (message) write(fd, message, strlen(message));
    close(fd);
}

int main(int argc, char *argv[]) {
    BLStartupLog("0.6.9 enter main\n");
    @autoreleasepool {
        BLStartupLog("0.6.9 autoreleasepool ready\n");
        BLStartupLog("0.6.9 before UIApplicationMain\n");
        int result = UIApplicationMain(argc, argv, nil, @"BLAppDelegate");
        BLStartupLog("0.6.9 UIApplicationMain returned\n");
        return result;
    }
}
