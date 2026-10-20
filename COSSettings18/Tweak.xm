#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const COSDomain = @"com.gokuencinar.cossettings18";
static NSString *const COSGroupItemsKey = @"COSSettings18GroupItems";
static char COSOriginalBackgroundKey, COSOriginalSeparatorKey, COSGroupingBusyKey;
static char COSOriginalSpecifiersKey, COSLastGroupingConfigKey;

static id COSValue(NSString *key, id fallback) {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
        (__bridge CFStringRef)COSDomain));
    return value ?: fallback;
}

static BOOL COSBoolean(NSString *key, BOOL fallback) {
    id value = COSValue(key, @(fallback));
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

static NSString *COSString(NSString *key, NSString *fallback) {
    id value = COSValue(key, fallback);
    return [value isKindOfClass:[NSString class]] && [value length] ? value : fallback;
}

static UIColor *COSColor(NSString *key, NSString *fallback) {
    NSString *s = COSString(key, fallback);
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    if (s.length != 7 || ![s hasPrefix:@"#"] ||
        [[s substringFromIndex:1] rangeOfCharacterFromSet:[hex invertedSet]].location != NSNotFound) {
        s = fallback;
    }
    unsigned int rgb = 0;
    [[NSScanner scannerWithString:[s substringFromIndex:1]] scanHexInt:&rgb];
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
        green:((rgb >> 8) & 255) / 255.0 blue:(rgb & 255) / 255.0 alpha:1];
}

static NSString *COSBackgroundPath(void) {
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    return [[library stringByAppendingPathComponent:@"Preferences"]
        stringByAppendingPathComponent:@"com.gokuencinar.cossettings18-background.jpg"];
}

static BOOL COSIsRootController(UIViewController *controller) {
    if (!controller || !controller.isViewLoaded) return NO;
    UINavigationController *nav = controller.navigationController;
    if (nav.viewControllers.count && nav.viewControllers.firstObject == controller) return YES;
    // Some versions of Settings place the root list below a dedicated wrapper.
    UIViewController *parent = controller.parentViewController;
    return parent && [NSStringFromClass(parent.class) isEqualToString:@"PSUIPrefsRootController"];
}

@interface COSGradientView : UIView
@property (nonatomic, strong) UIColor *top;
@property (nonatomic, strong) UIColor *bottom;
@end

@implementation COSGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.top || !self.bottom) return;
    CAGradientLayer *layer = (CAGradientLayer *)self.layer;
    layer.colors = @[(__bridge id)self.top.CGColor, (__bridge id)self.bottom.CGColor];
    layer.startPoint = CGPointMake(0.5, 0);
    layer.endPoint = CGPointMake(0.5, 1);
}
@end

// This controller shows the original preference specifiers. Loading and
// navigation need physical testing with PreferenceLoader on iOS 18.
@interface COSGroupedListController : PSListController
@end

@implementation COSGroupedListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSArray *items = [self.specifier propertyForKey:COSGroupItemsKey];
        NSMutableArray *groupItems = [[NSMutableArray alloc] initWithObjects:[PSSpecifier emptyGroupSpecifier], nil];
        if ([items isKindOfClass:[NSArray class]]) [groupItems addObjectsFromArray:items];
        _specifiers = groupItems;
    }
    return _specifiers;
}
@end

static NSArray *COSGroupedSpecifiers(NSArray *original, PSListController *controller) {
    if (!COSBoolean(@"enabled", NO) || !COSBoolean(@"groupTweaks", YES) || original.count == 0) return original;
    // PreferenceLoader 2.2.8 stamps its own rows with pl_bundle. It does NOT
    // use the PREFERENCELOADER_GROUP ID found in some third-party forks.
    NSMutableIndexSet *tweakIndexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < original.count; ++i) {
        PSSpecifier *s = original[i];
        if ([[s propertyForKey:@"id"] isEqual:@"COS_SETTINGS18_GROUP"]) return original;
        if (s.cellType != PSGroupCell && [[s propertyForKey:@"pl_bundle"] isKindOfClass:[NSBundle class]])
            [tweakIndexes addIndex:i];
    }
    if (!tweakIndexes.count) return original;
    // PreferenceLoader adds an *unnamed group* followed by its consecutive
    // rows. Some PSBundleController entries have no pl_bundle property: use
    // the identifiable entries only as anchors and take the complete group.
    NSUInteger firstIndex = tweakIndexes.firstIndex;
    if (firstIndex == 0) return original;
    NSUInteger headerIndex = NSNotFound;
    for (NSUInteger i = firstIndex; i > 0; --i) {
        PSSpecifier *candidate = original[i - 1];
        if (candidate.cellType == PSGroupCell) { headerIndex = i - 1; break; }
    }
    if (headerIndex == NSNotFound || ((PSSpecifier *)original[headerIndex]).name.length != 0) return original;
    NSUInteger endIndex = original.count;
    for (NSUInteger i = headerIndex + 1; i < original.count; ++i) {
        if (((PSSpecifier *)original[i]).cellType == PSGroupCell) { endIndex = i; break; }
    }
    if (endIndex <= headerIndex + 1 || tweakIndexes.lastIndex >= endIndex) return original;

    NSMutableArray *items = [NSMutableArray new];
    for (NSUInteger i = headerIndex + 1; i < endIndex; ++i) [items addObject:original[i]];

    if (COSBoolean(@"alphabetizeTweaks", YES)) {
        [items sortUsingComparator:^NSComparisonResult(PSSpecifier *a, PSSpecifier *b) {
            return [(a.name ?: @"") localizedStandardCompare:(b.name ?: @"")];
        }];
    }

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:COSString(@"tweaksTitle", @"Mis tweaks")
        target:controller set:NULL get:NULL detail:[COSGroupedListController class]
        cell:PSLinkCell edit:nil];
    [group setProperty:items forKey:COSGroupItemsKey];
    [group setProperty:@"COS_SETTINGS18_GROUP" forKey:@"id"];
    [group setProperty:@YES forKey:@"enabled"];
    NSMutableArray *result = [original mutableCopy];
    // Preserve the source group marker. Replacing only its rows keeps every
    // other Settings group/index untouched.
    [result removeObjectsInRange:NSMakeRange(headerIndex + 1, endIndex - headerIndex - 1)];
    NSUInteger insertion = headerIndex + 1;
    if (COSBoolean(@"groupAtTop", NO)) {
        insertion = (result.count > 0 && ((PSSpecifier *)result[0]).cellType == PSGroupCell) ? 1 : 0;
    }
    [result insertObject:group atIndex:insertion];
    return result;
}

static void COSApplyGrouping(PSListController *controller) {
    if (objc_getAssociatedObject(controller, &COSGroupingBusyKey) ||
        ![controller respondsToSelector:@selector(setSpecifiers:)]) return;
    NSArray *current = [controller specifiers];
    BOOL containsOurLink = NO;
    for (PSSpecifier *s in current) {
        if ([[s propertyForKey:@"id"] isEqual:@"COS_SETTINGS18_GROUP"]) { containsOurLink = YES; break; }
    }
    NSArray *original = objc_getAssociatedObject(controller, &COSOriginalSpecifiersKey);
    if (!original || !containsOurLink) {
        original = [current copy];
        objc_setAssociatedObject(controller, &COSOriginalSpecifiersKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL enabled = COSBoolean(@"enabled", NO) && COSBoolean(@"groupTweaks", YES);
    NSString *configuration = [NSString stringWithFormat:@"%d:%d:%@",
        enabled, COSBoolean(@"alphabetizeTweaks", YES), COSString(@"tweaksTitle", @"Mis tweaks")];
    configuration = [configuration stringByAppendingFormat:@":%d", COSBoolean(@"groupAtTop", NO)];
    NSString *lastConfiguration = objc_getAssociatedObject(controller, &COSLastGroupingConfigKey);
    if ([configuration isEqualToString:lastConfiguration] && (containsOurLink == enabled)) return;
    NSArray *grouped = enabled ? COSGroupedSpecifiers(original, controller) : original;
    if (grouped == original && !containsOurLink) {
        objc_setAssociatedObject(controller, &COSLastGroupingConfigKey, configuration, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return;
    }
    objc_setAssociatedObject(controller, &COSGroupingBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [controller setSpecifiers:grouped];
    objc_setAssociatedObject(controller, &COSGroupingBusyKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(controller, &COSLastGroupingConfigKey, configuration, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void COSApplyAppearance(PSListController *controller) {
    if (!COSIsRootController(controller)) return;
    SEL tableSelector = [controller respondsToSelector:@selector(tableView)] ?
        @selector(tableView) : ([controller respondsToSelector:@selector(table)] ? @selector(table) : NULL);
    if (!tableSelector) return;
    UITableView *(*getTable)(id, SEL) = (UITableView *(*)(id, SEL))objc_msgSend;
    UITableView *table = getTable(controller, tableSelector);
    if (![table isKindOfClass:[UITableView class]]) return;

    if (!objc_getAssociatedObject(table, &COSOriginalSeparatorKey)) {
        objc_setAssociatedObject(table, &COSOriginalSeparatorKey, @(table.separatorStyle + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(table, &COSOriginalBackgroundKey, table.backgroundView ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL enabled = COSBoolean(@"appearanceEnabled", NO);
    BOOL gradient = enabled && COSBoolean(@"gradientEnabled", YES);
    BOOL useImage = enabled && COSBoolean(@"backgroundImageEnabled", NO);
    BOOL hideSeparators = enabled && COSBoolean(@"hideSeparators", NO);
    table.separatorStyle = hideSeparators ? UITableViewCellSeparatorStyleNone :
        ([objc_getAssociatedObject(table, &COSOriginalSeparatorKey) integerValue] - 1);

    UIImage *image = useImage ? [UIImage imageWithContentsOfFile:COSBackgroundPath()] : nil;
    if (image) {
        UIView *background = [[UIView alloc] initWithFrame:table.bounds];
        background.clipsToBounds = YES;
        background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:background.bounds];
        imageView.image = image;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:imageView];
        if (COSBoolean(@"backgroundBlurEnabled", NO) && !UIAccessibilityIsReduceTransparencyEnabled()) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
                [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
            blur.frame = background.bounds;
            blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [background addSubview:blur];
        }
        table.backgroundView = background;
    } else if (gradient) {
        COSGradientView *view = [[COSGradientView alloc] initWithFrame:table.bounds];
        view.top = COSColor(@"gradientTop", @"#15263A");
        view.bottom = COSColor(@"gradientBottom", @"#536A85");
        table.backgroundView = view;
    } else {
        id original = objc_getAssociatedObject(table, &COSOriginalBackgroundKey);
        table.backgroundView = original == [NSNull null] ? nil : original;
    }
}

%group ModernSettings
%hook PSUIPrefsListController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    COSApplyGrouping(self);
    COSApplyAppearance(self);
}

%end
%end

%group LegacySettings
%hook PrefsListController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    COSApplyGrouping(self);
    COSApplyAppearance(self);
}

%end
%end

%ctor {
    @autoreleasepool {
        Class modern = objc_getClass("PSUIPrefsListController");
        Class legacy = objc_getClass("PrefsListController");
        if (modern && class_getInstanceMethod(modern, @selector(viewWillAppear:)) &&
            class_getInstanceMethod(modern, @selector(setSpecifiers:))) %init(ModernSettings);
        if (legacy && legacy != modern && class_getInstanceMethod(legacy, @selector(viewWillAppear:)) &&
            class_getInstanceMethod(legacy, @selector(setSpecifiers:))) %init(LegacySettings);
    }
}
