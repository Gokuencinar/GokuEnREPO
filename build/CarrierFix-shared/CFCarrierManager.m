#import "CFCarrierManager.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <sys/stat.h>
#import <unistd.h>
#import <limits.h>
#import <stdlib.h>

static NSString * const CFCarrierPreferencePath = @"/private/var/mobile/Library/Preferences/com.apple.carrier.plist";
static NSString * const CFBackupDirectory = @"/private/var/mobile/Library/CarrierFix";
static NSString * const CFHistoryDirectory = @"/private/var/mobile/Library/CarrierFix/History";

static uint64_t CFPathIdentifier(NSString *path) {
    const unsigned char *bytes = (const unsigned char *)path.UTF8String;
    uint64_t hash = 1469598103934665603ULL;
    if (!bytes) return hash;
    while (*bytes) {
        hash ^= (uint64_t)(*bytes++);
        hash *= 1099511628211ULL;
    }
    return hash;
}

@interface CFCarrierManager ()
- (NSString *)resolvedCarrierPath;
- (BOOL)hasIMSAPN:(NSDictionary *)carrier;
- (BOOL)schemaIsSafeForPatch:(NSDictionary *)carrier reason:(NSString **)reason;
- (BOOL)prepareVerifiedBackup:(NSString **)message;
- (NSDictionary *)patchedCarrierFromOriginal:(NSDictionary *)original;
@end

@implementation CFCarrierManager

- (NSString *)resolvedCarrierPath {
    char resolved[PATH_MAX] = {0};
    if (realpath(CFCarrierPreferencePath.fileSystemRepresentation, resolved)) {
        return [NSString stringWithUTF8String:resolved];
    }
    return CFCarrierPreferencePath;
}

- (NSString *)identifierForPath:(NSString *)path {
    return [NSString stringWithFormat:@"%016llx", (unsigned long long)CFPathIdentifier(path ?: @"")];
}

- (NSDictionary *)storagePathsForCarrierPath:(NSString *)path {
    NSString *identifier = [self identifierForPath:path];
    return @{
        @"backup": [CFBackupDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"original-%@.plist", identifier]],
        @"metadata": [CFBackupDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"metadata-%@.plist", identifier]],
        @"patched": [CFBackupDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"patched-%@.plist", identifier]]
    };
}

- (NSDictionary *)carrierDictionaryAtPath:(NSString *)path format:(NSPropertyListFormat *)format error:(NSError **)outError {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:outError];
    if (!data.length) return nil;
    NSPropertyListFormat localFormat = NSPropertyListBinaryFormat_v1_0;
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:&localFormat error:outError];
    if (format) *format = localFormat;
    return [obj isKindOfClass:NSDictionary.class] ? obj : nil;
}

- (NSDictionary *)carrierDictionaryAtPath:(NSString *)path {
    return [self carrierDictionaryAtPath:path format:NULL error:nil];
}

- (NSString *)machineIdentifier {
    struct utsname u;
    if (uname(&u) == 0) return [NSString stringWithUTF8String:u.machine] ?: @"unknown";
    return @"unknown";
}

- (BOOL)dictionaryLooksCricket:(NSDictionary *)carrier path:(NSString *)path {
    NSString *carrierName = [carrier[@"CarrierName"] isKindOfClass:NSString.class] ? carrier[@"CarrierName"] : @"";
    NSString *wifiName = [carrier[@"OverrideOperatorWiFiName"] isKindOfClass:NSString.class] ? carrier[@"OverrideOperatorWiFiName"] : @"";
    if ([carrierName rangeOfString:@"Cricket" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([wifiName rangeOfString:@"Cricket" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([path rangeOfString:@"ATT_aio" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;

    NSArray *images = [carrier[@"StatusBarImages"] isKindOfClass:NSArray.class] ? carrier[@"StatusBarImages"] : @[];
    for (id rawItem in images) {
        if (![rawItem isKindOfClass:NSDictionary.class]) continue;
        NSString *name = [rawItem[@"StatusBarCarrierName"] isKindOfClass:NSString.class] ? rawItem[@"StatusBarCarrierName"] : @"";
        if ([name rangeOfString:@"Cricket" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

- (BOOL)hasWritableDirectoryForPath:(NSString *)path {
    NSString *directory = path.stringByDeletingLastPathComponent;
    NSString *probe = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@".carrierfix-%d-%@", getpid(), NSUUID.UUID.UUIDString]];
    NSData *data = [@"CarrierFix" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    BOOL ok = [data writeToFile:probe options:NSDataWritingAtomic error:&error];
    if (ok) [[NSFileManager defaultManager] removeItemAtPath:probe error:nil];
    return ok;
}

- (BOOL)schemaIsSafeForPatch:(NSDictionary *)carrier reason:(NSString **)reason {
    NSDictionary *ims = [carrier[@"IMSConfig"] isKindOfClass:NSDictionary.class] ? carrier[@"IMSConfig"] : nil;
    NSDictionary *signaling = [ims[@"Signaling"] isKindOfClass:NSDictionary.class] ? ims[@"Signaling"] : nil;
    NSArray *apns = [carrier[@"apns"] isKindOfClass:NSArray.class] ? carrier[@"apns"] : nil;
    if (!ims || !signaling) {
        if (reason) *reason = @"This carrier bundle has no existing IMSConfig/Signaling structure. CarrierFix will not create IMS from scratch on this iOS version.";
        return NO;
    }
    if (!apns.count) {
        if (reason) *reason = @"This carrier bundle has no APN configuration array. CarrierFix will not synthesize one from scratch.";
        return NO;
    }
    BOOL hasConfigurationGroup = NO;
    for (id rawGroup in apns) {
        if (![rawGroup isKindOfClass:NSDictionary.class]) continue;
        if ([rawGroup[@"configuration"] isKindOfClass:NSArray.class]) {
            hasConfigurationGroup = YES;
            break;
        }
    }
    if (!hasConfigurationGroup) {
        if (reason) *reason = @"The APN schema is different from the iOS 15-18 layouts CarrierFix understands.";
        return NO;
    }
    if (![self hasIMSAPN:carrier]) {
        if (reason) *reason = @"This Cricket profile has no existing IMS APN. CarrierFix will not create one automatically on an untested carrier/iOS combination; copy the diagnostic for a targeted profile instead.";
        return NO;
    }
    return YES;
}

- (BOOL)fixLooksApplied:(NSDictionary *)carrier {
    NSDictionary *ims = [carrier[@"IMSConfig"] isKindOfClass:NSDictionary.class] ? carrier[@"IMSConfig"] : @{};
    NSDictionary *signaling = [ims[@"Signaling"] isKindOfClass:NSDictionary.class] ? ims[@"Signaling"] : @{};
    NSDictionary *imsSMS = [ims[@"SMS"] isKindOfClass:NSDictionary.class] ? ims[@"SMS"] : @{};
    NSDictionary *smsSettings = [carrier[@"SMSSettings"] isKindOfClass:NSDictionary.class] ? carrier[@"SMSSettings"] : @{};
    if (![carrier[@"SupportsImsCapability"] boolValue]) return NO;
    if (![signaling[@"ForcedFeatureTags"] isEqual:@"voice,sms"]) return NO;
    if (![smsSettings[@"TransportFallback"] isKindOfClass:NSNumber.class] || [smsSettings[@"TransportFallback"] boolValue]) return NO;
    if (![imsSMS[@"SMSBundleToVoice"] isKindOfClass:NSNumber.class] || [imsSMS[@"SMSBundleToVoice"] boolValue]) return NO;
    if (![imsSMS[@"allowCSFBInVolteMode"] isKindOfClass:NSNumber.class] || [imsSMS[@"allowCSFBInVolteMode"] boolValue]) return NO;
    return YES;
}

- (BOOL)hasIMSAPN:(NSDictionary *)carrier {
    NSArray *apns = [carrier[@"apns"] isKindOfClass:NSArray.class] ? carrier[@"apns"] : @[];
    for (id rawGroup in apns) {
        if (![rawGroup isKindOfClass:NSDictionary.class]) continue;
        NSArray *configs = [rawGroup[@"configuration"] isKindOfClass:NSArray.class] ? rawGroup[@"configuration"] : @[];
        for (id rawConfig in configs) {
            if (![rawConfig isKindOfClass:NSDictionary.class]) continue;
            NSString *apn = [rawConfig[@"apn"] isKindOfClass:NSString.class] ? rawConfig[@"apn"] : @"";
            if ([apn caseInsensitiveCompare:@"ims"] == NSOrderedSame) return YES;
        }
    }
    return NO;
}

- (BOOL)backupAvailableForPath:(NSString *)path {
    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:paths[@"metadata"]];
    NSData *backup = [NSData dataWithContentsOfFile:paths[@"backup"]];
    if (!backup.length || ![meta[@"sourcePath"] isEqual:path]) return NO;
    return [NSPropertyListSerialization propertyListWithData:backup options:0 format:nil error:nil] != nil;
}

- (NSDictionary *)diagnose {
    NSString *path = [self resolvedCarrierPath];
    NSDictionary *carrier = [self carrierDictionaryAtPath:path];
    if (!carrier) {
        return @{ @"ok": @NO, @"path": path ?: @"", @"message": @"Could not read the active carrier plist." };
    }

    NSDictionary *ims = [carrier[@"IMSConfig"] isKindOfClass:NSDictionary.class] ? carrier[@"IMSConfig"] : @{};
    NSDictionary *signaling = [ims[@"Signaling"] isKindOfClass:NSDictionary.class] ? ims[@"Signaling"] : @{};
    NSDictionary *imsSMS = [ims[@"SMS"] isKindOfClass:NSDictionary.class] ? ims[@"SMS"] : @{};
    NSDictionary *smsSettings = [carrier[@"SMSSettings"] isKindOfClass:NSDictionary.class] ? carrier[@"SMSSettings"] : @{};
    NSString *carrierName = [carrier[@"CarrierName"] isKindOfClass:NSString.class] ? carrier[@"CarrierName"] : @"Unknown";
    NSString *forcedTags = [signaling[@"ForcedFeatureTags"] isKindOfClass:NSString.class] ? signaling[@"ForcedFeatureTags"] : @"(missing)";
    NSString *schemaReason = nil;
    BOOL schemaSafe = [self schemaIsSafeForPatch:carrier reason:&schemaReason];
    BOOL carrierWritable = [[NSFileManager defaultManager] isWritableFileAtPath:path] && [self hasWritableDirectoryForPath:path];

    return @{ @"ok": @YES,
              @"path": path ?: @"",
              @"carrier": carrierName,
              @"cricket": @([self dictionaryLooksCricket:carrier path:path]),
              @"ios": UIDevice.currentDevice.systemVersion ?: @"",
              @"model": [self machineIdentifier],
              @"writable": @(carrierWritable),
              @"schemaSafe": @(schemaSafe),
              @"schemaReason": schemaReason ?: @"",
              @"backupAvailable": @([self backupAvailableForPath:path]),
              @"fixApplied": @([self fixLooksApplied:carrier]),
              @"supportsIMS": @([carrier[@"SupportsImsCapability"] boolValue]),
              @"forcedFeatureTags": forcedTags,
              @"hasIMSAPN": @([self hasIMSAPN:carrier]),
              @"smsTransportFallback": smsSettings[@"TransportFallback"] ?: @"(missing)",
              @"smsBundleToVoice": imsSMS[@"SMSBundleToVoice"] ?: @"(missing)",
              @"allowCSFBInVolteMode": imsSMS[@"allowCSFBInVolteMode"] ?: @"(missing)" };
}

- (BOOL)isCricketConfiguration:(NSDictionary *)diagnosis {
    return [diagnosis[@"cricket"] boolValue];
}

- (BOOL)archiveExistingBackupIfNeeded:(NSDictionary *)paths identifier:(NSString *)identifier {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *backupPath = paths[@"backup"];
    if (![fm fileExistsAtPath:backupPath]) return YES;
    [fm createDirectoryAtPath:CFHistoryDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
    NSString *stamp = [NSString stringWithFormat:@"%.0f", NSDate.date.timeIntervalSince1970];
    NSString *archive = [CFHistoryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"original-%@-%@.plist", identifier, stamp]];
    return [fm copyItemAtPath:backupPath toPath:archive error:nil];
}

- (BOOL)prepareVerifiedBackup:(NSString **)message {
    NSString *path = [self resolvedCarrierPath];
    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSError *readError = nil;
    NSDictionary *carrier = [self carrierDictionaryAtPath:path format:&format error:&readError];
    if (!carrier) {
        if (message) *message = readError.localizedDescription ?: @"The active carrier plist could not be read.";
        return NO;
    }
    if (![self dictionaryLooksCricket:carrier path:path]) {
        if (message) *message = @"Cricket / ATT_aio was not detected. No backup or changes were made.";
        return NO;
    }
    if (![[NSFileManager defaultManager] isWritableFileAtPath:path] || ![self hasWritableDirectoryForPath:path]) {
        if (message) *message = @"The active carrier overlay or its directory is not writable in this jailbreak environment.";
        return NO;
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    if (![fm createDirectoryAtPath:CFBackupDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) {
        if (message) *message = error.localizedDescription ?: @"Could not create CarrierFix backup directory.";
        return NO;
    }

    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSData *currentData = [NSData dataWithContentsOfFile:path options:0 error:&error];
    NSData *backupData = [NSData dataWithContentsOfFile:paths[@"backup"]];
    NSData *patchedData = [NSData dataWithContentsOfFile:paths[@"patched"]];

    // If the current carrier file is exactly our previously verified patched snapshot,
    // keep the existing original backup. Never replace it with the patched state.
    if (currentData.length && patchedData.length && [currentData isEqualToData:patchedData] && [self backupAvailableForPath:path]) {
        if (message) *message = @"Existing original backup verified; the active carrier file matches CarrierFix's patched snapshot.";
        return YES;
    }

    // If the carrier file changed outside CarrierFix (carrier update, SIM/profile change),
    // archive the old baseline and capture the new current state before a new patch.
    if (backupData.length && ![currentData isEqualToData:backupData]) {
        NSString *identifier = [self identifierForPath:path];
        if (![self archiveExistingBackupIfNeeded:paths identifier:identifier]) {
            if (message) *message = @"An older backup exists and could not be archived safely. CarrierFix refused to continue.";
            return NO;
        }
    }

    if (!currentData.length || ![currentData writeToFile:paths[@"backup"] options:NSDataWritingAtomic error:&error]) {
        if (message) *message = error.localizedDescription ?: @"Could not create the carrier backup.";
        return NO;
    }

    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil] ?: @{};
    NSMutableDictionary *meta = [@{ @"sourcePath": path,
                                    @"created": NSDate.date,
                                    @"carrier": carrier[@"CarrierName"] ?: @"Unknown",
                                    @"ios": UIDevice.currentDevice.systemVersion ?: @"",
                                    @"format": @(format) } mutableCopy];
    if (attrs[NSFilePosixPermissions]) meta[@"permissions"] = attrs[NSFilePosixPermissions];
    if (![meta writeToFile:paths[@"metadata"] atomically:YES]) {
        if (message) *message = @"Backup metadata could not be saved. CarrierFix refused to continue.";
        return NO;
    }

    NSData *verifyData = [NSData dataWithContentsOfFile:paths[@"backup"]];
    if (![verifyData isEqualToData:currentData] || ![self backupAvailableForPath:path]) {
        if (message) *message = @"Backup verification failed. The active carrier file was not modified.";
        return NO;
    }

    NSString *restoreProbe = [CFBackupDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"restore-test-%@.plist", NSUUID.UUID.UUIDString]];
    BOOL probeOK = [verifyData writeToFile:restoreProbe options:NSDataWritingAtomic error:&error];
    NSData *probeData = probeOK ? [NSData dataWithContentsOfFile:restoreProbe] : nil;
    [fm removeItemAtPath:restoreProbe error:nil];
    if (!probeOK || ![probeData isEqualToData:verifyData]) {
        if (message) *message = @"Restore preflight failed. CarrierFix refused to enable the fix.";
        return NO;
    }

    if (message) *message = @"Original carrier configuration backed up and restore preflight passed.";
    return YES;
}

- (BOOL)writeData:(NSData *)data toCarrierPath:(NSString *)path metadata:(NSDictionary *)metadata error:(NSString **)errorText {
    NSError *error = nil;
    if (!data.length || ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        if (errorText) *errorText = error.localizedDescription ?: @"Could not write the active carrier overlay.";
        return NO;
    }
    NSNumber *permissions = metadata[@"permissions"];
    if (permissions) {
        [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: permissions} ofItemAtPath:path error:nil];
    }
    NSData *readBack = [NSData dataWithContentsOfFile:path];
    if (![readBack isEqualToData:data]) {
        if (errorText) *errorText = @"Byte-for-byte read-back verification failed.";
        return NO;
    }
    return YES;
}

- (NSDictionary *)patchedCarrierFromOriginal:(NSDictionary *)original {
    NSMutableDictionary *carrier = [original mutableCopy];
    carrier[@"SupportsImsCapability"] = @YES;

    NSMutableDictionary *smsSettings = [([carrier[@"SMSSettings"] isKindOfClass:NSDictionary.class] ? carrier[@"SMSSettings"] : @{}) mutableCopy];
    smsSettings[@"TransportFallback"] = @NO;
    carrier[@"SMSSettings"] = smsSettings;

    NSMutableDictionary *ims = [carrier[@"IMSConfig"] mutableCopy];
    NSMutableDictionary *signaling = [ims[@"Signaling"] mutableCopy];
    signaling[@"ForcedFeatureTags"] = @"voice,sms";
    // Preserve an existing registration policy. Only use ATT when the old bundle
    // already carries the key but its value is blank.
    if ([signaling[@"RegistrationPolicy"] isKindOfClass:NSString.class] && [signaling[@"RegistrationPolicy"] length] == 0) {
        signaling[@"RegistrationPolicy"] = @"ATT";
    }
    ims[@"Signaling"] = signaling;

    NSMutableDictionary *imsSMS = [([ims[@"SMS"] isKindOfClass:NSDictionary.class] ? ims[@"SMS"] : @{}) mutableCopy];
    imsSMS[@"SMSBundleToVoice"] = @NO;
    imsSMS[@"allowCSFBInVolteMode"] = @NO;
    ims[@"SMS"] = imsSMS;
    carrier[@"IMSConfig"] = ims;

    NSMutableArray *apnGroups = [carrier[@"apns"] mutableCopy];
    BOOL foundIMS = NO;
    for (NSUInteger i = 0; i < apnGroups.count; i++) {
        NSDictionary *group = [apnGroups[i] isKindOfClass:NSDictionary.class] ? apnGroups[i] : nil;
        if (!group || ![group[@"configuration"] isKindOfClass:NSArray.class]) continue;
        NSMutableDictionary *mutableGroup = [group mutableCopy];
        NSMutableArray *configs = [group[@"configuration"] mutableCopy];
        for (NSUInteger j = 0; j < configs.count; j++) {
            NSDictionary *cfg = [configs[j] isKindOfClass:NSDictionary.class] ? configs[j] : nil;
            NSString *apn = [cfg[@"apn"] isKindOfClass:NSString.class] ? cfg[@"apn"] : @"";
            if ([apn caseInsensitiveCompare:@"ims"] != NSOrderedSame) continue;
            NSMutableDictionary *m = [cfg mutableCopy];
            if (!m[@"AllowedProtocolMask"]) m[@"AllowedProtocolMask"] = @3;
            if (!m[@"AllowedProtocolMaskInRoaming"]) m[@"AllowedProtocolMaskInRoaming"] = @3;
            m[@"SupportSwitchOver"] = @YES;
            configs[j] = m;
            foundIMS = YES;
        }
        mutableGroup[@"configuration"] = configs;
        apnGroups[i] = mutableGroup;
    }
    if (!foundIMS) return nil;
    carrier[@"apns"] = apnGroups;
    return carrier;
}

- (BOOL)applyCricketSMSFix:(NSString **)message {
    NSDictionary *d = [self diagnose];
    if (![d[@"ok"] boolValue] || ![d[@"cricket"] boolValue]) {
        if (message) *message = @"CarrierFix did not detect a readable Cricket / ATT_aio configuration. No changes were made.";
        return NO;
    }
    if (![d[@"schemaSafe"] boolValue]) {
        if (message) *message = d[@"schemaReason"] ?: @"Carrier schema is not recognized safely.";
        return NO;
    }

    NSString *backupMessage = nil;
    if (![self prepareVerifiedBackup:&backupMessage]) {
        if (message) *message = backupMessage ?: @"Backup preflight failed.";
        return NO;
    }

    NSString *path = [self resolvedCarrierPath];
    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:paths[@"metadata"]] ?: @{};
    NSPropertyListFormat format = (NSPropertyListFormat)[meta[@"format"] unsignedIntegerValue];
    NSError *error = nil;
    NSDictionary *original = [self carrierDictionaryAtPath:path format:NULL error:&error];
    NSDictionary *candidate = [self patchedCarrierFromOriginal:original];
    if (!candidate) {
        if (message) *message = @"The IMS APN disappeared between safety preflight and Apply. No changes were made.";
        return NO;
    }
    NSData *candidateData = [NSPropertyListSerialization dataWithPropertyList:candidate format:format options:0 error:&error];
    if (!candidateData.length) {
        if (message) *message = error.localizedDescription ?: @"Could not serialize the patched carrier configuration.";
        return NO;
    }

    NSString *writeError = nil;
    if (![self writeData:candidateData toCarrierPath:path metadata:meta error:&writeError]) {
        NSData *backup = [NSData dataWithContentsOfFile:paths[@"backup"]];
        [self writeData:backup toCarrierPath:path metadata:meta error:nil];
        if (message) *message = [NSString stringWithFormat:@"Write verification failed and CarrierFix restored the original automatically: %@", writeError ?: @"unknown error"];
        return NO;
    }

    NSDictionary *verify = [self carrierDictionaryAtPath:path];
    BOOL good = [self fixLooksApplied:verify] && [self hasIMSAPN:verify];
    if (!good) {
        NSData *backup = [NSData dataWithContentsOfFile:paths[@"backup"]];
        [self writeData:backup toCarrierPath:path metadata:meta error:nil];
        if (message) *message = @"The patched plist did not pass semantic verification. CarrierFix restored the original automatically.";
        return NO;
    }

    if (![candidateData writeToFile:paths[@"patched"] options:NSDataWritingAtomic error:&error]) {
        NSData *backup = [NSData dataWithContentsOfFile:paths[@"backup"]];
        [self writeData:backup toCarrierPath:path metadata:meta error:nil];
        if (message) *message = @"CarrierFix could not save its verified patched snapshot, so it restored the original rather than leave an untracked change.";
        return NO;
    }

    if (message) *message = @"Cricket IMS/SMS compatibility keys were applied and verified. Toggle Airplane Mode for about 30 seconds, then test SMS to an Android number. If anything gets worse, use Restore Original.";
    return YES;
}

- (BOOL)restoreOriginal:(NSString **)message {
    NSString *path = [self resolvedCarrierPath];
    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:paths[@"metadata"]];
    NSData *backup = [NSData dataWithContentsOfFile:paths[@"backup"]];
    if (!backup.length || !meta) {
        if (message) *message = @"No verified CarrierFix backup exists for the currently active carrier overlay.";
        return NO;
    }
    if (![meta[@"sourcePath"] isEqual:path]) {
        if (message) *message = @"The active carrier overlay changed since this backup was created. CarrierFix refused to restore a backup to a different carrier path.";
        return NO;
    }
    if (![NSPropertyListSerialization propertyListWithData:backup options:0 format:nil error:nil]) {
        if (message) *message = @"The stored backup is not a valid plist. Restore was refused.";
        return NO;
    }

    NSString *writeError = nil;
    if (![self writeData:backup toCarrierPath:path metadata:meta error:&writeError]) {
        if (message) *message = [NSString stringWithFormat:@"Restore failed: %@", writeError ?: @"unknown error"];
        return NO;
    }
    [[NSFileManager defaultManager] removeItemAtPath:paths[@"patched"] error:nil];
    if (message) *message = @"Original carrier configuration restored and verified byte-for-byte. Toggle Airplane Mode for about 30 seconds or reboot before testing again.";
    return YES;
}

- (BOOL)prepareForApply:(NSString **)message {
    NSDictionary *d = [self diagnose];
    if (![d[@"ok"] boolValue] || ![d[@"cricket"] boolValue]) {
        if (message) *message = @"Cricket / ATT_aio was not detected.";
        return NO;
    }
    if (![d[@"schemaSafe"] boolValue]) {
        if (message) *message = d[@"schemaReason"] ?: @"Unsupported carrier schema.";
        return NO;
    }
    return [self prepareVerifiedBackup:message];
}

- (BOOL)hasVerifiedBackupForActiveCarrier {
    return [self backupAvailableForPath:[self resolvedCarrierPath]];
}

- (NSString *)diagnosticText {
    NSDictionary *d = [self diagnose];
    if (![d[@"ok"] boolValue]) return [NSString stringWithFormat:@"CarrierFix 0.2.1\nError: %@\nPath: %@", d[@"message"] ?: @"Unknown", d[@"path"] ?: @""];
    return [NSString stringWithFormat:
            @"CarrierFix 0.2.1\niOS: %@\nModel: %@\nCarrier: %@\nDetected Cricket: %@\nCarrier plist: %@\nWritable overlay: %@\nRecognized IMS/APN schema: %@\nVerified backup: %@\nFix currently present: %@\nSupports IMS: %@\nIMS APN: %@\nIMS ForcedFeatureTags: %@\nSMS TransportFallback: %@\nIMS SMSBundleToVoice: %@\nIMS allowCSFBInVolteMode: %@%@\n\nNo phone number, IMSI or ICCID is included in this report.",
            d[@"ios"], d[@"model"], d[@"carrier"], [d[@"cricket"] boolValue] ? @"YES" : @"NO", d[@"path"],
            [d[@"writable"] boolValue] ? @"YES" : @"NO", [d[@"schemaSafe"] boolValue] ? @"YES" : @"NO",
            [d[@"backupAvailable"] boolValue] ? @"YES" : @"NO", [d[@"fixApplied"] boolValue] ? @"YES" : @"NO",
            [d[@"supportsIMS"] boolValue] ? @"YES" : @"NO", [d[@"hasIMSAPN"] boolValue] ? @"YES" : @"NO",
            d[@"forcedFeatureTags"], d[@"smsTransportFallback"], d[@"smsBundleToVoice"], d[@"allowCSFBInVolteMode"],
            [d[@"schemaSafe"] boolValue] ? @"" : [NSString stringWithFormat:@"\nSchema note: %@", d[@"schemaReason"] ?: @""]];
}
@end
