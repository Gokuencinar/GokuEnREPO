#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <math.h>

static CFStringRef const COSDomain = CFSTR("com.gokuencinar.cossettings18");

@interface COSRootListController : PSListController <PHPickerViewControllerDelegate>
@end

@implementation COSRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:[NSString class]]) return nil;
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, COSDomain);
    return value ? CFBridgingRelease(value) : [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:[NSString class]] || !value) return;
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, COSDomain);
    CFPreferencesAppSynchronize(COSDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.gokuencinar.cossettings18/preferences-changed"), NULL, NULL, YES);
}

- (NSString *)backgroundFilePath {
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    return [[library stringByAppendingPathComponent:@"Preferences"]
        stringByAppendingPathComponent:@"com.gokuencinar.cossettings18-background.jpg"];
}

- (void)chooseBackground {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (![provider canLoadObjectOfClass:[UIImage class]]) return;
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
        if (error || ![object isKindOfClass:[UIImage class]]) return;
        UIImage *photo = (UIImage *)object;
        dispatch_async(dispatch_get_main_queue(), ^{
            // UIKit's drawing context should be created on the UI thread.
            CGFloat maxSide = MAX(photo.size.width, photo.size.height);
            if (!isfinite(maxSide) || maxSide < 1.0) return;
            CGFloat factor = maxSide > 1600.0 ? 1600.0 / maxSide : 1.0;
            CGSize size = CGSizeMake(photo.size.width * factor, photo.size.height * factor);
            UIGraphicsBeginImageContextWithOptions(size, YES, 1.0);
            [photo drawInRect:(CGRect){CGPointZero, size}];
            UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSData *jpeg = UIImageJPEGRepresentation(scaled, 0.85);
            if (!jpeg || jpeg.length > 8000000) return;
            if (![jpeg writeToFile:[self backgroundFilePath] atomically:YES]) return;
            CFPreferencesSetAppValue(CFSTR("backgroundImageEnabled"), kCFBooleanTrue, COSDomain);
            CFPreferencesSetAppValue(CFSTR("appearanceEnabled"), kCFBooleanTrue, COSDomain);
            CFPreferencesAppSynchronize(COSDomain);
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                CFSTR("com.gokuencinar.cossettings18/preferences-changed"), NULL, NULL, YES);
            [self reloadSpecifiers];
        });
    }];
}

- (void)clearBackground {
    [[NSFileManager defaultManager] removeItemAtPath:[self backgroundFilePath] error:NULL];
    CFPreferencesSetAppValue(CFSTR("backgroundImageEnabled"), kCFBooleanFalse, COSDomain);
    CFPreferencesAppSynchronize(COSDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.gokuencinar.cossettings18/preferences-changed"), NULL, NULL, YES);
    [self reloadSpecifiers];
}

@end
