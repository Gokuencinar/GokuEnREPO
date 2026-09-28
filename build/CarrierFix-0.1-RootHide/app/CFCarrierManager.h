#import <Foundation/Foundation.h>
@interface CFCarrierManager : NSObject
- (NSDictionary *)diagnose;
- (BOOL)isCricketConfiguration:(NSDictionary *)diagnosis;
- (BOOL)prepareForApply:(NSString **)message;
- (BOOL)hasVerifiedBackupForActiveCarrier;
- (BOOL)applyCricketSMSFix:(NSString **)message;
- (BOOL)restoreOriginal:(NSString **)message;
- (NSString *)diagnosticText;
@end