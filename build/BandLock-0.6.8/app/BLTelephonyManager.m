#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLProbe.h"

@interface BLTelephonyManager ()
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousBands;
@property (nonatomic, copy, readwrite) NSString *radioAccessTechnology;
@property (nonatomic, copy, readwrite) NSString *servingBand;
@property (nonatomic, copy, readwrite) NSString *networkMode;
@property (nonatomic, copy, readwrite) NSString *statusText;
@property (nonatomic, copy, readwrite) NSString *detailText;
@property (nonatomic, assign, readwrite) BOOL hasReadState;
@property (nonatomic, assign, readwrite) BOOL busy;
@end

@implementation BLTelephonyManager

+ (instancetype)sharedManager {
    static BLTelephonyManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] initPrivate]; });
    return manager;
}

- (instancetype)init { return BLTelephonyManager.sharedManager; }

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        BLProbeLog("manager init\n");
        _supportedBands = @[@1,@3,@7,@8,@20,@28,@38];
        _activeBands = @[@1,@3,@7,@8,@20,@28,@38];
        _pendingBands = _activeBands;
        _previousBands = @[];
        _radioAccessTechnology = @"LTE/4G (stub)";
        _servingBand = @"B20 (stub)";
        _networkMode = @"Automatic (stub)";
        _statusText = @"Stub ready";
        _detailText = @"UI diagnostic: no socket or CoreTelephony is used.";
        _hasReadState = YES;
        _busy = NO;
    }
    return self;
}

- (void)complete:(BLActionCompletion)completion message:(NSString *)message {
    self.statusText = @"Stub OK";
    self.detailText = message ?: @"Stub OK";
    if (completion) completion(YES, self.detailText);
}

- (void)refreshWithCompletion:(BLActionCompletion)completion {
    BLProbeLog("stub refresh begin\n");
    self.busy = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.busy = NO;
        BLProbeLog("stub refresh completion\n");
        [self complete:completion message:@"Stub refresh completed without IPC."];
    });
}

- (void)setPendingBands:(NSArray<NSNumber *> *)bands { self.pendingBands = BLSortedBands(bands); }
- (void)setNetworkModeAutomatic:(BLActionCompletion)completion { self.networkMode = @"Automatic (stub)"; [self complete:completion message:@"Stub automatic mode."]; }
- (void)setNetworkModeLTEOnly:(BLActionCompletion)completion { self.networkMode = @"LTE only (stub)"; [self complete:completion message:@"Stub LTE-only mode."]; }
- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion { self.activeBands = self.pendingBands; [self complete:completion message:@"Stub apply."]; }
- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion { [self complete:completion message:@"Stub restore previous."]; }
- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion { self.pendingBands = self.supportedBands; self.activeBands = self.supportedBands; [self complete:completion message:@"Stub restore all."]; }
- (void)openFieldTestWithCompletion:(BLActionCompletion)completion { [self complete:completion message:@"Stub Field Test."]; }

@end
