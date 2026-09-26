#import <Foundation/Foundation.h>

typedef void (^BLActionCompletion)(BOOL success, NSString *message);

@interface BLTelephonyManager : NSObject

@property (nonatomic, copy, readonly) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *previousBands;
@property (nonatomic, copy, readonly) NSString *radioAccessTechnology;
@property (nonatomic, copy, readonly) NSString *servingBand;
@property (nonatomic, copy, readonly) NSString *networkMode;
@property (nonatomic, copy, readonly) NSString *statusText;
@property (nonatomic, copy, readonly) NSString *detailText;
@property (nonatomic, assign, readonly) BOOL hasReadState;
@property (nonatomic, assign, readonly) BOOL busy;

+ (instancetype)sharedManager;

- (void)refreshWithCompletion:(BLActionCompletion)completion;
- (void)setPendingBands:(NSArray<NSNumber *> *)bands;
- (void)setNetworkModeAutomatic:(BLActionCompletion)completion;
- (void)setNetworkModeLTEOnly:(BLActionCompletion)completion;
- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion;
- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion;
- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion;
- (void)openFieldTestWithCompletion:(BLActionCompletion)completion;

@end
