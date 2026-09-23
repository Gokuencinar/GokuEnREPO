#import <Preferences/PSListController.h>

@interface BLRootListController : PSListController
- (NSString *)statusValue;
- (NSString *)ratValue;
- (NSString *)supportedBandsValue;
- (NSString *)activeBandsValue;
- (NSString *)detailValue;
- (NSString *)logValue;
- (NSString *)versionValue;
- (void)reloadBands;
- (void)clearLogs;
@end
