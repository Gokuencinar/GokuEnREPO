#import "Module.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <string.h>

#if BL_VARIANT_ROOTHIDE
#import <roothide.h>
#endif

@interface CCUIToggleModule (BLReconfigure)
- (void)reconfigureView;
@end

@interface BLCCModule ()
@property (nonatomic, copy) NSString *currentModeCode;
@property (nonatomic, assign) BOOL supports5G;
@property (nonatomic, assign) BOOL requestInFlight;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentModeCode = @"automatic";
        _supports5G = NO;
        _requestInFlight = NO;
        _daemonQueue = dispatch_queue_create("com.gokuencinar.bandlock.ccmodule", DISPATCH_QUEUE_SERIAL);
        [self bl_refreshFromDaemon];
    }
    return self;
}

- (UIImage *)iconGlyph {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
    label.textColor = UIColor.blackColor;
    label.backgroundColor = UIColor.clearColor;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.7;
    label.clipsToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;

    NSString *text = @"Auto";
    if ([self.currentModeCode isEqualToString:@"lte"]) text = @"4G";
    else if ([self.currentModeCode isEqualToString:@"3g"]) text = @"3G";
    else if (self.supports5G && [self.currentModeCode hasPrefix:@"5g-"]) text = @"5G";
    else if (![self.currentModeCode isEqualToString:@"automatic"]) text = @"?";

    label.font = [UIFont systemFontOfSize:[text isEqualToString:@"Auto"] ? 13.0 : 16.0
                                  weight:UIFontWeightSemibold];
    label.text = text;

    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 0.0);
    [label.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)selectedIconGlyph {
    return [self iconGlyph];
}

- (UIColor *)selectedColor {
    return UIColor.systemBlueColor;
}

- (BOOL)isSelected {
    if ([self.currentModeCode isEqualToString:@"lte"]) return YES;
    if ([self.currentModeCode isEqualToString:@"3g"]) return YES;
    if (self.supports5G && [self.currentModeCode hasPrefix:@"5g-"]) return YES;
    return NO;
}

- (void)setSelected:(BOOL)selected {
    (void)selected;
    if (self.requestInFlight) return;
    [self bl_cycleToNextMode];
}

- (void)refreshState {
    [super refreshState];
    if (!self.daemonQueue) return;
    [self bl_refreshFromDaemon];
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

- (NSArray<NSString *> *)bl_modeSequence {
    if (self.supports5G) {
        return @[@"automatic", @"lte", @"5g-on", @"3g"];
    }
    return @[@"automatic", @"lte", @"3g"];
}

- (void)bl_cycleToNextMode {
    NSArray<NSString *> *sequence = [self bl_modeSequence];
    NSUInteger index = [sequence indexOfObject:self.currentModeCode ?: @"automatic"];
    if (index == NSNotFound) index = 0;
    NSString *nextMode = sequence[(index + 1) % sequence.count];

    self.requestInFlight = YES;
    dispatch_queue_t queue = self.daemonQueue;
    if (!queue) {
        self.requestInFlight = NO;
        return;
    }

    dispatch_async(queue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"rat", @"mode": nextMode}];
        BOOL success = [result[@"success"] boolValue];
        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        BOOL supports5G = [result[@"supports_5g"] boolValue];

        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"automatic";

        dispatch_async(dispatch_get_main_queue(), ^{
            self.requestInFlight = NO;
            if (success && modeCode.length) {
                self.currentModeCode = modeCode;
                self.supports5G = supports5G;
                [self reconfigureView];
            } else {
                [self bl_refreshFromDaemon];
            }
        });
    });
}

- (void)bl_refreshFromDaemon {
    dispatch_queue_t queue = self.daemonQueue;
    if (!queue) return;

    dispatch_async(queue, ^{
        NSDictionary *result = [self bl_sendRequestSynchronously:@{@"cmd": @"status"}];
        if (![result[@"success"] boolValue]) return;

        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        BOOL supports5G = [result[@"supports_5g"] boolValue];
        if (!modeCode.length) return;
        if (!supports5G && [modeCode hasPrefix:@"5g-"]) modeCode = @"automatic";

        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentModeCode = modeCode;
            self.supports5G = supports5G;
            [self reconfigureView];
        });
    });
}

- (NSDictionary *)bl_sendRequestSynchronously:(NSDictionary *)request {
    NSData *body = [NSJSONSerialization dataWithJSONObject:request ?: @{} options:0 error:nil];
    if (!body) return @{@"success": @NO};

    NSMutableData *wire = [body mutableCopy];
    [wire appendBytes:"\n" length:1];

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return @{@"success": @NO};

    int one = 1;
    (void)setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
    struct timeval timeout = {.tv_sec = 1, .tv_usec = 500000};
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

    NSRange newline =
        [responseData rangeOfData:[NSData dataWithBytes:"\n" length:1]
                          options:0
                            range:NSMakeRange(0, responseData.length)];
    if (newline.location != NSNotFound) responseData.length = newline.location;

    id result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    return [result isKindOfClass:NSDictionary.class] ? result : @{@"success": @NO};
}

@end
