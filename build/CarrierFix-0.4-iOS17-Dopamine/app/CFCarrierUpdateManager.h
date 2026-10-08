#import <Foundation/Foundation.h>

// Stages official, byte-for-byte verified carrier update files.
// Does not modify the active carrier, baseband, SIM/eSIM or iOS.
@interface CFCarrierUpdateManager : NSObject
+ (BOOL)archiveCarrierAtPath:(NSString *)path
                    model:(NSString *)model
                   output:(NSURL **)output
                    error:(NSError **)error;
+ (void)downloadOfficialCricket58WithCompletion:(void (^)(NSURL *fileURL, NSError *error))completion;
@end
