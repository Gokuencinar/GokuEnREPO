#import "CFCarrierUpdateManager.h"
#import <CommonCrypto/CommonDigest.h>
#import <limits.h>
#import <stdlib.h>
#import <string.h>
#import <sys/stat.h>
#import <dlfcn.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <unistd.h>

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

+ (NSString *)onDeviceInstallationCapabilityReport {
    SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
    CFErrorRef entitlementError = NULL;
    CFTypeRef entitlement = task ?
        SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.CommCenter.fine-grained"), &entitlementError) : NULL;
    NSArray *rights = (entitlement && CFGetTypeID(entitlement) == CFArrayGetTypeID()) ?
        (__bridge NSArray *)entitlement : @[];
    BOOL spiDeclared = [rights containsObject:@"spi"];
    BOOL resetDeclared = [rights containsObject:@"preferences-reset"];
    BOOL platformDeclared = NO;
    if (task) {
        CFTypeRef platform = SecTaskCopyValueForEntitlement(task, CFSTR("platform-application"), NULL);
        platformDeclared = platform && CFGetTypeID(platform) == CFBooleanGetTypeID() && CFBooleanGetValue(platform);
        if (platform) CFRelease(platform);
    }
    if (entitlement) CFRelease(entitlement);
    if (entitlementError) CFRelease(entitlementError);
    if (task) CFRelease(task);

    void *library = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony",
                           RTLD_NOW | RTLD_LOCAL);
    BOOL createAPI = library && dlsym(library, "_CTServerConnectionCreate");
    BOOL installAPI = library && dlsym(library, "_CTServerConnectionInstallCarrierBundle");
    BOOL resetAPI = library && dlsym(library, "_CTServerConnectionResetCarrierBundle");
    if (library) dlclose(library);

    NSString *version = [UIDevice currentDevice].systemVersion ?: @"unknown";
    BOOL canInvestigate = platformDeclared && spiDeclared && createAPI && installAPI && resetAPI;
    return [NSString stringWithFormat:
      @"CarrierFix on-device IPCC preflight (read-only)\n"
       @"iOS: %@\n"
       @"Effective UID: %u\n"
       @"Platform entitlement present: %@\n"
       @"CommCenter SPI entitlement present: %@\n"
       @"CommCenter preferences-reset entitlement present: %@\n"
       @"CoreTelephony library load: %@\n"
       @"Create connection symbol: %@\n"
       @"Install carrier bundle symbol: %@\n"
       @"Reset carrier bundle symbol: %@\n\n"
       @"Preliminary eligibility: %@\n"
       @"No installation, restore or service restart was attempted. "
       @"These checks do not prove CommCenter will authorize an install or accept Cricket 58.1 on iOS %@. "
       @"An original overlay reference copy is not a tested rollback.",
       version, (unsigned)geteuid(),
       platformDeclared ? @"YES" : @"NO", spiDeclared ? @"YES" : @"NO",
       resetDeclared ? @"YES" : @"NO",
       library ? @"YES" : @"NO",
       createAPI ? @"YES" : @"NO",
       installAPI ? @"YES" : @"NO",
       resetAPI ? @"YES" : @"NO",
       canInvestigate ? @"POTENTIAL (not verified)" : @"BLOCKED / requires more investigation", version];
}

+ (NSURL *)researchDirectory:(NSError **)error {
    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory
                                                              inDomains:NSUserDomainMask] firstObject];
    if (!library) {
        if (error) *error = CFUpdateError(@"Could not resolve the app's cache directory.");
        return nil;
    }
    NSURL *folder = [library URLByAppendingPathComponent:@"CarrierFixUpdateResearch" isDirectory:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm createDirectoryAtURL:folder
                                 withIntermediateDirectories:YES
                                                  attributes:@{NSFilePosixPermissions:@0700} error:error]) {
        return nil;
    }
    // A same-UID jailbreak process must not redirect our staging directory
    // through a pre-existing symbolic link.
    struct stat directoryInfo = {0};
    if (lstat(folder.fileSystemRepresentation, &directoryInfo) != 0 ||
        !S_ISDIR(directoryInfo.st_mode) || S_ISLNK(directoryInfo.st_mode)) {
        if (error) *error = CFUpdateError(@"The carrier update staging directory is not a real directory.");
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
           expectedSHA384:(NSString **)expectedSHA384
                    error:(NSError **)error {
    // Verify the canonical filesystem location, not an untrusted string prefix
    // that could contain ../ traversal or resolve through a malicious symlink.
    char canonical[PATH_MAX] = {0};
    if (![model isEqualToString:@"iPhone16,2"] || !path.length ||
        !realpath(path.fileSystemRepresentation, canonical)) {
        if (error) *error = CFUpdateError(@"The active Cricket overlay does not match the tested iPhone 15 Pro Max path. Nothing was changed.");
        return NO;
    }
    NSString *resolvedPath = [NSString stringWithUTF8String:canonical];
    if (![resolvedPath hasPrefix:@"/private/var/mobile/Library/Carrier Bundles/Overlay/"] ||
        ![resolvedPath hasSuffix:@".plist"] || ![path isEqualToString:resolvedPath]) {
        if (error) *error = CFUpdateError(@"Carrier overlay path is not canonical or escapes the expected Overlay directory.");
        return NO;
    }
    NSData *original = [NSData dataWithContentsOfFile:resolvedPath options:0 error:error];
    if (!original.length || original.length > (4 * 1024 * 1024)) {
        if (error && !*error) *error = CFUpdateError(@"Carrier overlay is missing or unexpectedly large.");
        return NO;
    }
    NSDictionary *carrier = [NSPropertyListSerialization propertyListWithData:original options:0 format:nil error:error];
    NSString *carrierName = [carrier[@"CarrierName"] isKindOfClass:NSString.class] ? carrier[@"CarrierName"] : @"";
    NSString *wifiName = [carrier[@"OverrideOperatorWiFiName"] isKindOfClass:NSString.class] ? carrier[@"OverrideOperatorWiFiName"] : @"";
    BOOL cricket = [carrierName rangeOfString:@"Cricket" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                   [wifiName rangeOfString:@"Cricket" options:NSCaseInsensitiveSearch].location != NSNotFound;
    if (![carrier isKindOfClass:NSDictionary.class] || !cricket) {
        if (error) *error = CFUpdateError(@"The active plist is not a validated Cricket dictionary.");
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
    NSData *current = [NSData dataWithContentsOfFile:resolvedPath options:0 error:error];
    if (![verified isEqualToData:original] || ![current isEqualToData:original]) {
        [[NSFileManager defaultManager] removeItemAtURL:backup error:nil];
        if (error) *error = CFUpdateError(@"Carrier overlay changed during the read-only snapshot. Snapshot was discarded.");
        return NO;
    }
    if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600,
                                                        NSFileProtectionKey:NSFileProtectionComplete}
                                           ofItemAtPath:backup.path error:error]) {
        [[NSFileManager defaultManager] removeItemAtURL:backup error:nil];
        return NO;
    }
    NSDictionary *meta = @{
        @"originalPath":resolvedPath, @"model":model,
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
    if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600,
                                                        NSFileProtectionKey:NSFileProtectionComplete}
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
    if (expectedSHA384) *expectedSHA384 = hash;
    return YES;
}

+ (NSString *)officialCricket58SHA384 {
    return CFAppleSHA384;
}

+ (BOOL)verifyExportAtURL:(NSURL *)fileURL
           expectedSHA384:(NSString *)expectedSHA384
                    error:(NSError **)error {
    if (!fileURL.isFileURL || expectedSHA384.length != CC_SHA384_DIGEST_LENGTH * 2) {
        if (error) *error = CFUpdateError(@"File/hash selection is invalid.");
        return NO;
    }
    NSURL *folder = [self researchDirectory:error];
    if (!folder) return NO;
    NSString *name = fileURL.lastPathComponent ?: @"";
    BOOL official = [name isEqualToString:@"ATT_aio_US_iPhone.ipcc"];
    BOOL original = [name hasPrefix:@"Cricket-original-"] && [name hasSuffix:@".plist"] &&
                    ![name hasSuffix:@".metadata.plist"];
    if ((!official && !original) || (official && ![expectedSHA384 isEqualToString:CFAppleSHA384])) {
        if (error) *error = CFUpdateError(@"Unexpected staged carrier file.");
        return NO;
    }
    char fileResolved[PATH_MAX] = {0};
    char folderResolved[PATH_MAX] = {0};
    struct stat item = {0};
    if (!realpath(fileURL.fileSystemRepresentation, fileResolved) ||
        !realpath(folder.fileSystemRepresentation, folderResolved) ||
        lstat(fileURL.fileSystemRepresentation, &item) != 0 ||
        !S_ISREG(item.st_mode) ||
        ![[NSString stringWithUTF8String:fileResolved] isEqualToString:
          [[NSString stringWithUTF8String:folderResolved] stringByAppendingPathComponent:name]]) {
        if (error) *error = CFUpdateError(@"Staged file is missing or no longer inside the expected directory.");
        return NO;
    }
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:error];
    if (!data.length || data.length > 4 * 1024 * 1024 ||
        (official && data.length != 89008) ||
        ![CFCarrierSHA384(data) isEqualToString:expectedSHA384]) {
        if (error) *error = CFUpdateError(@"The saved file changed since verification. Export blocked.");
        return NO;
    }
    return YES;
}

+ (void)discardReferenceAtURL:(NSURL *)fileURL {
    if (!fileURL.isFileURL) return;
    NSString *name = fileURL.lastPathComponent ?: @"";
    if (![name hasPrefix:@"Cricket-original-"] || ![name hasSuffix:@".plist"] ||
        [name hasSuffix:@".metadata.plist"]) return;
    NSURL *folder = [self researchDirectory:nil];
    if (!folder || ![fileURL.path isEqualToString:[[folder URLByAppendingPathComponent:name] path]]) return;
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    NSString *metadataName = [[name substringToIndex:name.length - @".plist".length] stringByAppendingString:@".metadata.plist"];
    [[NSFileManager defaultManager] removeItemAtURL:[folder URLByAppendingPathComponent:metadataName] error:nil];
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
