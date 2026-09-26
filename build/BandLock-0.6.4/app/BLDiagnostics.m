#import "BLDiagnostics.h"
#import <signal.h>
#import <fcntl.h>
#import <unistd.h>
#import <string.h>
#import <stdio.h>

static NSString * const BLDiagPath = @"/var/tmp/BandLock-ui-diagnostics.log";
static const char *BLSignalPath = "/var/tmp/BandLock-ui-signal.log";

void BLDiagLog(NSString *event) {
    @autoreleasepool {
        NSString *line = [NSString stringWithFormat:@"%@ | %@\n", [NSDate date], event ?: @"(null)"];
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        @synchronized (NSFileManager.defaultManager) {
            if (![NSFileManager.defaultManager fileExistsAtPath:BLDiagPath]) {
                [data writeToFile:BLDiagPath atomically:YES];
            } else {
                NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:BLDiagPath];
                [handle seekToEndOfFile];
                [handle writeData:data];
                [handle closeFile];
            }
        }
    }
}

static void BLSignalHandler(int signo) {
    char buffer[96];
    int length = snprintf(buffer, sizeof(buffer), "BandLock received signal %d\n", signo);
    int fd = open(BLSignalPath, O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd >= 0) {
        if (length > 0) write(fd, buffer, (size_t)length);
        close(fd);
    }
    signal(signo, SIG_DFL);
    raise(signo);
}

static void BLExceptionHandler(NSException *exception) {
    NSString *stack = [exception.callStackSymbols componentsJoinedByString:@"\n"] ?: @"";
    BLDiagLog([NSString stringWithFormat:@"UNCAUGHT %@: %@\n%@", exception.name, exception.reason, stack]);
}

void BLInstallCrashDiagnostics(void) {
    NSSetUncaughtExceptionHandler(&BLExceptionHandler);
    signal(SIGABRT, BLSignalHandler);
    signal(SIGSEGV, BLSignalHandler);
    signal(SIGBUS, BLSignalHandler);
    signal(SIGILL, BLSignalHandler);
    signal(SIGTRAP, BLSignalHandler);
    BLDiagLog(@"=== BandLock 0.6.4 launch ===");
}
