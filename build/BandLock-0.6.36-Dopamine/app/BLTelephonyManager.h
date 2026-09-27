#import <Foundation/Foundation.h>

typedef void (^BLActionCompletion)(BOOL success, NSString *message);

@interface BLTelephonyManager : NSObject

@property (nonatomic, copy, readonly) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *previousBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *supportedNRBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *activeNRBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *pendingNRBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *previousNRBands;
@property (nonatomic, assign, readonly) BOOL supports5G;
@property (nonatomic, copy, readonly) NSString *radioAccessTechnology;
@property (nonatomic, copy, readonly) NSString *servingBand;
@property (nonatomic, copy, readonly) NSString *networkMode;
@property (nonatomic, copy, readonly) NSString *statusText;
@property (nonatomic, copy, readonly) NSString *detailText;
@property (nonatomic, assign, readonly) BOOL hasReadState;
@property (nonatomic, assign, readonly) BOOL hasRefreshedStatus;
@property (nonatomic, assign, readonly) BOOL busy;

+ (instancetype)sharedManager;

- (void)refreshWithCompletion:(BLActionCompletion)completion;
- (void)setPendingBands:(NSArray<NSNumber *> *)bands;
- (void)setPendingNRBands:(NSArray<NSNumber *> *)bands;
- (void)setNetworkModeAutomatic:(BLActionCompletion)completion;
- (void)setNetworkModeLTEOnly:(BLActionCompletion)completion;
- (void)setNetworkMode5GAuto:(BLActionCompletion)completion;
- (void)setNetworkMode5GOn:(BLActionCompletion)completion;
- (void)setNetworkMode5GOnly:(BLActionCompletion)completion;
- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion;
- (void)applyPendingNRBandsWithCompletion:(BLActionCompletion)completion;
- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion;
- (void)restorePreviousNRBandsWithCompletion:(BLActionCompletion)completion;
- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion;
- (void)restoreAllSupportedNRBandsWithCompletion:(BLActionCompletion)completion;
- (void)openFieldTestWithCompletion:(BLActionCompletion)completion;

@end
