#import "CFCarrierUpdateManager.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const CFAppleIPCCURL =
    @"https://updates.cdn-apple.com/20240513/carrierbundles/032-23478/E247835C-8950-4A31-A430-A6DB27A40158/ATT_aio_US_iPhone.ipcc";
static NSString * const CFAppleSHA384 =
    @"55CED9623258B24B76670A5CA19CB5F53D4B23F7B7389E1257AAD8BED5BA981CB1241342B6740945F675FBB7BD0B29B5";

static NSError *CFUpdateError(NSString *reason) {
    return [NSError errorWithDomain:@"CarrierFixCarrierUpdate" code:1
                          userInfo:@{NSLocalizedDescriptionKey:reason ?: @"Unknown carrier update error."}];
}

static NSString *CFCarrierSHA384(NSData *data) {
    if (!data.length || data.length > UINT32_MAX) return nil;
    unsigned char digest[CC_SHA384_DIGEST_LENGTH] = {0};
    CC_SHA384(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA384_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA384_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    return result;
}

@implementation CFCarrierUpdateManager

+ (NSURL *)researchDirectory:(NSError **)error {
    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory
                                                              inDomains:NSUserDomainMask] firstObject];
    if (!library) {
        if (error) *error = CFUpdateError(@"Could not resolve the app's Library directory.");
        return nil;
    }
    NSURL *folder = [library URLByAppendingPathComponent:@"CarrierFixUpdateResearch" isDirectory:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm createDirectoryAtURL:folder
                                 withIntermediateDirectories:YES
                                                  attributes:@{NSFilePosixPermissions:@0700} error:error]) {
        return nil;
    }
    if (![fm setAttributes:@{NSFilePosixPermissions:@0700} ofItemAtPath:folder.path error:error]) {
        return nil;
    }
    return folder;
}

+ (BOOL)archiveCarrierAtPath:(NSString *)path
                    model:(NSString *)model
                   output:(NSURL **)output
                    error:(NSError **)error {
    if (![model isEqualToString:@"iPhone16,2"] ||
        ![path hasPrefix:@"/private/var/mobile/Library/Carrier Bundles/Overlay/"] ||
        ![path hasSuffix:@".plist"]) {
        if (error) *error = CFUpdateError(@"The active Cricket overlay does not match the tested iPhone 15 Pro Max path. Nothing was changed.");
        return NO;
    }
    NSData *original = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!original.length || original.length > (4 * 1024 * 1024)) {
        if (error && !*error) *error = CFUpdateError(@"Carrier overlay is missing or unexpectedly large.");
        return NO;
    }
    if (![NSPropertyListSerialization propertyListWithData:original options:0 format:nil error:error]) {
        return NO;
    }
    NSString *hash = CFCarrierSHA384(original);
    if (!hash.length) {
        if (error) *error = CFUpdateError(@"Could not hash the original carrier overlay.");
        return NO;
    }
    NSURL *folder = [self researchDirectory:error];
    if (!folder) return NO;
    NSString *idPart = NSUUID.UUID.UUIDString;
    NSURL *backup = [folder URLByAppendingPathComponent:[NSString stringWithFormat:@"Cricket-original-%@.plist", idPart]];
    NSURL *metadata = [folder URLByAppendingPathComponent:[NSString stringWithFormat:@"Cricket-original-%@.metadata.plist", idPart]];
    if (![original writeToURL:backup options:NSDataWritingAtomic error:error]) return NO;
    NSData *verified = [NSData dataWithContentsOfURL:backup options:0 error:error];
    NSData *current = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (![verified isEqualToData:original] || ![current isEqualToData:original]) {
        [[NSFileManager defaultManager] removeItemAtURL:backup error:nil];
        if (error) *error = CFUpdateError(@"Carrier overlay changed during the read-only snapshot. Snapshot was discarded.");
        return NO;
    }
    if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600}
                                           ofItemAtPath:backup.path error:error]) {
        [[NSFileManager defaultManager] removeItemAtURL:backup error:nil];
        return NO;
    }
    NSDictionary *meta = @{
        @"originalPath":path, @"model":model,
        @"iOS":NSProcessInfo.processInfo.operatingSystemVersionString ?: @"unknown",
        @"SHA384":hash, @"savedAt":[NSDate date],
        @"description":@"Reference copy only, NOT an independently verified restorable backup."
    };
    NSData *metadataData = [NSPropertyListSerialization dataWithPropertyList:meta
                                                                      format:NSPropertyListXMLFormat_v1_0
                                                                     options:0 error:error];
    if (!metadataData || ![metadataData writeToURL:metadata options:NSDataWritingAtomic error:error]) {
        [[NSFileManager defaultManager] removeItemAtURL:backup error:nil];
        return NO;
    }
    if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600}
                                           ofItemAtPath:metadata.path error:error]) {
        [[NSFileManager defaultManager] removeItemAtURL:backup error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:metadata error:nil];
        return NO;
    }
    NSDictionary *writtenMeta = [NSDictionary dictionaryWithContentsOfURL:metadata];
    if (![writtenMeta[@"SHA384"] isEqualToString:hash]) {
        [[NSFileManager defaultManager] removeItemAtURL:backup error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:metadata error:nil];
        if (error) *error = CFUpdateError(@"Snapshot metadata could not be verified.");
        return NO;
    }
    if (output) *output = backup;
    return YES;
}

+ (void)downloadOfficialCricket58WithCompletion:(void (^)(NSURL *fileURL, NSError *error))completion {
    NSParameterAssert(completion);
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 30;
    config.timeoutIntervalForResource = 60;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *url = [NSURL URLWithString:CFAppleIPCCURL];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url
                                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *requestError) {
        NSURL *result = nil;
        NSError *failure = requestError;
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
        if (!failure && (http.statusCode != 200 || ![response.URL.scheme.lowercaseString isEqualToString:@"https"])) {
            failure = CFUpdateError(@"Apple did not return an HTTPS carrier bundle (HTTP 200).");
        }
        if (!failure && (data.length != 89008 || memcmp(data.bytes, "PK\x03\x04", 4) != 0 ||
                         ![CFCarrierSHA384(data) isEqualToString:CFAppleSHA384])) {
            failure = CFUpdateError(@"The downloaded Cricket 58.1 carrier bundle did not match Apple's pinned SHA-384. File rejected.");
        }
        if (!failure) {
            NSURL *folder = [self researchDirectory:&failure];
            NSURL *destination = [folder URLByAppendingPathComponent:@"ATT_aio_US_iPhone.ipcc"];
            if (!failure && [data writeToURL:destination options:NSDataWritingAtomic error:&failure]) {
                NSData *check = [NSData dataWithContentsOfURL:destination options:0 error:&failure];
                if ([CFCarrierSHA384(check) isEqualToString:CFAppleSHA384]) {
                    result = destination;
                } else {
                    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
                    failure = CFUpdateError(@"Saved update file did not pass verification.");
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(result, failure); });
        [session finishTasksAndInvalidate];
    }];
    [task resume];
}
@end
