#import "CFCarrierManager.h"
#import <sys/utsname.h>
#import <sys/stat.h>
#import <limits.h>
#import <stdlib.h>

static NSString * const CFCarrierPreferencePath = @"/private/var/mobile/Library/Preferences/com.apple.carrier.plist";
static NSString * const CFBackupDirectory = @"/private/var/mobile/Library/CarrierFix";
static NSString * const CFBackupPath = @"/private/var/mobile/Library/CarrierFix/original-carrier.plist";
static NSString * const CFMetadataPath = @"/private/var/mobile/Library/CarrierFix/metadata.plist";

@implementation CFCarrierManager

- (NSString *)resolvedCarrierPath {
    char resolved[PATH_MAX] = {0};
    if (realpath(CFCarrierPreferencePath.fileSystemRepresentation, resolved)) {
        return [NSString stringWithUTF8String:resolved];
    }
    return CFCarrierPreferencePath;
}

- (NSDictionary *)carrierDictionaryAtPath:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
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
    for (NSDictionary *item in images) {
        NSString *name = [item[@"StatusBarCarrierName"] isKindOfClass:NSString.class] ? item[@"StatusBarCarrierName"] : @"";
        if ([name rangeOfString:@"Cricket" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    NSArray *sims = [carrier[@"SupportedSIMs"] isKindOfClass:NSArray.class] ? carrier[@"SupportedSIMs"] : @[];
    for (id value in sims) {
        NSString *s = [value description];
        if ([s hasPrefix:@"310150"]) return YES;
    }
    return NO;
}

- (NSDictionary *)diagnose {
    NSString *path = [self resolvedCarrierPath];
    NSDictionary *carrier = [self carrierDictionaryAtPath:path];
    if (!carrier) {
        return @{ @"ok": @NO,
                  @"path": path ?: @"",
                  @"message": @"Could not read the active carrier plist." };
    }

    NSDictionary *ims = [carrier[@"IMSConfig"] isKindOfClass:NSDictionary.class] ? carrier[@"IMSConfig"] : @{};
    NSDictionary *signaling = [ims[@"Signaling"] isKindOfClass:NSDictionary.class] ? ims[@"Signaling"] : @{};
    NSDictionary *imsSMS = [ims[@"SMS"] isKindOfClass:NSDictionary.class] ? ims[@"SMS"] : @{};
    NSDictionary *smsSettings = [carrier[@"SMSSettings"] isKindOfClass:NSDictionary.class] ? carrier[@"SMSSettings"] : @{};
    NSString *carrierName = [carrier[@"CarrierName"] isKindOfClass:NSString.class] ? carrier[@"CarrierName"] : @"Unknown";
    NSString *forcedTags = [signaling[@"ForcedFeatureTags"] isKindOfClass:NSString.class] ? signaling[@"ForcedFeatureTags"] : @"(missing)";

    BOOL hasIMSAPN = NO;
    NSArray *apns = [carrier[@"apns"] isKindOfClass:NSArray.class] ? carrier[@"apns"] : @[];
    for (NSDictionary *group in apns) {
        NSArray *configs = [group[@"configuration"] isKindOfClass:NSArray.class] ? group[@"configuration"] : @[];
        for (NSDictionary *cfg in configs) {
            if ([cfg[@"apn"] isKindOfClass:NSString.class] && [cfg[@"apn"] caseInsensitiveCompare:@"ims"] == NSOrderedSame) {
                hasIMSAPN = YES;
            }
        }
    }

    return @{ @"ok": @YES,
              @"path": path ?: @"",
              @"carrier": carrierName,
              @"cricket": @([self dictionaryLooksCricket:carrier path:path]),
              @"ios": UIDevice.currentDevice.systemVersion ?: @"",
              @"model": [self machineIdentifier],
              @"supportsIMS": @([carrier[@"SupportsImsCapability"] boolValue]),
              @"forcedFeatureTags": forcedTags,
              @"hasIMSAPN": @(hasIMSAPN),
              @"smsTransportFallback": smsSettings[@"TransportFallback"] ?: @"(missing)",
              @"smsBundleToVoice": imsSMS[@"SMSBundleToVoice"] ?: @"(missing)",
              @"allowCSFBInVolteMode": imsSMS[@"allowCSFBInVolteMode"] ?: @"(missing)" };
}

- (BOOL)isCricketConfiguration:(NSDictionary *)diagnosis {
    return [diagnosis[@"cricket"] boolValue];
}

- (BOOL)ensureBackupForPath:(NSString *)path carrier:(NSDictionary *)carrier error:(NSString **)errorText {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    if (![fm createDirectoryAtPath:CFBackupDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) {
        if (errorText) *errorText = error.localizedDescription;
        return NO;
    }
    if (![fm fileExistsAtPath:CFBackupPath]) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data.length || ![data writeToFile:CFBackupPath options:NSDataWritingAtomic error:&error]) {
            if (errorText) *errorText = error.localizedDescription ?: @"Could not save carrier backup.";
            return NO;
        }
        NSDictionary *meta = @{ @"sourcePath": path ?: @"",
                                @"created": NSDate.date,
                                @"carrier": carrier[@"CarrierName"] ?: @"Unknown",
                                @"ios": UIDevice.currentDevice.systemVersion ?: @"" };
        [meta writeToFile:CFMetadataPath atomically:YES];
    }
    return YES;
}

- (BOOL)writeCarrier:(NSDictionary *)carrier toPath:(NSString *)path error:(NSString **)errorText {
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:carrier format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        if (errorText) *errorText = error.localizedDescription ?: @"Could not write the active carrier overlay.";
        return NO;
    }
    chmod(path.fileSystemRepresentation, 0644);
    return YES;
}

- (BOOL)applyCricketSMSFix:(NSString **)message {
    NSString *path = [self resolvedCarrierPath];
    NSDictionary *original = [self carrierDictionaryAtPath:path];
    if (!original) {
        if (message) *message = @"The active carrier plist could not be read.";
        return NO;
    }
    if (![self dictionaryLooksCricket:original path:path]) {
        if (message) *message = @"CarrierFix did not detect a Cricket / ATT_aio carrier configuration. No changes were made.";
        return NO;
    }

    NSString *backupError = nil;
    if (![self ensureBackupForPath:path carrier:original error:&backupError]) {
        if (message) *message = [NSString stringWithFormat:@"Backup failed: %@", backupError ?: @"unknown error"];
        return NO;
    }

    NSMutableDictionary *carrier = [original mutableCopy];
    carrier[@"SupportsImsCapability"] = @YES;
    carrier[@"SendTextMMSToShortCodeAsSMS"] = @YES;

    NSMutableDictionary *smsSettings = [([carrier[@"SMSSettings"] isKindOfClass:NSDictionary.class] ? carrier[@"SMSSettings"] : @{}) mutableCopy];
    smsSettings[@"TransportFallback"] = @NO;
    carrier[@"SMSSettings"] = smsSettings;

    NSMutableDictionary *ims = [([carrier[@"IMSConfig"] isKindOfClass:NSDictionary.class] ? carrier[@"IMSConfig"] : @{}) mutableCopy];
    NSMutableDictionary *signaling = [([ims[@"Signaling"] isKindOfClass:NSDictionary.class] ? ims[@"Signaling"] : @{}) mutableCopy];
    signaling[@"ForcedFeatureTags"] = @"voice,sms";
    if (!signaling[@"RegistrationPolicy"]) signaling[@"RegistrationPolicy"] = @"ATT";
    ims[@"Signaling"] = signaling;

    NSMutableDictionary *imsSMS = [([ims[@"SMS"] isKindOfClass:NSDictionary.class] ? ims[@"SMS"] : @{}) mutableCopy];
    imsSMS[@"SMSBundleToVoice"] = @NO;
    imsSMS[@"allowCSFBInVolteMode"] = @NO;
    ims[@"SMS"] = imsSMS;
    carrier[@"IMSConfig"] = ims;

    NSMutableArray *apnGroups = [([carrier[@"apns"] isKindOfClass:NSArray.class] ? carrier[@"apns"] : @[]) mutableCopy];
    BOOL foundIMS = NO;
    for (NSUInteger i = 0; i < apnGroups.count; i++) {
        NSDictionary *group = [apnGroups[i] isKindOfClass:NSDictionary.class] ? apnGroups[i] : nil;
        if (!group) continue;
        NSMutableDictionary *mutableGroup = [group mutableCopy];
        NSMutableArray *configs = [([group[@"configuration"] isKindOfClass:NSArray.class] ? group[@"configuration"] : @[]) mutableCopy];
        for (NSUInteger j = 0; j < configs.count; j++) {
            NSDictionary *cfg = [configs[j] isKindOfClass:NSDictionary.class] ? configs[j] : nil;
            if (![cfg[@"apn"] isKindOfClass:NSString.class] || [cfg[@"apn"] caseInsensitiveCompare:@"ims"] != NSOrderedSame) continue;
            NSMutableDictionary *m = [cfg mutableCopy];
            m[@"type-mask"] = @131072;
            m[@"tech-type-mask"] = @131072;
            m[@"AllowedProtocolMask"] = @3;
            m[@"AllowedProtocolMaskInRoaming"] = @3;
            m[@"SupportSwitchOver"] = @YES;
            configs[j] = m;
            foundIMS = YES;
        }
        mutableGroup[@"configuration"] = configs;
        apnGroups[i] = mutableGroup;
    }
    if (!foundIMS) {
        NSMutableDictionary *group = apnGroups.count && [apnGroups[0] isKindOfClass:NSDictionary.class] ? [apnGroups[0] mutableCopy] : [@{ @"technology-mask": @25, @"configuration": @[] } mutableCopy];
        NSMutableArray *configs = [([group[@"configuration"] isKindOfClass:NSArray.class] ? group[@"configuration"] : @[]) mutableCopy];
        [configs addObject:@{ @"apn": @"ims", @"username": @"", @"password": @"", @"type-mask": @131072, @"tech-type-mask": @131072, @"AllowedProtocolMask": @3, @"AllowedProtocolMaskInRoaming": @3, @"SupportSwitchOver": @YES }];
        group[@"configuration"] = configs;
        if (apnGroups.count) apnGroups[0] = group; else [apnGroups addObject:group];
    }
    carrier[@"apns"] = apnGroups;

    NSString *writeError = nil;
    if (![self writeCarrier:carrier toPath:path error:&writeError]) {
        if (message) *message = [NSString stringWithFormat:@"Write failed: %@", writeError ?: @"unknown error"];
        return NO;
    }

    NSDictionary *verify = [self diagnose];
    BOOL good = [verify[@"supportsIMS"] boolValue] && [verify[@"hasIMSAPN"] boolValue] && [verify[@"forcedFeatureTags"] isEqual:@"voice,sms"];
    if (!good) {
        if (message) *message = @"The overlay was written, but verification did not see all expected IMS/SMS keys. Use Restore Original before rebooting.";
        return NO;
    }

    if (message) *message = @"Cricket IMS/SMS compatibility keys were applied and verified. Toggle Airplane Mode for about 30 seconds, then test an SMS to an Android number. If service gets worse, reopen CarrierFix and use Restore Original.";
    return YES;
}

- (BOOL)restoreOriginal:(NSString **)message {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:CFBackupPath]) {
        if (message) *message = @"No CarrierFix backup exists on this device.";
        return NO;
    }
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:CFMetadataPath] ?: @{};
    NSString *path = [meta[@"sourcePath"] isKindOfClass:NSString.class] && [meta[@"sourcePath"] length] ? meta[@"sourcePath"] : [self resolvedCarrierPath];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:CFBackupPath];
    if (!data.length || ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        if (message) *message = [NSString stringWithFormat:@"Restore failed: %@", error.localizedDescription ?: @"unknown error"];
        return NO;
    }
    chmod(path.fileSystemRepresentation, 0644);
    if (message) *message = @"Original carrier configuration restored. Toggle Airplane Mode for about 30 seconds or reboot before testing again.";
    return YES;
}

- (NSString *)diagnosticText {
    NSDictionary *d = [self diagnose];
    if (![d[@"ok"] boolValue]) return [NSString stringWithFormat:@"CarrierFix 0.1.0\nError: %@\nPath: %@", d[@"message"] ?: @"Unknown", d[@"path"] ?: @""];
    return [NSString stringWithFormat:
            @"CarrierFix 0.1.0\niOS: %@\nModel: %@\nCarrier: %@\nDetected Cricket: %@\nCarrier plist: %@\nSupports IMS: %@\nIMS APN: %@\nIMS ForcedFeatureTags: %@\nSMS TransportFallback: %@\nIMS SMSBundleToVoice: %@\nIMS allowCSFBInVolteMode: %@\n\nNo phone number, IMSI or ICCID is included in this report.",
            d[@"ios"], d[@"model"], d[@"carrier"], [d[@"cricket"] boolValue] ? @"YES" : @"NO", d[@"path"],
            [d[@"supportsIMS"] boolValue] ? @"YES" : @"NO", [d[@"hasIMSAPN"] boolValue] ? @"YES" : @"NO",
            d[@"forcedFeatureTags"], d[@"smsTransportFallback"], d[@"smsBundleToVoice"], d[@"allowCSFBInVolteMode"]];
}
@end
