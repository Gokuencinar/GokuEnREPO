#import <Foundation/Foundation.h>

@class BLTelephonyManager;

// Experimental, opt-in LTE scanning. Never auto-start a radio mutation.
@interface BLSignalScan : NSObject
+ (instancetype)sharedScan;
- (NSDictionary *)probeWithManager:(BLTelephonyManager *)manager;
- (NSDictionary *)startWithManager:(BLTelephonyManager *)manager;
- (NSDictionary *)status;
- (NSDictionary *)cancel;
- (NSDictionary *)requestRecoveryWithManager:(BLTelephonyManager *)manager;
- (BOOL)isRunning;
- (BOOL)hasPendingRecovery;
- (void)recoverIfNeededWithManager:(BLTelephonyManager *)manager;
@end
