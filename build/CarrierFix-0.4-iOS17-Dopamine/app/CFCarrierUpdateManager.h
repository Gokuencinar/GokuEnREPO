#import <Foundation/Foundation.h>

// Stages official, byte-for-byte verified carrier update files.
// Does not modify the active carrier, baseband, SIM/eSIM or iOS.
@interface CFCarrierUpdateManager : NSObject
+ (BOOL)archiveCarrierAtPath:(NSString *)path
                    model:(NSString *)model
                   output:(NSURL **)output
           expectedSHA384:(NSString **)expectedSHA384
                    error:(NSError **)error;
+ (void)downloadOfficialCricket58WithCompletion:(void (^)(NSURL *fileURL, NSError *error))completion;
+ (NSString *)officialCricket58SHA384;
+ (BOOL)verifyExportAtURL:(NSURL *)fileURL
           expectedSHA384:(NSString *)expectedSHA384
                    error:(NSError **)error;
+ (void)discardReferenceAtURL:(NSURL *)fileURL;
// Read-only preflight: checks effective entitlements and CoreTelephony symbols.
// It never invokes install/reset, changes any carrier files, or restarts CommCenter.
+ (NSString *)onDeviceInstallationCapabilityReport;
@end
