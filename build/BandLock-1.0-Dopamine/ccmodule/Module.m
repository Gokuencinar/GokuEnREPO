#import "Module.h"
#import <ControlCenterUIKit/ControlCenterUI-Structs.h>
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <signal.h>
#import <string.h>
#if BL_VARIANT_ROOTHIDE
#import <roothide.h>
#endif

typedef NS_ENUM(NSInteger, BLCCMode) {
    BLCCModeAutomatic = 0,
    BLCCModeLTE,
    BLCCMode5G,
    BLCCMode3G
};

@interface BLCCContentViewController ()
@property (nonatomic, copy) NSString *currentModeCode;
@property (nonatomic, strong) NSArray<UIButton *> *modeButtons;
@property (nonatomic, strong) dispatch_queue_t daemonQueue;
@end

@implementation BLCCModule

- (instancetype)init {
    self = [super init];
    if (self) {
        _contentViewController = [BLCCContentViewController new];
    }
    return self;
}

- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation {
    return (CCUILayoutSize){2, 2};
}

@end

@implementation BLCCContentViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        signal(SIGPIPE, SIG_IGN);
        _currentModeCode = @"unknown";
        _daemonQueue = dispatch_queue_create("com.gokuencinar.bandlock.ccmodule", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.clipsToBounds = YES;

    NSArray<NSString *> *titles = @[@"Auto", @"4G", @"5G", @"3G"];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray arrayWithCapacity:4];

    for (NSInteger index = 0; index < 4; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = index;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        button.layer.cornerRadius = 14.0;
        button.clipsToBounds = YES;
        [button setTitle:titles[index] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(modeTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
        [buttons addObject:button];
    }
    self.modeButtons = buttons;

    UIButton *autoButton = buttons[0];
    UIButton *lteButton = buttons[1];
    UIButton *fiveGButton = buttons[2];
    UIButton *threeGButton = buttons[3];

    UILayoutGuide *guide = self.view.layoutMarginsGuide;
    self.view.layoutMargins = UIEdgeInsetsMake(7, 7, 7, 7);
    CGFloat gap = 7.0;

    [NSLayoutConstraint activateConstraints:@[
        [autoButton.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [autoButton.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [lteButton.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [lteButton.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [threeGButton.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [threeGButton.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
        [fiveGButton.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [fiveGButton.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],

        [autoButton.trailingAnchor constraintEqualToAnchor:lteButton.leadingAnchor constant:-gap],
        [threeGButton.trailingAnchor constraintEqualToAnchor:fiveGButton.leadingAnchor constant:-gap],
        [autoButton.bottomAnchor constraintEqualToAnchor:threeGButton.topAnchor constant:-gap],
        [lteButton.bottomAnchor constraintEqualToAnchor:fiveGButton.topAnchor constant:-gap],

        [autoButton.widthAnchor constraintEqualToAnchor:lteButton.widthAnchor],
        [autoButton.widthAnchor constraintEqualToAnchor:threeGButton.widthAnchor],
        [autoButton.widthAnchor constraintEqualToAnchor:fiveGButton.widthAnchor],
        [autoButton.heightAnchor constraintEqualToAnchor:lteButton.heightAnchor],
        [autoButton.heightAnchor constraintEqualToAnchor:threeGButton.heightAnchor],
        [autoButton.heightAnchor constraintEqualToAnchor:fiveGButton.heightAnchor]
    ]];

    [self updateButtonAppearance];
    [self refreshFromDaemon];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFromDaemon];
}

- (CGFloat)preferredExpandedContentWidth {
    return UIScreen.mainScreen.bounds.size.width * 0.82;
}

- (CGFloat)preferredExpandedContentHeight {
    return self.preferredExpandedContentWidth;
}

- (BOOL)providesOwnPlatter {
    return NO;
}

- (BOOL)_canShowWhileLocked {
    return YES;
}

- (NSString *)socketPath {
#if BL_VARIANT_ROOTHIDE
    NSString *resolved = jbroot(@"/tmp/com.gokuencinar.bandlockd.sock");
    return resolved.length ? resolved : @"/tmp/com.gokuencinar.bandlockd.sock";
#elif BL_VARIANT_ROOTFUL
    return @"/tmp/com.gokuencinar.bandlockd.rootful.sock";
#else
    return @"/tmp/com.gokuencinar.bandlockd.dopamine.sock";
#endif
}

- (NSString *)daemonModeForButton:(BLCCMode)mode {
    switch (mode) {
        case BLCCModeLTE: return @"lte";
        case BLCCMode5G: return @"5g-on";
        case BLCCMode3G: return @"3g";
        case BLCCModeAutomatic:
        default: return @"automatic";
    }
}

- (NSString *)displayCodeForButton:(BLCCMode)mode {
    switch (mode) {
        case BLCCModeLTE: return @"lte";
        case BLCCMode5G: return @"5g-on";
        case BLCCMode3G: return @"3g";
        case BLCCModeAutomatic:
        default: return @"automatic";
    }
}

- (void)modeTapped:(UIButton *)sender {
    BLCCMode mode = (BLCCMode)sender.tag;
    NSString *requestedMode = [self daemonModeForButton:mode];
    NSString *optimisticCode = [self displayCodeForButton:mode];

    self.currentModeCode = optimisticCode;
    [self updateButtonAppearance];
    [self setButtonsEnabled:NO];

    dispatch_async(self.daemonQueue, ^{
        NSDictionary *result = [self sendRequestSynchronously:@{@"cmd": @"rat", @"mode": requestedMode}];
        if ([result[@"success"] boolValue]) {
            NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
            if (modeCode.length) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.currentModeCode = modeCode;
                    [self updateButtonAppearance];
                    [self setButtonsEnabled:YES];
                });
                return;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setButtonsEnabled:YES];
        });
        [self refreshFromDaemon];
    });
}

- (void)setButtonsEnabled:(BOOL)enabled {
    for (UIButton *button in self.modeButtons) button.enabled = enabled;
}

- (BOOL)isButtonSelected:(BLCCMode)mode {
    if (mode == BLCCModeAutomatic) return [self.currentModeCode isEqualToString:@"automatic"] || [self.currentModeCode isEqualToString:@"5g-auto"];
    if (mode == BLCCModeLTE) return [self.currentModeCode isEqualToString:@"lte"];
    if (mode == BLCCMode5G) return [self.currentModeCode hasPrefix:@"5g-"];
    if (mode == BLCCMode3G) return [self.currentModeCode isEqualToString:@"3g"];
    return NO;
}

- (void)updateButtonAppearance {
    for (UIButton *button in self.modeButtons) {
        BOOL selected = [self isButtonSelected:(BLCCMode)button.tag];
        button.backgroundColor = selected ? UIColor.systemBlueColor : [UIColor.whiteColor colorWithAlphaComponent:0.13];
        [button setTitleColor:selected ? UIColor.whiteColor : UIColor.labelColor forState:UIControlStateNormal];
        button.alpha = button.enabled ? 1.0 : 0.72;
    }
}

- (void)refreshFromDaemon {
    dispatch_async(self.daemonQueue, ^{
        NSDictionary *result = [self sendRequestSynchronously:@{@"cmd": @"status"}];
        if (![result[@"success"] boolValue]) return;
        NSString *modeCode = [result[@"mode_code"] isKindOfClass:NSString.class] ? result[@"mode_code"] : nil;
        if (!modeCode.length) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentModeCode = modeCode;
            [self updateButtonAppearance];
        });
    });
}

- (NSDictionary *)sendRequestSynchronously:(NSDictionary *)request {
    NSData *body = [NSJSONSerialization dataWithJSONObject:request ?: @{} options:0 error:nil];
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

    const char *path = self.socketPath.fileSystemRepresentation;
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
