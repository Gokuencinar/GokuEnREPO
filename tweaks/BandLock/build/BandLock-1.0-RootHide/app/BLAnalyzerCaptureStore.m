#import "BLAnalyzerCaptureStore.h"
#import "BLLocalization.h"

static NSString *const BLAnalyzerCaptureIndexKey = @"BLAnalyzerCaptureIndex.v1";
static NSString *const BLAnalyzerCaptureDirectoryName = @"BandLockAnalyzerCaptures";

@implementation BLAnalyzerCaptureStore

+ (NSURL *)captureDirectoryURL {
    NSURL *base = [[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                        inDomains:NSUserDomainMask] firstObject];
    if (!base) return nil;
    NSURL *directory = [base URLByAppendingPathComponent:BLAnalyzerCaptureDirectoryName isDirectory:YES];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory
                                withIntermediateDirectories:YES attributes:nil error:&error]) return nil;
    return directory;
}

+ (NSURL *)URLForCapture:(NSDictionary *)capture {
    NSString *filename = [capture[@"filename"] isKindOfClass:NSString.class] ? capture[@"filename"] : nil;
    if (!filename.length || ![filename isEqualToString:filename.lastPathComponent] ||
        [[filename pathExtension] caseInsensitiveCompare:@"png"] != NSOrderedSame) return nil;
    NSURL *directory = [self captureDirectoryURL];
    return directory ? [directory URLByAppendingPathComponent:filename isDirectory:NO] : nil;
}

+ (NSArray<NSDictionary *> *)captures {
    NSArray *raw = [NSUserDefaults.standardUserDefaults arrayForKey:BLAnalyzerCaptureIndexKey];
    if (![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSDictionary *> *valid = [NSMutableArray array];
    for (id candidate in raw) {
        if (![candidate isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *item = candidate;
        NSString *captureID = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : nil;
        NSString *mode = [item[@"mode"] isKindOfClass:NSString.class] ? item[@"mode"] : nil;
        NSNumber *created = [item[@"created_at"] isKindOfClass:NSNumber.class] ? item[@"created_at"] : nil;
        NSURL *url = [self URLForCapture:item];
        if (!captureID.length || !mode.length || !created || !url ||
            ![NSFileManager.defaultManager fileExistsAtPath:url.path]) continue;
        [valid addObject:item];
    }
    [valid sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [right[@"created_at"] compare:left[@"created_at"]];
    }];
    if (valid.count != raw.count)
        [NSUserDefaults.standardUserDefaults setObject:valid forKey:BLAnalyzerCaptureIndexKey];
    return valid;
}

+ (NSDictionary *)saveImage:(UIImage *)image
                        mode:(NSString *)mode
                operatorName:(NSString *)operatorName
                       error:(NSError **)error {
    NSData *png = UIImagePNGRepresentation(image);
    if (!png.length) {
        if (error) *error = [NSError errorWithDomain:@"BandLockCapture" code:1
            userInfo:@{NSLocalizedDescriptionKey: BLT(@"No se pudo crear la captura.", @"Could not create the capture.")}];
        return nil;
    }
    NSURL *directory = [self captureDirectoryURL];
    if (!directory) {
        if (error) *error = [NSError errorWithDomain:@"BandLockCapture" code:2
            userInfo:@{NSLocalizedDescriptionKey: BLT(@"No se pudo acceder al almacenamiento.", @"Could not access storage.")}];
        return nil;
    }
    NSString *captureID = NSUUID.UUID.UUIDString;
    NSString *filename = [NSString stringWithFormat:@"%@.png", captureID];
    NSURL *url = [directory URLByAppendingPathComponent:filename isDirectory:NO];
    NSError *writeError = nil;
    if (![png writeToURL:url options:NSDataWritingAtomic error:&writeError]) {
        if (error) *error = [NSError errorWithDomain:@"BandLockCapture" code:3
            userInfo:@{NSLocalizedDescriptionKey: BLT(@"No se pudo guardar la captura.", @"Could not save the capture.")}];
        return nil;
    }

    NSMutableDictionary *metadata = [@{
        @"id": captureID,
        @"filename": filename,
        @"created_at": @(NSDate.date.timeIntervalSince1970),
        @"mode": mode.length ? mode : @"AUTO"
    } mutableCopy];
    NSString *cleanOperator = [operatorName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (cleanOperator.length) metadata[@"operator_name"] = cleanOperator;

    NSMutableArray *all = [[self captures] mutableCopy];
    [all insertObject:metadata atIndex:0];
    [NSUserDefaults.standardUserDefaults setObject:all forKey:BLAnalyzerCaptureIndexKey];
    return metadata;
}

+ (BOOL)deleteCapture:(NSDictionary *)capture error:(NSError **)error {
    NSURL *url = [self URLForCapture:capture];
    if (url && [NSFileManager.defaultManager fileExistsAtPath:url.path]) {
        NSError *removeError = nil;
        if (![NSFileManager.defaultManager removeItemAtURL:url error:&removeError]) {
            if (error) *error = [NSError errorWithDomain:@"BandLockCapture" code:4
                userInfo:@{NSLocalizedDescriptionKey: BLT(@"No se pudo eliminar la captura.", @"Could not delete the capture.")}];
            return NO;
        }
    }
    NSString *captureID = [capture[@"id"] isKindOfClass:NSString.class] ? capture[@"id"] : nil;
    NSMutableArray *all = [[self captures] mutableCopy];
    NSIndexSet *matches = [all indexesOfObjectsPassingTest:^BOOL(id item, NSUInteger idx, BOOL *stop) {
        return captureID.length && [item isKindOfClass:NSDictionary.class] &&
               [((NSDictionary *)item)[@"id"] isEqualToString:captureID];
    }];
    if (matches.count) [all removeObjectsAtIndexes:matches];
    [NSUserDefaults.standardUserDefaults setObject:all forKey:BLAnalyzerCaptureIndexKey];
    return YES;
}

+ (NSString *)displayMode:(NSString *)mode {
    if ([mode isEqualToString:@"LTE"]) return @"4G";
    if ([mode isEqualToString:@"NR"]) return @"5G";
    if ([mode isEqualToString:@"AUTO"]) return @"Auto";
    if ([mode isEqualToString:@"LIVE"]) return BLT(@"En vivo", @"Live");
    return mode.length ? mode : @"—";
}

+ (NSString *)displayTitleForCapture:(NSDictionary *)capture {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[capture[@"created_at"] doubleValue]];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"dd/MM/yy HH:mm:ss";
    return [NSString stringWithFormat:@"%@ · %@", [formatter stringFromDate:date],
            [self displayMode:capture[@"mode"]]];
}

@end
