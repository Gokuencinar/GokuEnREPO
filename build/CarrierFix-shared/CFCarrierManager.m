#import "CFCarrierManager.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <sys/stat.h>
#import <unistd.h>
#import <limits.h>
#import <stdlib.h>

static NSString * const CFBackupDirectory = @"/private/var/mobile/Library/CarrierFix";

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
- (NSInteger)currentIOSMajorVersion;
- (BOOL)hasIMSAPN:(NSDictionary *)carrier;
- (BOOL)schemaIsSafeForPatch:(NSDictionary *)carrier reason:(NSString **)reason;
- (BOOL)prepareVerifiedBackup:(NSString **)message;
- (BOOL)prepareVerifiedBackupForPath:(NSString *)path message:(NSString **)message;
- (BOOL)restoreVerifiedBackupAtPath:(NSString *)path metadata:(NSDictionary *)metadata error:(NSString **)errorText;
- (NSDictionary *)carrierDictionaryFromData:(NSData *)data;
- (NSDictionary *)patchedCarrierFromOriginal:(NSDictionary *)original;
@end

@implementation CFCarrierManager

- (NSArray<NSString *> *)carrierPreferenceCandidates {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSMutableSet<NSString *> *seenCandidates = [NSMutableSet set];
    BOOL expandedDiscovery = [self currentIOSMajorVersion] >= 17;
    NSArray<NSString *> *roots = @[
        @"/rootfs/var/mobile/Library/Carrier Bundles/Library/Preferences",
        @"/private/var/mobile/Library/Carrier Bundles/Library/Preferences",
        @"/var/mobile/Library/Carrier Bundles/Library/Preferences"
    ];
    NSArray<NSString *> *preferredNames = expandedDiscovery ? @[
        @"com.apple.carrier_1.plist",
        @"com.apple.carrier_2.plist",
        @"com.apple.operator_1.plist",
        @"com.apple.operator_2.plist"
    ] : @[
        @"com.apple.carrier_1.plist",
        @"com.apple.carrier_2.plist",
        @"com.apple.operator_1.plist",
        @"com.apple.operator_2.plist",
        @"com.apple.carrier.default.plist"
    ];
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *root in roots) {
        for (NSString *name in preferredNames) {
            NSString *candidate = [root stringByAppendingPathComponent:name];
            if ([fm fileExistsAtPath:candidate] && ![seenCandidates containsObject:candidate]) {
                [seenCandidates addObject:candidate];
                [candidates addObject:candidate];
            }
        }

        if (!expandedDiscovery) continue;

        NSError *listError = nil;
        NSArray<NSString *> *directoryEntries = [fm contentsOfDirectoryAtPath:root error:&listError];
        NSArray<NSString *> *sortedEntries = [directoryEntries sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
        for (NSString *name in sortedEntries ?: @[]) {
            BOOL carrierPreference = [name hasPrefix:@"com.apple.carrier_"] && [name hasSuffix:@".plist"];
            BOOL operatorPreference = [name hasPrefix:@"com.apple.operator_"] && [name hasSuffix:@".plist"];
            if (!carrierPreference && !operatorPreference) continue;
            NSString *candidate = [root stringByAppendingPathComponent:name];
            if ([fm fileExistsAtPath:candidate] && ![seenCandidates containsObject:candidate]) {
                [seenCandidates addObject:candidate];
                [candidates addObject:candidate];
            }
        }

        NSString *defaultCandidate = [root stringByAppendingPathComponent:@"com.apple.carrier.default.plist"];
        if ([fm fileExistsAtPath:defaultCandidate] && ![seenCandidates containsObject:defaultCandidate]) {
            [seenCandidates addObject:defaultCandidate];
            [candidates addObject:defaultCandidate];
        }
    }
    return candidates;
}

- (NSString *)resolvedPathForCandidate:(NSString *)candidate {
    char resolved[PATH_MAX] = {0};
    if (realpath(candidate.fileSystemRepresentation, resolved)) {
        return [NSString stringWithUTF8String:resolved];
    }
    return candidate;
}

- (NSString *)resolvedCarrierPath {
    NSString *firstReadable = nil;
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSString *candidate in [self carrierPreferenceCandidates]) {
        NSString *resolved = [self resolvedPathForCandidate:candidate];
        if (!resolved.length || [seen containsObject:resolved]) continue;
        [seen addObject:resolved];
        NSDictionary *carrier = [self carrierDictionaryAtPath:resolved];
        if (!carrier) continue;
        if (!firstReadable && [candidate rangeOfString:@"default" options:NSCaseInsensitiveSearch].location == NSNotFound) {
            firstReadable = resolved;
        }
        if ([self dictionaryLooksCricket:carrier path:resolved]) return resolved;
    }
    return firstReadable;
}

- (NSString *)identifierForPath:(NSString *)path {
    return [NSString stringWithFormat:@"%016llx", (unsigned long long)CFPathIdentifier(path ?: @"")];
}

- (NSInteger)currentIOSMajorVersion {
    return UIDevice.currentDevice.systemVersion.integerValue;
}

- (NSString *)backupDirectory {
    NSInteger majorVersion = [self currentIOSMajorVersion];
    if (majorVersion >= 17) {
        return [CFBackupDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"iOS%ld", (long)majorVersion]];
    }
    return CFBackupDirectory;
}

- (NSString *)historyDirectory {
    return [[self backupDirectory] stringByAppendingPathComponent:@"History"];
}

- (BOOL)metadataMatchesCurrentIOSMajor:(NSDictionary *)metadata {
    NSString *savedIOS = [metadata[@"ios"] isKindOfClass:NSString.class] ? metadata[@"ios"] : @"";
    NSInteger savedMajor = savedIOS.integerValue;
    NSInteger currentMajor = [self currentIOSMajorVersion];
    return savedMajor > 0 && currentMajor > 0 && savedMajor == currentMajor;
}

- (NSDictionary *)storagePathsForCarrierPath:(NSString *)path {
    NSString *identifier = [self identifierForPath:path];
    NSString *directory = [self backupDirectory];
    return @{
        @"backup": [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"original-%@.plist", identifier]],
        @"metadata": [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"metadata-%@.plist", identifier]],
        @"patched": [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"patched-%@.plist", identifier]]
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

- (NSDictionary *)carrierDictionaryFromData:(NSData *)data {
    if (!data.length) return nil;
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:nil];
    return [obj isKindOfClass:NSDictionary.class] ? obj : nil;
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
    NSInteger majorVersion = [self currentIOSMajorVersion];
    if (majorVersion < 16 || majorVersion > 17) {
        if (reason) *reason = [NSString stringWithFormat:@"CarrierFix has only been prepared for iOS 16 and iOS 17 carrier schemas. This device is running iOS %@.", UIDevice.currentDevice.systemVersion ?: @"unknown"];
        return NO;
    }
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
    BOOL hasFlatAPNSchema = NO;
    BOOL hasGroupedAPNSchema = NO;
    for (id rawGroup in apns) {
        if (![rawGroup isKindOfClass:NSDictionary.class]) continue;
        if ([rawGroup[@"configuration"] isKindOfClass:NSArray.class]) {
            hasGroupedAPNSchema = YES;
        }
        if ([rawGroup[@"apn"] isKindOfClass:NSString.class]) {
            hasFlatAPNSchema = YES;
        }
    }
    if (!hasFlatAPNSchema && !hasGroupedAPNSchema) {
        if (reason) *reason = @"The APN schema is different from the iOS 16/17 layouts CarrierFix understands.";
        return NO;
    }
    if (![self hasIMSAPN:carrier]) {
        if (reason) *reason = @"This Cricket profile has no existing IMS APN. CarrierFix will not create one automatically on an untested carrier/iOS combination; copy the diagnostic for a targeted profile instead.";
        return NO;
    }

    if (majorVersion == 17) {
        NSDictionary *imsSMS = [ims[@"SMS"] isKindOfClass:NSDictionary.class] ? ims[@"SMS"] : nil;
        NSString *forcedTags = [signaling[@"ForcedFeatureTags"] isKindOfClass:NSString.class] ? signaling[@"ForcedFeatureTags"] : nil;
        NSString *registrationPolicy = [signaling[@"RegistrationPolicy"] isKindOfClass:NSString.class] ? signaling[@"RegistrationPolicy"] : nil;
        NSNumber *supportsIMS = [carrier[@"SupportsImsCapability"] isKindOfClass:NSNumber.class] ? carrier[@"SupportsImsCapability"] : nil;
        id rawSMSSettings = carrier[@"SMSSettings"];
        NSDictionary *smsSettings = [rawSMSSettings isKindOfClass:NSDictionary.class] ? rawSMSSettings : nil;

        // Cricket 31.1 and the iOS 17.5+ 58.1 bundle use this grouped ATT_aio
        // IMS shape. Refuse any other iOS 17 layout instead of guessing.
        if (!hasGroupedAPNSchema || hasFlatAPNSchema || !imsSMS ||
            ![forcedTags isEqualToString:@"voice,sms"] ||
            ![registrationPolicy isEqualToString:@"ATT"] ||
            !supportsIMS.boolValue) {
            if (reason) *reason = @"This iOS 17 Cricket profile does not match the known ATT_aio IMS/APN schema. Copy the diagnostic so the profile can be handled explicitly instead of patching an unknown layout.";
            return NO;
        }
        if (rawSMSSettings && !smsSettings) {
            if (reason) *reason = @"This iOS 17 Cricket profile has an unexpected SMSSettings type. CarrierFix refused to modify it.";
            return NO;
        }
        for (NSString *key in @[@"SMSBundleToVoice", @"allowCSFBInVolteMode", @"enableInNonVoLTEMode"]) {
            id value = imsSMS[key];
            if (value && ![value isKindOfClass:NSNumber.class]) {
                if (reason) *reason = [NSString stringWithFormat:@"This iOS 17 Cricket profile has an unexpected IMS SMS value for %@. CarrierFix refused to modify it.", key];
                return NO;
            }
        }
        id transportFallback = smsSettings[@"TransportFallback"];
        if (transportFallback && ![transportFallback isKindOfClass:NSNumber.class]) {
            if (reason) *reason = @"This iOS 17 Cricket profile has an unexpected SMS TransportFallback value. CarrierFix refused to modify it.";
            return NO;
        }
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
    if ([self currentIOSMajorVersion] == 17 &&
        (![imsSMS[@"enableInNonVoLTEMode"] isKindOfClass:NSNumber.class] || [imsSMS[@"enableInNonVoLTEMode"] boolValue])) return NO;
    return YES;
}

- (BOOL)hasIMSAPN:(NSDictionary *)carrier {
    NSArray *apns = [carrier[@"apns"] isKindOfClass:NSArray.class] ? carrier[@"apns"] : @[];
    for (id rawGroup in apns) {
        if (![rawGroup isKindOfClass:NSDictionary.class]) continue;
        NSString *directAPN = [rawGroup[@"apn"] isKindOfClass:NSString.class] ? rawGroup[@"apn"] : @"";
        if ([directAPN caseInsensitiveCompare:@"ims"] == NSOrderedSame) return YES;
        NSArray *configs = [rawGroup[@"configuration"] isKindOfClass:NSArray.class] ? rawGroup[@"configuration"] : @[];
        for (id rawConfig in configs) {
            if (![rawConfig isKindOfClass:NSDictionary.class]) continue;
            NSString *apn = [rawConfig[@"apn"] isKindOfClass:NSString.class] ? rawConfig[@"apn"] : @"";
            if ([apn caseInsensitiveCompare:@"ims"] == NSOrderedSame) return YES;
        }
    }
    return NO;
}

- (NSString *)apnSchemaDescription:(NSDictionary *)carrier {
    BOOL hasFlat = NO;
    BOOL hasGrouped = NO;
    NSArray *apns = [carrier[@"apns"] isKindOfClass:NSArray.class] ? carrier[@"apns"] : @[];
    for (id rawGroup in apns) {
        if (![rawGroup isKindOfClass:NSDictionary.class]) continue;
        if ([rawGroup[@"apn"] isKindOfClass:NSString.class]) hasFlat = YES;
        if ([rawGroup[@"configuration"] isKindOfClass:NSArray.class]) hasGrouped = YES;
    }
    if (hasFlat && hasGrouped) return @"mixed flat/grouped";
    if (hasGrouped) return @"grouped configuration";
    if (hasFlat) return @"flat apns";
    return @"unknown";
}

- (NSString *)carrierBundleVersion:(NSDictionary *)carrier {
    NSArray<NSString *> *keys = @[@"CarrierBundleVersion", @"CFBundleShortVersionString", @"CFBundleVersion"];
    for (NSString *key in keys) {
        id value = carrier[key];
        if ([value isKindOfClass:NSString.class] && [value length]) return value;
        if ([value isKindOfClass:NSNumber.class]) return [value stringValue];
    }
    return @"(missing)";
}

- (BOOL)backupAvailableForPath:(NSString *)path {
    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:paths[@"metadata"]];
    NSData *backup = [NSData dataWithContentsOfFile:paths[@"backup"]];
    if (!backup.length || ![meta[@"sourcePath"] isEqual:path] || ![self metadataMatchesCurrentIOSMajor:meta]) return NO;
    return [NSPropertyListSerialization propertyListWithData:backup options:0 format:nil error:nil] != nil;
}

- (NSDictionary *)diagnose {
    NSString *path = [self resolvedCarrierPath];
    if (!path.length) {
        return @{ @"ok": @NO,
                  @"path": @"",
                  @"message": @"Could not locate an active carrier overlay in the Carrier Bundles preferences." };
    }
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
              @"carrierBundleVersion": [self carrierBundleVersion:carrier],
              @"cricket": @([self dictionaryLooksCricket:carrier path:path]),
              @"ios": UIDevice.currentDevice.systemVersion ?: @"",
              @"model": [self machineIdentifier],
              @"writable": @(carrierWritable),
              @"schemaSafe": @(schemaSafe),
              @"apnSchema": [self apnSchemaDescription:carrier],
              @"schemaReason": schemaReason ?: @"",
              @"backupAvailable": @([self backupAvailableForPath:path]),
              @"fixApplied": @([self fixLooksApplied:carrier]),
              @"supportsIMS": @([carrier[@"SupportsImsCapability"] boolValue]),
              @"forcedFeatureTags": forcedTags,
              @"hasIMSAPN": @([self hasIMSAPN:carrier]),
              @"smsTransportFallback": smsSettings[@"TransportFallback"] ?: @"(missing)",
              @"smsBundleToVoice": imsSMS[@"SMSBundleToVoice"] ?: @"(missing)",
              @"allowCSFBInVolteMode": imsSMS[@"allowCSFBInVolteMode"] ?: @"(missing)",
              @"enableInNonVoLTEMode": imsSMS[@"enableInNonVoLTEMode"] ?: @"(missing)" };
}

- (BOOL)isCricketConfiguration:(NSDictionary *)diagnosis {
    return [diagnosis[@"cricket"] boolValue];
}

- (BOOL)archiveExistingBackupIfNeeded:(NSDictionary *)paths identifier:(NSString *)identifier {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *backupPath = paths[@"backup"];
    if (![fm fileExistsAtPath:backupPath]) return YES;
    NSString *historyDirectory = [self historyDirectory];
    [fm createDirectoryAtPath:historyDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
    NSString *stamp = [NSString stringWithFormat:@"%.0f", NSDate.date.timeIntervalSince1970];
    NSString *archive = [historyDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"original-%@-%@.plist", identifier, stamp]];
    return [fm copyItemAtPath:backupPath toPath:archive error:nil];
}

- (BOOL)prepareVerifiedBackupForPath:(NSString *)path message:(NSString **)message {
    if (!path.length) {
        if (message) *message = @"No active carrier overlay could be located.";
        return NO;
    }
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
    NSString *schemaReason = nil;
    if (![self schemaIsSafeForPatch:carrier reason:&schemaReason]) {
        if (message) *message = schemaReason ?: @"Carrier schema is not recognized safely. No backup or changes were made.";
        return NO;
    }
    if (![[NSFileManager defaultManager] isWritableFileAtPath:path] || ![self hasWritableDirectoryForPath:path]) {
        if (message) *message = @"The active carrier overlay or its directory is not writable in this jailbreak environment.";
        return NO;
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    NSString *backupDirectory = [self backupDirectory];
    if (![fm createDirectoryAtPath:backupDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) {
        if (message) *message = error.localizedDescription ?: @"Could not create CarrierFix backup directory.";
        return NO;
    }

    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSData *currentData = [NSData dataWithContentsOfFile:path options:0 error:&error];
    NSData *backupData = [NSData dataWithContentsOfFile:paths[@"backup"]];
    NSData *patchedData = [NSData dataWithContentsOfFile:paths[@"patched"]];
    NSPropertyListFormat snapshotFormat = format;
    id snapshotObject = currentData.length ? [NSPropertyListSerialization propertyListWithData:currentData options:NSPropertyListMutableContainersAndLeaves format:&snapshotFormat error:&error] : nil;
    NSDictionary *snapshotCarrier = [snapshotObject isKindOfClass:NSDictionary.class] ? snapshotObject : nil;
    NSString *snapshotSchemaReason = nil;
    if (!snapshotCarrier || ![self dictionaryLooksCricket:snapshotCarrier path:path] || ![self schemaIsSafeForPatch:snapshotCarrier reason:&snapshotSchemaReason]) {
        if (message) *message = snapshotSchemaReason ?: error.localizedDescription ?: @"The carrier overlay changed to an unsupported profile during backup preflight.";
        return NO;
    }
    carrier = snapshotCarrier;
    format = snapshotFormat;

    // If the current carrier file is exactly our previously verified patched snapshot,
    // keep the existing original backup. Never replace it with the patched state.
    if (currentData.length && patchedData.length && [currentData isEqualToData:patchedData]) {
        if ([self backupAvailableForPath:path]) {
            if (message) *message = @"Existing original backup verified; the active carrier file matches CarrierFix's patched snapshot.";
            return YES;
        }
        if (message) *message = @"The active carrier file matches a previous CarrierFix patch, but its original backup is missing or invalid. CarrierFix refused to replace that baseline.";
        return NO;
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
    NSData *activeDataAfterBackup = [NSData dataWithContentsOfFile:path];
    if (![[self resolvedCarrierPath] isEqual:path] || ![activeDataAfterBackup isEqualToData:currentData]) {
        if (message) *message = @"The active carrier overlay changed during backup verification. CarrierFix refused to enable Apply; refresh and try again.";
        return NO;
    }

    NSString *restoreProbe = [backupDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"restore-test-%@.plist", NSUUID.UUID.UUIDString]];
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

- (BOOL)prepareVerifiedBackup:(NSString **)message {
    return [self prepareVerifiedBackupForPath:[self resolvedCarrierPath] message:message];
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

- (BOOL)restoreVerifiedBackupAtPath:(NSString *)path metadata:(NSDictionary *)metadata error:(NSString **)errorText {
    if (!path.length || !metadata || ![metadata[@"sourcePath"] isEqual:path] || ![self metadataMatchesCurrentIOSMajor:metadata]) {
        if (errorText) *errorText = @"Backup metadata no longer matches the active carrier overlay.";
        return NO;
    }
    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSData *backup = [NSData dataWithContentsOfFile:paths[@"backup"]];
    if (!backup.length || ![NSPropertyListSerialization propertyListWithData:backup options:0 format:nil error:nil]) {
        if (errorText) *errorText = @"The verified original backup is missing or invalid.";
        return NO;
    }
    return [self writeData:backup toCarrierPath:path metadata:metadata error:errorText];
}

- (NSDictionary *)patchedCarrierFromOriginal:(NSDictionary *)original {
    if (![original isKindOfClass:NSDictionary.class]) return nil;
    NSInteger majorVersion = [self currentIOSMajorVersion];
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

    NSDictionary *originalIMSSMS = [ims[@"SMS"] isKindOfClass:NSDictionary.class] ? ims[@"SMS"] : nil;
    if (majorVersion == 17 && !originalIMSSMS) return nil;
    NSMutableDictionary *imsSMS = [(originalIMSSMS ?: @{}) mutableCopy];
    imsSMS[@"SMSBundleToVoice"] = @NO;
    imsSMS[@"allowCSFBInVolteMode"] = @NO;
    if (majorVersion == 17) imsSMS[@"enableInNonVoLTEMode"] = @NO;
    ims[@"SMS"] = imsSMS;
    carrier[@"IMSConfig"] = ims;

    NSMutableArray *apnGroups = [carrier[@"apns"] mutableCopy];
    BOOL foundIMS = NO;
    for (NSUInteger i = 0; i < apnGroups.count; i++) {
        NSDictionary *group = [apnGroups[i] isKindOfClass:NSDictionary.class] ? apnGroups[i] : nil;
        if (!group) continue;

        NSString *directAPN = [group[@"apn"] isKindOfClass:NSString.class] ? group[@"apn"] : @"";
        if ([directAPN caseInsensitiveCompare:@"ims"] == NSOrderedSame) {
            NSMutableDictionary *direct = [group mutableCopy];
            if (majorVersion == 16) {
                if (!direct[@"AllowedProtocolMask"]) direct[@"AllowedProtocolMask"] = @3;
                if (!direct[@"AllowedProtocolMaskInRoaming"]) direct[@"AllowedProtocolMaskInRoaming"] = @3;
                direct[@"SupportSwitchOver"] = @YES;
            }
            apnGroups[i] = direct;
            foundIMS = YES;
            continue;
        }

        if (![group[@"configuration"] isKindOfClass:NSArray.class]) continue;
        NSMutableDictionary *mutableGroup = [group mutableCopy];
        NSMutableArray *configs = [group[@"configuration"] mutableCopy];
        for (NSUInteger j = 0; j < configs.count; j++) {
            NSDictionary *cfg = [configs[j] isKindOfClass:NSDictionary.class] ? configs[j] : nil;
            NSString *apn = [cfg[@"apn"] isKindOfClass:NSString.class] ? cfg[@"apn"] : @"";
            if ([apn caseInsensitiveCompare:@"ims"] != NSOrderedSame) continue;
            NSMutableDictionary *m = [cfg mutableCopy];
            if (majorVersion == 16) {
                if (!m[@"AllowedProtocolMask"]) m[@"AllowedProtocolMask"] = @3;
                if (!m[@"AllowedProtocolMaskInRoaming"]) m[@"AllowedProtocolMaskInRoaming"] = @3;
                m[@"SupportSwitchOver"] = @YES;
            }
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

    NSString *path = [d[@"path"] isKindOfClass:NSString.class] ? d[@"path"] : @"";
    if (!path.length) {
        if (message) *message = @"The diagnosed carrier overlay path is missing. No changes were made.";
        return NO;
    }

    NSString *backupMessage = nil;
    if (![self prepareVerifiedBackupForPath:path message:&backupMessage]) {
        if (message) *message = backupMessage ?: @"Backup preflight failed.";
        return NO;
    }

    NSString *activePath = [self resolvedCarrierPath];
    if (![activePath isEqual:path]) {
        if (message) *message = @"The active carrier overlay changed after safety preflight. CarrierFix cancelled Apply; run Refresh and try again.";
        return NO;
    }
    NSDictionary *paths = [self storagePathsForCarrierPath:path];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:paths[@"metadata"]];
    if (![self backupAvailableForPath:path] || ![meta[@"sourcePath"] isEqual:path] || ![self metadataMatchesCurrentIOSMajor:meta]) {
        if (message) *message = @"The verified backup no longer matches the active carrier overlay. CarrierFix cancelled Apply without writing anything.";
        return NO;
    }
    NSNumber *formatValue = [meta[@"format"] isKindOfClass:NSNumber.class] ? meta[@"format"] : nil;
    if (!formatValue) {
        if (message) *message = @"The verified backup metadata has no valid property-list format. CarrierFix cancelled Apply without writing anything.";
        return NO;
    }
    NSPropertyListFormat format = (NSPropertyListFormat)formatValue.unsignedIntegerValue;
    NSError *error = nil;
    NSData *backupData = [NSData dataWithContentsOfFile:paths[@"backup"]];
    NSData *patchedData = [NSData dataWithContentsOfFile:paths[@"patched"]];
    NSData *expectedCurrentData = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (patchedData.length && [expectedCurrentData isEqualToData:patchedData]) {
        NSDictionary *alreadyPatched = [self carrierDictionaryFromData:expectedCurrentData];
        if ([self fixLooksApplied:alreadyPatched] && [self hasIMSAPN:alreadyPatched]) {
            if (message) *message = @"The Cricket IMS/SMS fix is already present and the original backup is still verified.";
            return YES;
        }
        if (message) *message = @"The active carrier file matches CarrierFix's saved patched snapshot, but it no longer passes semantic verification. Apply was cancelled.";
        return NO;
    }
    if (!backupData.length || ![expectedCurrentData isEqualToData:backupData]) {
        if (message) *message = @"The carrier overlay changed after its verified backup was created. CarrierFix cancelled Apply; run Refresh to capture and verify the new state first.";
        return NO;
    }
    NSDictionary *original = [self carrierDictionaryFromData:expectedCurrentData];
    if (!original) {
        if (message) *message = error.localizedDescription ?: @"The active carrier overlay could not be parsed after backup verification. No changes were made.";
        return NO;
    }
    NSString *schemaReason = nil;
    if (![self dictionaryLooksCricket:original path:path] || ![self schemaIsSafeForPatch:original reason:&schemaReason]) {
        if (message) *message = schemaReason ?: @"The carrier schema changed after backup verification. No changes were made.";
        return NO;
    }
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

    activePath = [self resolvedCarrierPath];
    NSData *dataBeforeWrite = [NSData dataWithContentsOfFile:path];
    if (![activePath isEqual:path] || ![dataBeforeWrite isEqualToData:expectedCurrentData]) {
        if (message) *message = @"The active carrier overlay changed while CarrierFix prepared the patch. Apply was cancelled without writing anything; refresh the diagnostic and try again.";
        return NO;
    }

    if (![candidateData writeToFile:paths[@"patched"] options:NSDataWritingAtomic error:&error]) {
        if (message) *message = error.localizedDescription ?: @"CarrierFix could not save the patched snapshot. The active carrier file was not changed.";
        return NO;
    }
    NSData *savedPatchedData = [NSData dataWithContentsOfFile:paths[@"patched"]];
    if (![savedPatchedData isEqualToData:candidateData]) {
        [[NSFileManager defaultManager] removeItemAtPath:paths[@"patched"] error:nil];
        if (message) *message = @"CarrierFix could not verify its patched snapshot. The active carrier file was not changed.";
        return NO;
    }

    activePath = [self resolvedCarrierPath];
    dataBeforeWrite = [NSData dataWithContentsOfFile:path];
    if (![activePath isEqual:path] || ![dataBeforeWrite isEqualToData:expectedCurrentData]) {
        [[NSFileManager defaultManager] removeItemAtPath:paths[@"patched"] error:nil];
        if (message) *message = @"The carrier overlay changed immediately before Apply. CarrierFix cancelled without writing anything.";
        return NO;
    }

    NSString *writeError = nil;
    if (![self writeData:candidateData toCarrierPath:path metadata:meta error:&writeError]) {
        NSString *rollbackError = nil;
        BOOL restored = [self restoreVerifiedBackupAtPath:path metadata:meta error:&rollbackError];
        if (restored) [[NSFileManager defaultManager] removeItemAtPath:paths[@"patched"] error:nil];
        if (message) {
            *message = restored
                ? [NSString stringWithFormat:@"Write verification failed and CarrierFix restored the original automatically: %@", writeError ?: @"unknown error"]
                : [NSString stringWithFormat:@"Write verification failed, and automatic restore also failed (%@). Original write error: %@", rollbackError ?: @"unknown restore error", writeError ?: @"unknown write error"];
        }
        return NO;
    }

    NSDictionary *verify = [self carrierDictionaryAtPath:path];
    BOOL good = [self fixLooksApplied:verify] && [self hasIMSAPN:verify];
    if (!good) {
        NSString *rollbackError = nil;
        BOOL restored = [self restoreVerifiedBackupAtPath:path metadata:meta error:&rollbackError];
        if (restored) [[NSFileManager defaultManager] removeItemAtPath:paths[@"patched"] error:nil];
        if (message) {
            *message = restored
                ? @"The patched plist did not pass semantic verification. CarrierFix restored the original automatically."
                : [NSString stringWithFormat:@"The patched plist did not pass semantic verification, and automatic restore failed: %@", rollbackError ?: @"unknown restore error"];
        }
        return NO;
    }

    if (message) *message = @"Cricket IMS/SMS compatibility keys were applied and verified. Toggle Airplane Mode for about 30 seconds, then test SMS to an Android number. If anything gets worse, use Restore Original.";
    return YES;
}

- (BOOL)restoreOriginal:(NSString **)message {
    NSString *path = [self resolvedCarrierPath];
    if (!path.length) {
        if (message) *message = @"No active carrier overlay could be located.";
        return NO;
    }
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
    if (![self metadataMatchesCurrentIOSMajor:meta]) {
        if (message) *message = @"This backup was created on a different major iOS version. CarrierFix refused to restore it over the current carrier overlay.";
        return NO;
    }
    if (![NSPropertyListSerialization propertyListWithData:backup options:0 format:nil error:nil]) {
        if (message) *message = @"The stored backup is not a valid plist. Restore was refused.";
        return NO;
    }

    NSData *currentData = [NSData dataWithContentsOfFile:path];
    NSData *patchedData = [NSData dataWithContentsOfFile:paths[@"patched"]];
    if ([currentData isEqualToData:backup]) {
        [[NSFileManager defaultManager] removeItemAtPath:paths[@"patched"] error:nil];
        if (message) *message = @"The active carrier configuration already matches the verified original backup.";
        return YES;
    }
    if (!patchedData.length || ![currentData isEqualToData:patchedData]) {
        if (message) *message = @"The active carrier overlay changed after CarrierFix created its patched snapshot. Restore was refused so a carrier, SIM or eSIM update is not overwritten by a stale backup.";
        return NO;
    }

    NSString *activePath = [self resolvedCarrierPath];
    NSData *latestData = [NSData dataWithContentsOfFile:path];
    if (![activePath isEqual:path] || ![latestData isEqualToData:currentData]) {
        if (message) *message = @"The active carrier overlay changed while Restore was being prepared. Nothing was written; refresh and try again.";
        return NO;
    }

    NSString *writeError = nil;
    if (![self restoreVerifiedBackupAtPath:path metadata:meta error:&writeError]) {
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
    NSString *path = [d[@"path"] isKindOfClass:NSString.class] ? d[@"path"] : @"";
    if (!path.length || ![[self resolvedCarrierPath] isEqual:path]) {
        if (message) *message = @"The active carrier overlay changed during safety preflight. Refresh the diagnostic and try again.";
        return NO;
    }
    return [self prepareVerifiedBackupForPath:path message:message];
}

- (BOOL)hasVerifiedBackupForActiveCarrier {
    return [self backupAvailableForPath:[self resolvedCarrierPath]];
}

- (NSString *)diagnosticText {
    NSDictionary *d = [self diagnose];
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CarrierFixBuildLabel"];
    if (![version isKindOfClass:NSString.class] || !version.length) {
        version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    }
    if (![version isKindOfClass:NSString.class] || !version.length) version = @"unknown";
    if (![d[@"ok"] boolValue]) return [NSString stringWithFormat:@"CarrierFix %@\nError: %@\nPath: %@", version, d[@"message"] ?: @"Unknown", d[@"path"] ?: @""];
    return [NSString stringWithFormat:
            @"CarrierFix %@\niOS: %@\nModel: %@\nCarrier: %@\nCarrier bundle version: %@\nDetected Cricket: %@\nCarrier plist: %@\nAPN schema: %@\nWritable overlay: %@\nRecognized IMS/APN schema: %@\nVerified backup: %@\nFix currently present: %@\nSupports IMS: %@\nIMS APN: %@\nIMS ForcedFeatureTags: %@\nSMS TransportFallback: %@\nIMS SMSBundleToVoice: %@\nIMS allowCSFBInVolteMode: %@\nIMS enableInNonVoLTEMode: %@%@\n\nNo phone number, IMSI or ICCID is included in this report.",
            version, d[@"ios"], d[@"model"], d[@"carrier"], d[@"carrierBundleVersion"], [d[@"cricket"] boolValue] ? @"YES" : @"NO", d[@"path"], d[@"apnSchema"],
            [d[@"writable"] boolValue] ? @"YES" : @"NO", [d[@"schemaSafe"] boolValue] ? @"YES" : @"NO",
            [d[@"backupAvailable"] boolValue] ? @"YES" : @"NO", [d[@"fixApplied"] boolValue] ? @"YES" : @"NO",
            [d[@"supportsIMS"] boolValue] ? @"YES" : @"NO", [d[@"hasIMSAPN"] boolValue] ? @"YES" : @"NO",
            d[@"forcedFeatureTags"], d[@"smsTransportFallback"], d[@"smsBundleToVoice"], d[@"allowCSFBInVolteMode"], d[@"enableInNonVoLTEMode"],
            [d[@"schemaSafe"] boolValue] ? @"" : [NSString stringWithFormat:@"\nSchema note: %@", d[@"schemaReason"] ?: @""]];
}
@end
