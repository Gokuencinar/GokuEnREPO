#import "Module.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#import <signal.h>
#if BL_VARIANT_ROOTHIDE
#import <roothide.h>
#endif

@interface BLCCModule ()
@property (nonatomic, assign) BOOL cachedSelected;
@property (nonatomic, strong) dispatch_queue_t bandLockQueue;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        signal(SIGPIPE, SIG_IGN);
        _cachedSelected = NO;
        _bandLockQueue = dispatch_queue_create("com.gokuencinar.bandlock.ccmodule", DISPATCH_QUEUE_SERIAL);
        [self bl_refreshFromDaemon];
    }
    return self;
}

- (UIImage *)iconGlyph {
    return [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
}

- (UIImage *)selectedIconGlyph {
    return [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
}

- (UIColor *)selectedColor {
    return UIColor.systemBlueColor;
}

- (BOOL)isSelected {
    return self.cachedSelected;
}

- (void)setSelected:(BOOL)selected {
    self.cachedSelected = selected;
    [super refreshState];

    NSDictionary *request = @{
        @"cmd": @"rat",
        @"mode": selected ? @"lte" : @"automatic"
    };

    dispatch_async(self.bandLockQueue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:request];
        BOOL success = [result[@"success"] boolValue];
        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;

        if (success && modeCode.length) {
            [self bl_publishSelected:[modeCode isEqualToString:@"lte"]];
        } else {
            [self bl_refreshFromDaemon];
        }
    });
}

- (void)refreshState {
    [super refreshState];
    [self bl_refreshFromDaemon];
}

- (void)bl_publishSelected:(BOOL)selected {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cachedSelected = selected;
        [super refreshState];
    });
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

- (void)bl_refreshFromDaemon {
    dispatch_async(self.bandLockQueue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"status"}];
        if (![result[@"success"] boolValue]) return;
        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : @"";
        [self bl_publishSelected:[modeCode isEqualToString:@"lte"]];
    });
}

- (NSDictionary *)bl_sendRequestSynchronously:(NSDictionary *)request {
    NSError *jsonError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:request ?: @{} options:0 error:&jsonError];
    if (!body) return @{@"success": @NO};

    NSMutableData *wire = [body mutableCopy];
    [wire appendBytes:"\n" length:1];

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return @{@"success": @NO};

    int one = 1;
    (void)setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
    struct timeval timeout = {.tv_sec = 4, .tv_usec = 0};
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
    NSRange newline = [responseData rangeOfData:[NSData dataWithBytes:"\n" length:1]
                                       options:0
                                         range:NSMakeRange(0, responseData.length)];
    if (newline.location != NSNotFound) responseData.length = newline.location;

    id result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    return [result isKindOfClass:NSDictionary.class] ? result : @{@"success": @NO};
}

@end
